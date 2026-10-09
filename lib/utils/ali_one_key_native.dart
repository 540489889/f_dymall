/// 阿里云号码认证: APP 一键登录(ali_auth)
/// * 只拿阿里云 accessToken,换取手机号与登录态由后端(/api/login/phoneAuthLogin)完成
/// * 前置: 阿里云控制台添加号码认证方案 -> 拿到 Android/iOS 密钥 -> 填 Config.aliAndroidSk / aliIosSk
///   - 阿里云后台登记的签名必须与打包签名一致(项目当前统一用 android/keystore/lehui.keystore)
/// * 桌面端(macOS/Windows/Linux)与 web 不支持,supported 返回 false
/// * 本文件仅由 ali_one_key.dart 条件导出,在存在 dart:io 的平台(Android/iOS)编译

import 'dart:async';
import 'dart:io' show Platform;

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../config/index.dart';
import 'ali_one_key_error.dart';

class AliOneKey {
  static bool _listened = false;
  static Completer<String>? _completer;

  /// 过程性事件码(不是取号结果,必须忽略,否则会误判为失败)
  /// * 600001 唤起授权页成功 / 600016 预取号成功 / 600024 环境检查成功
  /// * 700002 点击登录按钮 / 700003 点击协议勾选框 / 700004 点击协议
  static const Set<String> _ignoredCodes = <String>{
    '600001',
    '600016',
    '600024',
    '700002',
    '700003',
    '700004',
  };

  /// 当前平台是否有实现(仅 Android / iOS)
  static bool get supported => Platform.isAndroid || Platform.isIOS;

  /// 是否已配置密钥(两端配一个即可,取当前平台对应的那个)
  static bool get configured =>
      (Platform.isAndroid && Config.aliAndroidSk.trim().isNotEmpty) ||
      (Platform.isIOS && Config.aliIosSk.trim().isNotEmpty);

  /// 是否可以展示入口
  static bool get available => supported && configured;

  /// 阿里云授权页 UI 配置(对齐 H5 univerifyStyle: 主色 + 协议前置勾选文案)
  static AliAuthModel _config() {
    return AliAuthModel(
      Config.aliAndroidSk.trim(),
      Config.aliIosSk.trim(),
      isDebug: kDebugMode,
      // 不设背景图: 默认是 assets/background_image.jpeg,项目没有这张图会打 FileNotFoundException
      pageBackgroundPath: null,
      // false: initSdk 后直接拉起授权页;true 需再调 AliAuth.login()
      isDelay: false,
      // 实测该参数没能关掉授权页,页面拿到 token 后会主动调 quit(),这里保留 true 无害
      autoQuitPage: true,
      pageType: PageType.fullPort,
      navColor: '#FFFFFF',
      navText: '本机号码一键登录',
      navTextColor: '#202020',
      navTextSize: 17,
      logoImgPath: 'assets/images/logo.png',
      logoWidth: 72,
      logoHeight: 72,
      numberColor: '#202020',
      numberSize: 28,
      logBtnText: '本机号码一键登录',
      logBtnTextSize: 16,
      logBtnTextColor: '#FFFFFF',
      logBtnHeight: 48,
      logBtnMarginLeftAndRight: 28,
      sloganText: '乐惠商城',
      sloganTextColor: '#BBBBBB',
      sloganTextSize: 13,
      switchAccText: '其他登录方式',
      switchAccTextColor: '#656565',
      switchAccTextSize: 14,
      // 协议(H5 一致的两份协议地址)
      protocolOneName: '《隐私协议》',
      protocolOneURL: '${Config.baseUrl}/index/index/privacy_agreement.html',
      protocolTwoName: '《用户协议》',
      protocolTwoURL: '${Config.baseUrl}/index/index/reg_agreement.html',
      protocolColor: '#BBBBBB',
      protocolCustomColor: '#FF2C55',
      privacyBefore: '我已阅读并同意',
      privacyEnd: '并使用本机号码登录',
      privacyTextSize: 12,
      // 默认已勾选(登录页协议勾选由页面控制,这里保持一致更顺滑)
      privacyState: true,
      privacyOperatorIndex: 0,
      protocolLayoutGravity: Gravity.centerHorizntal,
      protocolGravity: Gravity.centerHorizntal,
      statusBarColor: '#FFFFFF',
      lightColor: true,
      isStatusBarHidden: false,
      webNavColor: '#FFFFFF',
      webNavTextColor: '#202020',
      webSupportedJavascript: true,
    );
  }

  /// 注册一次全局监听(授权页结果通过 EventChannel 回调)
  static void _listen() {
    if (_listened) return;
    _listened = true;
    AliAuth.loginListen(
      onEvent: (dynamic event) {
        debugPrint('[ali] event=$event');
        if (_completer == null || _completer!.isCompleted) return;
        if (event is! Map) return;
        final String code = '${event['code'] ?? ''}';
        final String msg = '${event['msg'] ?? ''}'.trim();
        final String data = '${event['data'] ?? ''}';
        // 600000: 取号成功,data 即 accessToken
        if (code == '600000') {
          _finish(data);
          return;
        }
        // 700000 点击返回 / 700001 点击切换账号: 用户取消
        if (code == '700000' || code == '700001') {
          _fail('已取消一键登录', code: code);
          return;
        }
        // 过程性事件,不是结果: 继续等 600000
        // * 600001 唤起授权页成功 / 600024 环境检查成功 / 600016 预取号成功
        // * 700002 点击登录按钮 / 700003 点击勾选框 / 700004 点击协议
        if (_ignoredCodes.contains(code)) return;
        // 其余 6xxxxx 为失败(600002 唤起失败 / 600011 取号失败 / 600004 配置失败等)
        if (code.startsWith('6')) {
          _fail(_errorText(code, msg), code: code);
        }
      },
      onError: (dynamic error) => _fail('一键登录异常:$error'),
    );
  }

  /// 失败码 -> 可读提示(阿里云号码认证官方码表,取最常见的几种)
  static String _errorText(String code, String msg) {
    const Map<String, String> map = <String, String>{
      '600002': '唤起授权页失败,请重试',
      '600004': '获取运营商配置失败,请检查密钥/签名是否与阿里云后台一致',
      '600005': '终端环境不安全,请关闭 VPN 或代理后重试',
      '600007': '未检测到 SIM 卡',
      '600008': '未开启移动数据,请打开蜂窝网络后重试',
      '600009': '无法判断运营商,请关闭 WiFi 用移动网络重试',
      '600011': '获取 token 失败,请重试',
      '600012': '预取号失败,请重试',
      '600013': '数据解析异常,请重试',
      '600014': '登录超时,请重试',
      '600015': '已取消一键登录',
      '600021': '运营商已切换,请重试',
      '600024': '终端环境检查失败,需开启移动数据',
    };
    final String? text = map[code];
    if (text == null) return msg.isEmpty ? '一键登录失败($code)' : msg;
    return msg.isEmpty ? text : '$text($msg)';
  }

  static void _finish(String token) {
    // 关键节点: token 是否真的回到了 Dart 层(completer 为 null 说明回调早于调用)
    debugPrint(
      '[ali] STEP2 收到600000,token长度=${token.length},completer存在=${_completer != null}',
    );
    final Completer<String>? completer = _completer;
    _completer = null;
    completer?.complete(token);
  }

  static void _fail(String message, {String code = ''}) {
    debugPrint('[ali] FAIL code=$code $message');
    final Completer<String>? completer = _completer;
    _completer = null;
    // 带错误码抛出: 登录页据此判断是"环境不支持"(静默)还是"其他错误"(提示)
    completer?.completeError(AliOneKeyFailure(code, message));
  }

  /// 拉起一键登录授权页并返回 accessToken(失败抛字符串,调用方直接 toast)
  /// * 用户取消、切换账号、取号失败都会抛错
  // 30 秒: 授权页加载 + 阅读协议 + 点击登录,15 秒偏紧(阿里云偶发限流时还要多等一会)
  static Future<String> login({Duration timeout = const Duration(seconds: 30)}) async {
    if (!supported) throw '当前环境不支持一键登录';
    if (!configured) throw '未配置阿里云密钥,请先填写 Config.aliAndroidSk / aliIosSk';
    if (_completer != null && !_completer!.isCompleted) throw '一键登录正在进行中';

    debugPrint('[ali] STEP1 调用 initSdk,准备拉起授权页');
    _listen();
    final Completer<String> completer = Completer<String>();
    _completer = completer;

    // 先订阅再 initSdk: 授权页在 initSdk 期间就会回调(600001/600000),
    // 晚订阅会让 completeError 变成未处理异常
    final Future<String> future = completer.future.timeout(
      timeout,
      onTimeout: () {
        _completer = null;
        AliAuth.quitPage();
        throw '一键登录超时,请重试';
      },
    );

    // 不 await initSdk: 它的 Future 要等授权页销毁才回调(实测点击登录到取号完成隔了 7 秒),
    // 一旦 await 就会卡在 login() 里,future 迟迟不返回,
    // 表现就是"取号成功(600000)但业务层没反应,phoneAuthLogin 根本没调"
    // 结果一律走上面的监听回调: 600000 成功 / 6xxxxx 失败 / 700000 取消
    unawaited(
      AliAuth.initSdk(_config()).catchError((Object e) {
        debugPrint('[ali] initSdk 异常:$e');
        if (_completer == completer) _fail('一键登录初始化失败:$e');
      }),
    );

    return future;
  }

  /// 主动关闭授权页(页面销毁/取消时调用)
  static Future<void> quit() async {
    _completer = null;
    try {
      await AliAuth.quitPage();
    } catch (_) {}
  }

  /// 销毁监听(登录页 dispose 时调用)
  static void dispose() {
    _completer = null;
    AliAuth.dispose();
    _listened = false;
  }
}
