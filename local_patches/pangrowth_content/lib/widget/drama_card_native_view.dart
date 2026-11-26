import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../pangrowth_content.dart';

/// 内嵌原生短剧卡片视图
///
/// 通过 PlatformView 将原生短剧卡片内嵌到 Flutter 中,
/// 提供16:9比例的视频预览体验。
///
/// 使用前请确保:
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化。
///
/// 使用示例:
/// ```dart
/// DramaCardNativeView(
///   config: DramaCardConfig(
///     dramaId: 12345,
///     width: 220,
///     isAutoPlay: true,
///     isMuteDefault: true,
///   ),
/// )
/// ```
class DramaCardNativeView extends StatefulWidget {
  /// 短剧卡片配置
  final DramaCardConfig config;

  /// 卡片控制器(可选)
  ///
  /// 提供 play/pause/stop/setMute 等控制方法。
  final DramaCardController? controller;

  /// 卡片事件监听器(可选)
  ///
  /// 使用Listener模式统一管理所有回调事件,与gromore_ads保持一致的设计风格。
  ///
  /// 示例:
  /// ```dart
  /// DramaCardNativeView(
  ///   listener: DramaCardListener(
  ///     onCardReady: (cardId) => print('卡片就绪'),
  ///     onCardError: (error) => print('加载失败'),
  ///   ),
  /// )
  /// ```
  final DramaCardListener? listener;

  /// 自定义卡片标识(用于事件过滤),默认自动生成
  final String? cardId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const DramaCardNativeView({
    super.key,
    required this.config,
    this.controller,
    this.listener,
    this.cardId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<DramaCardNativeView> createState() => _DramaCardNativeViewState();
}

class _DramaCardNativeViewState extends State<DramaCardNativeView> {
  static const String _viewType = 'pangrowth_content/drama_card_view';

  late final String _cardId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _cardId = widget.cardId ?? _generateCardId();
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
        // 页面销毁时停止播放，释放资源
        _stopCard();

        widget.controller?.dispose();
        widget.listener?.onCardDisposed?.call();
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DramaCardNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_cardId);
      }
    }

    // 处理 listener 更新
    if (!identical(widget.listener, oldWidget.listener)) {
      _unregisterListener();
      _registerListener();
    }
  }

  /// 停止卡片播放
  Future<void> _stopCard() async {
    try {
      await PangrowthContent.stopDramaCard(_cardId);
    } catch (e) {
      debugPrint('DramaCardNativeView: Failed to stop card: $e');
    }
  }

  void _onPlatformViewCreated(int id) {
    if (!_disposed) {
      _created = true;
      widget.controller?.initialize(_cardId);
      widget.listener?.onCardReady?.call(_cardId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'cardId': _cardId,
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
              '当前平台不支持短剧卡片',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        );
    }
  }

  static String _generateCardId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'drama_card_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerDramaCardListener(_cardId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterDramaCardListener(_cardId);
  }
}
