/// 小视频事件监听器
///
/// 用于监听小视频播放器的各种事件，包括生命周期和播放控制事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class VideoListener {
  // ==================== 生命周期事件 ====================

  /// 视频创建完成并准备就绪
  /// [videoId] 视频实例唯一标识
  final void Function(String videoId)? onVideoReady;

  /// 视频发生错误
  /// [error] 错误信息
  final void Function(String error)? onVideoError;

  /// 视频销毁
  final void Function()? onVideoDisposed;

  // ==================== 播放控制事件 ====================

  /// 视频开始播放
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPVideoPlay(map)`
  /// - iOS: `onVideoPlay(info)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPlay;

  /// 视频暂停
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPVideoPause(map)`
  /// - iOS: `onVideoPause(info)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPause;

  /// 视频恢复播放
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPVideoContinue(map)`
  /// - iOS: `onVideoContinue(info)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoContinue;

  /// 视频播放完成
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPVideoCompletion(map)`
  /// - iOS: `onVideoCompletion(info)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoCompletion;

  /// 视频播放结束
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPVideoOver(map)`
  /// - iOS: `onVideoOver(info)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoOver;

  /// 视频关闭
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPClose()`
  /// - iOS: `onVideoClose()`
  final void Function()? onVideoClose;

  /// 页面切换（滑动到下一个视频）
  /// [position] 当前位置索引
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPPageChange(position, map)`
  /// - iOS: `onVideoPageChange(position, info)`
  final void Function(int position, Map<String, dynamic>? extraInfo)?
  onPageChange;

  /// 视频进度跳转
  /// [position] 视频位置索引
  /// [time] 跳转时间（毫秒）
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDPSeekTo(position, time)`
  /// - iOS: `onVideoSeekToTime(time, position)`
  final void Function(int position, int time)? onSeekTo;

  // ==================== 数据请求事件 ====================

  /// 开始请求视频数据
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onRequestStart;

  /// 请求视频数据失败
  /// [code] 错误码
  /// [message] 错误信息
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android+iOS
  final void Function(
    int code,
    String message,
    Map<String, dynamic>? extraInfo,
  )?
  onRequestFail;

  /// 请求视频数据成功
  /// [list] 返回的视频列表数据
  ///
  /// **平台**: Android+iOS
  final void Function(List<Map<String, dynamic>> list)? onRequestSuccess;

  /// 刷新完成
  ///
  /// **平台**: Android独有
  final void Function()? onRefreshComplete;

  // ==================== 广告事件 ====================

  /// 广告请求
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdRequest;

  /// 广告加载成功
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdLoadSuccess;

  /// 广告加载失败
  /// [errorCode] 错误码
  /// [errorMessage] 错误信息
  ///
  /// **平台**: Android+iOS
  final void Function(int errorCode, String errorMessage)? onAdLoadFail;

  /// 广告填充失败
  /// [errorCode] 错误码
  /// [errorMessage] 错误信息
  ///
  /// **平台**: Android+iOS
  final void Function(int errorCode, String errorMessage)? onAdFillFail;

  /// 广告曝光
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdShow;

  /// 广告点击
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdClick;

  /// 广告开始播放
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdPlayStart;

  /// 广告暂停播放
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdPlayPause;

  /// 广告继续播放
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdPlayContinue;

  /// 广告播放结束
  ///
  /// **平台**: Android+iOS
  final void Function()? onAdPlayComplete;

  // ==================== 交互事件 ====================

  /// 点击作者头像
  /// [extraInfo] 作者信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickAuthorAvatar;

  /// 点击作者名称
  /// [extraInfo] 作者信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickAuthorName;

  /// 点击评论按钮
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickComment;

  /// 点击点赞按钮
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickLike;

  /// 举报结果
  /// [success] 是否成功
  /// [message] 结果消息
  ///
  /// **平台**: iOS独有
  final void Function(bool success, String? message)? onReportResult;

  const VideoListener({
    // 生命周期
    this.onVideoReady,
    this.onVideoError,
    this.onVideoDisposed,
    // 播放控制
    this.onVideoPlay,
    this.onVideoPause,
    this.onVideoContinue,
    this.onVideoCompletion,
    this.onVideoOver,
    this.onVideoClose,
    this.onPageChange,
    this.onSeekTo,
    // 数据请求
    this.onRequestStart,
    this.onRequestFail,
    this.onRequestSuccess,
    this.onRefreshComplete,
    // 广告事件
    this.onAdRequest,
    this.onAdLoadSuccess,
    this.onAdLoadFail,
    this.onAdFillFail,
    this.onAdShow,
    this.onAdClick,
    this.onAdPlayStart,
    this.onAdPlayPause,
    this.onAdPlayContinue,
    this.onAdPlayComplete,
    // 交互事件
    this.onClickAuthorAvatar,
    this.onClickAuthorName,
    this.onClickComment,
    this.onClickLike,
    this.onReportResult,
  });
}
