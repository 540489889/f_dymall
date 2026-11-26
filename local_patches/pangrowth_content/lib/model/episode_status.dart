/// 剧集锁定状态
class EpisodeStatus {
  /// 集数（从1开始）
  final int index;

  /// 是否锁定
  final bool isLocked;

  const EpisodeStatus({required this.index, required this.isLocked});

  factory EpisodeStatus.fromMap(Map<String, dynamic> map) {
    final dynamic rawIndex = map['index'] ?? map['episodeIndex'];
    return EpisodeStatus(
      index: _coerceInt(rawIndex),
      isLocked: map['isLocked'] as bool? ?? (map['locked'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'index': index,
    'isLocked': isLocked,
  };

  static int _coerceInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
