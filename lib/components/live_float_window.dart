/// 直播间悬浮小窗
/// * 从直播间点商品进商品详情后显示,小窗里继续播直播画面,点小窗回到直播间
/// * 为什么不复用直播间的 Player: media_kit 的 Video 走的是 Texture 输出,
///   同一个 VideoController 给两个 Video 用会互相抢输出(直播间里切房就是这么处理的),
///   所以这里单独起一路 Player(静音),直播间的播放器完全不动
/// * 路由: 直播间在栈里就退回去(Get.until),不在就直接带着房间号重新进
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../utils/player_config.dart';

/// 小窗尺寸(竖屏比例,和直播间画幅一致)
const double _kCardWidth = 96.0;
const double _kCardHeight = 136.0;
/// 距屏幕边缘的间距(吸边后)
const double _kEdge = 10.0;

/// 直播间悬浮小窗: 全局单例,跨页面显示在最上层
class LiveFloatWindow {
  LiveFloatWindow._();

  static final LiveFloatWindow instance = LiveFloatWindow._();

  OverlayEntry? _entry;

  bool get visible => _entry != null;

  /// 显示小窗
  /// * [context] 调用方(页面)的 context: 由它往上找根 Overlay
  ///   * 不能用 Get.overlayContext: 那是 Overlay 自己的 context,而 Overlay.of 只往上找祖先,
  ///     拿它查会返回 null(insert 时空指针,小窗就静默不显示)
  /// * [roomSn] 直播间房间号 sn(点小窗回直播间用)
  /// * [pullUrl] 拉流地址,为空时只显示封面
  /// * [cover] 直播间封面(首帧出来前显示)
  void show({
    required BuildContext context,
    required String roomSn,
    String cover = '',
    String anchorName = '',
    String pullUrl = '',
  }) {
    // 房间号允许为空(演示房间没有 sn): 直播间还在栈里,点小窗退栈就能回去
    if (_entry != null) return;
    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      if (kDebugMode) debugPrint('[live]悬浮小窗: 找不到 Overlay,不显示');
      return;
    }
    if (kDebugMode) {
      debugPrint('[live]悬浮小窗: 显示 roomSn=$roomSn cover=${cover.isNotEmpty} pullUrl=${pullUrl.isNotEmpty}');
    }
    _entry = OverlayEntry(
      builder: (BuildContext context) => _LiveFloatCard(
        roomSn: roomSn,
        cover: cover,
        anchorName: anchorName,
        pullUrl: pullUrl,
        onClose: hide,
      ),
    );
    overlay.insert(_entry!);
  }

  /// 移除小窗(会顺带释放小窗的播放器)
  void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _LiveFloatCard extends StatefulWidget {
  const _LiveFloatCard({
    required this.roomSn,
    required this.onClose,
    this.cover = '',
    this.anchorName = '',
    this.pullUrl = '',
  });

  final String roomSn;
  final String cover;
  final String anchorName;
  final String pullUrl;
  final VoidCallback onClose;

  @override
  State<_LiveFloatCard> createState() => _LiveFloatCardState();
}

class _LiveFloatCardState extends State<_LiveFloatCard> {
  // 小窗播放器: 单独一路流,静音(直播间的播放器还在播,两路都有声会叠在一起)
  late final Player player = createLivePlayer();
  // Android 上走软解(floatWindowVideoConfig): 直播间那一路已经占着硬解码码器,
  // 小窗再去抢会开不出第二路(海思这类芯片尤其明显),最终只剩封面
  late final VideoController videoController = VideoController(
    player,
    configuration: isAndroidPlatform ? floatWindowVideoConfig : const VideoControllerConfiguration(),
  );
  // 首帧: 解码出画面尺寸才算真有画面,之前/断流时继续显示封面
  final ValueNotifier<bool> firstFrame = ValueNotifier<bool>(false);
  // 小窗这路流也会踩 Android 那个坑: 收到分辨率 -> Surface 重建 -> 内部 seek -> RTMP 被打断,
  // 不出画面。所以和直播间一样交给 LiveReconnector 起播(带首帧看门狗 + 自动重连)
  late final LiveReconnector reconnector = LiveReconnector(
    player,
    // 重连期间画面是空的: 把封面重新显示出来,不然是一块白板
    onReconnecting: () {
      if (mounted) firstFrame.value = false;
    },
  );
  StreamSubscription<VideoParams>? _videoParamsSub;

  // 位置(默认右下,可拖动 + 松手吸边)
  double? _left;
  double _top = 160.0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('[live]悬浮小窗: 卡片已挂载 roomSn=${widget.roomSn} pullUrl=${widget.pullUrl.isNotEmpty}');
    }
    // 视频轨: 出尺寸才算真有画面;变回空(被 seek 打断)就退回收藏封面
    _videoParamsSub = player.stream.videoParams.listen((VideoParams params) {
      final bool hasVideo = (params.dw ?? 0) > 0;
      if (hasVideo == firstFrame.value) return;
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[live]悬浮小窗: ${hasVideo ? '画面就绪 ${params.dw}x${params.dh}' : '画面丢失,退回封面'}');
      }
      firstFrame.value = hasVideo;
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    if (widget.pullUrl.isEmpty) {
      if (kDebugMode) debugPrint('[live]悬浮小窗: 没有拉流地址,只显示封面');
      return;
    }
    // 静音: 直播间的播放器还在出声,两路都有声会叠在一起
    await player.setVolume(0.0);
    await reconnector.open(widget.pullUrl);
  }

  @override
  void dispose() {
    _videoParamsSub?.cancel();
    reconnector.dispose();
    firstFrame.dispose();
    player.dispose();
    super.dispose();
  }

  /// 点小窗: 回到直播间
  Future<void> _backToLive() async {
    widget.onClose();
    // 直播间在栈里(从直播间 push 过来的)就一路退回去;退到首页都没找到再重新进
    Get.until((Route<dynamic> route) => route.settings.name == '/live' || route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (Get.currentRoute != '/live') {
      Get.toNamed('/live', arguments: <String, dynamic>{'sn': widget.roomSn});
    }
  }

  void _snapToEdge(Size size) {
    final double center = (_left ?? size.width) + _kCardWidth / 2.0;
    _left = center < size.width / 2.0 ? _kEdge : size.width - _kCardWidth - _kEdge;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double topSafe = MediaQuery.paddingOf(context).top;
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;
    _left ??= size.width - _kCardWidth - _kEdge;
    _top = _top.clamp(topSafe + _kEdge, size.height - _kCardHeight - bottomSafe - _kEdge);

    return AnimatedPositioned(
      // 拖动过程不要动画(会拖尾),松手吸边时才要
      duration: Duration(milliseconds: _dragging ? 0 : 200),
      left: _left,
      top: _top,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (DragUpdateDetails details) {
          setState(() {
            _left = ((_left ?? 0.0) + details.delta.dx).clamp(_kEdge, size.width - _kCardWidth - _kEdge);
            _top = (_top + details.delta.dy).clamp(topSafe + _kEdge, size.height - _kCardHeight - bottomSafe - _kEdge);
          });
        },
        onPanEnd: (_) => setState(() {
          _dragging = false;
          _snapToEdge(size);
        }),
        onTap: _backToLive,
        child: Container(
          width: _kCardWidth,
          height: _kCardHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x33000000), blurRadius: 8.0, offset: Offset(0.0, 2.0)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              // 画面: 首帧出来前显示直播间封面
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: firstFrame,
                  builder: (BuildContext context, bool ok, Widget? cover) => ok
                      ? Video(controller: videoController, fit: BoxFit.cover, controls: NoVideoControls)
                      : cover!,
                  child: _buildCover(),
                ),
              ),
              // 底部信息条: 直播中 + 主播名
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5.0, 10.0, 5.0, 4.0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x00000000), Color(0x99000000)],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 5.0,
                        height: 5.0,
                        decoration: const BoxDecoration(color: Color(0xFFFF2C55), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 3.0),
                      Expanded(
                        child: Text(
                          widget.anchorName.isEmpty ? '直播中' : widget.anchorName,
                          style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 关闭
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 20.0,
                    height: 20.0,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8.0)),
                    ),
                    child: const Icon(Icons.close, size: 13.0, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (widget.cover.isEmpty) {
      return Container(
        color: const Color(0xFF333333),
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv_rounded, size: 24.0, color: Colors.white70),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.cover,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => Container(color: const Color(0xFF333333)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF333333),
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv_rounded, size: 24.0, color: Colors.white70),
      ),
    );
  }
}
