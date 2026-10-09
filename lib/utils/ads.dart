/// 广告封装(gromore_ads): GroMore 聚合SDK = 初始化 + 统一事件日志 + 激励视频/插屏/Banner
/// * 后台用了瀑布流+竞价, 必须走聚合SDK(useMediation=true), 普通穿山甲SDK请求聚合代码位会失败
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gromore_ads/gromore_ads.dart';

import 'ads_config.dart';

// 导出插件: 页面用 AdBannerWidget 等组件时只需 import utils/ads.dart
export 'package:gromore_ads/gromore_ads.dart';

class Ads {
  /// 当前平台是否支持广告SDK(GroMore 只有 Android/iOS 实现, H5/桌面端没有插件实现)
  /// * H5 上调插件方法会抛 MissingPluginException / Unsupported operation, 所有入口先判这个
  static bool get supported => !kIsWeb;

  static bool _inited = false;
  /// SDK 是否初始化成功(失败时请求广告必然报错)
  static bool _sdkReady = false;
  /// 对外只读: 内容SDK(pangrowth_content)初始化前要确认广告SDK已就绪
  static bool get ready => _sdkReady;
  /// 最近一次错误码, 用于区分"没看完"和"没拉起来"
  static int lastErrorCode = 0;
  static String lastErrorMessage = '';

  /// 初始化SDK: 全局只调一次, 未配置 appId 时直接跳过(不会报错)
  static Future<bool> init() async {
    // H5(web)没有原生实现: 不注册事件通道、不初始化, 直接跳过(否则报 MissingPluginException)
    if (!supported) {
      debugPrint('[ads] 当前平台不支持广告SDK(H5/桌面端), 跳过初始化');
      return false;
    }
    if (!AdsConfig.enabled) {
      debugPrint('[ads] 未配置 appId, 跳过初始化');
      return false;
    }
    // 开发调试: 临时关闭穿山甲, 不初始化也不请求广告(见 AdsConfig.debugDisable)
    if (AdsConfig.debugDisable) {
      debugPrint('[ads] 开发调试已关闭广告SDK, 跳过初始化');
      _inited = true;
      _sdkReady = false;
      return false;
    }
    // 上次初始化失败时允许重试(热重启/网络抖动都会导致失败)
    if (_inited && _sdkReady) return true;

    // 全局事件日志(各业务按需再单独订阅)
    GromoreAds.onEvent(
      onEvent: (AdEvent event) {
        debugPrint('[ads] action=${event.action} posId=${event.posId}');
      },
      onError: (AdErrorEvent event) {
        lastErrorCode = event.code ?? 0;
        lastErrorMessage = event.message;
        debugPrint('[ads] errCode=${event.code} errMsg=${event.message}');
      },
      onReward: (AdRewardEvent event) {
        debugPrint('[ads] reward amount=${event.rewardAmount} verified=${event.verified}');
      },
    );

    // iOS 追踪授权
    if (Platform.isIOS) await GromoreAds.requestIDFA;
    final bool ok = await GromoreAds.initAd(
      AdsConfig.appId,
      useMediation: true,
      debugMode: kDebugMode,
    );
    _sdkReady = ok;
    debugPrint('[ads] SDK初始化 appId=${AdsConfig.appId} useMediation=true result=$ok');
    // Android 动态权限(定位/存储等)
    if (Platform.isAndroid) await GromoreAds.requestPermissionIfNecessary;
    _inited = true;
    return true;
  }

  /// 激励视频: true = 完整看完, 可以发奖励
  /// * GroMore 需要先 load 再 show; 收到奖励回调即算完成, 关闭/跳过/出错都算未完成
  static Future<bool> showRewardVideo({String customData = '', String userId = ''}) async {
    if (!await init() || AdsConfig.rewardVideoId.isEmpty) return false;
    if (!_sdkReady) {
      debugPrint('[ads] SDK未就绪, 不发起激励视频请求(先看上面的 SDK初始化 result)');
      return false;
    }
    lastErrorCode = 0;
    lastErrorMessage = '';
    final Completer<bool> completer = Completer<bool>();
    void finish(bool value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    final AdEventSubscription sub = GromoreAds.onRewardVideoEvents(
      AdsConfig.rewardVideoId,
      onRewarded: (AdRewardEvent event) => finish(true),
      onSkipped: (AdEvent event) => finish(false),
      onClosed: (AdEvent event) => finish(false),
      onError: (AdErrorEvent event) {
        lastErrorCode = event.code ?? 0;
        lastErrorMessage = event.message;
        finish(false);
      },
    );

    bool loaded = false;
    try {
      loaded = await GromoreAds.loadRewardVideoAd(
        AdsConfig.rewardVideoId,
        customData: customData,
        userId: userId,
      );
    } catch (e) {
      // 原生侧加载失败会抛 PlatformException(LOAD_ERROR), 这里兜住避免变成未捕获异常
      debugPrint('[ads] 激励视频加载异常 posId=${AdsConfig.rewardVideoId} err=$e');
      final String s = e.toString();
      final RegExpMatch? m = RegExp(r'(\d{5})\s*,').firstMatch(s);
      if (m != null) lastErrorCode = int.tryParse(m.group(1)!) ?? -1;
      lastErrorMessage = s;
    }
    debugPrint('[ads] 激励视频加载 posId=${AdsConfig.rewardVideoId} loaded=$loaded');
    if (loaded) {
      try {
        await GromoreAds.showRewardVideoAd(AdsConfig.rewardVideoId);
      } catch (e) {
        debugPrint('[ads] 激励视频展示异常 posId=${AdsConfig.rewardVideoId} err=$e');
        finish(false);
      }
    } else {
      finish(false);
    }

    // 兜底: 用户一直不关闭(或事件丢失)时不要一直挂着
    final bool ok = await completer.future.timeout(const Duration(minutes: 3), onTimeout: () => false);
    sub.cancel();
    return ok;
  }

  /// 插屏广告: 加载 -> 展示
  static Future<void> showInterstitial() async {
    if (!await init() || AdsConfig.interstitialId.isEmpty) return;
    if (!_sdkReady) return;
    final bool loaded = await GromoreAds.loadInterstitialAd(AdsConfig.interstitialId);
    debugPrint('[ads] 插屏加载 posId=${AdsConfig.interstitialId} loaded=$loaded');
    if (loaded) await GromoreAds.showInterstitialAd(AdsConfig.interstitialId);
  }
}

/// Banner 广告组件: 插件的 AdBannerWidget 不带自动刷新, 这里定时重建实现轮播
class AdsBanner extends StatefulWidget {
  final String posId;
  final double width;
  final double height;
  /// 刷新间隔(秒), 0 = 不刷新
  final int refreshSeconds;

  const AdsBanner({
    super.key,
    required this.posId,
    required this.width,
    required this.height,
    this.refreshSeconds = 30,
  });

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  Timer? _timer;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    if (!Ads.supported) return;
    if (widget.refreshSeconds > 0) {
      _timer = Timer.periodic(Duration(seconds: widget.refreshSeconds), (_) {
        if (mounted) setState(() => _refreshKey++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // H5 不渲染广告(插件无 web 实现, 渲染会抛 MissingPluginException)
    // 开发调试关闭广告时也直接占位, 否则 AdBannerWidget 会去调原生插件报错
    if (!Ads.supported || !AdsConfig.usable) return const SizedBox.shrink();
    return AdBannerWidget(
      key: ValueKey<int>(_refreshKey),
      posId: widget.posId,
      width: widget.width,
      height: widget.height,
      onAdLoaded: () => debugPrint('[ads] Banner加载成功 posId=${widget.posId}'),
      onAdError: (String error) => debugPrint('[ads] Banner错误 posId=${widget.posId} error=$error'),
    );
  }
}
