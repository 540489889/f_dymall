import 'map_utils.dart';

/// 内容事件基类
class ContentEvent {
  /// 事件动作
  final String action;

  /// 内容ID
  final String contentId;

  /// 时间戳
  final int timestamp;

  /// 额外数据
  final Map<String, dynamic>? extra;

  const ContentEvent({
    required this.action,
    required this.contentId,
    required this.timestamp,
    this.extra,
  });

  /// 从Map创建事件对象
  factory ContentEvent.fromMap(Map<String, dynamic> map) {
    return ContentEvent(
      action: map['action'] as String,
      contentId: map['contentId'] as String,
      timestamp: map['timestamp'] as int,
      extra: castMapOrNull(map['extra']),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'contentId': contentId,
      'timestamp': timestamp,
      if (extra != null) 'extra': extra,
    };
  }

  /// 事件类型（别名：action）
  String get type => action;

  /// 事件数据（组合所有相关数据）
  Map<String, dynamic> get data => {
    'contentId': contentId,
    'timestamp': timestamp,
    if (extra != null) ...extra!,
  };

  @override
  String toString() {
    return 'ContentEvent(action: $action, contentId: $contentId, timestamp: $timestamp, extra: $extra)';
  }
}
