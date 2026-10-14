/// 播放器统一配置
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 是否 Android 平台
/// * H5(web)读 Platform.isAndroid 会抛 Unsupported operation: Platform._operatingSystem,
///   所以先判 kIsWeb; 桌面端也不需要 Android 那套硬解配置
bool get isAndroidPlatform => !kIsWeb && Platform.isAndroid;

/// 是否 iOS 平台(同样先判 kIsWeb)
/// * iOS 的 media_kit 用的是 libmpv-darwin-build 预编译包, 其 ffmpeg 不含 rtmp,
///   所以 iOS 拉流必须走 HLS(m3u8), 不能直接用 push_link(rtmp://)
bool get isIosPlatform => !kIsWeb && Platform.isIOS;

/// 协议白名单
/// media_kit 默认的 PlayerConfiguration.protocolWhitelist 不含 rtmp,
/// 直接播 rtmp:// 直播会被 ffmpeg 拦掉,这里补齐
const List<String> playerProtocolWhitelist = <String>[
  'udp',
  'rtp',
  'tcp',
  'tls',
  'data',
  'file',
  'http',
  'https',
  'crypto',
  'rtmp',
  'rtmps',
  'rtmpte',
  'rtmpts',
  'rtsp',
  'rtspu',
  'rtsps',
];

/// 直播拉流用 Player: 补齐 rtmp 白名单,并打开 mpv 日志便于排查
Player createLivePlayer() {
  return Player(
    configuration: const PlayerConfiguration(
      protocolWhitelist: playerProtocolWhitelist,
      logLevel: MPVLogLevel.info,
    ),
  );
}

/// Android 视频输出配置
///
/// hwdec 必须用 mediacodec-copy(硬解后拷回内存),不能用 mediacodec / mediacodec_embed:
/// 该机型海思 OMX 解码器在 1080p 上要求 9~12 个输出 buffer,而 media_kit 在 Android
/// 的输出是 ImageReader(buffer 数固定,不支持动态扩容),直出必然
/// `Failed to allocate buffers` -> `Could not open codec`。
const VideoControllerConfiguration androidLiveVideoConfig = VideoControllerConfiguration(
  vo: 'gpu',
  hwdec: 'mediacodec-copy',
  // 是否等视频参数(分辨率)到达后再挂 Surface
  // * true(实测无效,已回退): 起播时 VO 是 [null], 收到分辨率后照样走
  //   SetSurfaceSize -> wid 变化 -> 内部 seek -> RTMP 被打断, 一次重连照样发生;
  //   而且第一轮根本没真输出画面(VO null), "首帧已渲染" 判定反而更不可靠
  // * false: 起播就有 VO(能看到画面), 代价是首帧后被 seek 打断一次, 由 LiveReconnector 重连恢复
  androidAttachSurfaceAfterVideoParameters: false,
);

/// 最近一次直播视频的实际输出尺寸(经旋转换算,与 SetSize 用的尺寸一致)
/// * 用于下次起播前预设 Surface 尺寸, 见 [presetLiveSurfaceSize]
int? lastLiveVideoWidth;
int? lastLiveVideoHeight;

/// 横屏 / 竖屏各自最近一次的实测输出尺寸
/// * 分开记的原因: 换到横竖屏不同的房间时, "上一条流的尺寸"必然对不上,
///   出帧那次 SetSurfaceSize 会重建 Surface -> seek 打断 RTMP -> 白白重连一次
///   (实测: 从竖屏 540x960 的房间切到横屏 1920x1080 的房间, 进房要黑 4~5 秒才出画面)
/// * 按宽高比归档(w >= h 记横屏), 起播前按目标房间的横竖屏各取各的
int? lastLandscapeVideoWidth;
int? lastLandscapeVideoHeight;
int? lastPortraitVideoWidth;
int? lastPortraitVideoHeight;

/// 按横竖屏取上次实测的输出尺寸(没实测过时用常规比例兜底: 横屏 16:9 / 竖屏 9:16)
/// * [landscape] true 取横屏那条, false 取竖屏那条
int presetWidthOf(bool landscape) =>
    landscape ? (lastLandscapeVideoWidth ?? 1920) : (lastPortraitVideoWidth ?? 540);
int presetHeightOf(bool landscape) =>
    landscape ? (lastLandscapeVideoHeight ?? 1080) : (lastPortraitVideoHeight ?? 960);

/// 首页直播预览是否被挂起(进入直播间时为 true, 离开直播间恢复 false)
///
/// * 首页预览与直播间是两台播放器(两路硬解), 同时开第二路在部分机型上直接开不出来
///   (见 androidLiveVideoConfig 里海思 OMX 的说明), 结果就是直播间那一路没有视频轨、只剩封面
/// * 所以进直播间先把首页预览停掉, 空出解码器; 离开直播间再按"卡片是否可见"恢复
final ValueNotifier<bool> livePreviewSuspended = ValueNotifier<bool>(false);

/// media_kit_video 的底层 channel(与插件内 AndroidVideoController 用的是同一个)
/// * Android 的 VideoController.setSize 直接抛 UnsupportedError,
///   但 Java 侧 `VideoOutputManager.SetSurfaceSize` 是通的, 只能绕过 Dart API 调它
const MethodChannel liveVideoChannel = MethodChannel('com.alexmercerind/media_kit_video');

/// 起播前先把 Surface 尺寸设成"视频的实际尺寸"
///
/// media_kit_video(Android) 收到视频分辨率后会走 `VideoOutputManager.SetSurfaceSize`:
/// 1. Dart 侧: `isSame`(与缓存的 rect 比) 命中才 return, 否则调 Java
/// 2. Java 侧: `surfaceProducer.getWidth()/getHeight()` 与新尺寸一致才 return, 否则
///    重建 Surface -> wid 变化 -> widListener 内部 seek -> RTMP 被打断 -> 只能重连一次才稳定
///
/// 起播时 Surface 默认是 1x1(且 wid 还没挂上, mpv 的 VO 是 [null]), 必然不匹配,
/// 所以每次起播都要重建一次 Surface: 首帧出来后立刻被 seek 打断, 起播时间直接翻倍。
/// 这里提前把 Surface 建好并挂上, 让"收到分辨率"那次直接命中短路。
/// * 尺寸猜错了没有副作用: 只是跟原来一样重建一次(由 LiveReconnector 重连兜底)
/// * 优先用上次实测的尺寸(同一个主播的流分辨率一般不变), 首次用 1080p 兜底
/// * [maxTries] 探测次数(每次间隔 100ms): 尺寸猜对时一两次就命中; 猜错会跑满才放弃,
///   切房这种不能白等的场景传小一点(见 LivePage 的 _presetSurfaceOnce)
/// [width] / [height] 给了就用它, 没给才回落到"上次实测的尺寸"(见 presetWidthOf)
Future<void> presetLiveSurfaceSize(Player player, VideoController controller,
    {int maxTries = 10, int? width, int? height}) async {
  if (!isAndroidPlatform) return;
  final int w = width ?? lastLiveVideoWidth ?? 1920;
  final int h = height ?? lastLiveVideoHeight ?? 1080;
  try {
    final int handle = await player.handle;
    for (int i = 0; i < maxTries; i++) {
      await liveVideoChannel.invokeMethod(
        'VideoOutputManager.SetSurfaceSize',
        <String, Object>{
          'handle': handle.toString(),
          'width': w.toString(),
          'height': h.toString(),
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // rect 被更新说明 Java 侧真的建好了 Surface: VideoOutput 还没 Create 时这次调用会被静默忽略
      if ((controller.rect.value?.width.toInt() ?? 0) == w) {
        debugPrint('[live]预设 Surface 尺寸: ${w}x$h');
        return;
      }
    }
    debugPrint('[live]预设 Surface 尺寸未生效(忽略): 目标 ${w}x$h');
  } catch (e) {
    debugPrint('[live]预设 Surface 尺寸失败(忽略): $e');
  }
}

/// 记录本次直播的实际输出尺寸(供下次起播预设)
void recordLiveVideoSize(VideoParams params) {
  final int? dw = params.dw;
  final int? dh = params.dh;
  if (dw == null || dh == null || dw <= 0 || dh <= 0) return;
  // 90/270 度旋转时输出宽高是交换过的, 与 media_kit 里 SetSize 用的尺寸保持一致
  final bool swap = params.rotate == 90 || params.rotate == 270;
  final int w = swap ? dh : dw;
  final int h = swap ? dw : dh;
  lastLiveVideoWidth = w;
  lastLiveVideoHeight = h;
  // 按宽高比归档到横屏/竖屏: 下次起播按目标房间的横竖屏各取各的, 不会互相污染
  if (w >= h) {
    lastLandscapeVideoWidth = w;
    lastLandscapeVideoHeight = h;
  } else {
    lastPortraitVideoWidth = w;
    lastPortraitVideoHeight = h;
  }
}

/// 悬浮小窗的视频输出配置: 走软解(hwdec=no),不跟直播间抢硬解码码器
///
/// 为什么小窗不能用 mediacodec-copy:
/// 1. 从直播间进商品详情时,直播间那一路还在播,硬解码码器已经被占着;
/// 2. 海思这类芯片(OMX.hisi.video.decoder.avc)在 1080p 上要求 9~12 个输出 buffer,
///    并发开第二路硬解大概率直接开不出来 -> 没有视频轨 -> 小窗只剩封面;
/// 3. 小窗只有 96x136,软解完全够用,省下的硬解留给直播间那一大屏。
const VideoControllerConfiguration floatWindowVideoConfig = VideoControllerConfiguration(
  vo: 'gpu',
  hwdec: 'no',
  androidAttachSurfaceAfterVideoParameters: false,
);

/// RTMP 直播自动重连
///
/// 针对 media_kit_video 在 Android 上的一个已知行为:
/// 1. 收到视频分辨率后 -> `VideoOutputManager.SetSurfaceSize` 重建 Surface
/// 2. Surface 句柄(wid)变化 -> `widListener()` 内部会执行一次 `player.seek()`
/// 3. RTMP 不支持 seek -> 流被打断,表现为 videoParams 变回 null、画面黑屏
///
/// 重连一次即可稳定: 再次 open 时视频分辨率与已缓存的 rect 尺寸一致,
/// `isSame` 命中会跳过 SetSurfaceSize,Surface 不再重建,也就不会再触发 seek。
/// (Android 上 VideoControllerConfiguration 的 width/height 无效,无法提前固定尺寸)
///
/// 还有一种更糟的情况: 流在画面出来之前就被打断(videoParams 一直是 null),
/// 上面"出过帧又丢帧"的判定不命中, 会一直黑屏。所以再补两个信号:
/// a. playing 播起来过又变 false、且一直没出画面 -> 300ms 后重连
/// b. 起播 3s 仍无画面、且流已经停了(既没播也没缓冲) -> 重连
/// * 流没断只是起播慢时不打断它, 否则正常起播会被重新来一遍(观感就是"播了两遍")
class LiveReconnector {
  LiveReconnector(this.player, {this.srcProvider, this.onReconnecting});

  final Player player;

  /// 重连前刷新拉流地址: m3u8 地址带 auth_key 时效, 过期后旧地址会 403
  /// * 返回空字符串时沿用当前地址
  final Future<String> Function()? srcProvider;

  /// 开始重连的回调: 重连期间画面是空的, 上层要把封面/占位重新显示出来, 否则就是一块白板
  final VoidCallback? onReconnecting;

  /// 最大重连次数(主播真的下播时避免无限重连)
  static const int maxRetry = 3;

  /// 起播后多久还没画面就检查一次流是不是断了
  /// * 太短会打断正常起播, 太长则黑屏时间久; 流没断只是慢时会再宽限几轮
  static const Duration firstFrameCheck = Duration(seconds: 3);

  /// 当前拉流地址
  String src = '';

  StreamSubscription<VideoParams>? _subscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _timer;
  int _retries = 0;
  bool _hadVideo = false;
  bool _didPlay = false;
  int _openSeq = 0;
  int _slowChecks = 0;

  /// 打开直播流(切换直播间也要走这里,保证重连用最新地址)
  Future<void> open(String url, {bool play = true}) async {
    src = url;
    _retries = 0;
    _hadVideo = false;
    _didPlay = false;
    _slowChecks = 0;
    // 起播序号: 切房/重连后让上一轮还在等待的超时回调失效
    final int seq = ++_openSeq;
    _subscription ??= player.stream.videoParams.listen(_onVideoParams);
    _playingSubscription ??= player.stream.playing.listen(_onPlaying);
    debugPrint('[live]起播: ${url.length > 90 ? '${url.substring(0, 90)}...' : url}');
    await player.open(Media(url), play: play);
    _armWatchdog(seq);
  }

  /// 排一次"首帧超时"检查
  void _armWatchdog(int seq) {
    _timer?.cancel();
    _timer = Timer(firstFrameCheck, () => _onFirstFrameTimeout(seq));
  }

  /// 起播后一直没画面: 流还在就再等等, 流已经停了就重连
  Future<void> _onFirstFrameTimeout(int seq) async {
    if (seq != _openSeq || _hadVideo || src.isEmpty) return;
    // 在播/在缓冲说明流是通的, 只是起播慢: 不要打断它重新起播(那会变成"播了两遍")
    if (player.state.playing || player.state.buffering) {
      if (_slowChecks >= 2) return;
      _slowChecks += 1;
      _armWatchdog(seq);
      return;
    }
    if (_retries >= maxRetry) return;
    _retries += 1;
    debugPrint('[live]起播 ${firstFrameCheck.inSeconds}s 仍无画面(流已停),第 $_retries 次重连: $src');
    await _reconnect(seq);
  }

  /// 播放状态: 播起来过又停了、却一直没出画面 -> 起播被打断, 尽快重连
  Future<void> _onPlaying(bool playing) async {
    if (playing) {
      _didPlay = true;
      return;
    }
    if (!_didPlay || _hadVideo || src.isEmpty || _retries >= maxRetry) return;
    _didPlay = false;
    final int seq = _openSeq;
    // 稍微等一下: open 切换流时会先来一次 playing=false
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (seq != _openSeq || _hadVideo || src.isEmpty || _retries >= maxRetry) return;
    _retries += 1;
    debugPrint('[live]起播后流断了(还没出画面),第 $_retries 次重连: $src');
    await _reconnect(seq);
  }

  /// 视频轨丢失(出过帧又变回无视频)时重连
  Future<void> _onVideoParams(VideoParams params) async {
    final bool hasVideo = (params.dw ?? 0) > 0;
    if (hasVideo) {
      // 记下实际输出尺寸: 下次起播前用它预设 Surface, 让这次的 SetSize 命中短路不再重建
      recordLiveVideoSize(params);
      if (!_hadVideo) debugPrint('[live]视频轨就绪: ${params.dw}x${params.dh}');
      _hadVideo = true;
      return;
    }
    if (!_hadVideo || src.isEmpty || _retries >= maxRetry) return;
    _hadVideo = false;
    final int seq = _openSeq;
    _retries += 1;
    debugPrint('[live]直播流被 seek 打断,第 $_retries 次重连: $src');
    // 重连尽快: 这 600ms 原来会直接叠加到起播等待上(画面刚出又被打断, 白等一截)
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (seq != _openSeq) return;
    await _reconnect(seq);
  }

  /// 重连: 优先用 srcProvider 刷新地址(auth_key 有时效)
  Future<void> _reconnect(int seq) async {
    // 通知上层: 接下来画面会空一段时间(封面重新显示, 避免白板/黑屏)
    onReconnecting?.call();
    String url = src;
    final Future<String> Function()? provider = srcProvider;
    if (provider != null) {
      try {
        url = (await provider()).trim();
      } catch (e) {
        debugPrint('[live]刷新拉流地址失败: $e');
      }
      if (url.isEmpty) url = src;
    }
    // 等地址期间用户可能已经滑走/退出
    if (url.isEmpty || seq != _openSeq) return;
    src = url;
    _hadVideo = false;
    _didPlay = false;
    _slowChecks = 0;
    await player.open(Media(url), play: true);
    _armWatchdog(seq);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _playingSubscription?.cancel();
    _playingSubscription = null;
  }
}
