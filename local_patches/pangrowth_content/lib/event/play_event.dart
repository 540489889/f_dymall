import 'content_event.dart';
import 'map_utils.dart';

/// 播放事件
class PlayEvent extends ContentEvent {
  /// 播放位置（毫秒）
  final int position;

  /// 总时长（毫秒）
  final int duration;

  /// 播放状态
  final PlayStatus status;

  const PlayEvent({
    required super.action,
    required super.contentId,
    required super.timestamp,
    required this.position,
    required this.duration,
    required this.status,
    super.extra,
  });

  /// 从Map创建播放事件
  factory PlayEvent.fromMap(Map<String, dynamic> map) {
    return PlayEvent(
      action: map['action'] as String,
      contentId: map['contentId'] as String,
      timestamp: map['timestamp'] as int,
      position: map['position'] as int,
      duration: map['duration'] as int,
      status: PlayStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PlayStatus.unknown,
      ),
      extra: castMapOrNull(map['extra']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'position': position,
      'duration': duration,
      'status': status.name,
    });
    return map;
  }

  @override
  Map<String, dynamic> get data => {
    ...super.data,
    'position': position,
    'duration': duration,
    'status': status.name,
  };

  @override
  String toString() {
    return 'PlayEvent(action: $action, contentId: $contentId, position: $position, duration: $duration, status: $status)';
  }
}

/// 播放状态枚举
enum PlayStatus {
  /// 开始播放
  started,

  /// 暂停
  paused,

  /// 恢复播放
  resumed,

  /// 播放完成
  completed,

  /// 播放错误
  error,

  /// 未知状态
  unknown,
}
