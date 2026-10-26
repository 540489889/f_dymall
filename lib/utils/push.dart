/// 极光推送(离线推送)封装
/// * 对齐后端《APP推送接口文档》: bind / unbind + 通知点击跳转(extras 的 type/id)
/// * 职责: 初始化 / 通知权限 / RegistrationID 上报 / alias(会员id)绑定 / 点击跳转 / 角标清理
/// * 设计原则: 任何一步失败都只打日志, 绝不影响 App 启动与其他功能
/// * 未配置 Config.jpushAppKey 时整体跳过(视为未接入)
library;

import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
import '../controller/main_tab.dart';
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

  /// 本会话内已上报过的 rid(内存级, 仅防止命令回调多次下发时重复 bind;
  /// 不要用持久化值判重——登录态变化需要重新 bind, 且覆盖安装会残留旧值导致永远跳过)
  String? _lastBoundRid;

  /// 最近一次登录的 token(内存级)。退出登录时 AuthStore.authorization 已被清空,
  /// 拦截器取不到 token, 故 unbind 时用它显式带上, 满足后端「unbind 必须带 token」的要求
  String? _lastToken;

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
      _inited = true;
      // 启动即已登录时, ever 不会因「初始值」触发(它只响应变化), 这里主动补一次 bind+alias,
      // 否则只能等 rid 就绪那次才带 token, 日志里看不到「登录后 bind」; 也顺带兜住
      // 「登录早于 init 完成」导致 _onAuthChanged 因 !_inited 被吞掉的情况
      // 主动调用需把当前 token 值传入, 否则无参时会被当成「退出」误调 unbind
      if (Get.isRegistered<AuthStore>() && AuthStore.to.isLogin) {
        unawaited(_onAuthChanged(AuthStore.to.authorization.value).catchError((_) {}));
      }

      // 6. 冷启动: 用户点通知栏拉起 App 时, 首帧后再跳目标页
      unawaited(_handleLaunchNotification());

      debugPrint('[push] 极光推送初始化完成(rid=${registrationId.isEmpty ? '未就绪' : registrationId})');
    } catch (e) {
      debugPrint('[push] 极光推送初始化异常: $e');
    }
  }

  /// 登录态联动: 用 GetX worker 而不是改 AuthStore, 避免 controller -> utils -> controller 循环依赖
  void _watchAuth() {
    if (!Get.isRegistered<AuthStore>()) return;
    final AuthStore auth = AuthStore.to;
    // 用 authorization 变化后的「值」判定登录/退出, 不依赖 storage.isLogin:
    // setAuthorization 先改 authorization.value(触发 ever), 再写 storage, ever 回调里
    // storage 可能尚未写入, 若按 isLogin 判断会在登录瞬间误判为「退出」而调 unbind
    ever(auth.authorization, (val) => _onAuthChanged(val));
    // memberInfo 后到: 登录瞬间 member_id 可能还是 0, 会员信息回来后再补绑一次 alias
    ever(auth.memberInfo, (_) => _syncAlias());
  }

  /// 登录 / 退出登录
  /// * [token] 为 ever(authorization) 变化后的新值: 非空=刚登录(带 token bind+绑 alias),
  ///   空=刚退出(解绑+清 alias)。不传时回退到 storage.isLogin(供初始化时主动补触发)
  Future<void> _onAuthChanged([dynamic token]) async {
    if (!_inited) return;
    final AuthStore? auth = Get.isRegistered<AuthStore>() ? AuthStore.to : null;
    if (auth == null) return;

    final bool loggedIn = token != null
        ? '$token'.isNotEmpty
        : auth.isLogin;
    if (loggedIn) {
      // 登录成功: 记录本次 token(供退出时 unbind 携带), 再带 token 再 bind 一次,
      // 把设备与账号关联(未登录时那次只登记了设备)
      _lastToken = auth.authorization.value;
      if (registrationId.isNotEmpty) {
        _lastBoundRid = registrationId;
        await _bindDevice();
      }
      await _syncAlias();
      return;
    }
    // 退出登录: 先解绑设备(token 由 _unbindDevice 显式携带, 因此刻 AuthStore 已清空),
    // 再清 alias
    await _unbindDevice();
    await _clearAlias();
  }

  // ===== RegistrationID / 设备上报 =====

  /// 拉取 RegistrationID, 与本地记录不一致时上报后端
  /// * 部分 SDK 版本 getRegistrationID() 直接返回空, 真正的 rid 只在 onCommandResult(cmd=2005) 下发,
  ///   所以这里拿不到也别急, _onCommandResult 会补上
  Future<void> _syncRegistrationId() async {
    String rid = '';
    try {
      // 首启时要等长连接建立才有 rid, 这里等一下; 拿不到不阻塞(_onConnected 会再同步)
      rid = (await _jpush.getRegistrationID().timeout(const Duration(seconds: 15))).trim();
    } catch (_) {}
    if (rid.isEmpty) {
      debugPrint('[push] getRegistrationID() 返回空, 等待命令回调(2005)下发 RegistrationID');
      return;
    }
    await _acceptRegistrationId(rid);
  }

  /// 收到一个 RegistrationID(无论来源: getRegistrationID 返回值 / 命令回调 2005):
  /// 记录并在「本会话内首次拿到该 rid」时上报设备(未登录只登记设备, 登录后 ever 会再带 token bind 一次)
  Future<void> _acceptRegistrationId(String rid) async {
    rid = rid.trim();
    if (rid.isEmpty) return;
    registrationId = rid;
    // 仅用内存级判重防命令回调重复下发, 不读持久化值(否则覆盖安装残留旧值会让 bind 永远被跳过)
    if (_lastBoundRid == rid) return;
    _lastBoundRid = rid;
    _box.write(_ridKey, rid);
    await _bindDevice();
  }

  /// 上报设备(POST /api/push/bind)
  /// * 已登录时 Request 拦截器会自动带上 token, 服务端据此绑定 member_id
  Future<void> _bindDevice() async {
    if (registrationId.isEmpty) return;
    // 打印是否带登录态(token), 方便确认这次 bind 是「仅登记设备」还是「绑定用户」
    final bool loggedIn = Get.isRegistered<AuthStore>() && AuthStore.to.isLogin;
    debugPrint('[push][bind] 触发: registrationId=$registrationId, '
        '已登录(将带token绑定用户)=${loggedIn ? '是' : '否'}');
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
  /// * 退出时 AuthStore.authorization 已清空, 故用本机真实 registrationId + 登录时记录的
  ///   [_lastToken] 显式携带, 满足后端「unbind 必须带 registration_id + token」
  Future<void> _unbindDevice() async {
    final bool hasToken = _lastToken != null && _lastToken!.isNotEmpty;
    debugPrint('[push][unbind] 触发: registrationId=${registrationId.isEmpty ? '未就绪' : registrationId}, '
        '携带token=${hasToken ? '是' : '否(退出前未记录到token, 后端可能拒签)'}');
    if (registrationId.isEmpty) {
      debugPrint('[push][unbind] 跳过: registrationId 未就绪, 无法解绑具体设备');
      return;
    }
    final bool ok = await PushApi.unbind(
      registrationId: registrationId,
      token: _lastToken ?? '',
    );
    debugPrint('[push] 解绑设备: ${ok ? '成功' : '失败'}');
    _lastToken = null;
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
    await _dispatchTarget(target);
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
  /// * cmd=2005 是 getRegistrationID 的结果, msg 字段即 RegistrationID
  ///   (本 SDK 版本 getRegistrationID() 直接返回空, rid 只在命令回调里下发, 必须在这里接住)
  Future<dynamic> _onCommandResult(Map<String, dynamic> event) async {
    debugPrint('[push] 命令结果: $event');
    final int cmd = event['cmd'] is int
        ? event['cmd'] as int
        : int.tryParse('${event['cmd']}') ?? 0;
    if (cmd == 2005) {
      final String rid = '${event['msg'] ?? ''}'.trim();
      debugPrint('[push] 命令回调拿到 RegistrationID: $rid');
      await _acceptRegistrationId(rid);
    }
    return null;
  }

  /// 长连接建立: rid 可能已变化, 重新同步一次
  Future<dynamic> _onConnected(Map<String, dynamic> event) async {
    debugPrint('[push] 极光长连接已建立');
    await _syncRegistrationId();
    return null;
  }

  // ===== 跳转 =====

  /// 把 extras 规整成 Map: 兼容极光安卓的多种回传形态
  /// * 安卓点击通知时, 真实字段被包在嵌套的 cn.jpush.android.EXTRA 里
  ///   (该键的值可能是 Map, 也可能是 '{"id":..,"type":..}' 字符串)
  /// * 安卓前台收通知 / iOS 则可能直接就是扁平的 {id, type} Map 或 JSON 字符串
  /// * 旧逻辑只认「顶层 Map」与「JSON 字符串」, 遇上嵌套结构解析失败 ->
  ///   type/id 全空 -> 全部误跳 /notice
  Map<String, dynamic> _parseExtras(dynamic extras) {
    Map<String, dynamic>? fromValue(dynamic v) {
      if (v is Map) return v.cast<String, dynamic>();
      if (v is String && v.trim().isNotEmpty) {
        try {
          final dynamic decoded = jsonDecode(v);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    if (extras is Map) {
      final Map<String, dynamic> map = extras.cast<String, dynamic>();
      // 优先取极光安卓包在 cn.jpush.android.EXTRA 里的真实内容
      final Map<String, dynamic>? nested = fromValue(map['cn.jpush.android.EXTRA']);
      if (nested != null) return nested;
      // 已经是扁平的 {id, type} 结构, 原样返回
      return map;
    }
    return fromValue(extras) ?? <String, dynamic>{};
  }

  /// 按 extras 里的 type / id 生成跳转路径(对齐后台《APP推送接口文档》类型表)
  /// * 规则: 有 id 跳对应详情页, id 为空跳列表/兜底页
  /// * task 返回哨兵 '/tab/<type>', 由 _dispatchTarget 转成「切主框架底部 tab」(不走页面跳转)
  /// * order  订单      -> /order/detail?order_id= (无 id -> /order)
  /// * live   直播间    -> /live?sn= (进房要房间号 sn, 后台发的 id 即字符串房间号; 无 id -> /live/list)
  /// * task   任务中心  -> /tab/earn (切底部「赚钱」tab)
  /// * seckill 秒杀     -> /seckill/detail?id= (无 id -> /seckill)
  /// * system 系统公告  -> /notice/detail(有 title/content) / /notice(列表)
  /// * 其他/缺省         -> /notice
  String _targetOf(Map<String, dynamic> payload) {
    final Map<String, dynamic> extras = _parseExtras(payload['extras']);
    final String type = _text(extras['type']);
    final String id = _text(extras['id']);
    final String Function(String) q = Uri.encodeQueryComponent;
    debugPrint('[push] 解析 extras: type=$type id=$id');

    switch (type) {
      case 'order':
        return id.isEmpty ? '/order' : '/order/detail?order_id=${q(id)}';
      case 'live':
        return id.isEmpty ? '/live/list' : '/live?sn=${q(id)}';
      case 'task':
        return '/earn'; // 任务中心: 跳赚钱页(独立页面, 带右下角回到首页)
      case 'seckill':
        return id.isEmpty ? '/seckill' : '/seckill/detail?id=${q(id)}';
      case 'system':
        final String title = _text(extras['title']);
        final String content = _text(extras['content']);
        if (title.isNotEmpty || content.isNotEmpty) {
          return '/notice/detail?title=${q(title)}&content=${q(content)}';
        }
        return '/notice';
      default:
        return '/notice';
    }
  }

  /// 按目标路径分发跳转
  /// * '/tab/<type>' 哨兵: 切主框架底部 tab(若在子页面则先回到根路由露出底层页)
  /// * 其余: 交给 Utils.openAppLink 走内部路由/外链(放到首帧回调里, 见 _navigateWhenReady)
  Future<void> _dispatchTarget(String target) async {
    if (target.startsWith('/tab/')) {
      final String type = target.substring('/tab/'.length);
      debugPrint('[push] 切 tab: type=$type');
      // 静态调用 MainTabController.switchTo, 不依赖 GetX 注册状态
      MainTabController.switchTo(type);
      // 若当前停留在子页面(如商品详情), 回到根路由让底层 Layout 露出来
      try {
        Get.until((r) => r.isFirst);
      } catch (_) {}
      return;
    }
    if (target.isNotEmpty) _navigateWhenReady(target);
  }

  /// 在首帧回调里再跳转
  /// * 通知点击/冷启动的回调发生在 Flutter 完成首帧之前: 此时直接 toNamed 会"记录了路由
  ///   但页面没渲染"(看起来像跳到了首页)。放进 addPostFrameCallback, 等引擎恢复渲染后的
  ///   那一帧在 Flutter 帧循环内执行 toNamed, 页面才会真正 push 出来
  void _navigateWhenReady(String target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[push] 首帧后跳转: $target');
      unawaited(Utils.openAppLink(target));
    });
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
      await _dispatchTarget(target);
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
