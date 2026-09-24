/// 微信开放平台: APP 授权登录(fluwx) —— 移动端实现(Android / iOS)
/// * 只拿授权 code,换取 access_token/openid 由后端(/api/login/appWxLogin)完成,与 H5 uni.login 一致
/// * 前置: 微信开放平台创建移动应用并审核通过 + Config.wxAppId 填写
///   - Android: 开放平台登记包名 com.chongloutech.lehui 与应用签名 MD5(debug/release 都要登记)
///   - iOS: Config.wxUniversalLink + Info.plist 的 CFBundleURLTypes / LSApplicationQueriesSchemes
/// * 桌面端(macOS/Windows/Linux)虽然也是 dart.library.io,但没有微信SDK实现,supported 返回 false
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:fluwx/fluwx.dart';

import '../config/index.dart';

class WxAuth {
  static final Fluwx _fluwx = Fluwx();
  static bool _registered = false;

  /// 当前平台是否有实现(仅 Android / iOS)
  static bool get supported => Platform.isAndroid || Platform.isIOS;

  /// 是否已配置 AppID(未配置时不能拉起微信,debug 下可先预览入口位置)
  static bool get configured => Config.wxAppId.trim().isNotEmpty;

  /// 注册微信SDK(重复调用无副作用)
  /// * 返回 false 表示未接入成功,调用方应提示而不是继续拉起微信
  static Future<bool> init() async {
    if (!supported || !configured) return false;
    if (_registered) return true;
    try {
      final String link = Config.wxUniversalLink.trim();
      final bool ok = await _fluwx.registerApi(
        appId: Config.wxAppId.trim(),
        doOnAndroid: true,
        doOnIOS: true,
        universalLink: link.isEmpty ? null : link,
      );
      _registered = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// 是否已安装微信(未安装时不应展示入口,微信也不允许未安装时授权)
  /// * 注意: Android 11(API 30)+ 必须在 AndroidManifest 的 <queries> 里声明
  ///   <package android:name="com.tencent.mm" />,否则微信SDK一律返回"未安装"
  static Future<bool> isInstalled() async {
    if (!supported) return false;
    try {
      // 部分机型/版本需要先注册SDK才能查询安装状态
      if (!_registered) await init();
      final bool installed = await _fluwx.isWeChatInstalled;
      debugPrint('[wx] isWeChatInstalled=$installed');
      return installed;
    } catch (e) {
      debugPrint('[wx] isWeChatInstalled error: $e');
      return false;
    }
  }

  /// 拉起微信授权并返回 code(失败抛字符串,调用方直接 toast)
  /// * scope: snsapi_userinfo(用户信息) 与 H5 onlyAuthorize 拿到 code 的效果一致
  /// * 用户取消(errCode = -2)、未安装、超时都会抛错
  static Future<String> authCode({Duration timeout = const Duration(seconds: 60)}) async {
    if (!supported) throw '当前环境不支持微信登录';
    if (!configured) throw '未配置微信AppID,请先在 Config.wxAppId 填写';
    if (!await init()) throw '微信SDK注册失败,请检查AppID配置';
    if (!await isInstalled()) throw '未安装微信,请使用其他方式登录';

    final Completer<String> completer = Completer<String>();
    FluwxCancelable? cancelable;
    Timer? timer;

    void clean() {
      timer?.cancel();
      cancelable?.cancel();
    }

    void finish(String error, [String? code]) {
      if (completer.isCompleted) return;
      clean();
      if (code != null && code.isNotEmpty) {
        completer.complete(code);
      } else {
        completer.completeError(error);
      }
    }

    cancelable = _fluwx.addSubscriber((WeChatResponse response) {
      if (response is! WeChatAuthResponse) return;
      // errCode: 0 成功 / -2 用户取消 / -4 用户拒绝 / 其他失败
      if (response.errCode != 0) {
        final String errStr = response.errStr?.trim() ?? '';
        finish(response.errCode == -2
            ? '已取消微信授权'
            : (errStr.isNotEmpty ? errStr : '微信授权失败(${response.errCode})'));
        return;
      }
      finish('', response.code);
    });

    final bool sent = await _fluwx.authBy(
      which: NormalAuth(scope: 'snsapi_userinfo', state: '${DateTime.now().millisecondsSinceEpoch}'),
    );
    if (!sent) {
      finish('拉起微信失败,请稍后重试');
      return completer.future;
    }

    timer = Timer(timeout, () => finish('微信授权超时,请重试'));
    return completer.future;
  }

  /// 统一错误提示
  static String errorMsg(dynamic error) {
    final String message = '$error'.trim();
    return message.isEmpty ? '微信登录失败' : message;
  }
}
