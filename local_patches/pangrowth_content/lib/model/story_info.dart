/// 短故事信息模型，保持与穿山甲 Nov/MNStoryInfoModel 字段对齐
class StoryInfo {
  /// 短故事ID（字符串形式，便于前端使用）
  final String storyId;

  /// 标题
  final String title;

  /// 简介 / 描述
  final String description;

  /// 作者
  final String author;

  /// 封面图
  final String coverUrl;

  /// 封面图类型：0封面图、1默认图、2无图
  final int imageType;

  /// 分类ID
  final int categoryId;

  /// 分类名称
  final String categoryName;

  /// 总章节数
  final int totalChapters;

  /// 创建时间（毫秒）
  final int createTime;

  /// 当前阅读章节
  final int currentIndex;

  /// 当前章节阅读进度 0.0~1.0
  final double progress;

  /// 阅读次数（statsCount）
  final int statsCount;

  /// 是否已收藏
  final bool isFavorited;

  /// 收藏时间（秒级，可能为0）
  final int favoriteTime;

  /// 第一章内容预览
  final String contentPreview;

  /// 额外透传字段
  final Map<String, dynamic> extras;

  const StoryInfo({
    required this.storyId,
    required this.title,
    required this.description,
    required this.author,
    required this.coverUrl,
    required this.imageType,
    required this.categoryId,
    required this.categoryName,
    required this.totalChapters,
    required this.createTime,
    required this.currentIndex,
    required this.progress,
    required this.statsCount,
    required this.isFavorited,
    required this.favoriteTime,
    required this.contentPreview,
    this.extras = const <String, dynamic>{},
  });

  /// 从Map创建短故事信息
  factory StoryInfo.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> extras = const <String, dynamic>{};
    if (map.containsKey('extras') && map['extras'] is Map) {
      extras = Map<String, dynamic>.from(map['extras'] as Map);
    }

    return StoryInfo(
      storyId: _string(map['storyId'] ?? map['id']),
      title: _string(map['title']),
      description: _string(map['description'] ?? map['desc']),
      author: _string(map['author']),
      coverUrl: _string(map['coverUrl'] ?? map['coverImage']),
      imageType: _int(map['imageType'] ?? map['coverType']),
      categoryId: _int(map['categoryId']),
      categoryName: _string(map['categoryName']),
      totalChapters: _int(map['total'] ?? map['totalChapters']),
      createTime: _int(map['createTime'] ?? map['createdAt']),
      currentIndex: _int(map['currentIndex'] ?? map['index']),
      progress: _double(map['progress']),
      statsCount: _int(map['statsCount'] ?? map['readCount']),
      isFavorited: _bool(map['isFavorited'] ?? map['favoriteState']),
      favoriteTime: _int(map['favoriteTime']),
      contentPreview: _string(
        map['contentPreview'] ?? map['content'] ?? map['contentTruncation'],
      ),
      extras: extras,
    );
  }

  /// 转换为Map，保持与原生key一致
  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'title': title,
      'description': description,
      'author': author,
      'coverUrl': coverUrl,
      'imageType': imageType,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'total': totalChapters,
      'createTime': createTime,
      'currentIndex': currentIndex,
      'progress': progress,
      'statsCount': statsCount,
      'isFavorited': isFavorited,
      'favoriteTime': favoriteTime,
      'contentPreview': contentPreview,
      if (extras.isNotEmpty) 'extras': extras,
    };
  }

  @override
  String toString() {
    return 'StoryInfo(storyId: $storyId, title: $title, categoryName: $categoryName, favorited: $isFavorited)';
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) return value.toString();
    return value.toString();
  }

  static int _int(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    final String str = value.toString();
    return int.tryParse(str) ?? 0;
  }

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    final String str = value.toString();
    return double.tryParse(str) ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String str = value.toString().toLowerCase();
    return str == 'true' || str == '1';
  }
}
