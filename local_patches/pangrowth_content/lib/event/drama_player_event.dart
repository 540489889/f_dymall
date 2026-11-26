import 'content_event.dart';
import 'map_utils.dart';

/// 短剧播放页事件
class DramaPlayerEvent extends ContentEvent {
  /// 播放页ID
  final String playerId;

  /// 短剧ID
  final int? dramaId;

  /// 集数
  final int? episode;

  /// 播放状态
  final String? playStatus;

  /// 播放位置（毫秒）
  final int? position;

  /// 总时长（毫秒）
  final int? duration;

  /// 错误码
  final int? errorCode;

  /// 错误信息
  final String? errorMessage;

  const DramaPlayerEvent({
    required super.action,
    required this.playerId,
    required super.timestamp,
    this.dramaId,
    this.episode,
    this.playStatus,
    this.position,
    this.duration,
    this.errorCode,
    this.errorMessage,
    super.extra,
  }) : super(contentId: playerId);

  /// 从Map创建播放页事件
  factory DramaPlayerEvent.fromMap(Map<String, dynamic> map) {
    return DramaPlayerEvent(
      action: map['action'] as String,
      playerId: map['playerId'] as String? ?? map['contentId'] as String,
      timestamp: map['timestamp'] as int,
      dramaId: map['dramaId'] as int?,
      episode: map['episode'] as int?,
      playStatus: map['playStatus'] as String?,
      position: map['position'] as int?,
      duration: map['duration'] as int?,
      errorCode: map['errorCode'] as int?,
      errorMessage: map['errorMessage'] as String?,
      extra: castMapOrNull(map['extra']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({'playerId': playerId});

    if (dramaId != null) map['dramaId'] = dramaId;
    if (episode != null) map['episode'] = episode;
    if (playStatus != null) map['playStatus'] = playStatus;
    if (position != null) map['position'] = position;
    if (duration != null) map['duration'] = duration;
    if (errorCode != null) map['errorCode'] = errorCode;
    if (errorMessage != null) map['errorMessage'] = errorMessage;

    return map;
  }

  @override
  Map<String, dynamic> get data => {
    ...super.data,
    'playerId': playerId,
    if (dramaId != null) 'dramaId': dramaId,
    if (episode != null) 'episode': episode,
    if (playStatus != null) 'playStatus': playStatus,
    if (position != null) 'position': position,
    if (duration != null) 'duration': duration,
    if (errorCode != null) 'errorCode': errorCode,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  @override
  String toString() {
    return 'DramaPlayerEvent(action: $action, playerId: $playerId, dramaId: $dramaId, episode: $episode)';
  }
}

/// 短剧播放页事件动作常量
class DramaPlayerEventAction {
  /// 播放页创建成功
  static const String playerCreated = 'drama_player_created';

  /// 播放页创建失败
  static const String playerCreateFailed = 'drama_player_create_failed';

  /// 播放页展示
  static const String playerShown = 'drama_player_shown';

  /// 播放页隐藏
  static const String playerHidden = 'drama_player_hidden';

  /// 播放页销毁
  static const String playerDestroyed = 'drama_player_destroyed';

  /// 视频开始播放
  static const String videoStartPlay = 'drama_video_start_play';

  /// 视频播放结束
  static const String videoOverPlay = 'drama_video_over_play';

  /// 视频暂停
  static const String videoPause = 'drama_video_pause';

  /// 视频继续播放
  static const String videoContinue = 'drama_video_continue';

  /// 视频播放完成
  static const String videoCompletion = 'drama_video_completion';

  /// 视频进度跳转
  static const String videoSeek = 'drama_video_seek';

  /// 页面切换
  static const String pageChange = 'drama_page_change';

  /// 集数切换
  static const String episodeChange = 'drama_episode_change';

  /// 播放页关闭
  static const String playerClose = 'drama_close';

  /// 短剧切换
  static const String dramaSwitch = 'drama_switch';

  /// 解锁流程开始
  static const String unlockStart = 'drama_unlock_start';

  /// 解锁流程结束
  static const String unlockEnd = 'drama_unlock_end';

  /// 显示自定义广告
  static const String showCustomAd = 'drama_show_custom_ad';

  /// 点击进入
  static const String clickEnter = 'drama_click_enter';

  /// 下一部短剧将播放
  static const String nextWillPlay = 'drama_next_will_play';

  /// 广告请求
  static const String adRequest = 'drama_ad_request';

  /// 广告加载成功
  static const String adLoadSuccess = 'drama_ad_load_success';

  /// 广告加载失败
  static const String adLoadFail = 'drama_ad_load_fail';

  /// 广告填充失败
  static const String adFillFail = 'drama_ad_fill_fail';

  /// 广告展示
  static const String adShow = 'drama_ad_show';

  /// 广告点击
  static const String adClick = 'drama_ad_click';

  /// 广告开始播放
  static const String adPlayStart = 'drama_ad_play_start';

  /// 广告播放完成
  static const String adPlayFinish = 'drama_ad_play_finish';

  /// 激励广告完成
  static const String adRewardFinish = 'drama_ad_reward_finish';

  /// 激励广告跳过
  static const String adRewardSkip = 'drama_ad_reward_skip';
}

/// 播放页状态枚举
enum DramaPlayerStatus {
  /// 创建中
  creating,

  /// 已创建
  created,

  /// 展示中
  showing,

  /// 已隐藏
  hidden,

  /// 播放中
  playing,

  /// 已暂停
  paused,

  /// 已完成
  completed,

  /// 错误状态
  error,

  /// 已销毁
  destroyed,

  /// 未知状态
  unknown,
}
