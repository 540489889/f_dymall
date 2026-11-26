import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../pangrowth_content.dart';

/// 内嵌原生短剧聚合页视图（单实例）。
///
/// 使用前请确保：
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化（原生层会再次校验，未完成时会发送错误事件）。
class DramaHomeNativeView extends StatefulWidget {
  /// 聚合页配置
  final DramaHomeConfig config;

  /// 聚合页控制器（可选）
  ///
  /// 提供 seekTo/setCurrentPage/setCurrentDramaIndex 等控制方法。
  /// 注意：DramaHome仅支持Android平台。
  final DramaHomeController? controller;

  /// 聚合页事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// DramaHomeNativeView(
  ///   listener: DramaHomeListener(
  ///     onHomeReady: (homeId) => print('Ready: $homeId'),
  ///     onHomeError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final DramaHomeListener? listener;

  /// 自定义视图标识（用于事件过滤），默认自动生成
  final String? viewId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const DramaHomeNativeView({
    super.key,
    required this.config,
    this.controller,
    this.listener,
    this.viewId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<DramaHomeNativeView> createState() => _DramaHomeNativeViewState();
}

class _DramaHomeNativeViewState extends State<DramaHomeNativeView> {
  static const String _viewType = 'pangrowth_content/drama_home_view';
  static bool _isMounted = false;

  late final String _viewId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    if (_isMounted) {
      throw StateError('短剧聚合页视图仅支持单实例，请先销毁已有实例后再创建。');
    }
    _isMounted = true;
    _viewId = widget.viewId ?? _generateViewId();
    // 注册 listener
    _registerListener();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _isMounted = false;
      // 取消注册 listener
      _unregisterListener();
      if (_created) {
        widget.controller?.dispose();
        widget.listener?.onHomeDisposed?.call();
      }
      unawaited(PangrowthContent.destroyDramaHome(_viewId));
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DramaHomeNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_viewId);
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
      widget.controller?.initialize(_viewId);
      widget.listener?.onHomeReady?.call(_viewId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'viewId': _viewId,
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
        return const SizedBox.shrink();
    }
  }

  static String _generateViewId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'drama_home_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerDramaHomeListener(_viewId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterDramaHomeListener(_viewId);
  }
}
