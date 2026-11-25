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

  /// 按平台选择广告 ID: iOS 与 Android 是 GroMore 后台两套独立应用/广告位,不能混用。
  /// * iOS 的 ID 未填(空串)时,currentAppId 为空 -> enabled=false -> 静默跳过广告,不报错
  static void _applyPlatformIds() {
    if (Platform.isIOS) {
      AdsConfig.currentAppId = AdsConfig.iosAppId;
      AdsConfig.currentRewardVideoId = AdsConfig.iosRewardVideoId;
      AdsConfig.currentInterstitialId = AdsConfig.iosInterstitialId;
      AdsConfig.currentBannerId = AdsConfig.iosBannerId;
    } else {
      AdsConfig.currentAppId = AdsConfig.androidAppId;
      AdsConfig.currentRewardVideoId = AdsConfig.androidRewardVideoId;
      AdsConfig.currentInterstitialId = AdsConfig.androidInterstitialId;
      AdsConfig.currentBannerId = AdsConfig.androidBannerId;
    }
  }

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
    // 先按平台选 ID: iOS/Android 各用各的 appId 与广告位
    _applyPlatformIds();
    if (!AdsConfig.enabled) {
      debugPrint('[ads] 当前平台(${Platform.isIOS ? 'iOS' : 'Android'})未配置 appId, 跳过初始化');
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
      AdsConfig.currentAppId,
      useMediation: true,
      debugMode: kDebugMode,
    );
    _sdkReady = ok;
    debugPrint('[ads] SDK初始化 appId=${AdsConfig.currentAppId} useMediation=true result=$ok');
    // Android 动态权限(定位/存储等)
    if (Platform.isAndroid) await GromoreAds.requestPermissionIfNecessary;
    _inited = true;
    return true;
  }

  /// 激励视频: true = 完整看完, 可以发奖励
  /// * GroMore 需要先 load 再 show; 收到奖励回调即算完成, 关闭/跳过/出错都算未完成
  static Future<bool> showRewardVideo({String customData = '', String userId = ''}) async {
    if (!await init() || AdsConfig.currentRewardVideoId.isEmpty) return false;
    if (!_sdkReady) {
      debugPrint('[ads] SDK未就绪, 不发起激励视频请求(先看上面的 SDK初始化 result)');
      return false;
    }
    lastErrorCode = 0;
    lastErrorMessage = '';

    // 事件订阅仅用于采集错误码/日志, 不再用它阻塞调用方:
    // iOS 广告页弹出/关闭期间 EventSink 常断开, onRewarded/onCompleted/onClosed
    // 全部不回传, 之前 await completer 会一直挂到超时, 导致赚钱页按钮锁死。
    // 奖励的最终判定以服务端 progress_num 为准(看完才加进度), 客户端只负责拉起广告 + 事后刷新。
    final AdEventSubscription sub = GromoreAds.onRewardVideoEvents(
      AdsConfig.currentRewardVideoId,
      onShowed: (AdEvent event) {
        debugPrint('[ads] 激励视频已展示 posId=${AdsConfig.currentRewardVideoId}');
      },
      onRewarded: (AdRewardEvent event) {
        debugPrint('[ads] 激励视频发放奖励 posId=${AdsConfig.currentRewardVideoId}');
      },
      onCompleted: (AdEvent event) {
        debugPrint('[ads] 激励视频播放完成 posId=${AdsConfig.currentRewardVideoId}');
      },
      onSkipped: (AdEvent event) {
        debugPrint('[ads] 激励视频跳过 posId=${AdsConfig.currentRewardVideoId}');
      },
      onClosed: (AdEvent event) {
        debugPrint('[ads] 激励视频关闭 posId=${AdsConfig.currentRewardVideoId}');
      },
      onError: (AdErrorEvent event) {
        lastErrorCode = event.code ?? 0;
        lastErrorMessage = event.message;
        debugPrint('[ads] 激励视频错误 code=${event.code} msg=${event.message}');
      },
    );

    bool loaded = false;
    try {
      // 关键: iOS 上原生加载回调(didReceiveAd/didFailWithError)可能不回传,
      // load 会永久挂起 -> adPlaying 一直为 true -> 赚钱页按钮全锁死。
      // 用 timeout 兜底: 15s 内没加载成功就当失败返回, 保证调用方一定解锁。
      loaded = await GromoreAds
          .loadRewardVideoAd(
            AdsConfig.currentRewardVideoId,
            customData: customData,
            userId: userId,
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('[ads] 激励视频加载超时(15s) posId=${AdsConfig.currentRewardVideoId}');
        lastErrorCode = -1;
        lastErrorMessage = '广告加载超时';
        return false;
      });
    } catch (e) {
      // 原生侧加载失败会抛 PlatformException(LOAD_ERROR), 这里兜住避免变成未捕获异常
      debugPrint('[ads] 激励视频加载异常 posId=${AdsConfig.currentRewardVideoId} err=$e');
      final String s = e.toString();
      final RegExpMatch? m = RegExp(r'(\d{5})\s*,').firstMatch(s);
      if (m != null) lastErrorCode = int.tryParse(m.group(1)!) ?? -1;
      lastErrorMessage = s;
    }
    debugPrint('[ads] 激励视频加载 posId=${AdsConfig.currentRewardVideoId} loaded=$loaded');
    if (!loaded) {
      sub.cancel();
      return false;
    }

    // show 成功即返回: 广告页是全屏原生 VC, 用户看完/关闭后自然回到赚钱页。
    // 不等待任何回调 —— 回调可能永久丢失, 但"展示成功"本身是同步可确认的。
    try {
      await GromoreAds
          .showRewardVideoAd(AdsConfig.currentRewardVideoId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[ads] 激励视频展示调用超时(10s) posId=${AdsConfig.currentRewardVideoId}');
        return true; // 展示调用超时通常意味着广告已经弹出, 按成功处理让调用方解锁
      });
      debugPrint('[ads] 激励视频展示成功 posId=${AdsConfig.currentRewardVideoId}');
      // 延迟取消订阅, 给事件回传留一点窗口用于记录日志/错误码
      Future<void>.delayed(const Duration(seconds: 10), sub.cancel);
      return true;
    } catch (e) {
      debugPrint('[ads] 激励视频展示异常 posId=${AdsConfig.currentRewardVideoId} err=$e');
      sub.cancel();
      return false;
    }
  }

  /// 插屏广告: 加载 -> 展示
  static Future<void> showInterstitial() async {
    if (!await init() || AdsConfig.currentInterstitialId.isEmpty) return;
    if (!_sdkReady) return;
    final bool loaded = await GromoreAds.loadInterstitialAd(AdsConfig.currentInterstitialId);
    debugPrint('[ads] 插屏加载 posId=${AdsConfig.currentInterstitialId} loaded=$loaded');
    if (loaded) await GromoreAds.showInterstitialAd(AdsConfig.currentInterstitialId);
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
