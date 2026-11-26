import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pangrowth_content.dart';

/// 内嵌原生小视频视图
///
/// 通过 PlatformView 将原生小视频播放器内嵌到 Flutter 中，
/// 自动处理 Android 和 iOS 平台的差异，提供统一的接口。
///
/// 使用前请确保：
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化（如果需要广告）。
class VideoNativeView extends StatefulWidget {
  /// 频道类型：1-推荐，2-关注，3-推荐+关注
  final int channelType;

  /// 内容类型：1-小视频，2-直播，3-小视频+直播
  final int contentType;

  /// 样式类型：2-全屏沉浸式，3-宫格，4-瀑布流
  final int style;

  /// 是否隐藏频道名称（顶部切换栏）
  final bool hideChannelName;

  /// 是否自动播放
  final bool autoPlay;

  /// 视频控制器（可选）
  /// 如果提供控制器，将自动初始化和管理视频ID
  final VideoController? controller;

  /// 视频事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// VideoNativeView(
  ///   listener: VideoListener(
  ///     onVideoReady: (videoId) => print('Ready: $videoId'),
  ///     onVideoError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final VideoListener? listener;

  /// 自定义视频标识（用于事件过滤），默认自动生成
  /// 如果使用 controller，此参数会被忽略
  final String? videoId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const VideoNativeView({
    super.key,
    this.channelType = 1,
    this.contentType = 1,
    this.style = 2,
    this.hideChannelName = false,
    this.autoPlay = true,
    this.controller,
    this.listener,
    this.videoId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<VideoNativeView> createState() => _VideoNativeViewState();
}

class _VideoNativeViewState extends State<VideoNativeView>
    with WidgetsBindingObserver {
  static const String _viewType = 'pangrowth_content/video_view';

  late final String _videoId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _videoId = widget.videoId ?? _generateVideoId();
    WidgetsBinding.instance.addObserver(this);
    // 注册 listener
    _registerListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_disposed) {
      _disposed = true;
      // 取消注册 listener
      _unregisterListener();
      if (_created) {
        // 页面销毁时停止播放，释放资源
        _pauseVideo();

        // 如果提供了控制器，由控制器负责销毁
        if (widget.controller != null) {
          widget.controller!.dispose();
        }
        widget.listener?.onVideoDisposed?.call();
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_created) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // 应用进入后台，暂停视频
        _pauseVideo();
        break;
      case AppLifecycleState.resumed:
        // 应用回到前台，恢复视频
        _resumeVideo();
        break;
      default:
        break;
    }
  }

  @override
  void didUpdateWidget(covariant VideoNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_videoId);
      }
    }

    // 处理 listener 更新
    if (!identical(widget.listener, oldWidget.listener)) {
      _unregisterListener();
      _registerListener();
    }
  }

  void _onPlatformViewCreated(int id) {
    if (!_disposed) {
      _created = true;
      // 如果提供了控制器，自动初始化
      widget.controller?.initialize(_videoId);
      widget.listener?.onVideoReady?.call(_videoId);
    }
  }

  Future<void> _pauseVideo() async {
    try {
      await PangrowthContent.pauseVideo(_videoId);
    } catch (e) {
      debugPrint('VideoNativeView: Failed to pause video: $e');
    }
  }

  Future<void> _resumeVideo() async {
    try {
      await PangrowthContent.resumeVideo(_videoId);
    } catch (e) {
      debugPrint('VideoNativeView: Failed to resume video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'videoId': _videoId,
      'channelType': widget.channelType,
      'contentType': widget.contentType,
      'style': widget.style,
      'hideChannelName': widget.hideChannelName,
      'autoPlay': widget.autoPlay,
      if (widget.extra != null && widget.extra!.isNotEmpty)
        'extra': widget.extra,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        );

      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        );

      default:
        return Center(
          child: Text(
            'VideoNativeView is not supported on ${defaultTargetPlatform.name}',
            style: const TextStyle(color: Colors.red),
          ),
        );
    }
  }

  String _generateVideoId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'video_${timestamp}_$random';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerVideoListener(_videoId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterVideoListener(_videoId);
  }
}
