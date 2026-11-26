import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短故事管理器
class StoryManager {
  static final StoryManager _instance = StoryManager._internal();
  factory StoryManager() => _instance;
  StoryManager._internal();

  /// 获取故事列表
  /// [categoryId] 分类ID筛选（可选）
  /// [page] 页码（可选，默认1）
  /// [pageSize] 每页大小（可选，默认20）
  /// [order] 排序方式（可选，默认true为正序）
  Future<List<StoryInfo>> getStoryList({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
    bool order = true,
  }) async {
    try {
      return await PangrowthContent.getStoryList(
        page: page,
        count: pageSize,
        order: order,
        categoryId: categoryId,
      );
    } catch (e) {
      debugPrint('获取故事列表失败: $e');
      return [];
    }
  }

  /// 搜索故事
  /// [keyword] 搜索关键词
  /// [isFuzzy] 是否模糊搜索（可选，默认true）
  /// [page] 页码（可选，默认1）
  /// [count] 每页数量（可选，默认20）
  Future<List<StoryInfo>> searchStory(
    String keyword, {
    bool isFuzzy = true,
    int page = 1,
    int count = 20,
  }) async {
    try {
      return await PangrowthContent.searchStory(
        keyword,
        isFuzzy: isFuzzy,
        page: page,
        count: count,
      );
    } catch (e) {
      debugPrint('搜索故事失败: $e');
      return [];
    }
  }

  /// 获取故事详情
  /// [storyId] 故事ID
  /// 注意：当前API可能不支持单独获取故事详情，可通过列表或搜索获取
  Future<StoryInfo?> getStoryDetail(String storyId) async {
    try {
      // 目前通过搜索功能来获取特定故事的详情
      final results = await searchStory(storyId, isFuzzy: false, count: 1);
      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('获取故事详情失败: $e');
      return null;
    }
  }

  /// 标记故事为已读
  /// [storyId] 故事ID
  Future<bool> markAsRead(String storyId) async {
    try {
      return await PangrowthContent.markAsRead(storyId);
    } catch (e) {
      debugPrint('标记已读失败: $e');
      return false;
    }
  }

  /// 收藏故事
  /// [storyId] 故事ID
  /// [isFavorite] 是否收藏
  Future<bool> toggleFavorite(String storyId, bool isFavorite) async {
    try {
      return await PangrowthContent.favoriteStory(
        storyId,
        isFavorite: isFavorite,
      );
    } catch (e) {
      debugPrint('收藏操作失败: $e');
      return false;
    }
  }

  /// 点赞故事
  /// [storyId] 故事ID
  /// [isLiked] 是否点赞
  Future<bool> toggleLike(String storyId, bool isLiked) async {
    try {
      return await PangrowthContent.likeStory(storyId, isLiked: isLiked);
    } catch (e) {
      debugPrint('点赞操作失败: $e');
      return false;
    }
  }

  /// 更新阅读进度
  /// [storyId] 故事ID
  /// [readDuration] 阅读时长（毫秒）
  Future<bool> updateReadProgress(String storyId, int readDuration) async {
    try {
      return await PangrowthContent.updateReadProgress(storyId, readDuration);
    } catch (e) {
      debugPrint('更新阅读进度失败: $e');
      return false;
    }
  }

  /// 获取用户收藏的故事列表
  /// [page] 页码（可选，默认1）
  /// [count] 每页数量（可选，默认20）
  Future<List<StoryInfo>> getFavoriteStories({
    int page = 1,
    int count = 20,
  }) async {
    try {
      return await PangrowthContent.getFavoriteStories(
        page: page,
        count: count,
      );
    } catch (e) {
      debugPrint('获取收藏列表失败: $e');
      return [];
    }
  }

  /// 获取用户阅读历史
  /// [page] 页码（可选，默认1）
  /// [count] 每页数量（可选，默认20）
  Future<List<StoryInfo>> getReadHistory({int page = 1, int count = 20}) async {
    try {
      return await PangrowthContent.getStoryHistory(page: page, count: count);
    } catch (e) {
      debugPrint('获取阅读历史失败: $e');
      return [];
    }
  }

  /// 获取推荐故事列表
  /// [count] 推荐数量（默认10）
  /// [page] 页码（可选，默认1）
  Future<List<StoryInfo>> getRecommendedStories({
    int count = 10,
    int page = 1,
  }) async {
    try {
      // 获取正序排列的故事列表作为推荐
      return await getStoryList(page: page, pageSize: count, order: true);
    } catch (e) {
      debugPrint('获取推荐故事失败: $e');
      return [];
    }
  }

  /// 获取热门故事列表
  /// [count] 数量（默认10）
  /// [page] 页码（可选，默认1）
  Future<List<StoryInfo>> getPopularStories({
    int count = 10,
    int page = 1,
  }) async {
    try {
      // 获取倒序排列的故事列表作为热门内容
      final allStories = await getStoryList(
        page: page,
        pageSize: count * 2,
        order: false,
      );
      // 按阅读次数排序
      allStories.sort((a, b) => b.statsCount.compareTo(a.statsCount));
      return allStories.take(count).toList();
    } catch (e) {
      debugPrint('获取热门故事失败: $e');
      return [];
    }
  }

  /// 获取最新故事列表
  /// [count] 数量（默认10）
  /// [page] 页码（可选，默认1）
  Future<List<StoryInfo>> getLatestStories({
    int count = 10,
    int page = 1,
  }) async {
    try {
      // 获取倒序排列的故事列表作为最新内容
      final allStories = await getStoryList(
        page: page,
        pageSize: count * 2,
        order: false,
      );
      // 按创建时间排序
      allStories.sort((a, b) => b.createTime.compareTo(a.createTime));
      return allStories.take(count).toList();
    } catch (e) {
      debugPrint('获取最新故事失败: $e');
      return [];
    }
  }

  /// 获取分类列表
  Future<List<Map<String, dynamic>>> getCategoryList() async {
    try {
      return await PangrowthContent.getStoryCategoryList();
    } catch (e) {
      debugPrint('获取分类列表失败: $e');
      return [];
    }
  }

  /// 创建短故事聚合页
  Future<Map<String, dynamic>?> createStoryHome({
    StoryHomeConfig? config,
  }) async {
    try {
      return await PangrowthContent.createStoryHome(config: config);
    } catch (e) {
      debugPrint('创建短故事聚合页失败: $e');
      return null;
    }
  }

  /// 展示短故事聚合页
  /// [widgetId] 聚合页组件ID
  Future<Map<String, dynamic>?> showStoryHome(String widgetId) async {
    try {
      return await PangrowthContent.showStoryHome(widgetId);
    } catch (e) {
      debugPrint('展示短故事聚合页失败: $e');
      return null;
    }
  }

  /// 销毁短故事聚合页
  /// [widgetId] 聚合页组件ID
  Future<bool> destroyStoryHome(String widgetId) async {
    try {
      return await PangrowthContent.destroyStoryHome(widgetId);
    } catch (e) {
      debugPrint('销毁短故事聚合页失败: $e');
      return false;
    }
  }
}
