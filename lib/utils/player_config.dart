/// 播放器统一配置
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
