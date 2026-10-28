/// 阿里云移动推送(离线推送)封装
/// * 对齐后端《APP推送接口文档》: bind / unbind + 通知点击跳转(extras 的 type/id)
/// * 职责: 初始化 / 通知权限 / deviceId 上报 / alias(会员id)绑定 / 点击跳转 / 角标清理
/// * 设计原则: 任何一步失败都只打日志, 绝不影响 App 启动与其他功能
/// * 未配置 Config.aliPushAppKey / aliPushAppSecret 时整体跳过(视为未接入)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aliyun_push/aliyun_push.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/push.dart';
import '../config/index.dart';
import '../controller/auth_store.dart';
import '../controller/main_tab.dart';
import 'index.dart';
import 'platform.dart';

class PushService {
  PushService._();
  static final PushService to = PushService._();

  // 本地存储键(覆盖安装会残留旧值, 但本会话内只用内存级 _lastBoundRid 判重, 持久化仅用于观察)
  static const String _ridKey = 'ali_push_device_id';
  static const String _aliasKey = 'ali_push_alias';

  final GetStorage _box = GetStorage();
  // 阿里云推送单例(官方包 AliyunPush() 工厂返回同一实例)
  final AliyunPush _push = AliyunPush();

  // 本地通知: 前台收到推送时补弹一条高优先级通知(阿里云 SDK 前台只静默展示),
  // 并接管点击跳转(解析 extras 的 type/id)
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const String _localChannelId = 'push';

  bool _inited = false;

  /// 当前 deviceId(阿里云推送唯一标识, 后端按它推单设备); 对应极光的 RegistrationID
  String deviceId = '';

  /// 本会话内已上报过的 deviceId(内存级, 仅防止重复 bind;
  /// 不要用持久化值判重——登录态变化需要重新 bind, 且覆盖安装会残留旧值导致永远跳过)
  String? _lastBoundRid;

  /// 最近一次登录的 token(内存级)。退出登录时 AuthStore.authorization 已被清空,
  /// 拦截器取不到 token, 故 unbind 时用它显式带上, 满足后端「unbind 必须带 token」的要求
  String? _lastToken;

  /// 当前已设置的 alias(形如 member_123)
  String? _alias;

  /// 是否支持阿里云推送: 仅 Android / iOS(web 与桌面端没有对应 SDK)
  bool get _supported {
    final TargetPlatform p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  /// 初始化(在 runApp 之后调用, 不阻塞首帧)
  Future<void> init() async {
    if (_inited) return;
    if (kIsWeb || !_supported) {
      debugPrint('[push] 当前平台(${PlatformInfo.osType})不支持阿里云推送, 跳过初始化');
      return;
    }
    if (Config.aliPushAppKey.isEmpty || Config.aliPushAppSecret.isEmpty) {
      debugPrint('[push] 未配置 Config.aliPushAppKey/aliPushAppSecret, 跳过阿里云推送初始化');
      return;
    }

    try {
      // 1. 初始化: appKey/appSecret 由 Dart 传入。
      //    * Android 端用 PushInitConfig 传参, 无需在 AndroidManifest 写 appkey/appsecret meta-data
      //    * iOS 端同样走 initPush(appKey:, appSecret:)
      final Map<dynamic, dynamic> initResult = await _push.initPush(
        appKey: Config.aliPushAppKey,
        appSecret: Config.aliPushAppSecret,
      );
      debugPrint('[push] initPush 结果: $initResult');

      // 2. 厂商通道(华为/小米/...)走系统通道, App 被杀后仍能收推送(离线推送)
      //    * 仅 Android 需要; 内部注册 huawei/xiaomi/vivo/oppo/meizu/gcm/honor,
      //      缺对应 meta-data 的厂商会自动跳过, 不会报错
      //    * meta-data 在 AndroidManifest.xml 配: 华为 com.huawei.hms.client.appid(appid=)、
      //      小米 com.xiaomi.push.id / com.xiaomi.push.key(id=)
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic> tp = await _push.initAndroidThirdPush();
        debugPrint('[push] initAndroidThirdPush 结果: $tp');
      }

      // 3. 事件监听(插件每次 addMessageReceiver 会整体替换回调, 单例里注册一次即可)
      _push.addMessageReceiver(
        onNotification: _onNotification,
        onMessage: _onMessage,
        onNotificationOpened: _onNotificationOpened,
        onNotificationRemoved: _onNotificationRemoved,
        // 控制台配置「无动作」时, 点击走这个而不是 onNotificationOpened, 一并处理跳转
        onAndroidNotificationClickedWithNoAction: _onNotificationOpened,
      );

      // 本地通知: 用于前台收到推送时补弹高优先级通知(阿里云 SDK 在前台只静默展示),
      // 并接管点击跳转
      await _initLocalNotify();

      // 4. 通知权限: 进 App 主动申请, 避免「收到第一条推送才弹授权框」——
      //    那种懒弹框容易被用户误点拒绝, 之后离线(厂商通道)推送全都不会显示。
      //    * Android <13 / iOS 上该权限安装即授予, .request() 直接返回 granted, 不会弹窗(无副作用)
      //    * 已授权不重复打扰; 被永久拒绝/受限时弹窗无意义, 记录日志交由设置页引导去系统开启。
      final PermissionStatus noti = await Permission.notification.status;
      if (noti.isGranted) {
        debugPrint('[push] 通知权限已授权, 跳过申请');
      } else if (noti.isPermanentlyDenied || noti.isRestricted) {
        debugPrint('[push] 通知权限已被永久拒绝/受限, 需用户到系统设置开启: $noti');
      } else {
        final PermissionStatus r = await Permission.notification.request();
        debugPrint('[push] 通知权限申请结果: $r');
      }

      // 5. deviceId: 拿到后上报(变化才上报)
      await _syncDeviceId();

      // 6. 登录态联动: 登录后带 token 再 bind + 绑 alias, 退出后解绑 + 清 alias
      _watchAuth();
      _inited = true;
      // 启动即已登录时, ever 不会因「初始值」触发(它只响应变化), 这里主动补一次 bind+alias,
      // 否则只能等 deviceId 就绪那次才带 token, 日志里看不到「登录后 bind」; 也顺带兜住
      // 「登录早于 init 完成」导致 _onAuthChanged 因 !_inited 被吞掉的情况
      // 主动调用需把当前 token 值传入, 否则无参时会被当成「退出」误调 unbind
      if (Get.isRegistered<AuthStore>() && AuthStore.to.isLogin) {
        unawaited(_onAuthChanged(AuthStore.to.authorization.value).catchError((_) {}));
      }

      debugPrint('[push] 阿里云推送初始化完成(deviceId=${deviceId.isEmpty ? '未就绪' : deviceId})');
    } catch (e) {
      debugPrint('[push] 阿里云推送初始化异常: $e');
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
      if (deviceId.isNotEmpty) {
        _lastBoundRid = deviceId;
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

  // ===== deviceId / 设备上报 =====

  /// 拉取 deviceId, 与本地记录不一致时上报后端
  /// * 注册可能稍晚于 initPush 返回, 首次拿不到就等 1.5s 再试一次
  Future<void> _syncDeviceId() async {
    String id = '';
    try {
      id = (await _push.getDeviceId().timeout(const Duration(seconds: 15))).trim();
    } catch (_) {}
    if (id.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      try {
        id = (await _push.getDeviceId().timeout(const Duration(seconds: 15))).trim();
      } catch (_) {}
    }
    if (id.isEmpty) {
      debugPrint('[push] getDeviceId() 返回空, 等待下次登录/绑定重试');
      return;
    }
    await _acceptDeviceId(id);
  }

  /// 收到一个 deviceId(无论来源): 记录并在「本会话内首次拿到该 id」时上报设备
  /// (未登录只登记设备, 登录后 ever 会再带 token bind 一次)
  Future<void> _acceptDeviceId(String id) async {
    id = id.trim();
    if (id.isEmpty) return;
    deviceId = id;
    // 仅用内存级判重防重复上报, 不读持久化值(否则覆盖安装残留旧值会让 bind 永远被跳过)
    if (_lastBoundRid == id) return;
    _lastBoundRid = id;
    _box.write(_ridKey, id);
    await _bindDevice();
  }

  /// 上报设备(POST /api/push/bind)
  /// * 已登录时 Request 拦截器会自动带上 token, 服务端据此绑定 member_id
  /// * 后端 wire 字段仍叫 registration_id, 其值即阿里云 deviceId(后端需切到阿里云 SDK 下发)
  Future<void> _bindDevice() async {
    if (deviceId.isEmpty) return;
    // 打印是否带登录态(token), 方便确认这次 bind 是「仅登记设备」还是「绑定用户」
    final bool loggedIn = Get.isRegistered<AuthStore>() && AuthStore.to.isLogin;
    debugPrint('[push][bind] 触发: deviceId=$deviceId, '
        '已登录(将带token绑定用户)=${loggedIn ? '是' : '否'}');
    final Map<String, String> device = await _deviceInfo();
    final PackageInfo info = await PackageInfo.fromPlatform();
    final bool ok = await PushApi.bind(
      registrationId: deviceId,
      platform: PlatformInfo.osType, // ios / android(小写, 后端要求)
      deviceBrand: device['brand'] ?? '',
      deviceModel: device['model'] ?? '',
      systemVersion: device['system'] ?? '',
      appVersion: '${info.version}(${info.buildNumber})',
    );
    debugPrint('[push] 上报设备(deviceId=$deviceId, platform=${PlatformInfo.osType}): '
        '${ok ? '成功' : '失败'}');
  }

  /// 解绑设备(POST /api/push/unbind)
  /// * 退出时 AuthStore.authorization 已清空, 故用本机真实 deviceId + 登录时记录的
  ///   [_lastToken] 显式携带, 满足后端「unbind 必须带 registration_id + token」
  Future<void> _unbindDevice() async {
    final bool hasToken = _lastToken != null && _lastToken!.isNotEmpty;
    debugPrint('[push][unbind] 触发: deviceId=${deviceId.isEmpty ? '未就绪' : deviceId}, '
        '携带token=${hasToken ? '是' : '否(退出前未记录到token, 后端可能拒签)'}');
    if (deviceId.isEmpty) {
      debugPrint('[push][unbind] 跳过: deviceId 未就绪, 无法解绑具体设备');
      return;
    }
    final bool ok = await PushApi.unbind(
      registrationId: deviceId,
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
    final Map<dynamic, dynamic> res = await _push.addAlias(alias);
    debugPrint('[push] 设置 alias=$alias: $res');
  }

  /// 清掉上一个账号的 alias, 避免退出后还收到个人推送
  Future<void> _clearAlias() async {
    if (_alias == null) return;
    final String old = _alias!;
    _alias = null;
    _box.remove(_aliasKey);
    try {
      final Map<dynamic, dynamic> res = await _push.removeAlias(old);
      debugPrint('[push] 删除 alias=$old: $res');
    } catch (_) {}
  }

  // ===== 事件回调 =====

  /// 收到通知(App 在前台也会回调, 默认仍展示通知栏)
  /// * event: { title, summary, extraMap(Map) }
  Future<dynamic> _onNotification(Map<dynamic, dynamic> event) async {
    final Map<String, dynamic> payload = _payloadOf(event);
    debugPrint('[push] 收到通知: ${payload['title']} | ${payload['body']}');
    // 前台补弹一条高优先级本地通知, 保证有可见反馈(阿里云 SDK 前台只静默展示),
    // 点击跳转逻辑由 _onLocalTap 接管
    await _showLocal(
      payload['title'] as String? ?? '',
      payload['body'] as String? ?? '',
      payload['extras'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    return null;
  }

  /// 点击通知栏消息 -> 按 extras 的 type/id 跳转
  /// * event: { title, summary, extraMap(String JSON) }
  /// * 冷启动(被杀后点通知拉起 App)也走这里——原生 MessageReceiver 在 App 启动时收到点击,
  ///   只要 addMessageReceiver 已注册(本 init 内完成)即可收到; 个别机型若漏接, 仅影响「点击跳转」,
  ///   不影响通知栏展示与离线送达(那是系统通道负责)
  Future<dynamic> _onNotificationOpened(Map<dynamic, dynamic> event) async {
    final Map<String, dynamic> payload = _payloadOf(event);
    final String target = _targetOf(payload);
    debugPrint('[push] 点击通知: ${payload['title']} | 跳转 $target');
    await _clearBadge();
    await _dispatchTarget(target);
    return null;
  }

  /// 透传消息(服务端自定义消息, 不展示通知栏)
  /// * event: { title, content, msgId, appId, traceInfo }
  Future<dynamic> _onMessage(Map<dynamic, dynamic> event) async {
    debugPrint('[push] 收到透传消息: $event');
    return null;
  }

  /// 通知被用户移除
  Future<dynamic> _onNotificationRemoved(Map<dynamic, dynamic> event) async {
    debugPrint('[push] 通知被移除: $event');
    return null;
  }

  // ===== 本地通知(前台补弹 + 点击跳转) =====

  /// 初始化本地通知: 建一个高优先级 channel(可弹横幅/响铃/震动),
  /// 并接管点击 -> 按 extras 的 type/id 跳转
  Future<void> _initLocalNotify() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _localChannelId,
        '推送通知',
        description: '乐惠推送消息',
        importance: Importance.high,
        playSound: true,
        enableLights: true,
        enableVibration: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (resp) => _onLocalTap(resp),
      );

      if (Platform.isIOS) {
        await _local
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('[push] 本地通知初始化失败(不影响推送接收): $e');
    }
  }

  /// 弹本地通知。先取消阿里云 SDK 自己弹出的(前台静默)那条, 避免通知栏出现两条。
  /// [title]/[body] 展示文案, [extras] 原样塞进 payload, 点击时用于跳转
  Future<void> _showLocal(
    String title,
    String body,
    Map<String, dynamic> extras,
  ) async {
    try {
      final String payload = jsonEncode(
        <String, dynamic>{
          'title': title,
          'body': body,
          'extras': extras,
        },
      );
      // 去重: 清掉阿里云 SDK 自带的那条(它已先弹到栏里, 但前台是静默的)
      // 注意 cancelAll 会清掉本应用全部通知, 本 App 推送是唯一来源, 影响可忽略
      await _local.cancelAll();
      await _local.show(
        0,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _localChannelId,
            '推送通知',
            channelDescription: '乐惠推送消息',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableLights: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[push] 弹本地通知失败(不影响推送接收): $e');
    }
  }

  /// 点击本地通知: 解析 payload -> 按 type/id 跳转(逻辑与 onNotificationOpened 一致)
  Future<void> _onLocalTap(NotificationResponse resp) async {
    final String? p = resp.payload;
    if (p == null || p.isEmpty) return;
    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(p) as Map);
      final Map<String, dynamic> extras = Map<String, dynamic>.from(
        data['extras'] as Map? ?? <String, dynamic>{},
      );
      final String target = _targetOf(<String, dynamic>{
        'title': data['title'],
        'body': data['body'],
        'extras': extras,
      });
      debugPrint('[push] 点击本地通知: $target');
      await _clearBadge();
      await _dispatchTarget(target);
    } catch (e) {
      debugPrint('[push] 解析本地通知 payload 失败: $e');
    }
  }

  // ===== 跳转 =====

  /// 把事件规整成 { title, body, extras }
  /// * 通知: title=event['title'], body=event['summary'], extras=event['extraMap']
  /// * 透传: title=event['title'], body=event['content'](透传一般无 extraMap)
  Map<String, dynamic> _payloadOf(Map<dynamic, dynamic> event) {
    final String title = _text(event['title']);
    final String body = _text(event['summary'] ?? event['content']);
    final Map<String, dynamic> extras = _parseExtras(event['extraMap']);
    return <String, dynamic>{'title': title, 'body': body, 'extras': extras};
  }

  /// 把 extras 规整成 Map
  /// * 通知 onNotification 的 extraMap 是 Map<String,String>
  /// * 点击 onNotificationOpened / 无动作点击的 extraMap 是 JSON 字符串(需解码)
  Map<String, dynamic> _parseExtras(dynamic extraMap) {
    if (extraMap is Map) {
      return Map<String, dynamic>.from(extraMap);
    }
    if (extraMap is String && extraMap.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(extraMap);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  /// 按 extras 里的 type / id 生成跳转路径(对齐后台《APP推送接口文档》类型表)
  /// * 规则: 有 id 跳对应详情页, id 为空跳列表/兜底页
  /// * task 返回哨兵 '/tab/<type>', 由 _dispatchTarget 转成「切主框架底部 tab」(不走页面跳转)
  /// * order  订单      -> /order/detail?order_id= (无 id -> /order)
  /// * live   直播间    -> /live?sn= (进房要房间号 sn, 后台发的 id 即字符串房间号; 无 id -> /live/list)
  /// * task   任务中心  -> /earn (切底部「赚钱」tab)
  /// * seckill 秒杀     -> /seckill/detail?id= (无 id -> /seckill)
  /// * system 系统公告  -> /notice/detail(有 title/content) / /notice(列表)
  /// * 其他/缺省         -> /notice
  String _targetOf(Map<String, dynamic> payload) {
    final Map<String, dynamic> extras =
        payload['extras'] as Map<String, dynamic>? ?? <String, dynamic>{};
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

  String _text(dynamic v) {
    final String s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  /// 清角标(Android 用 setAndroidBadgeNum, iOS 用 setIOSBadgeNum)
  Future<void> _clearBadge() async {
    try {
      if (Platform.isAndroid) {
        await _push.setAndroidBadgeNum(0);
      } else if (Platform.isIOS) {
        await _push.setIOSBadgeNum(0);
      }
    } catch (_) {}
  }

  /// 清空通知栏 + 角标
  Future<void> clearNotifications() async {
    if (!_inited) return;
    try {
      if (Platform.isAndroid) {
        await _push.clearNotifications();
        await _push.setAndroidBadgeNum(0);
      } else if (Platform.isIOS) {
        await _push.setIOSBadgeNum(0);
      }
    } catch (_) {}
  }
}
