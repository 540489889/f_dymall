import 'drama_info.dart';

/// 短剧分页结果
class DramaPageResult {
  /// 短剧列表
  final List<DramaInfo> items;

  /// 服务端返回的总数（部分平台可能为0）
  final int total;

  /// 是否还有更多
  final bool hasMore;

  /// 透传的其它字段
  final Map<String, dynamic> others;

  const DramaPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.others,
  });

  factory DramaPageResult.fromMap(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final List<dynamic> rawItems =
        map['items'] as List<dynamic>? ?? const <dynamic>[];
    return DramaPageResult(
      items: rawItems
          .map(
            (dynamic item) =>
                DramaInfo.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      total: _coerceInt(map['total'] ?? map['count']),
      hasMore: map['hasMore'] as bool? ?? (map['has_more'] as bool? ?? false),
      others: Map<String, dynamic>.from(
        map['others'] as Map? ?? <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'items': items.map((DramaInfo item) => item.toMap()).toList(),
    'total': total,
    'hasMore': hasMore,
    'others': others,
  };

  static int _coerceInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
