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

  /// 微信「商家转账到零钱」免确认收款授权
  /// * 对齐 H5: wxsdk.requestMerchantTransfer({mchId, appId, package})
  /// * 底层是开放平台的 WXOpenBusinessViewReq, businessType = requestMerchantTransfer
  /// * query 形如: mchId=xxx&appId=xxx&package=xxx(与 H5 三个入参一一对应)
  /// * 用户确认后微信回到 App, onOpenBusinessViewResponse 的 errCode == 0 视为授权成功
  static Future<bool> requestMerchantTransfer({
    required String mchId,
    required String appId,
    required String package,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!supported) throw '当前环境不支持微信授权';
    if (!configured) throw '未配置微信AppID,请先在 Config.wxAppId 填写';
    if (!await init()) throw '微信SDK注册失败,请检查AppID配置';
    if (!await isInstalled()) throw '未安装微信,无法授权';
    if (!await _fluwx.isSupportOpenBusinessView) throw '当前微信版本不支持,请升级微信后再授权';

    final Completer<bool> completer = Completer<bool>();
    FluwxCancelable? cancelable;
    Timer? timer;

    void clean() {
      timer?.cancel();
      cancelable?.cancel();
    }

    void finish(String error, [bool ok = false]) {
      if (completer.isCompleted) return;
      clean();
      if (ok) {
        completer.complete(true);
      } else {
        completer.completeError(error);
      }
    }

    cancelable = _fluwx.addSubscriber((WeChatResponse response) {
      if (response is! WeChatOpenBusinessViewResponse) return;
      if (response.errCode != 0) {
        final String errStr = response.errStr?.trim() ?? '';
        finish(response.errCode == -2
            ? '已取消授权'
            : (errStr.isNotEmpty ? errStr : '授权失败(${response.errCode})'));
        return;
      }
      finish('', true);
    });

    final String query = 'mchId=$mchId&appId=$appId&package=$package';
    debugPrint('[wx] requestMerchantTransfer mchId=$mchId appId=$appId');
    final bool sent = await _fluwx.open(
      target: BusinessView(businessType: 'requestMerchantTransfer', query: query),
    );
    if (!sent) {
      finish('拉起微信失败,请稍后重试');
      return completer.future;
    }

    timer = Timer(timeout, () => finish('授权超时,请重试'));
    return completer.future;
  }

  /// 拉起微信小程序(yeepay 通道的支付页)
  /// * 对齐 H5 APP 端: plus.share.getServices -> sweixin.launchMiniProgram({id, path, type:0})
  /// * [username] 小程序原始id(gh_xxx),对应后台返回的 miniProgramOrgId
  /// * [path] 小程序页面路径(带支付参数),对应后台返回的 prePayTn
  /// * 返回 true 表示已发起跳转;支付结果以后台 /api/pay/status 为准(微信不回调支付结果)
  /// * 前提: 开放平台移动应用与小程序需在「同一开放平台账号」下关联,否则微信会拒绝跳转
  static Future<bool> launchMiniProgram({
    required String username,
    String path = '',
    WXMiniProgramType type = WXMiniProgramType.release,
  }) async {
    if (!supported) throw '当前环境不支持微信小程序';
    if (!configured) throw '未配置微信AppID,请先在 Config.wxAppId 填写';
    if (!await init()) throw '微信SDK注册失败,请检查AppID配置';
    if (!await isInstalled()) throw '未安装微信,无法跳转小程序支付';

    debugPrint('[wx] launchMiniProgram username=$username path=$path');
    return _fluwx.open(
      target: MiniProgram(
        username: username,
        path: path.trim().isEmpty ? null : path.trim(),
        miniProgramType: type,
      ),
    );
  }

  /// 微信 APP 支付(fluwx Payment)
  /// * [params] 后台 /api/pay/pay 下发的 APP 支付参数:
  ///   appId / partnerId / prepayId / package / nonceStr / timeStamp / sign / signType
  /// * 返回 true 表示微信端支付成功(errCode == 0),取消(-2)/失败抛错(调用方 toast)
  /// * 注意: 微信回调成功只代表端上支付完成,是否到账仍以后台 /api/pay/status 为准
  static Future<bool> pay({
    required Map<String, String> params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!supported) throw '当前环境不支持微信支付';
    if (!configured) throw '未配置微信AppID,请先在 Config.wxAppId 填写';
    if (!await init()) throw '微信SDK注册失败,请检查AppID配置';
    if (!await isInstalled()) throw '未安装微信,请使用其他支付方式';

    final Completer<bool> completer = Completer<bool>();
    FluwxCancelable? cancelable;
    Timer? timer;

    void clean() {
      timer?.cancel();
      cancelable?.cancel();
    }

    void finish(String error, [bool ok = false]) {
      if (completer.isCompleted) return;
      clean();
      if (ok) {
        completer.complete(true);
      } else {
        completer.completeError(error);
      }
    }

    cancelable = _fluwx.addSubscriber((WeChatResponse response) {
      if (response is! WeChatPaymentResponse) return;
      // errCode: 0 成功 / -2 用户取消 / 其他失败
      if (response.errCode != 0) {
        final String errStr = response.errStr?.trim() ?? '';
        finish(response.errCode == -2
            ? '已取消支付'
            : (errStr.isNotEmpty ? errStr : '微信支付失败(${response.errCode})'));
        return;
      }
      finish('', true);
    });

    final String appId = (params['appId'] ?? '').trim();
    debugPrint('[wx] pay partnerId=${params['partnerId']} prepayId=${params['prepayId']}');
    final bool sent = await _fluwx.pay(
      which: Payment(
        appId: appId.isNotEmpty ? appId : Config.wxAppId.trim(),
        partnerId: params['partnerId'] ?? '',
        prepayId: params['prepayId'] ?? '',
        packageValue: params['package'] ?? 'Sign=WXPay',
        nonceStr: params['nonceStr'] ?? '',
        timestamp: int.tryParse('${params['timeStamp'] ?? 0}') ?? 0,
        sign: params['sign'] ?? '',
        signType: (params['signType'] ?? '').trim().isEmpty ? null : params['signType'],
      ),
    );
    if (!sent) {
      finish('拉起微信支付失败,请稍后重试');
      return completer.future;
    }

    timer = Timer(timeout, () => finish('微信支付超时,请到订单列表查看支付结果'));
    return completer.future;
  }

  /// 统一错误提示
  static String errorMsg(dynamic error, [String fallback = '微信登录失败']) {
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
