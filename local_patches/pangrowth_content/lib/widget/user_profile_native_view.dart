import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../pangrowth_content.dart';

/// 个人主页 NativeView
///
/// 封装穿山甲内容 SDK 的 `create(DPWidgetUserProfileParam)` Fragment。
///
/// **平台支持**：
/// - ✅ Android: 完整支持
/// - ✅ iOS: 完整支持
class UserProfileNativeView extends StatefulWidget {
  /// 主页配置
  final UserProfileConfig config;

  /// 控制器（可选）
  final UserProfileController? controller;

  /// 个人主页事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// UserProfileNativeView(
  ///   listener: UserProfileListener(
  ///     onProfileReady: (profileId) => print('Ready: $profileId'),
  ///     onProfileError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final UserProfileListener? listener;

  /// 自定义 ID（用于事件过滤），默认自动生成
  final String? profileId;

  /// 额外参数
  final Map<String, dynamic>? extra;

  /// 手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const UserProfileNativeView({
    super.key,
    this.config = const UserProfileConfig(),
    this.controller,
    this.listener,
    this.profileId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<UserProfileNativeView> createState() => _UserProfileNativeViewState();
}

class _UserProfileNativeViewState extends State<UserProfileNativeView> {
  static const String _viewType = 'pangrowth_content/user_profile_view';

  late final String _profileId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId ?? _generateProfileId();
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
        widget.listener?.onProfileDisposed?.call();
        unawaited(PangrowthContent.destroyUserProfile(_profileId));
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserProfileNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_profileId);
      }
    }

    // 处理 listener 更新
    if (!identical(widget.listener, oldWidget.listener)) {
      _unregisterListener();
      _registerListener();
    }
  }

  void _onPlatformViewCreated(int id) {
    if (_disposed) {
      return;
    }
    _created = true;
    widget.controller?.initialize(_profileId);
    widget.listener?.onProfileReady?.call(_profileId);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'profileId': _profileId,
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
            '当前平台不支持个人主页',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
    }
  }

  static String _generateProfileId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'user_profile_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerUserProfileListener(
        _profileId,
        widget.listener!,
      );
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterUserProfileListener(_profileId);
  }
}
