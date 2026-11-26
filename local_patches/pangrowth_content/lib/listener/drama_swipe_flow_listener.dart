import '../model/drama_info.dart';

/// 短剧滑滑流事件监听器
///
/// 用于监听短剧滑滑流的各种事件，包括生命周期和业务交互事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class DramaSwipeFlowListener {
  // ==================== 生命周期事件 ====================

  /// 滑滑流创建完成并准备就绪
  /// [swipeFlowId] 滑滑流实例唯一标识
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String swipeFlowId)? onSwipeFlowReady;

  /// 滑滑流发生错误
  /// [error] 错误信息
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String error)? onSwipeFlowError;

  /// 滑滑流销毁
  ///
  /// **平台**: Flutter封装层自创
  final void Function()? onSwipeFlowDisposed;

  // ==================== 业务交互事件 ====================

  /// 打开短剧详情
  /// [drama] 要打开详情的短剧信息
  ///
  /// **平台**: Flutter封装层自创
  final void Function(DramaInfo drama)? onOpenDetail;

  // ==================== 播放控制事件 ====================

  /// 视频开始播放
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXVideoPlay(map)`
  /// - iOS: `DJXPlayerCallBackProtocol` 相关回调
  ///
  /// **extraInfo包含字段** (Android):
  /// - group_id (int): 视频id
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 短剧集数
  /// - total (int): 总集数
  /// - cover_image (String): 短剧封面图
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPlay;

  /// 视频暂停
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXVideoPause(map)`
  /// - iOS: `DJXPlayerCallBackProtocol` 相关回调
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPause;

  /// 视频恢复播放
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXVideoContinue(map)`
  /// - iOS: `DJXPlayerCallBackProtocol` 相关回调
  final void Function(Map<String, dynamic>? extraInfo)? onVideoContinue;

  /// 视频播放完成
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXVideoCompletion(map)`
  /// - iOS: `DJXPlayerCallBackProtocol` 相关回调
  final void Function(Map<String, dynamic>? extraInfo)? onVideoCompletion;

  /// 视频播放结束
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXVideoOver(map)`
  /// - iOS: `DJXPlayerCallBackProtocol` 相关回调
  final void Function(Map<String, dynamic>? extraInfo)? onVideoOver;

  // ==================== 页面切换事件 ====================

  /// 页面切换时回调
  /// [position] 页面索引值
  /// [extraInfo] 附加参数，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXPageChange(position, map)`
  /// - iOS: `drawVideoCurrentVideoChanged(...)`
  ///
  /// **extraInfo包含字段**:
  /// - group_id (int): 视频id
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 短剧集数
  /// - total (int): 总集数
  /// - cover_image (String): 短剧封面图
  final void Function(int position, Map<String, dynamic>? extraInfo)?
  onPageChange;

  /// 用户拖动进度条松手时回调
  /// [position] 视频位置索引
  /// [time] 跳转时间（毫秒）
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onDJXSeekTo(position, time)`
  /// - iOS: `DJXPlayerCallBackProtocol.onVideSeekToTime(endTime, position)`
  final void Function(int position, int time)? onSeekTo;

  /// 视频播放进度实时回调
  /// [current] 当前播放进度（毫秒）
  ///
  /// **平台**: Android独有
  /// - Android: `IDJXDrawListener.onDurationChange(current)`
  ///
  /// 🔵 Android 独有回调
  final void Function(int current)? onDurationChange;

  /// 频道Tab切换回调
  /// [channel] 频道类型（1: 推荐, 2: 剧场）
  ///
  /// **平台**: Android+iOS
  /// - Android: `IDJXDrawListener.onChannelTabChange(channel)`
  /// - iOS: `pageViewControllerSwitchToIndex(index)`
  final void Function(int channel)? onChannelTabChange;

  const DramaSwipeFlowListener({
    // 生命周期事件
    this.onSwipeFlowReady,
    this.onSwipeFlowError,
    this.onSwipeFlowDisposed,
    // 业务交互事件
    this.onOpenDetail,
    // 播放控制事件
    this.onVideoPlay,
    this.onVideoPause,
    this.onVideoContinue,
    this.onVideoCompletion,
    this.onVideoOver,
    // 页面切换事件
    this.onPageChange,
    this.onSeekTo,
    this.onDurationChange,
    this.onChannelTabChange,
  });
}
