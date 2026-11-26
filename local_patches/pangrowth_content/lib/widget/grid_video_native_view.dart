import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../pangrowth_content.dart';

/// 宫格/双Feed 小视频 NativeView
///
/// 通过 PlatformView 将原生 Fragment 内嵌到 Flutter。
///
/// **平台支持**：
/// - ✅ Android: 完整支持
/// - ✅ iOS: 完整支持
class GridVideoNativeView extends StatefulWidget {
  /// 布局类型（宫格 / 双Feed）
  final GridVideoLayout layout;

  /// 组件配置
  final GridVideoConfig config;

  /// 控制器（可选）
  final GridVideoController? controller;

  /// 宫格视频事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// GridVideoNativeView(
  ///   listener: GridVideoListener(
  ///     onGridReady: (gridId) => print('Ready: $gridId'),
  ///     onGridError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final GridVideoListener? listener;

  /// 自定义 ID（用于事件过滤），默认自动生成
  final String? viewId;

  /// 额外参数，原样透传给原生
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const GridVideoNativeView({
    super.key,
    this.layout = GridVideoLayout.grid,
    this.config = const GridVideoConfig(),
    this.controller,
    this.listener,
    this.viewId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<GridVideoNativeView> createState() => _GridVideoNativeViewState();
}

class _GridVideoNativeViewState extends State<GridVideoNativeView> {
  static const String _viewType = 'pangrowth_content/grid_video_view';

  late final String _gridId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _gridId = widget.viewId ?? _generateGridId();
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
        widget.controller?.dispose();
        widget.listener?.onGridDisposed?.call();
        unawaited(PangrowthContent.destroyGridVideo(_gridId));
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GridVideoNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_gridId);
      }
    }

    // 处理 listener 更新
    if (!identical(widget.listener, oldWidget.listener)) {
      _unregisterListener();
      _registerListener();
    }
  }

  void _onPlatformViewCreated(int id) {
    if (_disposed) return;
    _created = true;
    widget.controller?.initialize(_gridId);
    widget.listener?.onGridReady?.call(_gridId);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'gridId': _gridId,
      'layout': widget.layout.name,
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
            controller.addOnPlatformViewCreatedListener((int viewId) {
              params.onPlatformViewCreated(viewId);
              _onPlatformViewCreated(viewId);
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
        // macOS、Windows、Linux等未实现平台显示提示
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text(
            '当前平台不支持宫格小视频',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
    }
  }

  static String _generateGridId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'grid_video_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerGridVideoListener(_gridId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterGridVideoListener(_gridId);
  }
}
