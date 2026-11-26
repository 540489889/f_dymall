import 'episode_status.dart';

/// 短剧信息 - 对齐 DJXDrama / DJXPlayletInfoModel 数据结构
class DramaInfo {
  /// 短剧ID
  final int id;

  /// 短剧名称
  final String title;

  /// 短剧封面
  final String coverImage;

  /// 短剧描述
  final String desc;

  /// 总集数
  final int total;

  /// 当前集数
  final int index;

  /// 短剧类型
  final String type;

  /// 短剧类型ID（Android端）
  final int typeId;

  /// 短剧状态 (0:已完结, 1:未完结)
  final int status;

  /// 免费集数
  final int freeSet;

  /// 解锁集数
  final int lockSet;

  /// 创建时间 (毫秒)
  final int createTime;

  /// 最近操作时间（历史记录场景）
  final int actionTime;

  /// 改编小说名称
  final String scriptName;

  /// 改编小说作者
  final String scriptAuthor;

  /// 是否已收藏
  final bool isFavor;

  /// 收藏次数
  final int favoriteCount;

  /// 收藏时间 (毫秒)
  final int favoriteTime;

  /// 等级标签 (1:S级、2:A级、3:B级)
  final int levelLabel;

  /// 是否潜力剧
  final bool isPotential;

  /// 备案号
  final String icpNumber;

  /// 当前播放到的剧集 groupId (iOS 场景)
  final int groupId;

  /// 剧集状态列表（仅在详情页场景会返回）
  final List<EpisodeStatus> episodeStatusList;

  const DramaInfo({
    required this.id,
    required this.title,
    required this.coverImage,
    required this.desc,
    required this.total,
    required this.index,
    required this.type,
    this.typeId = 0,
    required this.status,
    required this.freeSet,
    required this.lockSet,
    required this.createTime,
    this.actionTime = 0,
    this.scriptName = '',
    this.scriptAuthor = '',
    required this.isFavor,
    required this.favoriteCount,
    this.favoriteTime = 0,
    this.levelLabel = 0,
    this.isPotential = false,
    this.icpNumber = '',
    this.groupId = 0,
    this.episodeStatusList = const <EpisodeStatus>[],
  });

  /// 从Map创建短剧信息 - 匹配真实SDK数据结构
  factory DramaInfo.fromMap(Map<String, dynamic> map) {
    final List<dynamic>? rawStatusList =
        map['episodeStatusList'] as List<dynamic>?;
    return DramaInfo(
      id: map['id'] is int ? map['id'] as int : int.parse(map['id'].toString()),
      title: map['title'] as String? ?? '',
      coverImage: map['coverImage'] as String? ?? '',
      desc: map['desc'] as String? ?? '',
      total: _coerceInt(map['total']),
      index: _coerceInt(map['index']),
      type: map['type'] as String? ?? '',
      typeId: _coerceInt(map['typeId']),
      status: _coerceInt(map['status']),
      freeSet: _coerceInt(map['freeSet']),
      lockSet: _coerceInt(map['lockSet']),
      createTime: _coerceInt(map['createTime']),
      actionTime: _coerceInt(map['actionTime']),
      scriptName: map['scriptName'] as String? ?? '',
      scriptAuthor: map['scriptAuthor'] as String? ?? '',
      isFavor: map['isFavor'] as bool? ?? (map['favoriteState'] == 1),
      favoriteCount: _coerceInt(map['favoriteCount']),
      favoriteTime: _coerceInt(map['favoriteTime']),
      levelLabel: _coerceInt(map['levelLabel']),
      isPotential: map['isPotential'] as bool? ?? false,
      icpNumber:
          map['icpNumber'] as String? ?? map['icp_number'] as String? ?? '',
      groupId: _coerceInt(map['groupId'] ?? map['group_id']),
      episodeStatusList: rawStatusList == null
          ? const <EpisodeStatus>[]
          : rawStatusList
                .map(
                  (dynamic item) => EpisodeStatus.fromMap(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'coverImage': coverImage,
      'desc': desc,
      'total': total,
      'index': index,
      'type': type,
      'typeId': typeId,
      'status': status,
      'freeSet': freeSet,
      'lockSet': lockSet,
      'createTime': createTime,
      'actionTime': actionTime,
      'scriptName': scriptName,
      'scriptAuthor': scriptAuthor,
      'isFavor': isFavor,
      'favoriteCount': favoriteCount,
      'favoriteTime': favoriteTime,
      'levelLabel': levelLabel,
      'isPotential': isPotential,
      'icpNumber': icpNumber,
      'groupId': groupId,
      'episodeStatusList': episodeStatusList
          .map((EpisodeStatus e) => e.toMap())
          .toList(),
    };
  }

  static int _coerceInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return 'DramaInfo(id: $id, title: $title, total: $total, index: $index)';
  }
}

/// 短剧分类信息
class CategoryInfo {
  /// 分类ID
  final String categoryId;

  /// 分类名称
  final String name;

  /// 分类图标
  final String iconUrl;

  /// 分类描述
  final String description;

  /// 短剧数量
  final int dramaCount;

  const CategoryInfo({
    required this.categoryId,
    required this.name,
    required this.iconUrl,
    required this.description,
    required this.dramaCount,
  });

  /// 从Map创建分类信息
  factory CategoryInfo.fromMap(Map<String, dynamic> map) {
    return CategoryInfo(
      categoryId: map['categoryId'] as String,
      name: map['name'] as String,
      iconUrl: map['iconUrl'] as String,
      description: map['description'] as String,
      dramaCount: map['dramaCount'] as int,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'iconUrl': iconUrl,
      'description': description,
      'dramaCount': dramaCount,
    };
  }

  @override
  String toString() {
    return 'CategoryInfo(categoryId: $categoryId, name: $name, dramaCount: $dramaCount)';
  }
}
