import 'map_utils.dart';

/// 小视频单卡片事件类型
enum VideoSingleCardEventType {
  /// 视频单卡片加载完成
  videoSingleCardLoad,

  /// 视频单卡片加载错误
  videoSingleCardError,

  /// 视频单卡片项点击
  videoSingleCardItemClick,

  /// 视频单卡片展示
  videoSingleCardShow,

  /// 视频单卡片播放
  videoSingleCardPlay,

  /// 视频单卡片暂停
  videoSingleCardPause,

  /// 视频单卡片继续播放
  videoSingleCardContinue,

  /// 视频单卡片播放完成
  videoSingleCardCompletion,

  /// 视频单卡片播放结束
  videoSingleCardOver,

  /// 视频单卡片点击头像
  videoSingleCardClickAvatar,

  /// 视频单卡片点击作者名
  videoSingleCardClickAuthorName,

  /// 视频单卡片点击评论
  videoSingleCardClickComment,

  /// 视频单卡片点击点赞
  videoSingleCardClickLike,

  /// 视频单卡片请求开始
  videoSingleCardRequestStart,

  /// 视频单卡片请求失败
  videoSingleCardRequestFail,

  /// 视频单卡片请求成功
  videoSingleCardRequestSuccess,

  /// 视频单卡片上报结果
  videoSingleCardReportResult,
}

/// 小视频单卡片事件数据
class VideoSingleCardEvent {
  /// 事件类型
  final VideoSingleCardEventType type;

  /// 视频ID
  final String? videoId;

  /// 事件数据
  final Map<String, dynamic>? data;

  /// 错误信息（仅在错误事件时有值）
  final String? error;

  /// 错误代码（仅在错误事件时有值）
  final int? errorCode;

  /// 是否点赞（仅在点赞事件时有值）
  final bool? isLike;

  /// 是否成功（仅在上报事件时有值）
  final bool? isSucceed;

  /// 标题
  final String? title;

  /// 用户名
  final String? userName;

  /// 评论数
  final int? commentCount;

  /// 发布时间
  final int? publishTime;

  const VideoSingleCardEvent({
    required this.type,
    this.videoId,
    this.data,
    this.error,
    this.errorCode,
    this.isLike,
    this.isSucceed,
    this.title,
    this.userName,
    this.commentCount,
    this.publishTime,
  });

  /// 从Map创建事件
  factory VideoSingleCardEvent.fromMap(Map<String, dynamic> map) {
    final String typeString = (map['type'] as String? ?? '').trim();
    final VideoSingleCardEventType type = _parseVideoSingleCardEventType(
      typeString,
    );

    return VideoSingleCardEvent(
      type: type,
      videoId: map['videoId'] as String?,
      data: castMapOrNull(map['data']),
      error: map['error'] as String?,
      errorCode: map['code'] as int?,
      isLike: map['isLike'] as bool?,
      isSucceed: map['isSucceed'] as bool?,
      title: map['title'] as String?,
      userName: map['userName'] as String?,
      commentCount: map['commentCount'] as int?,
      publishTime: map['publishTime'] as int?,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (videoId != null) 'videoId': videoId,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      if (errorCode != null) 'code': errorCode,
      if (isLike != null) 'isLike': isLike,
      if (isSucceed != null) 'isSucceed': isSucceed,
      if (title != null) 'title': title,
      if (userName != null) 'userName': userName,
      if (commentCount != null) 'commentCount': commentCount,
      if (publishTime != null) 'publishTime': publishTime,
    };
  }

  @override
  String toString() {
    return 'VideoSingleCardEvent(type: $type, videoId: $videoId, error: $error, isLike: $isLike)';
  }
}

VideoSingleCardEventType _parseVideoSingleCardEventType(String type) {
  switch (type) {
    case 'onVideoSingleCardLoad':
      return VideoSingleCardEventType.videoSingleCardLoad;
    case 'onVideoSingleCardError':
      return VideoSingleCardEventType.videoSingleCardError;
    case 'onVideoSingleCardClick':
      return VideoSingleCardEventType.videoSingleCardItemClick;
    case 'onVideoSingleCardShow':
      return VideoSingleCardEventType.videoSingleCardShow;
    case 'onVideoSingleCardPlay':
      return VideoSingleCardEventType.videoSingleCardPlay;
    case 'onVideoSingleCardPause':
      return VideoSingleCardEventType.videoSingleCardPause;
    case 'onVideoSingleCardContinue':
      return VideoSingleCardEventType.videoSingleCardContinue;
    case 'onVideoSingleCardCompletion':
      return VideoSingleCardEventType.videoSingleCardCompletion;
    case 'onVideoSingleCardOver':
      return VideoSingleCardEventType.videoSingleCardOver;
    case 'onVideoSingleCardClickAvatar':
      return VideoSingleCardEventType.videoSingleCardClickAvatar;
    case 'onVideoSingleCardClickAuthorName':
      return VideoSingleCardEventType.videoSingleCardClickAuthorName;
    case 'onVideoSingleCardClickComment':
      return VideoSingleCardEventType.videoSingleCardClickComment;
    case 'onVideoSingleCardClickLike':
      return VideoSingleCardEventType.videoSingleCardClickLike;
    case 'onVideoSingleCardRequestStart':
      return VideoSingleCardEventType.videoSingleCardRequestStart;
    case 'onVideoSingleCardRequestFail':
      return VideoSingleCardEventType.videoSingleCardRequestFail;
    case 'onVideoSingleCardRequestSuccess':
      return VideoSingleCardEventType.videoSingleCardRequestSuccess;
    case 'onVideoSingleCardReportResult':
      return VideoSingleCardEventType.videoSingleCardReportResult;
    default:
      return VideoSingleCardEventType.videoSingleCardError;
  }
}
