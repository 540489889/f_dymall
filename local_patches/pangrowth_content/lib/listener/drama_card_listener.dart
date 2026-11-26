import '../model/drama_info.dart';

/// 短剧卡片事件监听器
///
/// 用于监听短剧卡片的各种事件,包括生命周期和业务交互事件。
/// 与 gromore_ads 和 DramaSwipeFlowListener 保持一致的Listener模式。
class DramaCardListener {
  // ==================== 生命周期事件 ====================

  /// 卡片创建完成并准备就绪
  /// [cardId] 卡片实例唯一标识
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String cardId)? onCardReady;

  /// 卡片发生错误
  /// [error] 错误信息
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String error)? onCardError;

  /// 卡片销毁
  ///
  /// **平台**: Flutter封装层自创
  final void Function()? onCardDisposed;

  // ==================== 数据加载事件 ====================

  /// 卡片数据加载完成
  /// [drama] 加载完成的短剧信息
  ///
  /// **平台**: Android+iOS (Flutter封装)
  final void Function(DramaInfo? drama)? onDataLoaded;

  // ==================== 交互事件 ====================

  /// 卡片被点击
  /// [drama] 被点击的短剧信息
  ///
  /// **平台**: Android+iOS (Flutter封装)
  final void Function(DramaInfo? drama)? onCardClicked;

  // ==================== iOS 播放器状态事件 ====================

  /// 第一帧准备好显示（iOS专用）
  ///
  /// 当视频第一帧准备好可以显示时触发。
  /// 此时可以进行UI调整，如隐藏loading、显示播放按钮等。
  ///
  /// **平台**: iOS独有
  /// - iOS: `playletCardReadyToDisplay(_)`
  ///
  /// 🔵 iOS 独有回调
  final void Function()? onReadyToDisplay;

  /// 即将播放（iOS专用）
  ///
  /// 视频即将开始播放时触发。
  /// 在实际播放开始前的最后时刻调用。
  ///
  /// **平台**: iOS独有
  /// - iOS: `playletCardReadyToPlay(_)`
  ///
  /// 🔵 iOS 独有回调
  final void Function()? onReadyToPlay;

  /// 播放状态变化（仅保留向后兼容）
  /// [isPlaying] 是否正在播放
  ///
  /// **注意**: 推荐使用 `onPlayStateChanged` 获取详细的播放状态
  ///
  /// **平台**: 通用回调
  @Deprecated('推荐使用onPlayStateChanged获取详细的播放状态')
  final void Function(bool isPlaying)? onPlaybackStateChanged;

  /// 播放状态切换（iOS专用）
  /// [state] 播放状态字符串
  ///
  /// **状态值**:
  /// - 'playing': 正在播放
  /// - 'paused': 已暂停
  /// - 'stopped': 已停止
  /// - 'buffering': 缓冲中
  /// - 'error': 错误状态
  ///
  /// **平台**: iOS独有
  /// - iOS: `playletCard(_,playbackStateDidChanged:)`
  ///
  /// 🔵 iOS 独有回调
  final void Function(String state)? onPlayStateChanged;

  /// 用户主动停止播放（iOS专用）
  ///
  /// 当用户主动点击停止按钮或通过手势停止播放时触发。
  /// 与系统自动停止（如播放完成）区分开来。
  ///
  /// **平台**: iOS独有
  /// - iOS: `playletCardUserStopped(_)`
  ///
  /// 🔵 iOS 独有回调
  final void Function()? onUserStopped;

  /// 播放结束（iOS专用）
  /// [error] 错误信息（如果有）
  /// [statusCode] 状态码
  ///
  /// 视频播放结束时触发，可能是正常播放完成，也可能是出现错误。
  /// 通过 error 参数判断是否有错误发生。
  ///
  /// **平台**: iOS独有
  /// - iOS: `playletCardDidFinish(_,error:videoStatusException:)`
  ///
  /// 🔵 iOS 独有回调
  ///
  /// **使用示例**:
  /// ```dart
  /// onFinish: (error, statusCode) {
  ///   if (error != null) {
  ///     print('播放出错: $error (状态码: $statusCode)');
  ///   } else {
  ///     print('播放完成');
  ///   }
  /// }
  /// ```
  final void Function(String? error, int? statusCode)? onFinish;

  const DramaCardListener({
    // 生命周期事件
    this.onCardReady,
    this.onCardError,
    this.onCardDisposed,
    // 数据加载事件
    this.onDataLoaded,
    // 交互事件
    this.onCardClicked,
    // iOS 播放器状态事件
    this.onReadyToDisplay,
    this.onReadyToPlay,
    this.onPlaybackStateChanged,
    this.onPlayStateChanged,
    this.onUserStopped,
    this.onFinish,
  });
}
