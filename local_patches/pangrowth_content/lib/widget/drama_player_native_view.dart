import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../pangrowth_content.dart';

/// 内嵌原生短剧播放器视图
///
/// 通过 PlatformView 将原生短剧播放器内嵌到 Flutter 中，
/// 自动处理 Android 和 iOS 平台的差异，提供统一的接口。
///
/// 使用前请确保：
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化。
///
/// **返回按钮行为**：
/// - 原生SDK的返回按钮存在问题，因此使用Flutter层返回按钮替代
/// - 通过 `config.hideBack` 参数控制返回按钮显示：
///   - `hideBack: false` 或 `null`：显示 Flutter 层返回按钮（默认）
///   - `hideBack: true`：完全隐藏返回按钮
/// - 点击返回按钮默认调用 `Navigator.pop(context)`
class DramaPlayerNativeView extends StatefulWidget {
  /// 播放器配置
  final DramaPlayerConfig config;

  /// 播放器控制器（可选）
  /// 如果提供控制器，将自动初始化和管理播放器ID
  final DramaPlayerController? controller;

  /// 播放器事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// DramaPlayerNativeView(
  ///   listener: DramaPlayerListener(
  ///     onPlayerReady: (playerId) => print('Ready: $playerId'),
  ///     onPlayerError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final DramaPlayerListener? listener;

  /// 自定义播放器标识（用于事件过滤），默认自动生成
  /// 如果使用 controller，此参数会被忽略
  final String? playerId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const DramaPlayerNativeView({
    super.key,
    required this.config,
    this.controller,
    this.listener,
    this.playerId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  State<DramaPlayerNativeView> createState() => _DramaPlayerNativeViewState();
}

class _DramaPlayerNativeViewState extends State<DramaPlayerNativeView> {
  static const String _viewType = 'pangrowth_content/drama_player_view';

  late final String _viewPlayerId;
  late String _currentPlayerId;
  bool _disposed = false;
  bool _created = false;
  bool _nativeReady = false;

  DramaPlayerController? _controller;
  DramaPlayerListener? _listenerProxy;

  @override
  void initState() {
    super.initState();
    _viewPlayerId = widget.playerId ?? _generatePlayerId();
    _currentPlayerId = _viewPlayerId;
    _controller = widget.controller;

    // 注册内部代理listener，确保controller与SDK同步
    _registerListener();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _nativeReady = false;

      // 取消注册 listener
      _unregisterListener();

      if (_created) {
        unawaited(PangrowthContent.destroyDramaPlayer(_currentPlayerId));
        _controller?.dispose();
        widget.listener?.onPlayerDisposed?.call();
      }
    }
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    if (!_disposed) {
      _created = true;
    }
  }

  @override
  void didUpdateWidget(covariant DramaPlayerNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.controller, oldWidget.controller)) {
      // 清理旧控制器，避免继续持有失效的playerId
      oldWidget.controller?.dispose();
      _controller = widget.controller;

      if (_nativeReady && _controller != null) {
        _controller!.initialize(_currentPlayerId);
      }
    }

    if (!identical(widget.listener, oldWidget.listener)) {
      _registerListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 强制隐藏原生返回按钮，使用Flutter层返回按钮替代
    final modifiedConfig = widget.config.copyWith(hideBack: true);

    final Map<String, dynamic> creationParams = <String, dynamic>{
      'playerId': _viewPlayerId,
      'dramaId': modifiedConfig.dramaId,
      'episode': modifiedConfig.episode,
      'config': modifiedConfig.toMap(),
      if (widget.extra != null && widget.extra!.isNotEmpty)
        'extra': widget.extra,
    };

    return Stack(
      children: [
        // 原生播放器视图
        _buildPlatformView(context, creationParams),

        // Flutter层返回按钮（叠加在原生视图上）
        // 根据 config.hideBack 参数决定是否显示
        if (widget.config.hideBack != true) _buildFlutterBackButton(context),
      ],
    );
  }

  /// 构建原生平台视图
  Widget _buildPlatformView(
    BuildContext context,
    Map<String, dynamic> creationParams,
  ) {
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
              '当前平台不支持短剧播放',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        );
    }
  }

  /// 构建Flutter层返回按钮（模仿原生样式）
  Widget _buildFlutterBackButton(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _generatePlayerId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'drama_player_${millis}_${randomSuffix.toRadixString(16)}';
  }

  void _registerListener() {
    if (_disposed) {
      return;
    }
    _listenerProxy = _buildListenerProxy(widget.listener);
    PangrowthContent.registerDramaPlayerListener(
      _currentPlayerId,
      _listenerProxy!,
    );
  }

  void _unregisterListener() {
    PangrowthContent.unregisterDramaPlayerListener(_currentPlayerId);
    _listenerProxy = null;
  }

  DramaPlayerListener _buildListenerProxy(DramaPlayerListener? userListener) {
    return DramaPlayerListener(
      onPlayerReady: (playerId) {
        _handlePlayerReady(playerId, userListener);
      },
      onPlayerError: (error) {
        userListener?.onPlayerError?.call(error);
      },
      onPlayerClose: () {
        userListener?.onPlayerClose?.call();
      },
      onPlayerDisposed: () {
        _handlePlayerDisposed();
        userListener?.onPlayerDisposed?.call();
      },
      onVideoStart: (dramaInfo, extraInfo) {
        userListener?.onVideoStart?.call(dramaInfo, extraInfo);
      },
      onVideoOverPlay: (extraInfo) {
        userListener?.onVideoOverPlay?.call(extraInfo);
      },
      onVideoPause: (extraInfo) {
        userListener?.onVideoPause?.call(extraInfo);
      },
      onVideoContinue: (extraInfo) {
        userListener?.onVideoContinue?.call(extraInfo);
      },
      onVideoCompletion: (extraInfo) {
        userListener?.onVideoCompletion?.call(extraInfo);
      },
      onSeekTo: (position, time) {
        userListener?.onSeekTo?.call(position, time);
      },
      onDurationChange: (current) {
        userListener?.onDurationChange?.call(current);
      },
      onVideoProgress: (progress, dramaInfo) {
        userListener?.onVideoProgress?.call(progress, dramaInfo);
      },
      onPageChange: (position, extraInfo) {
        userListener?.onPageChange?.call(position, extraInfo);
      },
      onEpisodeChange: (episode) {
        // ignore: deprecated_member_use_from_same_package
        userListener?.onEpisodeChange?.call(episode);
      },
      onDramaSwitch: (drama) {
        userListener?.onDramaSwitch?.call(drama);
      },
      onDramaGalleryShow: (extraInfo) {
        userListener?.onDramaGalleryShow?.call(extraInfo);
      },
      onDramaGalleryClick: (extraInfo) {
        userListener?.onDramaGalleryClick?.call(extraInfo);
      },
      onClickEnter: (dramaInfo) {
        userListener?.onClickEnter?.call(dramaInfo);
      },
      onNextPlayletWillPlay: (dramaInfo) {
        userListener?.onNextPlayletWillPlay?.call(dramaInfo);
      },
      onUnlockStart: (dramaInfo, extraInfo) {
        userListener?.onUnlockStart?.call(dramaInfo, extraInfo);
      },
      onUnlockEnd: (success, extraInfo) {
        userListener?.onUnlockEnd?.call(success, extraInfo);
      },
      onShowCustomAd: (dramaInfo) {
        userListener?.onShowCustomAd?.call(dramaInfo);
      },
      onRewardDialogShow: (extraInfo) {
        userListener?.onRewardDialogShow?.call(extraInfo);
      },
      onUnlockDialogAction: (action, extraInfo) {
        userListener?.onUnlockDialogAction?.call(action, extraInfo);
      },
      onAdRequest: () {
        userListener?.onAdRequest?.call();
      },
      onAdLoadSuccess: () {
        userListener?.onAdLoadSuccess?.call();
      },
      onAdLoadFail: (code, message) {
        userListener?.onAdLoadFail?.call(code, message);
      },
      onAdFillFail: (code, message) {
        userListener?.onAdFillFail?.call(code, message);
      },
      onAdShow: () {
        userListener?.onAdShow?.call();
      },
      onAdClick: () {
        userListener?.onAdClick?.call();
      },
      onAdPlayStart: () {
        userListener?.onAdPlayStart?.call();
      },
      onAdPlayPause: () {
        userListener?.onAdPlayPause?.call();
      },
      onAdPlayContinue: () {
        userListener?.onAdPlayContinue?.call();
      },
      onAdPlayComplete: () {
        userListener?.onAdPlayComplete?.call();
      },
      onAdRewardFinish: () {
        userListener?.onAdRewardFinish?.call();
      },
      onAdSkip: () {
        userListener?.onAdSkip?.call();
      },
      onAdBuffer: () {
        userListener?.onAdBuffer?.call();
      },
      onRequestStart: (extraInfo) {
        userListener?.onRequestStart?.call(extraInfo);
      },
      onRequestFail: (code, message, extraInfo) {
        userListener?.onRequestFail?.call(code, message, extraInfo);
      },
      onRequestSuccess: (list) {
        userListener?.onRequestSuccess?.call(list);
      },
    );
  }

  void _handlePlayerReady(String playerId, DramaPlayerListener? userListener) {
    if (_disposed) {
      return;
    }

    if (playerId.isNotEmpty && playerId != _currentPlayerId) {
      PangrowthContent.unregisterDramaPlayerListener(_currentPlayerId);
      _currentPlayerId = playerId;
      _listenerProxy = _buildListenerProxy(userListener);
      PangrowthContent.registerDramaPlayerListener(
        _currentPlayerId,
        _listenerProxy!,
      );
    } else {
      _currentPlayerId = playerId;
    }

    _nativeReady = true;
    _controller?.initialize(playerId);
    userListener?.onPlayerReady?.call(playerId);
  }

  void _handlePlayerDisposed() {
    _nativeReady = false;
    _created = false;
    _controller?.dispose();
  }
}
