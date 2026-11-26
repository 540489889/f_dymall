import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../pangrowth_content.dart';

/// 内嵌原生短故事阅读器视图
///
/// 通过 PlatformView 将原生短故事阅读器内嵌到 Flutter 中,
/// 自动处理 Android 和 iOS 平台的差异,提供统一的接口。
///
/// **支持的自定义广告类型**:
/// - 章间广告: 在章节切换时插入的全屏广告
/// - 段间广告: 在段落间插入的行内广告
/// - Banner广告: 底部横幅广告
///
/// 使用前请确保:
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化(如果需要广告)。
class StoryReaderNativeView extends StatefulWidget {
  /// 阅读器配置
  final StoryReaderConfig config;

  /// 阅读器控制器(可选)
  /// 如果提供控制器,将自动初始化和管理阅读器ID
  final StoryReaderController? controller;

  /// 阅读器事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件,与gromore_ads保持一致的设计风格。
  ///
  /// 示例:
  /// ```dart
  /// StoryReaderNativeView(
  ///   listener: StoryReaderListener(
  ///     onReaderReady: (readerId) => print('Ready: $readerId'),
  ///     onReaderError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final StoryReaderListener? listener;

  /// 自定义阅读器标识(用于事件过滤),默认自动生成
  /// 如果使用 controller,此参数会被忽略
  final String? readerId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const StoryReaderNativeView({
    super.key,
    required this.config,
    this.controller,
    this.listener,
    this.readerId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<StoryReaderNativeView> createState() => _StoryReaderNativeViewState();
}

class _StoryReaderNativeViewState extends State<StoryReaderNativeView> {
  static const String _viewType = 'pangrowth_content/story_reader_view';

  late final String _readerId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _readerId = widget.readerId ?? _generateReaderId();
    // 注册 listener
    _registerListener();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      // 取消注册 listener
      _unregisterListener();
      if (_created) {
        unawaited(PangrowthContent.destroyStoryReader(_readerId));
        widget.controller?.dispose();
        widget.listener?.onReaderDisposed?.call();
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoryReaderNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_readerId);
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
      // 如果提供了控制器,自动初始化
      widget.controller?.initialize(_readerId);
      widget.listener?.onReaderReady?.call(_readerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'readerId': _readerId,
      'storyId': widget.config.storyId,
      'config': widget.config.toMap(),
      if (widget.extra != null && widget.extra!.isNotEmpty)
        'extra': widget.extra,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: _viewType,
          surfaceFactory:
              (BuildContext context, PlatformViewController controller) {
                return AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  gestureRecognizers: widget.gestureRecognizers,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                );
              },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            final SurfaceAndroidViewController controller =
                PlatformViewsService.initSurfaceAndroidView(
                  id: params.id,
                  viewType: _viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: creationParams,
                  creationParamsCodec: const StandardMessageCodec(),
                );
            controller.addOnPlatformViewCreatedListener((int id) {
              params.onPlatformViewCreated(id);
              _onPlatformViewCreated(id);
            });
            controller.create();
            return controller;
          },
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: widget.gestureRecognizers,
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      default:
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              '当前平台不支持短故事阅读器',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        );
    }
  }

  static String _generateReaderId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'story_reader_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerStoryReaderListener(_readerId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterStoryReaderListener(_readerId);
  }
}

/// 短故事阅读器页面组件
///
/// 包含完整页面结构的版本,适用于路由导航
class StoryReaderPage extends StatefulWidget {
  /// 阅读器配置
  final StoryReaderConfig config;

  /// 页面标题
  final String title;

  /// 是否显示应用栏
  final bool showAppBar;

  /// 背景色
  final Color backgroundColor;

  /// 自定义阅读器标识
  final String? readerId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 阅读器事件监听器
  final StoryReaderListener? listener;

  const StoryReaderPage({
    super.key,
    required this.config,
    this.title = '短故事阅读',
    this.showAppBar = true,
    this.backgroundColor = Colors.white,
    this.readerId,
    this.extra,
    this.listener,
  });

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: widget.backgroundColor,
              iconTheme: const IconThemeData(color: Colors.black),
              title: Text(
                widget.title,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            )
          : null,
      body: SafeArea(
        child: StoryReaderNativeView(
          config: widget.config,
          readerId: widget.readerId,
          extra: widget.extra,
          listener: widget.listener,
        ),
      ),
    );
  }
}
