/// 短剧卡片事件
class DramaCardEvent {
  /// 卡片ID
  final String cardId;

  /// 事件类型
  final DramaCardEventType eventType;

  /// 短剧信息
  final Map<String, dynamic>? dramaData;

  /// 错误信息
  final Map<String, dynamic>? error;

  /// 播放状态
  final String? playbackState;

  /// 视频状态码
  final int? statusCode;

  /// 展示时长
  final int? duration;

  const DramaCardEvent({
    required this.cardId,
    required this.eventType,
    this.dramaData,
    this.error,
    this.playbackState,
    this.statusCode,
    this.duration,
  });

  factory DramaCardEvent.fromMap(Map<String, dynamic> map) {
    return DramaCardEvent(
      cardId: map['cardId'] ?? '',
      eventType: DramaCardEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => DramaCardEventType.unknown,
      ),
      dramaData: map['dramaData'] != null
          ? Map<String, dynamic>.from(map['dramaData'])
          : null,
      error: map['error'] != null
          ? Map<String, dynamic>.from(map['error'])
          : null,
      playbackState: map['playbackState'],
      statusCode: map['statusCode']?.toInt(),
      duration: map['duration']?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'eventType': eventType.name,
      'dramaData': dramaData,
      'error': error,
      'playbackState': playbackState,
      'statusCode': statusCode,
      'duration': duration,
    };
  }

  @override
  String toString() {
    return 'DramaCardEvent('
        'cardId: $cardId, '
        'eventType: $eventType, '
        'dramaData: $dramaData, '
        'error: $error, '
        'playbackState: $playbackState, '
        'statusCode: $statusCode, '
        'duration: $duration'
        ')';
  }
}

/// 短剧卡片事件类型
enum DramaCardEventType {
  /// 卡片创建成功
  cardCreated,

  /// 卡片创建失败
  cardCreateFailed,

  /// 数据加载成功
  dataLoaded,

  /// 数据加载失败
  dataLoadFailed,

  /// 准备显示（第一帧）
  readyToDisplay,

  /// 准备播放
  readyToPlay,

  /// 播放状态变化
  playbackStateChanged,

  /// 用户手动停止
  userStopped,

  /// 播放完成/结束
  playbackFinished,

  /// 卡片点击
  cardClicked,

  /// 卡片销毁
  cardDestroyed,

  /// 未知事件
  unknown,
}
