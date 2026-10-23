/// 极光推送(离线推送)封装
/// * 对齐后端《APP推送接口文档》: bind / unbind + 通知点击跳转(extras 的 type/id)
/// * 职责: 初始化 / 通知权限 / RegistrationID 上报 / alias(会员id)绑定 / 点击跳转 / 角标清理
/// * 设计原则: 任何一步失败都只打日志, 绝不影响 App 启动与其他功能
/// * 未配置 Config.jpushAppKey 时整体跳过(视为未接入)
library;

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
// jpush_flutter.dart 只 import 不 export: 接口类(JPushFlutterInterface / NotificationSettingsIOS)
// 要从这个文件单独导入
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/push.dart';
import '../config/index.dart';
import '../controller/auth_store.dart';
import 'index.dart';
import 'platform.dart';

class PushService {
  PushService._();
  static final PushService to = PushService._();

  // 本地存储键
  static const String _ridKey = 'jpush_registration_id';
  static const String _aliasKey = 'jpush_alias';

  final GetStorage _box = GetStorage();
  // 懒加载: web / 桌面端不会走到 _supported 判断之后, 也就不会真正构造(其内部用 dart:io)
  late final JPushFlutterInterface _jpush = JPush.newJPush();

  bool _inited = false;

  /// 当前 RegistrationID(极光推送唯一标识, 后端按它推单设备)
  String registrationId = '';

  /// 当前已设置的 alias(形如 member_123)
  String? _alias;

  /// 是否支持极光推送: 仅 Android / iOS(web 与桌面端没有对应 SDK)
  bool get _supported {
    final TargetPlatform p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  /// 初始化(在 runApp 之后调用, 不阻塞首帧)
  Future<void> init() async {
    if (_inited) return;
    if (kIsWeb || !_supported) {
      debugPrint('[push] 当前平台(${PlatformInfo.osType})不支持极光推送, 跳过初始化');
      return;
    }
    if (Config.jpushAppKey.isEmpty) {
      debugPrint('[push] 未配置 Config.jpushAppKey, 跳过极光推送初始化');
      return;
    }

    try {
      // 1. 初始化: appKey 由 Dart 传入, Android 侧无需再配 manifestPlaceholders
      // * production 必须与服务端 .env 的 APNS_PRODUCTION 一致, 否则 iOS 收不到
      _jpush.setup(
        appKey: Config.jpushAppKey,
        channel: Config.jpushChannel,
        production: Config.jpushProduction,
        debug: kDebugMode,
      );

      // 2. 事件监听(插件只提供 add 没有 remove, 单例里注册一次即可)
      _jpush.addEventHandler(
        onReceiveNotification: _onReceiveNotification,
        onOpenNotification: _onOpenNotification,
        onReceiveMessage: _onReceiveMessage,
        onReceiveNotificationAuthorization: _onNotificationAuthorization,
        onCommandResult: _onCommandResult,
        onConnected: _onConnected,
      );

      // 3. 通知权限: Android 13+ 运行时权限(SDK 自建渠道); iOS 申请授权并自动注册 APNs
      _jpush.requestRequiredPermission();
      _jpush.applyPushAuthority(const NotificationSettingsIOS());

      // 4. RegistrationID: 拿到后上报(rid 变化才上报)
      await _syncRegistrationId();

      // 5. 登录态联动: 登录后带 token 再 bind + 绑 alias, 退出后解绑 + 清 alias
      _watchAuth();

      // 6. 冷启动: 用户点通知栏拉起 App 时, 首帧后再跳目标页
      unawaited(_handleLaunchNotification());

      _inited = true;
      debugPrint('[push] 极光推送初始化完成(rid=${registrationId.isEmpty ? '未就绪' : registrationId})');
    } catch (e) {
      debugPrint('[push] 极光推送初始化异常: $e');
    }
  }

  /// 登录态联动: 用 GetX worker 而不是改 AuthStore, 避免 controller -> utils -> controller 循环依赖
  void _watchAuth() {
    if (!Get.isRegistered<AuthStore>()) return;
    final AuthStore auth = AuthStore.to;
    ever(auth.authorization, (_) => _onAuthChanged());
    // memberInfo 后到: 登录瞬间 member_id 可能还是 0, 会员信息回来后再补绑一次 alias
    ever(auth.memberInfo, (_) => _syncAlias());
  }

  /// 登录 / 退出登录
  Future<void> _onAuthChanged() async {
    if (!_inited) return;
    final AuthStore? auth = Get.isRegistered<AuthStore>() ? AuthStore.to : null;
    if (auth == null) return;

    if (auth.isLogin) {
      // 登录成功: 带 token 再 bind 一次, 把设备与账号关联(未登录时那次只登记了设备)
      if (registrationId.isNotEmpty) await _bindDevice();
      await _syncAlias();
      return;
    }
    // 退出登录: 先解绑设备(服务端解绑该用户所有设备), 再清 alias
    await _unbindDevice();
    await _clearAlias();
  }

  // ===== RegistrationID / 设备上报 =====

  /// 拉取 RegistrationID, 与本地记录不一致时上报后端
  Future<void> _syncRegistrationId() async {
    String rid = '';
    try {
      // 首启时要等长连接建立才有 rid, 这里等一下; 拿不到不阻塞(_onConnected 会再同步)
      rid = (await _jpush.getRegistrationID().timeout(const Duration(seconds: 15))).trim();
    } catch (_) {}
    if (rid.isEmpty) {
      debugPrint('[push] 暂未拿到 RegistrationID, 等长连接建立后自动同步');
      return;
    }
    registrationId = rid;
    if (_box.read<String>(_ridKey) == rid) return;
    _box.write(_ridKey, rid);
    await _bindDevice();
  }

  /// 上报设备(POST /api/push/bind)
  /// * 已登录时 Request 拦截器会自动带上 token, 服务端据此绑定 member_id
  Future<void> _bindDevice() async {
    if (registrationId.isEmpty) return;
    final Map<String, String> device = await _deviceInfo();
    final PackageInfo info = await PackageInfo.fromPlatform();
    final bool ok = await PushApi.bind(
      registrationId: registrationId,
      platform: PlatformInfo.osType, // ios / android(小写, 后端要求)
      deviceBrand: device['brand'] ?? '',
      deviceModel: device['model'] ?? '',
      systemVersion: device['system'] ?? '',
      appVersion: '${info.version}(${info.buildNumber})',
    );
    debugPrint('[push] 上报设备(rid=$registrationId, platform=${PlatformInfo.osType}): '
        '${ok ? '成功' : '失败'}');
  }

  /// 解绑设备(POST /api/push/unbind)
  /// * 不传 registration_id: 服务端解绑该用户所有设备(换账号更彻底)
  Future<void> _unbindDevice() async {
    final bool ok = await PushApi.unbind();
    debugPrint('[push] 解绑设备: ${ok ? '成功' : '失败'}');
  }

  /// 厂商 / 机型 / 系统版本(后台用来判断该走哪家厂商通道, 排查「杀进程收不到」用)
  Future<Map<String, String>> _deviceInfo() async {
    final Map<String, String> info = <String, String>{};
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidDeviceInfo android = await plugin.androidInfo;
        info['brand'] = android.brand;
        info['model'] = android.model;
        info['system'] = android.version.release;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final IosDeviceInfo ios = await plugin.iosInfo;
        info['brand'] = 'apple';
        // utsname.machine 是机型标识(iPhone14,2 / iPad13,1), 比 model 的 "iPhone" 更有排查价值
        info['model'] = ios.utsname.machine;
        info['system'] = ios.systemVersion;
      }
    } catch (_) {}
    return info;
  }

  // ===== alias =====

  /// 同步 alias: 登录且拿到 member_id 时绑 member_<id>, 退出时删除
  Future<void> _syncAlias() async {
    if (!_inited) return;
    final AuthStore? auth = Get.isRegistered<AuthStore>() ? AuthStore.to : null;
    if (auth == null) return;

    final String alias = auth.isLogin && auth.memberId > 0 ? 'member_${auth.memberId}' : '';
    if (alias.isEmpty) {
      await _clearAlias();
      return;
    }
    if (_alias == alias) return;
    _alias = alias;
    _box.write(_aliasKey, alias);
    final Map<dynamic, dynamic> res = await _jpush.setAlias(alias);
    debugPrint('[push] 设置 alias=$alias: $res');
  }

  /// 清掉上一个账号的 alias, 避免退出后还收到个人推送
  Future<void> _clearAlias() async {
    if (_alias == null) return;
    _alias = null;
    _box.remove(_aliasKey);
    final Map<dynamic, dynamic> res = await _jpush.deleteAlias();
    debugPrint('[push] 删除 alias: $res');
  }

  // ===== 事件回调 =====

  /// 收到通知(App 在前台也会回调, 默认仍展示通知栏)
  Future<dynamic> _onReceiveNotification(Map<String, dynamic> event) async {
    final Map<String, dynamic> payload = _payloadOf(event);
    debugPrint('[push] 收到通知: ${payload['title']} | ${payload['content']}');
    return null;
  }

  /// 点击通知栏消息 -> 按 extras 的 type/id 跳转
  Future<dynamic> _onOpenNotification(Map<String, dynamic> event) async {
    final Map<String, dynamic> payload = _payloadOf(event);
    final String target = _targetOf(payload);
    debugPrint('[push] 点击通知: ${payload['title']} | 跳转 $target');
    await _clearBadge();
    if (target.isNotEmpty) await Utils.openAppLink(target);
    return null;
  }

  /// 透传消息(服务端自定义消息, 不展示通知栏)
  Future<dynamic> _onReceiveMessage(Map<String, dynamic> event) async {
    debugPrint('[push] 收到透传消息: $event');
    return null;
  }

  /// iOS 通知权限状态
  Future<dynamic> _onNotificationAuthorization(Map<String, dynamic> event) async {
    debugPrint('[push] 通知权限状态: $event');
    return null;
  }

  /// setAlias / getRegistrationID 等命令的结果(code 0 为成功)
  Future<dynamic> _onCommandResult(Map<String, dynamic> event) async {
    debugPrint('[push] 命令结果: $event');
    return null;
  }

  /// 长连接建立: rid 可能已变化, 重新同步一次
  Future<dynamic> _onConnected(Map<String, dynamic> event) async {
    debugPrint('[push] 极光长连接已建立');
    await _syncRegistrationId();
    return null;
  }

  // ===== 跳转 =====

  /// 按 extras 里的 type / id 生成跳转路径(与后端文档第五节一致)
  /// * order  订单      -> /order/detail?order_id=
  /// * refund 退款      -> /order/refund_detail?order_goods_id=
  /// * coupon 优惠券    -> /my/coupon
  /// * live   直播      -> /live?sn=(直播间进房要的是房间号 sn, 不是数据库 id)
  /// * system 系统公告  -> /notice/detail(有 title/content 时直接展示, 否则 /notice)
  /// * 其他/缺省         -> /notice
  String _targetOf(Map<String, dynamic> payload) {
    final Map<String, dynamic> extras = payload['extras'] is Map
        ? (payload['extras'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final String type = _text(extras['type']);
    final String id = _text(extras['id']);
    final String Function(String) q = Uri.encodeQueryComponent;

    switch (type) {
      case 'order':
        final String orderId = id.isNotEmpty ? id : _text(extras['order_id']);
        return orderId.isEmpty ? '/order' : '/order/detail?order_id=${q(orderId)}';
      case 'refund':
        final String refundId = id.isNotEmpty ? id : _text(extras['order_goods_id']);
        return refundId.isEmpty
            ? '/order/refund_list'
            : '/order/refund_detail?order_goods_id=${q(refundId)}';
      case 'coupon':
        return '/my/coupon';
      case 'live':
        // 直播间进房要「房间号 sn」(见 live.dart 的 arguments['sn']);
        // 后台按文档发的是 id, 优先用 sn, 没有 sn 时才拿 id 顶一下
        final String sn = _text(extras['sn']);
        if (sn.isEmpty && id.isEmpty) return '/live/list';
        return '/live?sn=${q(sn.isNotEmpty ? sn : id)}';
      case 'system':
        final String title = _text(extras['title']);
        final String content = _text(extras['content']);
        // 公告详情页直接用 title/content, 不单独请求详情接口
        if (title.isNotEmpty || content.isNotEmpty) {
          return '/notice/detail?title=${q(title)}&content=${q(content)}';
        }
        return '/notice';
      default:
        return '/notice';
    }
  }

  // ===== 工具 =====

  /// 取出事件里的消息体
  /// * Android 侧外面包了一层: { message: { title, content, extras } }
  /// * iOS 侧直接就是: { title, content, extras, badge, ... }
  Map<String, dynamic> _payloadOf(Map<String, dynamic> event) {
    final dynamic inner = event['message'];
    return inner is Map ? inner.cast<String, dynamic>() : event;
  }

  String _text(dynamic v) {
    final String s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  /// 清角标(iOS 生效; Android 通知栏由系统管理)
  Future<void> _clearBadge() async {
    try {
      await _jpush.setBadge(0);
    } catch (_) {}
  }

  /// 冷启动: 用户通过点击通知栏拉起 App 时, 跳转到通知指定的页面
  Future<void> _handleLaunchNotification() async {
    try {
      final Map<dynamic, dynamic> res = await _jpush.getLaunchAppNotification();
      if (res.isEmpty) return;
      final dynamic message = res['message'] ?? res;
      if (message is! Map) return;
      final String target = _targetOf(message.cast<String, dynamic>());
      if (target.isEmpty) return;
      // 等首帧与路由表就绪再跳(此刻可能还在启动图 / 隐私协议页)
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await Utils.openAppLink(target);
    } catch (_) {}
  }

  /// 清空通知栏 + 角标
  Future<void> clearNotifications() async {
    if (!_inited) return;
    try {
      await _jpush.clearAllNotifications();
      await _jpush.setBadge(0);
    } catch (_) {}
  }
}
