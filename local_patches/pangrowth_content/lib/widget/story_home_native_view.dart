import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pangrowth_content.dart';

/// 短故事聚合页 NativeView
///
/// 通过 PlatformView 将原生短故事聚合页内嵌到 Flutter 中，
/// 自动处理 Android 和 iOS 平台的差异，提供统一的接口。
///
/// 使用前请确保：
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化（如果需要广告）。
///
/// **架构说明**：
/// - Android: 使用 NovSdk.factory().createStoryHome() 创建 IDJXWidget
/// - iOS: 使用 MNSMainViewController 作为聚合页视图控制器
///
/// **推荐使用场景**：
/// - 内嵌式短故事聚合页（在Tab或Page中显示）
/// - 需要与其他Flutter Widget组合布局的场景
/// - 需要Flutter自动管理生命周期的场景
///
/// 对比 API方式:
/// - API方式: 通过 create/show/destroy 手动管理生命周期
/// - StoryHomeNativeView: 通过 PlatformView 自动管理（推荐）
class StoryHomeNativeView extends StatefulWidget {
  /// 是否支持下拉刷新
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：false（不支持下拉刷新）
  final bool? canPullRefresh;

  /// 布局Y轴偏移量，单位dp
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：-1（无偏移）
  final int? topOffset;

  /// 推荐榜请求分页大小
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：9
  final int? recPageSize;

  /// 阅读器的个性化配置
  ///
  /// 对应原生 NovReaderConfig (Android) / MNStoryReaderOpenParams (iOS) 的自定义字段
  ///
  /// **Android支持的配置项**：
  /// - endPageRecSize: 文末推荐数量
  /// - defaultTextSize: 默认字体大小
  /// - 更多配置请参考官方文档
  ///
  /// **iOS支持的配置项**：
  /// - customRewardAD: 是否自定义激励广告
  /// - addCustomRewardPoint: 是否增加自定义解锁点
  /// - showCustomBottomBannerAD: 是否显示banner广告
  /// - showCustomMiddleAD: 是否显示章间广告
  /// - pageIntervalForMiddleAD: 章间广告显示间隔
  /// - pageTurnType: 翻页模式 (0:仿真, 1:滑页, 2:平移, 3:上下滚动)
  /// - fontSizeLevel: 字体大小档位
  final Map<String, dynamic>? readerConfig;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  /// 短故事聚合页事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// StoryHomeNativeView(
  ///   listener: StoryHomeListener(
  ///     onStoryHomeReady: (homeId) => print('Ready: $homeId'),
  ///     onStoryHomeError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final StoryHomeListener? listener;

  /// 自定义视图标识（用于调试），默认自动生成
  final String? viewId;

  const StoryHomeNativeView({
    super.key,
    this.canPullRefresh,
    this.topOffset,
    this.recPageSize,
    this.readerConfig,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.listener,
    this.viewId,
  });

  @override
  State<StoryHomeNativeView> createState() => _StoryHomeNativeViewState();
}

class _StoryHomeNativeViewState extends State<StoryHomeNativeView>
    with WidgetsBindingObserver {
  static const String _viewType = 'pangrowth_content/story_home_view';

  late final String _viewId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _viewId = widget.viewId ?? _generateViewId();
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
        widget.listener?.onStoryHomeDisposed?.call();
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoryHomeNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 listener 更新
    if (!identical(widget.listener, oldWidget.listener)) {
      _unregisterListener();
      _registerListener();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 短故事聚合页的生命周期由SDK内部管理
    // 不需要手动调用 pause/resume
  }

  void _onPlatformViewCreated(int id) {
    if (!_disposed) {
      _created = true;
      widget.listener?.onStoryHomeReady?.call(_viewId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'viewId': _viewId,
    };

    // 添加可选参数（只传递非null值）
    if (widget.canPullRefresh != null) {
      creationParams['canPullRefresh'] = widget.canPullRefresh;
    }
    if (widget.topOffset != null) {
      creationParams['topOffset'] = widget.topOffset;
    }
    if (widget.recPageSize != null) {
      creationParams['recPageSize'] = widget.recPageSize;
    }
    if (widget.readerConfig != null && widget.readerConfig!.isNotEmpty) {
      creationParams['readerConfig'] = widget.readerConfig;
    }
    if (widget.extra != null && widget.extra!.isNotEmpty) {
      creationParams['extra'] = widget.extra;
    }

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
            'StoryHomeNativeView is not supported on ${defaultTargetPlatform.name}',
            style: const TextStyle(color: Colors.red),
          ),
        );
    }
  }

  String _generateViewId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'story_home_${timestamp}_$random';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerStoryHomeListener(_viewId, widget.listener!);
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterStoryHomeListener(_viewId);
  }
}
