import '../model/drama_info.dart';

/// 短剧播放器事件监听器
///
/// 用于监听短剧播放器的各种事件，包括生命周期和业务事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class DramaPlayerListener {
  // ==================== 生命周期事件 ====================

  /// 播放器创建完成并准备就绪
  /// [playerId] 播放器唯一标识
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String playerId)? onPlayerReady;

  /// 播放器发生错误
  /// [error] 错误信息
  ///
  /// **平台**: Flutter封装层自创
  final void Function(String error)? onPlayerError;

  /// 播放器关闭
  ///
  /// **平台**: Android独有 (`onDJXClose`)
  final void Function()? onPlayerClose;

  /// 播放器销毁
  ///
  /// **平台**: Flutter封装层自创
  final void Function()? onPlayerDisposed;

  // ==================== 播放控制事件 ====================

  /// 视频开始播放
  /// [dramaInfo] 当前短剧信息（可选）
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXVideoPlay(map)`
  /// - iOS: `drawVideoStartPlay(viewController, config)`
  ///
  /// **extraInfo包含字段** (Android):
  /// - group_id (int): 视频id
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 短剧集数
  /// - total (int): 总集数
  /// - cover_image (String): 短剧封面图
  /// - video_width (int): 视频宽度
  /// - video_height (int): 视频高度
  /// - video_duration (int): 视频时长
  /// - unlock_index (int): 短剧解锁进度
  final void Function(DramaInfo? dramaInfo, Map<String, dynamic>? extraInfo)?
  onVideoStart;

  /// 视频播放结束
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXVideoOver(map)`
  /// - iOS: `drawVideoOverPlay(viewController, config)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoOverPlay;

  /// 视频暂停
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXVideoPause(map)`
  /// - iOS: `drawVideoPause(viewController, config)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPause;

  /// 视频恢复播放
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXVideoContinue(map)`
  /// - iOS: `drawVideoContinue(viewController, config)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoContinue;

  /// 视频完成（包含重复播放）
  /// [extraInfo] SDK传递的附加信息，包含完整的短剧元数据
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXVideoCompletion(map)`
  /// - iOS: `drawVideoPlayCompletion(viewController, config)`
  final void Function(Map<String, dynamic>? extraInfo)? onVideoCompletion;

  /// 用户拖动进度条松手时回调
  /// [position] 视频位置索引
  /// [time] 跳转时间（毫秒）
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXSeekTo(position, time)`
  /// - iOS: `onVideSeekToTime(endTime, position)`
  final void Function(int position, int time)? onSeekTo;

  /// 视频播放进度实时回调（Android）
  /// [current] 当前播放进度（毫秒）
  ///
  /// **平台**: Android独有 (`onDurationChange`)
  final void Function(int current)? onDurationChange;

  /// 视频播放进度百分比回调（iOS）
  /// [progress] 播放进度百分比 (0.0 ~ 1.0)
  /// [dramaInfo] 当前短剧信息
  ///
  /// **平台**: iOS独有 (`drawVideo(_,_, progress)`)
  final void Function(double progress, DramaInfo? dramaInfo)? onVideoProgress;

  // ==================== 集数与短剧切换 ====================

  /// 页面切换时回调
  /// [position] 页面索引值
  /// [extraInfo] 附加参数，包含完整的短剧元数据
  ///
  /// **平台**: Android独有 (`onDJXPageChange`)
  ///
  /// **extraInfo包含字段**:
  /// - group_id (int): 视频id
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 短剧集数
  /// - total (int): 总集数
  /// - cover_image (String): 短剧封面图
  /// - unlock_index (int): 短剧解锁进度
  final void Function(int position, Map<String, dynamic>? extraInfo)?
  onPageChange;

  /// 集数切换（保留向后兼容）
  /// [episode] 当前集数
  ///
  /// **注意**: 推荐使用 `onPageChange`,此回调参数不完整
  @Deprecated('推荐使用onPageChange获取完整的extraInfo参数')
  final void Function(int episode)? onEpisodeChange;

  /// 短剧切换
  /// [drama] 切换到的短剧信息
  ///
  /// **平台**: Android独有 (`onDramaSwitch`)
  final void Function(DramaInfo drama)? onDramaSwitch;

  /// 短剧选集面板展现
  /// [extraInfo] 附加参数，包含当前短剧和集数信息
  ///
  /// **平台**: Android独有 (`onDramaGalleryShow`)
  ///
  /// **extraInfo包含字段**:
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 当前集数
  /// - total (int): 总集数
  /// - unlock_index (int): 解锁进度
  final void Function(Map<String, dynamic>? extraInfo)? onDramaGalleryShow;

  /// 短剧选集面板点击
  /// [extraInfo] 附加参数，包含当前集数和用户选择的集数
  ///
  /// **平台**: Android独有 (`onDramaGalleryClick`)
  ///
  /// **extraInfo包含字段**:
  /// - index (int): 当前集数
  /// - index_selected (int): 用户选择的集数
  /// - drama_id (int): 短剧id
  /// - total (int): 总集数
  final void Function(Map<String, dynamic>? extraInfo)? onDramaGalleryClick;

  /// 点击混排中进入跳转播放页的按钮
  /// [dramaInfo] 短剧信息
  ///
  /// **平台**: iOS独有 (`clickEnterView`)
  final void Function(DramaInfo? dramaInfo)? onClickEnter;

  /// 本剧集观看完毕，切到下一部短剧回调
  /// [dramaInfo] 即将播放的短剧信息
  ///
  /// **平台**: iOS独有 (`nextPlayletWillPlay`)
  final void Function(DramaInfo? dramaInfo)? onNextPlayletWillPlay;

  // ==================== 解锁流程事件 ====================

  /// 解锁流程开始
  /// [dramaInfo] 短剧信息（如果有）
  /// [extraInfo] SDK传递的附加信息（包含index、total等字段）
  ///
  /// **平台**: Android+iOS
  /// - Android: `unlockFlowStart(drama, callback, map)`
  /// - iOS: `playletDetailUnlockFlowStart(infoModel, handler, extraInfo)`
  ///
  /// **extraInfo包含字段**:
  /// - index (int): 当前需要解锁的集数
  /// - total (int): 总集数
  /// - is_continuity_unlock (bool): 是否连续解锁 (Android 1180+)
  /// - first_unlock_index (int): 后续需要解锁的集数 (Android 1180+)
  final void Function(DramaInfo? dramaInfo, Map<String, dynamic>? extraInfo)?
  onUnlockStart;

  /// 解锁流程结束
  /// [success] 是否解锁成功
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `unlockFlowEnd(drama, errCode, map)`
  /// - iOS: `playletDetailUnlockFlowEnd(infoModel, success, error, extraInfo)`
  final void Function(bool success, Map<String, dynamic>? extraInfo)?
  onUnlockEnd;

  /// 显示自定义广告（仅在 adMode='specific' 时触发）
  /// [dramaInfo] 短剧信息（如果有）
  ///
  /// **平台**: Android+iOS
  /// - Android: `showCustomAd(drama, callback)`
  /// - iOS: `playletDetailUnlockFlowShowCustomAD`
  final void Function(DramaInfo? dramaInfo)? onShowCustomAd;

  /// 短剧解锁弹窗展示
  /// [extraInfo] 附加参数，包含当前短剧和集数信息
  ///
  /// **平台**: Android独有 (`onRewardDialogShow`)
  final void Function(Map<String, dynamic>? extraInfo)? onRewardDialogShow;

  /// 短剧解锁弹窗点击动作
  /// [action] 点击动作 ('unlock_action_confirm' 或 'unlock_action_cancel')
  /// [extraInfo] 附加参数，包含当前短剧和集数信息
  ///
  /// **平台**: Android独有 (`onUnlockDialogAction`)
  final void Function(String action, Map<String, dynamic>? extraInfo)?
  onUnlockDialogAction;

  // ==================== 广告事件 ====================

  /// 广告请求
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdRequest(map)`
  /// - iOS: `djxSendAdRequest(event)`
  final void Function()? onAdRequest;

  /// 广告加载成功
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdRequestSuccess(map)`
  /// - iOS: `djxAdLoadSuccess(event)`
  final void Function()? onAdLoadSuccess;

  /// 广告加载失败
  /// [errorCode] 错误码
  /// [errorMessage] 错误信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdRequestFail(code, msg, map)`
  /// - iOS: `djxAdLoadFail(event, error)`
  final void Function(int errorCode, String errorMessage)? onAdLoadFail;

  /// 广告填充失败
  /// [errorCode] 错误码
  /// [errorMessage] 错误信息
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdFillFail(map)`
  /// - iOS: `djxAdFillFail(event)`
  final void Function(int errorCode, String errorMessage)? onAdFillFail;

  /// 广告曝光
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdShow(map)`
  /// - iOS: `djxAdWillShow(event)`
  final void Function()? onAdShow;

  /// 广告点击
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdClicked(map)`
  /// - iOS: `djxClickAdViewEvent(event)`
  final void Function()? onAdClick;

  /// 广告开始播放
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdPlayStart(map)`
  /// - iOS: `djxVideoAdStartPlay(event)`
  final void Function()? onAdPlayStart;

  /// 广告暂停播放
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdPlayPause(map)`
  /// - iOS: `djxVideoAdPause(event)`
  final void Function()? onAdPlayPause;

  /// 广告继续播放
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdPlayContinue(map)`
  /// - iOS: `djxVideoAdContinue(event)`
  final void Function()? onAdPlayContinue;

  /// 广告播放结束
  ///
  /// **平台**: Android+iOS
  /// - Android: `onDJXAdPlayComplete(map)`
  /// - iOS: `djxVideoAdOverPlay(event)`
  final void Function()? onAdPlayComplete;

  /// 激励广告奖励完成（看完视频）
  ///
  /// **平台**: Android+iOS
  /// - Android: `onRewardVerify(map)`
  /// - iOS: `djxVideoRewardFinishEvent(event)`
  final void Function()? onAdRewardFinish;

  /// 激励视频广告跳过
  ///
  /// **平台**: Android+iOS
  /// - Android: `onSkippedVideo(map)`
  /// - iOS: `djxVideoRewardSkipEvent(event)`
  final void Function()? onAdSkip;

  /// 广告缓冲
  ///
  /// **平台**: iOS独有 (`djxVideoBufferEvent`)
  final void Function()? onAdBuffer;

  // ==================== 数据请求事件 (Android独有) ====================

  /// 开始请求短剧数据
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android独有 (`onDJXRequestStart`)
  final void Function(Map<String, dynamic>? extraInfo)? onRequestStart;

  /// 请求短剧数据失败
  /// [code] 错误码
  /// [message] 错误信息
  /// [extraInfo] 附加参数，包含 req_id
  ///
  /// **平台**: Android独有 (`onDJXRequestFail`)
  final void Function(
    int code,
    String message,
    Map<String, dynamic>? extraInfo,
  )?
  onRequestFail;

  /// 请求短剧数据成功
  /// [list] 返回的短剧列表，每个元素包含完整的短剧元数据
  ///
  /// **平台**: Android独有 (`onDJXRequestSuccess`)
  ///
  /// **list元素包含字段**:
  /// - req_id (String): 请求id
  /// - group_id (int): 视频id
  /// - drama_id (int): 短剧id
  /// - title (String): 短剧标题
  /// - index (int): 短剧集数
  /// - total (int): 总集数
  /// - cover_image (String): 短剧封面图
  final void Function(List<Map<String, dynamic>> list)? onRequestSuccess;

  const DramaPlayerListener({
    // 生命周期事件
    this.onPlayerReady,
    this.onPlayerError,
    this.onPlayerClose,
    this.onPlayerDisposed,
    // 播放控制事件
    this.onVideoStart,
    this.onVideoOverPlay,
    this.onVideoPause,
    this.onVideoContinue,
    this.onVideoCompletion,
    this.onSeekTo,
    this.onDurationChange,
    this.onVideoProgress,
    // 集数与短剧切换
    this.onPageChange,
    this.onEpisodeChange,
    this.onDramaSwitch,
    this.onDramaGalleryShow,
    this.onDramaGalleryClick,
    this.onClickEnter,
    this.onNextPlayletWillPlay,
    // 解锁流程事件
    this.onUnlockStart,
    this.onUnlockEnd,
    this.onShowCustomAd,
    this.onRewardDialogShow,
    this.onUnlockDialogAction,
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
    this.onAdRewardFinish,
    this.onAdSkip,
    this.onAdBuffer,
    // 数据请求事件
    this.onRequestStart,
    this.onRequestFail,
    this.onRequestSuccess,
  });
}
