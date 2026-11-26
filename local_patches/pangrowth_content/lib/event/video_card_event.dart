import 'map_utils.dart';

/// 小视频卡片事件类型
enum VideoCardEventType {
  /// 视频卡片加载完成
  videoCardLoad,

  /// 视频卡片加载错误
  videoCardError,

  /// 视频卡片项点击
  videoCardItemClick,

  /// 视频卡片展示
  videoCardShow,

  /// 视频卡片进入滑动
  videoCardSwipeEnter,

  /// 视频卡片播放
  videoCardPlay,

  /// 视频卡片暂停
  videoCardPause,

  /// 视频卡片继续播放
  videoCardContinue,

  /// 视频卡片播放完成
  videoCardCompletion,

  /// 视频卡片播放结束
  videoCardOver,

  /// 视频卡片点击头像
  videoCardClickAvatar,

  /// 视频卡片点击作者名
  videoCardClickAuthorName,

  /// 视频卡片点击评论
  videoCardClickComment,

  /// 视频卡片点击点赞
  videoCardClickLike,

  /// 视频卡片点踩
  videoCardDislike,

  /// 视频卡片请求开始
  videoCardRequestStart,

  /// 视频卡片请求失败
  videoCardRequestFail,

  /// 视频卡片请求成功
  videoCardRequestSuccess,

  /// 视频卡片上报结果
  videoCardReportResult,
}

/// 小视频卡片事件数据
class VideoCardEvent {
  /// 事件类型
  final VideoCardEventType type;

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

  const VideoCardEvent({
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
  factory VideoCardEvent.fromMap(Map<String, dynamic> map) {
    final String typeString = (map['type'] as String? ?? '').trim();
    final VideoCardEventType type = _parseVideoCardEventType(typeString);

    return VideoCardEvent(
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
    return 'VideoCardEvent(type: $type, videoId: $videoId, error: $error, isLike: $isLike)';
  }
}

VideoCardEventType _parseVideoCardEventType(String type) {
  switch (type) {
    case 'onVideoCardLoad':
      return VideoCardEventType.videoCardLoad;
    case 'onVideoCardError':
      return VideoCardEventType.videoCardError;
    case 'onVideoCardClick':
      return VideoCardEventType.videoCardItemClick;
    case 'onVideoCardShow':
      return VideoCardEventType.videoCardShow;
    case 'onVideoCardSwipeEnter':
      return VideoCardEventType.videoCardSwipeEnter;
    case 'onVideoCardPlay':
      return VideoCardEventType.videoCardPlay;
    case 'onVideoCardPause':
      return VideoCardEventType.videoCardPause;
    case 'onVideoCardContinue':
      return VideoCardEventType.videoCardContinue;
    case 'onVideoCardCompletion':
      return VideoCardEventType.videoCardCompletion;
    case 'onVideoCardOver':
      return VideoCardEventType.videoCardOver;
    case 'onVideoCardClickAvatar':
      return VideoCardEventType.videoCardClickAvatar;
    case 'onVideoCardClickAuthorName':
      return VideoCardEventType.videoCardClickAuthorName;
    case 'onVideoCardClickComment':
      return VideoCardEventType.videoCardClickComment;
    case 'onVideoCardClickLike':
      return VideoCardEventType.videoCardClickLike;
    case 'onVideoCardDislike':
      return VideoCardEventType.videoCardDislike;
    case 'onVideoCardRequestStart':
      return VideoCardEventType.videoCardRequestStart;
    case 'onVideoCardRequestFail':
      return VideoCardEventType.videoCardRequestFail;
    case 'onVideoCardRequestSuccess':
      return VideoCardEventType.videoCardRequestSuccess;
    case 'onVideoCardReportResult':
      return VideoCardEventType.videoCardReportResult;
    default:
      return VideoCardEventType.videoCardError;
  }
}
