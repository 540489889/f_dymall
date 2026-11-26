import 'map_utils.dart';

/// 宫格小视频事件类型
enum GridVideoEventType {
  /// 宫格视频加载完成
  gridVideoLoad,

  /// 宫格视频加载错误
  gridVideoError,

  /// 宫格视频项点击
  gridVideoItemClick,

  /// 宫格视频项展示
  gridVideoItemShow,

  /// 宫格视频刷新完成
  gridVideoRefreshCompletion,

  /// 宫格视频播放
  gridVideoPlay,

  /// 宫格视频暂停
  gridVideoPause,

  /// 宫格视频继续播放
  gridVideoContinue,

  /// 宫格视频播放完成
  gridVideoCompletion,

  /// 宫格视频播放结束
  gridVideoOver,

  /// 宫格视频点击头像
  gridVideoClickAvatar,

  /// 宫格视频点击作者名
  gridVideoClickAuthorName,

  /// 宫格视频点击评论
  gridVideoClickComment,

  /// 宫格视频点击点赞
  gridVideoClickLike,

  /// 宫格视频请求开始
  gridVideoRequestStart,

  /// 宫格视频请求失败
  gridVideoRequestFail,

  /// 宫格视频请求成功
  gridVideoRequestSuccess,
}

/// 宫格小视频事件数据
class GridVideoEvent {
  /// 事件类型
  final GridVideoEventType type;

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

  /// 项目ID（仅在项目事件时有值）
  final String? itemId;

  /// 项目标题（仅在项目事件时有值）
  final String? title;

  const GridVideoEvent({
    required this.type,
    this.videoId,
    this.data,
    this.error,
    this.errorCode,
    this.isLike,
    this.itemId,
    this.title,
  });

  /// 从Map创建事件
  factory GridVideoEvent.fromMap(Map<String, dynamic> map) {
    final String typeString = (map['type'] as String? ?? '').trim();
    final GridVideoEventType type = _parseGridVideoEventType(typeString);

    return GridVideoEvent(
      type: type,
      videoId: map['videoId'] as String?,
      data: castMapOrNull(map['data']),
      error: map['error'] as String?,
      errorCode: map['code'] as int?,
      isLike: map['isLike'] as bool?,
      itemId: map['itemId'] as String?,
      title: map['title'] as String?,
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
      if (itemId != null) 'itemId': itemId,
      if (title != null) 'title': title,
    };
  }

  @override
  String toString() {
    return 'GridVideoEvent(type: $type, videoId: $videoId, error: $error, isLike: $isLike)';
  }
}

GridVideoEventType _parseGridVideoEventType(String type) {
  switch (type) {
    case 'onGridVideoItemClick':
      return GridVideoEventType.gridVideoItemClick;
    case 'onGridVideoClientShow':
    case 'onGridVideoItemShow':
      return GridVideoEventType.gridVideoItemShow;
    case 'onGridVideoRefreshFinish':
    case 'onGridVideoRefreshCompletion':
      return GridVideoEventType.gridVideoRefreshCompletion;
    case 'onGridVideoPlay':
      return GridVideoEventType.gridVideoPlay;
    case 'onGridVideoPause':
      return GridVideoEventType.gridVideoPause;
    case 'onGridVideoContinue':
      return GridVideoEventType.gridVideoContinue;
    case 'onGridVideoCompletion':
      return GridVideoEventType.gridVideoCompletion;
    case 'onGridVideoOver':
      return GridVideoEventType.gridVideoOver;
    case 'onGridVideoClickAvatar':
      return GridVideoEventType.gridVideoClickAvatar;
    case 'onGridVideoClickAuthorName':
      return GridVideoEventType.gridVideoClickAuthorName;
    case 'onGridVideoClickComment':
      return GridVideoEventType.gridVideoClickComment;
    case 'onGridVideoClickLike':
      return GridVideoEventType.gridVideoClickLike;
    case 'onGridVideoRequestStart':
      return GridVideoEventType.gridVideoRequestStart;
    case 'onGridVideoRequestFail':
      return GridVideoEventType.gridVideoRequestFail;
    case 'onGridVideoRequestSuccess':
      return GridVideoEventType.gridVideoRequestSuccess;
    case 'onGridVideoLoad':
      return GridVideoEventType.gridVideoLoad;
    default:
      return GridVideoEventType.gridVideoError;
  }
}
