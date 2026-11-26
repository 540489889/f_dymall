import 'content_event.dart';
import 'map_utils.dart';
import '../model/drama_info.dart';

/// 短剧聚合页事件
class DramaHomeEvent extends ContentEvent {
  /// 事件类型
  final DramaHomeEventType eventType;

  /// 相关短剧信息（可选）
  final DramaInfo? drama;

  /// 搜索关键词（搜索事件时）
  final String? searchKeyword;

  /// 分类名称（分类切换事件时）
  final String? category;

  const DramaHomeEvent({
    required super.action,
    required super.contentId,
    required super.timestamp,
    required this.eventType,
    this.drama,
    this.searchKeyword,
    this.category,
    super.extra,
  });

  /// 从Map创建聚合页事件
  factory DramaHomeEvent.fromMap(Map<String, dynamic> map) {
    return DramaHomeEvent(
      action: map['action'] as String,
      contentId: map['contentId'] as String,
      timestamp: map['timestamp'] as int,
      eventType: DramaHomeEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => DramaHomeEventType.unknown,
      ),
      drama: castMapOrNull(map['drama']) != null
          ? DramaInfo.fromMap(castMapOrNull(map['drama'])!)
          : null,
      searchKeyword: map['searchKeyword'] as String?,
      category: map['category'] as String?,
      extra: castMapOrNull(map['extra']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'eventType': eventType.name,
      'drama': drama?.toMap(),
      'searchKeyword': searchKeyword,
      'category': category,
    });
    return map;
  }

  /// 事件类型（使用eventType）
  @override
  String get type => eventType.name;

  @override
  Map<String, dynamic> get data => {
    ...super.data,
    'eventType': eventType.name,
    if (drama != null) 'drama': drama!.toMap(),
    if (searchKeyword != null) 'searchKeyword': searchKeyword,
    if (category != null) 'category': category,
  };

  @override
  String toString() {
    return 'DramaHomeEvent(action: $action, eventType: $eventType, drama: ${drama?.title}, searchKeyword: $searchKeyword, category: $category)';
  }
}

/// 短剧聚合页事件类型
enum DramaHomeEventType {
  /// 短剧项点击
  itemClick,

  /// 搜索
  search,

  /// 分类切换
  categorySwitch,

  /// 页面刷新
  refresh,

  /// 加载更多
  loadMore,

  /// 页面显示
  pageShow,

  /// 页面隐藏
  pageHide,

  /// 聚合页销毁
  destroyed,

  /// 未知事件
  unknown,
}
