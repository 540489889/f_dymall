import 'content_event.dart';
import 'map_utils.dart';

/// 短剧事件
class DramaEvent extends ContentEvent {
  /// 短剧ID
  final String dramaId;

  /// 集数索引
  final int episodeIndex;

  /// 事件类型
  final DramaEventType eventType;

  const DramaEvent({
    required super.action,
    required super.contentId,
    required super.timestamp,
    required this.dramaId,
    required this.episodeIndex,
    required this.eventType,
    super.extra,
  });

  /// 从Map创建短剧事件
  factory DramaEvent.fromMap(Map<String, dynamic> map) {
    return DramaEvent(
      action: map['action'] as String,
      contentId: map['contentId'] as String,
      timestamp: map['timestamp'] as int,
      dramaId: map['dramaId'] as String,
      episodeIndex: map['episodeIndex'] as int,
      eventType: DramaEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => DramaEventType.unknown,
      ),
      extra: castMapOrNull(map['extra']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'dramaId': dramaId,
      'episodeIndex': episodeIndex,
      'eventType': eventType.name,
    });
    return map;
  }

  /// 事件类型（使用eventType）
  @override
  String get type => eventType.name;

  @override
  Map<String, dynamic> get data => {
    ...super.data,
    'dramaId': dramaId,
    'episodeIndex': episodeIndex,
    'eventType': eventType.name,
  };

  @override
  String toString() {
    return 'DramaEvent(action: $action, dramaId: $dramaId, episodeIndex: $episodeIndex, eventType: $eventType)';
  }
}

/// 短剧事件类型枚举
enum DramaEventType {
  /// 进入短剧
  enter,

  /// 切换集数
  switchEpisode,

  /// 点赞
  like,

  /// 取消点赞
  unlike,

  /// 收藏
  favorite,

  /// 取消收藏
  unfavorite,

  /// 分享
  share,

  /// 解锁
  unlock,

  /// 观看完成
  complete,

  /// 聚合页点击
  aggregateClick,

  /// 聚合页搜索
  aggregateSearch,

  /// 聚合页分类切换
  aggregateCategorySwitch,

  /// 聚合页刷新
  aggregateRefresh,

  /// 聚合页加载更多
  aggregateLoadMore,

  /// 未知事件
  unknown,
}
