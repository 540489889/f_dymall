import 'map_utils.dart';

/// 小视频事件类型
enum VideoEventType {
  /// 视频开始播放
  videoStart,

  /// 视频暂停
  videoPause,

  /// 视频恢复播放
  videoResume,

  /// 视频正常结束
  videoComplete,

  /// 视频错误
  videoError,

  /// 视频关闭
  videoClose,

  /// 视频销毁
  videoDestroy,

  /// 视频点击
  videoClick,

  /// 请求开始
  requestStart,

  /// 请求失败
  requestFail,

  /// 请求成功
  requestSuccess,

  /// 数据源变化
  listDataChange,

  /// 页面切换
  pageChange,

  /// 列表刷新完成
  refreshFinish,

  /// 跳转到指定进度
  seek,

  /// 广告开始请求
  adRequest,

  /// 广告请求成功
  adRequestSuccess,

  /// 广告请求失败
  adRequestFail,

  /// 广告开始播放
  adStart,

  /// 广告开始展示
  adShow,

  /// 广告点击
  adClick,

  /// 广告关闭
  adClose,

  /// 广告错误
  adError,

  /// 广告完成
  adComplete,

  /// 页面进入
  pageEnter,

  /// 页面离开
  pageLeave,
}

/// 小视频事件数据
class VideoEvent {
  /// 事件类型
  final VideoEventType type;

  /// 事件数据
  final Map<String, dynamic>? data;

  /// 错误信息（仅在错误事件时有值）
  final String? error;

  const VideoEvent({required this.type, this.data, this.error});

  /// 从Map创建事件
  factory VideoEvent.fromMap(Map<String, dynamic> map) {
    final String typeString = (map['type'] as String? ?? '').trim();
    final VideoEventType type = _parseVideoEventType(typeString);
    final Map<String, dynamic>? rawData = castMapOrNull(map['data']);
    final Map<String, dynamic>? data = _augmentVideoData(typeString, rawData);

    return VideoEvent(type: type, data: data, error: map['error'] as String?);
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
    };
  }

  @override
  String toString() {
    return 'VideoEvent(type: $type, data: $data, error: $error)';
  }
}

VideoEventType _parseVideoEventType(String type) {
  switch (type) {
    case 'video_start':
    case 'videoStart':
    case 'onVideoPlay':
      return VideoEventType.videoStart;
    case 'video_pause':
    case 'videoPause':
    case 'onVideoPause':
      return VideoEventType.videoPause;
    case 'video_resume':
    case 'videoResume':
    case 'onVideoContinue':
      return VideoEventType.videoResume;
    case 'video_complete':
    case 'videoComplete':
    case 'onVideoCompletion':
      return VideoEventType.videoComplete;
    case 'video_error':
      return VideoEventType.videoError;
    case 'video_close':
    case 'onVideoClose':
      return VideoEventType.videoClose;
    case 'video_destroy':
    case 'onVideoOver':
      return VideoEventType.videoDestroy;
    case 'video_click':
    case 'videoClick':
    case 'onVideoClick':
    case 'onVideoClickAuthorName':
    case 'onVideoClickAvatar':
    case 'onVideoClickComment':
    case 'onVideoClickLike':
    case 'onVideoClickShare':
      return VideoEventType.videoClick;
    case 'onVideoRequestStart':
      return VideoEventType.requestStart;
    case 'onVideoRequestFail':
      return VideoEventType.requestFail;
    case 'onVideoRequestSuccess':
      return VideoEventType.requestSuccess;
    case 'onVideoListDataChange':
      return VideoEventType.listDataChange;
    case 'onVideoPageChange':
      return VideoEventType.pageChange;
    case 'onVideoRefreshFinish':
      return VideoEventType.refreshFinish;
    case 'onVideoSeekTo':
      return VideoEventType.seek;
    case 'video_ad_show':
    case 'onVideoAdShow':
      return VideoEventType.adShow;
    case 'video_ad_click':
    case 'onVideoAdClicked':
      return VideoEventType.adClick;
    case 'video_ad_close':
      return VideoEventType.adClose;
    case 'video_ad_error':
      return VideoEventType.adError;
    case 'video_ad_complete':
      return VideoEventType.adComplete;
    case 'onVideoAdRequest':
      return VideoEventType.adRequest;
    case 'onVideoAdRequestSuccess':
      return VideoEventType.adRequestSuccess;
    case 'onVideoAdRequestFail':
      return VideoEventType.adRequestFail;
    case 'onVideoAdPlayStart':
      return VideoEventType.adStart;
    case 'video_page_enter':
      return VideoEventType.pageEnter;
    case 'video_page_leave':
      return VideoEventType.pageLeave;
    default:
      return VideoEventType.videoError;
  }
}

Map<String, dynamic>? _augmentVideoData(
  String type,
  Map<String, dynamic>? rawData,
) {
  Map<String, dynamic>? data = rawData == null
      ? null
      : Map<String, dynamic>.from(rawData);

  void ensureAction(String action) {
    data ??= <String, dynamic>{};
    data!['action'] = action;
  }

  switch (type) {
    case 'onVideoClickAuthorName':
      ensureAction('authorName');
      break;
    case 'onVideoClickAvatar':
      ensureAction('avatar');
      break;
    case 'onVideoClickComment':
      ensureAction('comment');
      break;
    case 'onVideoClickLike':
      ensureAction('like');
      break;
    case 'onVideoClickShare':
      ensureAction('share');
      break;
    case 'onVideoSeekTo':
      ensureAction('seek');
      break;
  }

  return data;
}
