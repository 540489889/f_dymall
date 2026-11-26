import '../pangrowth_content.dart';

/// 短剧管理器
class DramaManager {
  static final DramaManager _instance = DramaManager._internal();
  factory DramaManager() => _instance;
  DramaManager._internal();

  /// 获取短剧列表
  /// [category] 分类筛选（可选）
  /// [page] 页码（可选，默认1）
  /// [pageSize] 每页大小（可选，默认20）
  Future<List<DramaInfo>> getDramaList({
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (category != null && category.isNotEmpty) {
      return PangrowthContent.getDramaListByCategory(
        category,
        page: page,
        count: pageSize,
      );
    }
    return PangrowthContent.getDramaList(page: page, count: pageSize);
  }

  /// 搜索短剧
  /// [keyword] 搜索关键词
  Future<List<DramaInfo>> searchDrama(String keyword) async {
    return await PangrowthContent.searchDrama(keyword);
  }

  /// 获取分类列表
  Future<List<CategoryInfo>> getCategoryList() async {
    final List<String> categoryNames = await PangrowthContent.getCategoryList();
    return categoryNames
        .map(
          (name) => CategoryInfo(
            categoryId: name,
            name: name,
            iconUrl: '',
            description: '',
            dramaCount: 0,
          ),
        )
        .toList();
  }

  /// 收藏短剧
  /// [dramaId] 短剧ID
  /// [isFavorite] 是否收藏
  Future<bool> toggleFavorite(
    int dramaId,
    bool isFavorite, {
    int? episodeIndex,
  }) async {
    return PangrowthContent.setDramaFavorite(
      dramaId,
      favorite: isFavorite,
      episodeIndex: episodeIndex,
    );
  }

  /// 点赞短剧
  /// [dramaId] 短剧ID
  /// [isLiked] 是否点赞
  Future<bool> toggleLike(int dramaId, int episodeIndex, bool isLiked) async {
    return PangrowthContent.likeDramaEpisode(
      dramaId,
      episodeIndex,
      like: isLiked,
    );
  }

  /// 更新观看进度
  ///
  /// **⚠️ 平台限制**: 仅Android支持,iOS不支持此功能
  ///
  /// [playerId] 播放页ID
  /// [duration] 跳转位置(毫秒)
  ///
  /// 注意:此方法直接调用原生 seekTo API,用于恢复播放进度
  ///
  /// @android
  Future<Map<String, dynamic>> updateWatchProgress(
    String playerId,
    int duration,
  ) async {
    return PangrowthContent.seekTo(playerId, duration);
  }

  /// 获取用户收藏的短剧列表
  Future<List<DramaInfo>> getFavoriteDramas() async {
    final DramaPageResult result = await PangrowthContent.getDramaFavorList();
    return result.items;
  }

  /// 获取用户观看历史
  Future<List<DramaInfo>> getWatchHistory() async {
    return PangrowthContent.getDramaHistory();
  }

  /// 获取推荐短剧列表
  /// [count] 推荐数量（默认10）
  Future<List<DramaInfo>> getRecommendedDramas({int count = 10}) async {
    return PangrowthContent.getRecommendedDramaList(count: count);
  }

  /// 根据短剧ID列表获取短剧详情
  Future<List<DramaInfo>> getDramasByIds(List<int> dramaIds) {
    return PangrowthContent.getDramaListByIds(dramaIds);
  }
}
