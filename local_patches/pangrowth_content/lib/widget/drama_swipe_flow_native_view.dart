import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../pangrowth_content.dart';

/// 短剧滑滑流组件配置
///
/// 适用于追剧Tab等场景，提供垂直滑动的短剧流体验。
/// 类似抖音的短视频流，用户可以上下滑动切换不同短剧。
class DramaSwipeFlowConfig {
  /// 频道类型（1: 推荐, 2: 剧场, 3: 推荐+剧场）
  final int channelType;

  /// 免费集数
  final int detailFree;

  /// 解锁集数（每次解锁的集数）
  final int unlockCount;

  /// 解锁广告模式
  /// 0: SDK默认解锁（使用SDK内置广告）
  /// 1: 自定义解锁（使用自定义广告流程）
  final int unlockAdMode;

  /// 是否隐藏顶部信息
  final bool hideTopInfo;

  /// 顶部信息偏移量（dp）
  final int? setTopOffset;

  /// 是否隐藏底部信息
  final bool hideBottomInfo;

  /// 底部信息偏移量（dp）
  final int? setBottomOffset;

  /// 是否隐藏进入（下一集）按钮
  final bool hideEnter;

  /// 是否隐藏点赞按钮
  final bool hideLikeButton;

  /// 是否隐藏收藏按钮
  final bool hideFavorButton;

  /// 是否显示换一换按钮
  final bool showChangeBtn;

  /// 是否隐藏返回按钮（兼容旧配置的统一开关）
  final bool hideBack;

  /// 是否隐藏滑滑流主页左上角关闭/返回按钮
  final bool? hideFeedBack;

  /// 是否隐藏短剧详情页左上角返回按钮
  final bool? hideDetailBack;

  /// 是否自动播放
  final bool autoPlay;

  /// 自定义广告配置 - Draw广告插入位置数组
  ///
  /// 例如: [3, 6, 9] 表示在第3、6、9个位置插入Draw广告
  /// 仅在提供customDrawAdViewId时生效
  final List<int>? drawAdPositions;

  /// 自定义广告配置 - Draw广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 配合drawAdPositions使用,插入自定义的竖版视频广告
  final String? customDrawAdViewId;

  /// 自定义广告配置 - Banner广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 用于在滑滑流底部显示自定义Banner广告
  final String? customBannerAdViewId;

  const DramaSwipeFlowConfig({
    this.channelType = 1, // 默认推荐频道
    this.detailFree = 5,
    this.unlockCount = 1,
    this.unlockAdMode = 0,
    this.hideTopInfo = false,
    this.setTopOffset,
    this.hideBottomInfo = false,
    this.setBottomOffset,
    this.hideEnter = false,
    this.hideLikeButton = false,
    this.hideFavorButton = false,
    this.showChangeBtn = true,
    this.hideBack = true,
    this.hideFeedBack,
    this.hideDetailBack,
    this.autoPlay = true, // 默认true保持向后兼容
    this.drawAdPositions,
    this.customDrawAdViewId,
    this.customBannerAdViewId,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'channelType': channelType,
      'detailFree': detailFree,
      'unlockCount': unlockCount,
      'unlockAdMode': unlockAdMode,
      'hideTopInfo': hideTopInfo,
      'hideBottomInfo': hideBottomInfo,
      'hideEnter': hideEnter,
      'hideLikeButton': hideLikeButton,
      'hideFavorButton': hideFavorButton,
      'showChangeBtn': showChangeBtn,
      'hideBack': hideBack,
      'hideFeedBack': hideFeedBack ?? hideBack,
      'hideDetailBack': hideDetailBack ?? hideBack,
      'hideRewardDialog': true, // 隐藏SDK奖励对话框，使用自定义对话框
      'autoPlay': autoPlay, // 添加自动播放配置
    };

    if (setTopOffset != null) map['setTopOffset'] = setTopOffset;
    if (setBottomOffset != null) map['setBottomOffset'] = setBottomOffset;

    // 自定义广告参数
    if (drawAdPositions != null && drawAdPositions!.isNotEmpty) {
      map['drawAdPositions'] = drawAdPositions;
    }
    if (customDrawAdViewId != null)
      map['customDrawAdViewId'] = customDrawAdViewId;
    if (customBannerAdViewId != null)
      map['customBannerAdViewId'] = customBannerAdViewId;

    return map;
  }
}

/// 内嵌原生短剧滑滑流视图
///
/// 通过 PlatformView 将原生短剧滑滑流内嵌到 Flutter 中，
/// 提供类似抖音的垂直滑动短剧体验。
///
/// 使用前请确保：
/// 1. 已成功调用 `PangrowthContent.initialize` 和 `PangrowthContent.start`。
/// 2. GroMore(gromore_ads) SDK 完成初始化。
class DramaSwipeFlowNativeView extends StatefulWidget {
  /// 滑滑流配置
  final DramaSwipeFlowConfig config;

  /// 滑滑流控制器（可选）
  final DramaSwipeFlowController? controller;

  /// 滑滑流事件监听器
  ///
  /// 使用Listener模式统一管理所有回调事件，与gromore_ads保持一致的设计风格。
  ///
  /// 示例：
  /// ```dart
  /// DramaSwipeFlowNativeView(
  ///   listener: DramaSwipeFlowListener(
  ///     onSwipeFlowReady: (swipeFlowId) => print('Ready: $swipeFlowId'),
  ///     onSwipeFlowError: (error) => print('Error: $error'),
  ///   ),
  /// )
  /// ```
  final DramaSwipeFlowListener? listener;

  /// 自定义滑滑流标识（用于事件过滤），默认自动生成
  final String? swipeFlowId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 自定义手势识别器
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const DramaSwipeFlowNativeView({
    super.key,
    required this.config,
    this.controller,
    this.listener,
    this.swipeFlowId,
    this.extra,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{
      Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
    },
  });

  @override
  State<DramaSwipeFlowNativeView> createState() =>
      _DramaSwipeFlowNativeViewState();
}

class _DramaSwipeFlowNativeViewState extends State<DramaSwipeFlowNativeView> {
  static const String _viewType = 'pangrowth_content/drama_swipe_flow_view';

  late final String _swipeFlowId;
  bool _disposed = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _swipeFlowId = widget.swipeFlowId ?? _generateSwipeFlowId();
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
        _pause();

        widget.controller?.dispose();
        widget.listener?.onSwipeFlowDisposed?.call();
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DramaSwipeFlowNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 controller 更新
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.dispose();
      if (_created) {
        widget.controller?.initialize(_swipeFlowId);
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
      widget.controller?.initialize(_swipeFlowId);
      widget.listener?.onSwipeFlowReady?.call(_swipeFlowId);
    }
  }

  /// 暂停滑滑流播放
  Future<void> _pause() async {
    try {
      // 调用原生层的pause方法暂停播放
      await PangrowthContent.pauseDramaSwipeFlow(_swipeFlowId);
    } catch (e) {
      debugPrint('DramaSwipeFlowNativeView: Failed to pause: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'swipeFlowId': _swipeFlowId,
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
              '当前平台不支持短剧滑滑流',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        );
    }
  }

  static String _generateSwipeFlowId() {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(1 << 20);
    return 'drama_swipe_flow_${millis}_${randomSuffix.toRadixString(16)}';
  }

  /// 注册 listener
  void _registerListener() {
    if (!_disposed && widget.listener != null) {
      PangrowthContent.registerDramaSwipeFlowListener(
        _swipeFlowId,
        widget.listener!,
      );
    }
  }

  /// 取消注册 listener
  void _unregisterListener() {
    PangrowthContent.unregisterDramaSwipeFlowListener(_swipeFlowId);
  }
}

/// 短剧滑滑流页面组件
///
/// 包含完整页面结构的版本，适用于路由导航
class DramaSwipeFlowPage extends StatefulWidget {
  /// 滑滑流配置
  final DramaSwipeFlowConfig config;

  /// 页面标题
  final String title;

  /// 是否显示应用栏
  final bool showAppBar;

  /// 背景色
  final Color backgroundColor;

  /// 自定义滑滑流标识
  final String? swipeFlowId;

  /// 传递给原生层的额外参数
  final Map<String, dynamic>? extra;

  /// 滑滑流事件监听器
  final DramaSwipeFlowListener? listener;

  const DramaSwipeFlowPage({
    super.key,
    required this.config,
    this.title = '追剧',
    this.showAppBar = true,
    this.backgroundColor = Colors.black,
    this.swipeFlowId,
    this.extra,
    this.listener,
  });

  @override
  State<DramaSwipeFlowPage> createState() => _DramaSwipeFlowPageState();
}

class _DramaSwipeFlowPageState extends State<DramaSwipeFlowPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: widget.backgroundColor,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : null,
      body: SafeArea(
        child: DramaSwipeFlowNativeView(
          config: widget.config,
          swipeFlowId: widget.swipeFlowId,
          extra: widget.extra,
          listener: widget.listener,
        ),
      ),
    );
  }
}
