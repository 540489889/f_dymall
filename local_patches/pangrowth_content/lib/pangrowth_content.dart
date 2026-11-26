import 'dart:async';

import 'package:flutter/foundation.dart';

import 'event/content_event_handler.dart';
import 'model/drama_info.dart';
import 'model/story_info.dart';
import 'model/content_config.dart';
import 'model/drama_swipe_config.dart';
import 'model/drama_card_config.dart';
import 'model/drama_player_config.dart';
import 'model/video_config.dart';
import 'model/grid_video_config.dart';
import 'model/video_card_config.dart';
import 'model/video_single_card_config.dart';
import 'model/episode_status.dart';
import 'model/drama_page_result.dart';
import 'model/story_home_config.dart';
import 'model/user_profile_config.dart';
import 'listener/drama_player_listener.dart';
import 'listener/video_listener.dart';
import 'listener/drama_card_listener.dart';
import 'listener/drama_swipe_flow_listener.dart';
import 'listener/grid_video_listener.dart';
import 'listener/user_profile_listener.dart';
import 'listener/drama_home_listener.dart';
import 'listener/story_home_listener.dart';
import 'listener/story_reader_listener.dart';
import 'pangrowth_content_platform_interface.dart';
export 'model/drama_info.dart';
export 'model/story_info.dart';
export 'model/content_config.dart';
export 'model/drama_home_config.dart';
export 'model/drama_swipe_config.dart';
export 'model/drama_card_config.dart';
export 'model/drama_player_config.dart';
export 'model/video_config.dart';
export 'model/grid_video_config.dart';
export 'model/video_card_config.dart';
export 'model/video_single_card_config.dart';
export 'model/user_profile_config.dart';
export 'model/privacy_config.dart';
export 'model/episode_status.dart';
export 'model/drama_page_result.dart';
export 'model/story_home_config.dart';
export 'model/story_reader_config.dart';
export 'manager/drama_manager.dart';
export 'manager/story_manager.dart';
export 'widget/drama_swipe_flow_native_view.dart';
export 'widget/drama_card_native_view.dart';
export 'widget/drama_player_native_view.dart';
export 'widget/drama_home_native_view.dart';
export 'widget/video_native_view.dart';
export 'widget/story_home_native_view.dart';
export 'widget/story_reader_native_view.dart';
export 'widget/grid_video_native_view.dart';
export 'widget/user_profile_native_view.dart';
export 'controller/drama_player_controller.dart';
export 'controller/video_controller.dart';
export 'controller/drama_swipe_flow_controller.dart';
export 'controller/drama_card_controller.dart';
export 'controller/drama_home_controller.dart';
export 'controller/story_home_controller.dart';
export 'controller/story_reader_controller.dart';
export 'controller/grid_video_controller.dart';
export 'controller/user_profile_controller.dart';
export 'listener/drama_player_listener.dart';
export 'listener/video_listener.dart';
export 'listener/drama_swipe_flow_listener.dart';
export 'listener/drama_card_listener.dart';
export 'listener/grid_video_listener.dart';
export 'listener/user_profile_listener.dart';
export 'listener/drama_home_listener.dart';
export 'listener/story_home_listener.dart';
export 'listener/story_reader_listener.dart';

/// 穿山甲内容SDK插件
class PangrowthContent {
  static PangrowthContentPlatform get _platform =>
      PangrowthContentPlatform.instance;

  static StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  // ==================== Listener映射表 ====================

  /// DramaPlayer listener 映射表 (playerId -> listener)
  static final Map<String, DramaPlayerListener> _dramaPlayerListeners = {};

  /// Video listener 映射表 (videoId -> listener)
  static final Map<String, VideoListener> _videoListeners = {};

  /// DramaCard listener 映射表 (cardId -> listener)
  static final Map<String, DramaCardListener> _cardListeners = {};

  /// DramaSwipeFlow listener 映射表 (swipeFlowId -> listener)
  static final Map<String, DramaSwipeFlowListener> _swipeFlowListeners = {};

  /// GridVideo listener 映射表 (gridId -> listener)
  static final Map<String, GridVideoListener> _gridVideoListeners = {};

  /// UserProfile listener 映射表 (profileId -> listener)
  static final Map<String, UserProfileListener> _userProfileListeners = {};

  /// DramaHome listener 映射表 (widgetId -> listener)
  static final Map<String, DramaHomeListener> _dramaHomeListeners = {};

  /// StoryHome listener 映射表 (widgetId -> listener)
  static final Map<String, StoryHomeListener> _storyHomeListeners = {};

  /// StoryReader listener 映射表 (readerId -> listener)
  static final Map<String, StoryReaderListener> _storyReaderListeners = {};

  // ==================== Listener注册/注销API ====================

  /// 注册 DramaPlayer listener
  static void registerDramaPlayerListener(
    String playerId,
    DramaPlayerListener listener,
  ) {
    debugPrint('[DramaPlayerDebug] 📝 注册 listener, playerId: $playerId');
    _dramaPlayerListeners[playerId] = listener;
    debugPrint(
      '[DramaPlayerDebug] 📝 当前已注册数量: ${_dramaPlayerListeners.length}',
    );
    _ensureContentEventSubscription();
  }

  /// 取消注册 DramaPlayer listener
  static void unregisterDramaPlayerListener(String playerId) {
    _dramaPlayerListeners.remove(playerId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 playerId 的 listener
  static DramaPlayerListener? getDramaPlayerListener(String playerId) {
    return _dramaPlayerListeners[playerId];
  }

  /// 注册 Video listener
  static void registerVideoListener(String videoId, VideoListener listener) {
    _videoListeners[videoId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 Video listener
  static void unregisterVideoListener(String videoId) {
    _videoListeners.remove(videoId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 videoId 的 listener
  static VideoListener? getVideoListener(String videoId) {
    return _videoListeners[videoId];
  }

  /// 注册 DramaCard listener
  static void registerDramaCardListener(
    String cardId,
    DramaCardListener listener,
  ) {
    _cardListeners[cardId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 DramaCard listener
  static void unregisterDramaCardListener(String cardId) {
    _cardListeners.remove(cardId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 cardId 的 listener
  static DramaCardListener? getDramaCardListener(String cardId) {
    return _cardListeners[cardId];
  }

  /// 注册 DramaSwipeFlow listener
  static void registerDramaSwipeFlowListener(
    String swipeFlowId,
    DramaSwipeFlowListener listener,
  ) {
    _swipeFlowListeners[swipeFlowId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 DramaSwipeFlow listener
  static void unregisterDramaSwipeFlowListener(String swipeFlowId) {
    _swipeFlowListeners.remove(swipeFlowId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 swipeFlowId 的 listener
  static DramaSwipeFlowListener? getDramaSwipeFlowListener(String swipeFlowId) {
    return _swipeFlowListeners[swipeFlowId];
  }

  /// 注册 GridVideo listener
  static void registerGridVideoListener(
    String gridId,
    GridVideoListener listener,
  ) {
    _gridVideoListeners[gridId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 GridVideo listener
  static void unregisterGridVideoListener(String gridId) {
    _gridVideoListeners.remove(gridId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 gridId 的 listener
  static GridVideoListener? getGridVideoListener(String gridId) {
    return _gridVideoListeners[gridId];
  }

  /// 注册 UserProfile listener
  static void registerUserProfileListener(
    String profileId,
    UserProfileListener listener,
  ) {
    _userProfileListeners[profileId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 UserProfile listener
  static void unregisterUserProfileListener(String profileId) {
    _userProfileListeners.remove(profileId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 profileId 的 listener
  static UserProfileListener? getUserProfileListener(String profileId) {
    return _userProfileListeners[profileId];
  }

  /// 注册 DramaHome listener
  static void registerDramaHomeListener(
    String widgetId,
    DramaHomeListener listener,
  ) {
    _dramaHomeListeners[widgetId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 DramaHome listener
  static void unregisterDramaHomeListener(String widgetId) {
    _dramaHomeListeners.remove(widgetId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 widgetId 的 DramaHome listener
  static DramaHomeListener? getDramaHomeListener(String widgetId) {
    return _dramaHomeListeners[widgetId];
  }

  /// 注册 StoryHome listener
  static void registerStoryHomeListener(
    String widgetId,
    StoryHomeListener listener,
  ) {
    _storyHomeListeners[widgetId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 StoryHome listener
  static void unregisterStoryHomeListener(String widgetId) {
    _storyHomeListeners.remove(widgetId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 widgetId 的 StoryHome listener
  static StoryHomeListener? getStoryHomeListener(String widgetId) {
    return _storyHomeListeners[widgetId];
  }

  /// 注册 StoryReader listener
  static void registerStoryReaderListener(
    String readerId,
    StoryReaderListener listener,
  ) {
    _storyReaderListeners[readerId] = listener;
    _ensureContentEventSubscription();
  }

  /// 取消注册 StoryReader listener
  static void unregisterStoryReaderListener(String readerId) {
    _storyReaderListeners.remove(readerId);
    unawaited(_maybeDisposeContentEventSubscription());
  }

  /// 获取指定 readerId 的 listener
  static StoryReaderListener? getStoryReaderListener(String readerId) {
    return _storyReaderListeners[readerId];
  }

  /// 安全的类型转换工具方法，将MethodChannel返回的Map转换为`Map<String, dynamic>`
  /// 支持递归转换嵌套的Map和List结构
  static Map<String, dynamic> _castMap(dynamic map) {
    if (map is Map<String, dynamic>) return map;
    if (map is Map) {
      return Map<String, dynamic>.fromEntries(
        map.entries.map(
          (entry) => MapEntry<String, dynamic>(
            entry.key.toString(),
            _castValue(entry.value),
          ),
        ),
      );
    }
    throw ArgumentError('Expected Map, got ${map.runtimeType}');
  }

  /// 递归转换值,处理嵌套的Map和List
  static dynamic _castValue(dynamic value) {
    if (value is Map) {
      return _castMap(value);
    } else if (value is List) {
      return value.map((item) => _castValue(item)).toList();
    }
    return value;
  }

  static Map<String, dynamic> _buildParams(Map<String, dynamic> source) {
    final Map<String, dynamic> result = {};
    source.forEach((String key, dynamic value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  static Future<dynamic> _invokeRaw(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    return _platform.invokeMethod<dynamic>(method, params);
  }

  static Future<bool> _invokeBool(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final bool? value = await _platform.invokeMethod<bool>(method, params);
    return value ?? false;
  }

  static Future<String?> _invokeString(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    return _platform.invokeMethod<String>(method, params);
  }

  static Future<List<dynamic>> _invokeList(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final List<dynamic>? raw = await _platform.invokeMethod<List<dynamic>>(
      method,
      params,
    );
    return raw ?? const <dynamic>[];
  }

  static Future<Map<String, dynamic>> _invokeMap(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final dynamic raw = await _platform.invokeMethod<dynamic>(method, params);
    if (raw == null) {
      return const <String, dynamic>{};
    }
    return _castMap(raw);
  }

  static void _ensureContentEventSubscription() {
    if (_eventSubscription != null) {
      return;
    }

    _eventSubscription = _platform.contentEventStream.listen(
      _handleContentEventPayload,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('pangrowth_content: event stream error: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );
  }

  static Future<void> _maybeDisposeContentEventSubscription({
    bool force = false,
  }) async {
    if (!force && _dramaPlayerListeners.isNotEmpty) {
      return;
    }
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  static void _handleContentEventPayload(Map<String, dynamic> payload) {
    debugPrint('[DramaPlayerDebug] 📨 收到原生事件: ${payload['type']}');
    try {
      handleContentEvent(payload);
    } catch (error, stackTrace) {
      debugPrint('pangrowth_content: failed to handle content event: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// 初始化SDK
  /// [configPath] 配置文件路径
  /// [config] 初始化配置
  static Future<bool> initialize({
    required String configPath,
    ContentConfig? config,
  }) async {
    if (configPath.isEmpty) {
      throw ArgumentError('configPath cannot be empty');
    }

    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'configPath': configPath,
      'config': config?.toMap(),
    });

    return _invokeBool('initialize', params);
  }

  /// 启动服务
  /// 需要在 GroMore(gromore_ads) 广告 SDK 初始化成功后调用
  /// [startVideo] 是否启动小视频模块
  static Future<bool> start({
    bool? startDrama,
    bool? startStory,
    bool? startVideo,
    Map<String, dynamic>? extra,
  }) async {
    final Map<String, dynamic> payload = _buildParams(<String, dynamic>{
      'startDrama': startDrama,
      'startStory': startStory,
      'startVideo': startVideo,
      'extra': extra == null || extra.isEmpty ? null : extra,
    });

    final Map<String, dynamic>? params = payload.isEmpty ? null : payload;
    return _invokeBool('start', params);
  }

  /// 获取短剧列表（分页）
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  /// [order] 排序方式，true为正序，false为倒序
  static Future<List<DramaInfo>> getDramaList({
    int? page,
    int? count,
    bool? order,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
      'order': order,
    });
    final List<dynamic> result = await _invokeList(
      'getDramaList',
      params.isEmpty ? null : params,
    );
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 获取短剧分类列表
  static Future<List<String>> getCategoryList() async {
    final List<dynamic> result = await _invokeList('getCategoryList');
    if (result.isEmpty) {
      return const <String>[];
    }
    if (result.first is String) {
      return result.cast<String>();
    }
    return result
        .map((dynamic item) => (item as Map)['name'] as String)
        .toList();
  }

  /// 搜索短剧（支持分页）
  /// [query] 搜索关键词
  /// [isFuzzy] 是否模糊搜索，默认true
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  static Future<List<DramaInfo>> searchDrama(
    String query, {
    bool? isFuzzy,
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'query': query,
      'isFuzzy': isFuzzy,
      'page': page,
      'count': count,
    });
    final List<dynamic> result = await _invokeList(
      'searchDrama',
      params.isEmpty ? null : params,
    );
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 获取短剧历史记录（分页）
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  static Future<List<DramaInfo>> getDramaHistory({
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
    });
    final List<dynamic> result = await _invokeList(
      'getDramaHistory',
      params.isEmpty ? null : params,
    );
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 获取推荐短剧列表（基于个性化推荐）
  static Future<List<DramaInfo>> getRecommendedDramaList({
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
    });
    final List<dynamic> result = await _invokeList(
      'getRecommendedDramaList',
      params.isEmpty ? null : params,
    );
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 根据短剧ID列表获取短剧信息
  static Future<List<DramaInfo>> getDramaListByIds(List<int> dramaIds) async {
    if (dramaIds.isEmpty) {
      return const <DramaInfo>[];
    }
    final Map<String, dynamic> params = {'dramaIds': dramaIds};
    final List<dynamic> result = await _invokeList('getDramaListByIds', params);
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 根据分类获取短剧列表
  static Future<List<DramaInfo>> getDramaListByCategory(
    String category, {
    int? page,
    int? count,
    bool? ascending,
  }) async {
    if (category.isEmpty) {
      throw ArgumentError('category cannot be empty');
    }
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'category': category,
      'page': page,
      'count': count,
      'order': ascending == null ? null : (ascending ? 0 : 1),
    });
    final List<dynamic> result = await _invokeList(
      'getDramaListByCategory',
      params.isEmpty ? null : params,
    );
    return result.map((item) => DramaInfo.fromMap(_castMap(item))).toList();
  }

  /// 清空短剧历史记录
  static Future<void> clearDramaHistory() async {
    await _invokeRaw('clearDramaHistory');
  }

  /// 收藏或取消收藏短剧
  static Future<bool> setDramaFavorite(
    int dramaId, {
    bool favorite = true,
    int? episodeIndex,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'dramaId': dramaId,
      'favorite': favorite,
      'episodeIndex': episodeIndex,
    });
    return _invokeBool('favorDrama', params);
  }

  /// 点赞或取消点赞短剧剧集
  static Future<bool> likeDramaEpisode(
    int dramaId,
    int episodeIndex, {
    bool like = true,
  }) async {
    final Map<String, dynamic> params = {
      'dramaId': dramaId,
      'episodeIndex': episodeIndex,
      'like': like,
    };
    return _invokeBool('likeEpisode', params);
  }

  /// 获取收藏列表（分页）
  static Future<DramaPageResult> getDramaFavorList({
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
    });
    final dynamic raw = await _invokeRaw(
      'getDramaFavorList',
      params.isEmpty ? null : params,
    );
    if (raw == null) {
      return const DramaPageResult(
        items: <DramaInfo>[],
        total: 0,
        hasMore: false,
        others: <String, dynamic>{},
      );
    }
    return DramaPageResult.fromMap(_castMap(raw));
  }

  /// 查询短剧剧集的解锁情况
  static Future<List<EpisodeStatus>> getDramaEpisodesStatus({
    required int dramaId,
    required int freeSet,
  }) async {
    final Map<String, dynamic> params = {
      'dramaId': dramaId,
      'freeSet': freeSet,
    };
    final dynamic raw = await _invokeRaw('getDramaEpisodesStatus', params);
    if (raw == null) {
      return const <EpisodeStatus>[];
    }
    final List<dynamic> result = List<dynamic>.from(raw as List);
    return result
        .map(
          (dynamic item) =>
              EpisodeStatus.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  /// 校验短剧参数是否符合规则
  static Future<Map<String, dynamic>> verifyDramaParams({
    required int total,
    required int freeSet,
    required int lockSet,
  }) async {
    final Map<String, dynamic> params = {
      'total': total,
      'freeSet': freeSet,
      'lockSet': lockSet,
    };
    return _invokeMap('verifyDramaParams', params);
  }

  /// 销毁短剧聚合页（PlatformView 销毁时调用）
  /// 建议在 `DramaHomeNativeView` 的 `dispose` 中调用，确保原生资源被释放。
  static Future<void> destroyDramaHome(String viewId) async {
    if (viewId.isEmpty) {
      return;
    }
    try {
      await _invokeRaw('destroyDramaHome', {'widgetId': viewId});
    } catch (_) {
      // 忽略销毁异常，避免在页面退出时抛出未捕获错误
    }
  }

  // MARK: - 短剧聚合页控制方法

  /// 跳转短剧聚合页到指定播放进度
  /// [homeId] 聚合页ID
  /// [time] 跳转位置（毫秒）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.seekTo(time)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<bool> seekToDramaHome(String homeId, int time) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': homeId, 'time': time};

    return _invokeBool('seekToDramaHome', params);
  }

  /// 设置短剧聚合页当前页面位置
  /// [homeId] 聚合页ID
  /// [position] 页面索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentPage(position)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<bool> setCurrentPageDramaHome(
    String homeId,
    int position,
  ) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'widgetId': homeId,
      'position': position,
    };

    return _invokeBool('setCurrentPageDramaHome', params);
  }

  /// 获取短剧聚合页当前短剧集数索引
  /// [homeId] 聚合页ID
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.getCurrentDramaIndex()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<int> getCurrentDramaIndexDramaHome(String homeId) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': homeId};
    final result = await _invokeMap('getCurrentDramaIndexDramaHome', params);
    return result['index'] as int? ?? -1;
  }

  /// 设置短剧聚合页当前短剧集数索引
  /// [homeId] 聚合页ID
  /// [index] 集数索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentDramaIndex(index)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<bool> setCurrentDramaIndexDramaHome(
    String homeId,
    int index,
  ) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }
    if (index < 1) {
      throw ArgumentError('index must be greater than 0');
    }

    final Map<String, dynamic> params = {'widgetId': homeId, 'index': index};

    return _invokeBool('setCurrentDramaIndexDramaHome', params);
  }

  /// 打开短剧聚合页更多弹窗（举报、设置等）
  /// [homeId] 聚合页ID
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.openMoreDialog()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<bool> openMoreDialogDramaHome(String homeId) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': homeId};

    return _invokeBool('openMoreDialogDramaHome', params);
  }

  /// 短剧聚合页返回并刷新页面
  /// [homeId] 聚合页ID
  ///
  /// 用于从详情页返回聚合页时刷新数据。
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.backRefresh()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  static Future<bool> backRefreshDramaHome(String homeId) async {
    if (homeId.isEmpty) {
      throw ArgumentError('homeId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': homeId};

    return _invokeBool('backRefreshDramaHome', params);
  }

  /// 设置个性化推荐
  /// [enabled] 是否开启个性化推荐
  static Future<void> setPersonalization(bool enabled) async {
    final Map<String, dynamic> params = {'enabled': enabled};
    await _invokeBool('setPersonalization', params);
  }

  /// 获取个性化推荐设置状态
  static Future<bool> getPersonalization() async {
    return _invokeBool('getPersonalization');
  }

  // MARK: - 短剧解锁记录绑定

  /// 生成短剧解锁记录绑定所需的签名参数
  /// [serverKey] 从穿山甲后台获取的 server key（必须）
  /// [nonce] 16 位随机字符串
  /// [timestamp] 秒级时间戳
  /// [payload] 额外参与签名的键值对（通常至少需要包含 `ouid`）
  static Future<String?> generateDramaUnlockSign({
    required String serverKey,
    required String nonce,
    required int timestamp,
    Map<String, String>? payload,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'serverKey': serverKey,
      'nonce': nonce,
      'timestamp': timestamp,
      'payload': payload,
    });

    return _invokeString('generateDramaUnlockSign', params);
  }

  /// 绑定短剧解锁记录
  /// 可直接传入已拼接好的 [params] 字符串，或通过 serverKey/nonce/timestamp/payload 由原生端生成并绑定
  static Future<Map<String, dynamic>> loginDramaUnlock({
    String? params,
    String? serverKey,
    String? nonce,
    int? timestamp,
    Map<String, String>? payload,
  }) async {
    final Map<String, dynamic> arguments = _buildParams(<String, dynamic>{
      'params': params,
      'serverKey': serverKey,
      'nonce': nonce,
      'timestamp': timestamp,
      'payload': payload,
    });

    return _invokeMap('loginDramaUnlock', arguments);
  }

  /// 解绑短剧解锁记录
  static Future<Map<String, dynamic>> logoutDramaUnlock() async {
    return _invokeMap('logoutDramaUnlock');
  }

  /// 查询短剧解锁记录是否已经绑定
  static Future<bool> isDramaUnlockLogin() async {
    return _invokeBool('isDramaUnlockLogin');
  }

  /// 创建短剧滑滑流
  /// [config] 滑滑流配置参数（可选）
  /// 返回创建结果，包含widgetId和success状态
  static Future<Map<String, dynamic>> createDramaSwipeFlow({
    DramaSwipeConfig? config,
  }) async {
    Map<String, dynamic>? params;
    if (config != null) {
      params = config.toMap();
    }

    return _invokeMap('createDramaSwipeFlow', params);
  }

  /// 展示短剧滑滑流
  /// [widgetId] 滑滑流组件ID，通过createDramaSwipeFlow获得
  /// 返回展示结果，包含widgetId和shown状态
  static Future<Map<String, dynamic>> showDramaSwipeFlow(
    String widgetId,
  ) async {
    if (widgetId.isEmpty) {
      throw ArgumentError('widgetId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': widgetId};

    return _invokeMap('showDramaSwipeFlow', params);
  }

  /// 隐藏短剧滑滑流
  /// [widgetId] 滑滑流组件ID
  static Future<bool> hideDramaSwipeFlow(String widgetId) async {
    if (widgetId.isEmpty) {
      throw ArgumentError('widgetId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': widgetId};

    return _invokeBool('hideDramaSwipeFlow', params);
  }

  /// 销毁短剧滑滑流
  /// [widgetId] 滑滑流组件ID
  static Future<bool> destroyDramaSwipeFlow(String widgetId) async {
    if (widgetId.isEmpty) {
      throw ArgumentError('widgetId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': widgetId};

    return _invokeBool('destroyDramaSwipeFlow', params);
  }

  /// 创建短剧卡片
  /// [config] 卡片配置参数
  /// 返回创建结果，包含cardId和success状态
  static Future<Map<String, dynamic>> createDramaCard(
    DramaCardConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createDramaCard', params);
  }

  /// 展示短剧卡片
  /// [cardId] 卡片ID，通过createDramaCard获得
  /// 返回展示结果，包含cardId和shown状态
  static Future<Map<String, dynamic>> showDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeMap('showDramaCard', params);
  }

  /// 播放短剧卡片
  /// [cardId] 卡片ID
  static Future<bool> playDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('playDramaCard', params);
  }

  /// 暂停短剧卡片
  /// [cardId] 卡片ID
  static Future<bool> pauseDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('pauseDramaCard', params);
  }

  /// 停止短剧卡片
  /// [cardId] 卡片ID
  static Future<bool> stopDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('stopDramaCard', params);
  }

  /// 设置短剧卡片静音状态
  /// [cardId] 卡片ID
  /// [mute] 是否静音
  static Future<bool> setDramaCardMute(String cardId, bool mute) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId, 'mute': mute};

    return _invokeBool('setDramaCardMute', params);
  }

  /// 上报短剧卡片展示埋点
  /// [cardId] 卡片ID
  /// [duration] 展示时长（毫秒）
  static Future<bool> reportDramaCardShow(String cardId, int duration) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'cardId': cardId,
      'duration': duration,
    };

    return _invokeBool('reportDramaCardShow', params);
  }

  /// 刷新短剧卡片数据
  /// [cardId] 卡片ID
  static Future<bool> refreshDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('refreshDramaCard', params);
  }

  /// 销毁短剧卡片
  /// [cardId] 卡片ID
  static Future<bool> destroyDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('destroyDramaCard', params);
  }

  /// 判断短剧卡片是否正在播放
  /// [cardId] 卡片ID
  /// 返回true表示正在播放，false表示未播放
  static Future<bool> isDramaCardPlaying(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('isDramaCardPlaying', params);
  }

  /// 获取短剧卡片的短剧信息
  /// [cardId] 卡片ID
  /// 返回短剧信息Map，包含dramaId、title等字段
  static Future<Map<String, dynamic>?> getDramaCardInfo(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    try {
      return await _invokeMap('getDramaCardInfo', params);
    } catch (e) {
      return null;
    }
  }

  /// 获取短剧卡片的短剧GID
  /// [cardId] 卡片ID
  /// 返回短剧GID
  static Future<String?> getDramaCardGid(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    final dynamic result = await _invokeRaw('getDramaCardGid', params);
    return result as String?;
  }

  /// 获取短剧卡片的短剧标题
  /// [cardId] 卡片ID
  /// 返回短剧标题
  static Future<String?> getDramaCardTitle(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    final dynamic result = await _invokeRaw('getDramaCardTitle', params);
    return result as String?;
  }

  /// 重新加载短剧卡片数据
  /// [cardId] 卡片ID
  ///
  /// 当数据加载失败或出现错误时,调用此方法重新请求数据。
  ///
  /// **平台支持**:
  /// - ✅ iOS: `DJXPlayletCard.retryLoadData()`
  /// - ❌ Android: 无对应方法,建议使用 `refreshDramaCard()` 方法
  ///
  /// 🔵 iOS 独有方法
  ///
  /// **使用场景**:
  /// - 网络请求失败后重试
  /// - 数据解析错误后重新加载
  /// - 配合 DramaCardListener 的 onCardError 回调使用
  static Future<bool> retryLoadDataDramaCard(String cardId) async {
    if (cardId.isEmpty) {
      throw ArgumentError('cardId cannot be empty');
    }

    final Map<String, dynamic> params = {'cardId': cardId};

    return _invokeBool('retryLoadDataDramaCard', params);
  }

  // MARK: - 短剧播放页相关方法

  /// 创建短剧播放页
  /// [config] 播放页配置参数
  /// 返回创建结果，包含playerId、dramaId、episode和success状态
  static Future<Map<String, dynamic>> createDramaPlayer(
    DramaPlayerConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createDramaPlayer', params);
  }

  /// 展示短剧播放页
  /// [playerId] 播放页ID，通过createDramaPlayer获得
  /// [presentationStyle] 展示样式（iOS专用）：'fullScreen', 'pageSheet', 'formSheet'
  /// [containerId] 容器ID（Android专用），默认使用android.R.id.content
  /// 返回展示结果，包含playerId和shown状态
  static Future<Map<String, dynamic>> showDramaPlayer(
    String playerId, {
    String? presentationStyle,
    int? containerId,
  }) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    if (presentationStyle != null) {
      params['presentationStyle'] = presentationStyle;
    }

    if (containerId != null) {
      params['containerId'] = containerId;
    }

    return _invokeMap('showDramaPlayer', params);
  }

  /// 自定义广告展示回调
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用自定义广告展示回调
  /// - iOS: 空实现，返回true但不执行任何操作
  ///
  /// [playerId] 播放页ID
  /// [cpm] 广告CPM价格（可选）
  static Future<bool> setCustomAdOnShow(String playerId, {String? cpm}) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'playerId': playerId,
      if (cpm != null) 'cpm': cpm,
    };

    return _invokeBool('setCustomAdOnShow', params);
  }

  /// 自定义广告奖励回调
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用自定义广告奖励回调，验证广告观看完成
  /// - iOS: 空实现，返回true但不执行任何操作
  ///
  /// [playerId] 播放页ID
  /// [verify] 是否验证通过
  /// [extraData] 额外数据（可选）
  static Future<bool> setCustomAdOnReward(
    String playerId, {
    required bool verify,
    Map<String, dynamic>? extraData,
  }) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'playerId': playerId,
      'verify': verify,
      if (extraData != null && extraData.isNotEmpty) 'extraData': extraData,
    };

    return _invokeBool('setCustomAdOnReward', params);
  }

  /// 跳转到指定播放进度
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用原生 `widget.seekTo(duration)` 方法
  /// - iOS: 仅发送事件通知，不执行实际跳转
  ///
  /// [playerId] 播放页ID
  /// [duration] 播放位置（毫秒）
  static Future<Map<String, dynamic>> seekTo(
    String playerId,
    int duration,
  ) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'playerId': playerId,
      'duration': duration,
    };

    return _invokeMap('seekTo', params);
  }

  /// 设置播放倍速
  ///
  /// [playerId] 播放页ID
  /// [speed] 倍速值（例如 1.0 = 正常、1.5 = 1.5倍）
  /// [scope] 倍速作用范围，`episode` 表示当前集、`drama` 表示整部短剧
  static Future<bool> setSpeedPlay(
    String playerId,
    double speed, {
    String scope = 'episode',
  }) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }
    if (speed <= 0) {
      throw ArgumentError('speed must be greater than 0');
    }

    final normalizedScope = scope.toLowerCase();
    final Map<String, dynamic> params = {
      'playerId': playerId,
      'speed': speed,
      'scope': normalizedScope,
    };

    final Map<String, dynamic> result = await _invokeMap(
      'setSpeedPlay',
      params,
    );
    final dynamic success = result['success'];
    if (success is bool) {
      return success;
    }
    return false;
  }

  /// 获取当前播放的集数
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用原生 `widget.getCurrentDramaIndex()` 方法
  /// - iOS: 返回-1表示不支持
  ///
  /// [playerId] 播放页ID
  /// 返回当前集数（从1开始）
  ///
  /// @android
  static Future<int> getCurrentDramaIndex(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};
    final result = await _invokeMap('getCurrentDramaIndex', params);
    return result['index'] as int? ?? -1;
  }

  /// 跳转到指定短剧集数
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用原生 `widget.setCurrentDramaIndex(index)` 方法
  /// - iOS: 仅发送事件通知，不执行实际切换
  ///
  /// [playerId] 播放页ID
  /// [index] 集数索引（从1开始）
  ///
  /// @android
  static Future<bool> setCurrentDramaIndex(String playerId, int index) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }
    if (index < 1) {
      throw ArgumentError('index must be greater than 0');
    }

    final Map<String, dynamic> params = {'playerId': playerId, 'index': index};

    return _invokeBool('setCurrentDramaIndex', params);
  }

  /// 设置当前播放集数
  /// [playerId] 播放页ID
  /// [episode] 集数（从1开始）
  static Future<Map<String, dynamic>> setCurrentEpisode(
    String playerId,
    int episode,
  ) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    if (episode < 1) {
      throw ArgumentError('episode must be greater than 0');
    }

    final Map<String, dynamic> params = {
      'playerId': playerId,
      'episode': episode,
    };

    return _invokeMap('setCurrentEpisode', params);
  }

  /// 获取当前播放集数
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> getCurrentEpisode(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('getCurrentEpisode', params);
  }

  /// 打开更多弹窗（包括举报等功能）
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用原生 `widget.openMoreDialog()` 方法
  /// - iOS: 空实现，返回成功但不执行任何操作
  ///
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> openMoreDialog(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('openMoreDialog', params);
  }

  /// 打开选集面板
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> openEpisodePanel(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('openEpisodePanel', params);
  }

  /// 刷新播放页（用户返回退出页面时挽留）
  ///
  /// **⚠️ 平台限制**: 仅Android支持，iOS不支持此功能
  ///
  /// - Android: 调用原生 `widget.backRefresh()` 方法，刷新视频并toast提醒"再按一次返回键退出"
  /// - iOS: 空实现，返回成功但不执行任何操作
  ///
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> refreshPlayer(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('refreshPlayer', params);
  }

  /// 进入播放页（iOS专用）
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> enterPlayPage(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('enterPlayPage', params);
  }

  // MARK: - 短剧播放器控制方法

  /// 打开短剧选集面板（别名方法）
  /// [playerId] 播放页ID
  static Future<bool> openDramaGallery(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    // 使用已有的openEpisodePanel方法
    final result = await openEpisodePanel(playerId);
    return result['success'] == true;
  }

  /// 解锁短剧
  ///
  /// 用于自定义解锁流程（如自定义广告）完成后，主动通知原生SDK执行解锁或取消解锁。
  ///
  /// - [playerId] 播放页ID，由 `DramaPlayerController` 自动管理
  /// - [episodeId] 当前解锁的集数（可选，仅用于更新内部状态）
  /// - [lockSet] 本次解锁的集数数量（可选，默认使用配置中的 `unlockSet`）
  /// - [cancel] 是否取消解锁（默认为 `false`）
  static Future<bool> unLockDrama(
    String playerId,
    int episodeId,
    int lockSet, {
    bool cancel = false,
  }) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'playerId': playerId,
      'episodeId': episodeId,
      'lockSet': lockSet,
      'cancel': cancel,
    };

    return _invokeBool('unLockDrama', params);
  }

  /// 确认解锁短剧（用于common模式下自定义解锁弹窗）
  ///
  /// **使用场景**:
  /// 当在common模式（SDK管理广告）下，设置了 `hideRewardDialog: true` 隐藏SDK默认解锁弹窗，
  /// 并使用自定义Flutter弹窗时，用户点击"解锁短剧"按钮后调用此方法，SDK会开始播放激励广告。
  ///
  /// **工作流程**:
  /// 1. 监听 `drama_unlock_start` 事件（用户点击需要解锁的集数时触发）
  /// 2. 显示自定义的Flutter解锁弹窗（如"残忍离开"和"解锁短剧"按钮）
  /// 3. 用户点击"解锁短剧"按钮时调用此方法
  /// 4. SDK开始播放激励广告
  /// 5. 广告播放完成后自动解锁相应集数
  ///
  /// **注意事项**:
  /// - 仅在common模式（非specific自定义广告模式）下有效
  /// - 必须配置 `hideRewardDialog: true` 才能使用自定义弹窗
  /// - 与 `cancelUnlock()` 配对使用
  ///
  /// [playerId] 播放器ID
  ///
  /// **示例**:
  /// ```dart
  /// // 监听解锁事件
  /// onDramaUnlockStart: (event) {
  ///   // 显示自定义弹窗
  ///   showDialog(
  ///     context: context,
  ///     builder: (context) => AlertDialog(
  ///       title: Text('解锁提示'),
  ///       content: Text('观看广告可解锁${event.unlockCount}集'),
  ///       actions: [
  ///         TextButton(
  ///           child: Text('残忍离开'),
  ///           onPressed: () {
  ///             Navigator.pop(context);
  ///             PangrowthContent.cancelUnlock(playerId);
  ///           },
  ///         ),
  ///         TextButton(
  ///           child: Text('解锁短剧'),
  ///           onPressed: () {
  ///             Navigator.pop(context);
  ///             PangrowthContent.confirmUnlock(playerId); // 开始播放广告
  ///           },
  ///         ),
  ///       ],
  ///     ),
  ///   );
  /// },
  /// ```
  static Future<bool> confirmUnlock(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeBool('confirmUnlock', params);
  }

  /// 取消解锁短剧（用于common模式下自定义解锁弹窗）
  ///
  /// **使用场景**:
  /// 当用户在自定义解锁弹窗中点击"残忍离开"或关闭弹窗时调用此方法，
  /// 告知SDK取消本次解锁流程。
  ///
  /// **工作流程**:
  /// 1. 监听 `drama_unlock_start` 事件
  /// 2. 显示自定义Flutter解锁弹窗
  /// 3. 用户点击"残忍离开"按钮时调用此方法
  /// 4. SDK取消解锁流程，继续播放当前集数
  ///
  /// **注意事项**:
  /// - 与 `confirmUnlock()` 配对使用
  /// - 调用后SDK不会播放广告，也不会解锁集数
  ///
  /// [playerId] 播放器ID
  ///
  /// **示例**: 参见 `confirmUnlock()` 方法的示例代码
  static Future<bool> cancelUnlock(String playerId) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeBool('cancelUnlock', params);
  }

  // MARK: - 小视频控制方法

  /// 暂停小视频播放
  /// [videoId] 视频ID
  static Future<bool> pauseVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('pauseVideo', params);
  }

  /// 恢复小视频播放
  /// [videoId] 视频ID
  static Future<bool> resumeVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('resumeVideo', params);
  }

  /// 销毁短剧播放页
  /// [playerId] 播放页ID
  static Future<Map<String, dynamic>> destroyDramaPlayer(
    String playerId,
  ) async {
    if (playerId.isEmpty) {
      throw ArgumentError('playerId cannot be empty');
    }

    final Map<String, dynamic> params = {'playerId': playerId};

    return _invokeMap('destroyDramaPlayer', params);
  }

  /// 暂停短剧滑滑流播放
  /// [swipeFlowId] 滑滑流ID
  /// 通过调用原生层 Widget Fragment 的 onPause() 方法来暂停播放
  static Future<bool> pauseDramaSwipeFlow(String swipeFlowId) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {'swipeFlowId': swipeFlowId};

    return _invokeBool('pauseDramaSwipeFlow', params);
  }

  /// 恢复短剧滑滑流播放
  /// [swipeFlowId] 滑滑流ID
  /// 通过调用原生层 Widget Fragment 的 onResume() 方法来恢复播放
  static Future<bool> resumeDramaSwipeFlow(String swipeFlowId) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {'swipeFlowId': swipeFlowId};

    return _invokeBool('resumeDramaSwipeFlow', params);
  }

  /// 跳转短剧滑滑流到指定播放进度
  /// [swipeFlowId] 滑滑流ID
  /// [time] 跳转位置（毫秒）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.seekTo(time)`
  /// - ✅ iOS: `DJXDrawVideoViewController.seekVideoToMSeconds(time)`
  static Future<bool> seekToDramaSwipeFlow(String swipeFlowId, int time) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'swipeFlowId': swipeFlowId,
      'time': time,
    };

    return _invokeBool('seekToDramaSwipeFlow', params);
  }

  /// 设置短剧滑滑流当前页面位置
  /// [swipeFlowId] 滑滑流ID
  /// [position] 页面索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentPage(position)`
  /// - ❌ iOS: 无对应方法
  ///
  /// 🔵 Android 独有方法
  static Future<bool> setCurrentPageDramaSwipeFlow(
    String swipeFlowId,
    int position,
  ) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'swipeFlowId': swipeFlowId,
      'position': position,
    };

    return _invokeBool('setCurrentPageDramaSwipeFlow', params);
  }

  /// 获取短剧滑滑流当前短剧集数索引
  /// [swipeFlowId] 滑滑流ID
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.getCurrentDramaIndex()`
  /// - ❌ iOS: 无对应方法
  ///
  /// 🔵 Android 独有方法
  static Future<int> getCurrentDramaIndexDramaSwipeFlow(
    String swipeFlowId,
  ) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {'swipeFlowId': swipeFlowId};
    final result = await _invokeMap(
      'getCurrentDramaIndexDramaSwipeFlow',
      params,
    );
    return result['index'] as int? ?? -1;
  }

  /// 设置短剧滑滑流当前短剧集数索引
  /// [swipeFlowId] 滑滑流ID
  /// [index] 集数索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentDramaIndex(index)`
  /// - ✅ iOS: `DJXDrawVideoViewController.setCurrentPlayletEpisode(index)`
  static Future<bool> setCurrentDramaIndexDramaSwipeFlow(
    String swipeFlowId,
    int index,
  ) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }
    if (index < 1) {
      throw ArgumentError('index must be greater than 0');
    }

    final Map<String, dynamic> params = {
      'swipeFlowId': swipeFlowId,
      'index': index,
    };

    return _invokeBool('setCurrentDramaIndexDramaSwipeFlow', params);
  }

  /// 打开短剧滑滑流更多弹窗（举报、设置等）
  /// [swipeFlowId] 滑滑流ID
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.openMoreDialog()`
  /// - ✅ iOS: `DJXDrawVideoViewController.playletMoreButtonClick()`
  static Future<bool> openMoreDialogDramaSwipeFlow(String swipeFlowId) async {
    if (swipeFlowId.isEmpty) {
      throw ArgumentError('swipeFlowId cannot be empty');
    }

    final Map<String, dynamic> params = {'swipeFlowId': swipeFlowId};

    return _invokeBool('openMoreDialogDramaSwipeFlow', params);
  }

  // MARK: - 短故事相关方法

  /// 创建短故事聚合页
  /// 返回创建结果，包含widgetId、widgetType和success状态
  static Future<Map<String, dynamic>> createStoryHome({
    StoryHomeConfig? config,
  }) async {
    final Map<String, dynamic>? params = config == null
        ? null
        : <String, dynamic>{'config': config.toMap()};

    return _invokeMap('createStoryHome', params);
  }

  /// 展示短故事聚合页
  /// [widgetId] 聚合页组件ID，通过createStoryHome获得
  /// 返回展示结果，包含widgetId和shown状态
  static Future<Map<String, dynamic>> showStoryHome(String widgetId) async {
    if (widgetId.isEmpty) {
      throw ArgumentError('widgetId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': widgetId};

    return _invokeMap('showStoryHome', params);
  }

  /// 销毁短故事聚合页
  /// [widgetId] 聚合页组件ID
  static Future<bool> destroyStoryHome(String widgetId) async {
    if (widgetId.isEmpty) {
      throw ArgumentError('widgetId cannot be empty');
    }

    final Map<String, dynamic> params = {'widgetId': widgetId};

    return _invokeBool('destroyStoryHome', params);
  }

  // ==================== 短故事阅读器相关方法 ====================

  /// 销毁短故事阅读器
  ///
  /// [readerId] 阅读器ID
  static Future<bool> destroyStoryReader(String readerId) async {
    if (readerId.isEmpty) {
      throw ArgumentError('readerId cannot be empty');
    }

    final Map<String, dynamic> params = {'readerId': readerId};

    return _invokeBool('destroyStoryReader', params);
  }

  /// 通用调用方法(供Controller使用)
  static Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> params,
  ) async {
    return _invokeMap(method, params);
  }

  // ==================== 短故事相关方法 ====================

  /// 获取短故事分类列表
  static Future<List<Map<String, dynamic>>> getStoryCategoryList() async {
    final List<dynamic> result = await _invokeList('getStoryCategoryList');
    return result.map((item) => _castMap(item)).toList();
  }

  /// 获取短故事列表（分页）
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  /// [order] 排序方式，true为正序，false为倒序
  /// [categoryId] 分类ID，可选
  static Future<List<StoryInfo>> getStoryList({
    int? page,
    int? count,
    bool? order,
    int? categoryId,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
      'order': order,
      'categoryId': categoryId,
    });

    final List<dynamic> result = await _invokeList(
      'getStoryList',
      params.isEmpty ? null : params,
    );
    return result.map((item) => StoryInfo.fromMap(_castMap(item))).toList();
  }

  /// 搜索短故事
  /// [keyword] 搜索关键词
  /// [isFuzzy] 是否模糊搜索，默认true
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  static Future<List<StoryInfo>> searchStory(
    String keyword, {
    bool? isFuzzy,
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'keyword': keyword,
      'isFuzzy': isFuzzy,
      'page': page,
      'count': count,
    });

    final List<dynamic> result = await _invokeList(
      'searchStory',
      params.isEmpty ? null : params,
    );
    return result.map((item) => StoryInfo.fromMap(_castMap(item))).toList();
  }

  /// 获取短故事阅读历史（分页）
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  static Future<List<StoryInfo>> getStoryHistory({
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
    });

    final List<dynamic> result = await _invokeList(
      'getStoryHistory',
      params.isEmpty ? null : params,
    );
    return result.map((item) => StoryInfo.fromMap(_castMap(item))).toList();
  }

  /// 收藏短故事
  /// [storyId] 短故事ID
  /// [isFavorite] 是否收藏，默认true
  static Future<bool> favoriteStory(
    String storyId, {
    bool isFavorite = true,
  }) async {
    if (storyId.isEmpty) {
      throw ArgumentError('storyId cannot be empty');
    }

    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'storyId': storyId,
      'isFavorite': isFavorite,
    });

    return _invokeBool('favoriteStory', params);
  }

  /// 获取收藏的短故事列表（分页）
  /// [page] 页码，从1开始
  /// [count] 每页数量，默认20
  static Future<List<StoryInfo>> getFavoriteStories({
    int? page,
    int? count,
  }) async {
    final Map<String, dynamic> params = _buildParams(<String, dynamic>{
      'page': page,
      'count': count,
    });

    final List<dynamic> result = await _invokeList(
      'getFavoriteStories',
      params.isEmpty ? null : params,
    );
    return result.map((item) => StoryInfo.fromMap(_castMap(item))).toList();
  }

  /// 标记短故事为已读
  /// [storyId] 短故事ID
  static Future<bool> markAsRead(String storyId) async {
    if (storyId.isEmpty) {
      throw ArgumentError('storyId cannot be empty');
    }

    final Map<String, dynamic> params = {'storyId': storyId};

    return _invokeBool('markAsRead', params);
  }

  /// 点赞短故事
  /// [storyId] 短故事ID
  /// [isLiked] 是否点赞，默认true
  static Future<bool> likeStory(String storyId, {bool isLiked = true}) async {
    if (storyId.isEmpty) {
      throw ArgumentError('storyId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'storyId': storyId,
      'isLiked': isLiked,
    };

    return _invokeBool('likeStory', params);
  }

  /// 更新阅读进度
  /// [storyId] 短故事ID
  /// [readDuration] 阅读时长（毫秒）
  static Future<bool> updateReadProgress(
    String storyId,
    int readDuration,
  ) async {
    if (storyId.isEmpty) {
      throw ArgumentError('storyId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'storyId': storyId,
      'readDuration': readDuration,
    };

    return _invokeBool('updateReadProgress', params);
  }

  // MARK: - 小视频相关方法

  /// 创建小视频
  /// [config] 视频配置参数
  /// 返回创建结果，包含videoId和success状态
  static Future<Map<String, dynamic>> createVideo(VideoConfig config) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createVideo', params);
  }

  /// 展示小视频
  ///
  /// **参数说明**：
  /// - [videoId] 视频ID，通过createVideo获得（必填）
  /// - [containerId] 容器ID（Android专用，可选）
  ///   Android平台用于指定视频展示的容器，默认使用android.R.id.content
  /// - [presentationStyle] 展示样式（iOS专用，可选）
  ///   iOS平台用于控制页面展示方式：
  ///   - 'fullScreen' - 全屏展示
  ///   - 'pageSheet' - 卡片式弹窗
  ///   - 'formSheet' - 表单式弹窗
  ///
  /// **平台差异**：
  /// - Android: 使用Activity展示，可通过containerId指定容器
  /// - iOS: 使用ViewController展示，可通过presentationStyle控制样式
  ///
  /// **返回值**：
  /// 返回Map包含：
  /// - 'videoId': 视频ID
  /// - 'shown': 是否成功展示（布尔值）
  ///
  /// **示例**：
  /// ```dart
  /// // Android
  /// final result = await PangrowthContent.showVideo(
  ///   videoId,
  ///   containerId: android.R.id.content,
  /// );
  ///
  /// // iOS
  /// final result = await PangrowthContent.showVideo(
  ///   videoId,
  ///   presentationStyle: 'pageSheet',
  /// );
  /// ```
  static Future<Map<String, dynamic>> showVideo(
    String videoId, {
    int? containerId,
    String? presentationStyle,
  }) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    if (containerId != null) {
      params['containerId'] = containerId;
    }

    if (presentationStyle != null) {
      params['presentationStyle'] = presentationStyle;
    }

    return _invokeMap('showVideo', params);
  }

  /// 刷新小视频内容
  /// [videoId] 视频ID
  static Future<bool> refreshVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('refreshVideo', params);
  }

  /// 滚动到顶部（Android专用）
  /// [videoId] 视频ID
  static Future<bool> scrollToTop(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('scrollToTop', params);
  }

  /// 返回刷新（Android专用）
  /// [videoId] 视频ID
  static Future<bool> backRefresh(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('backRefresh', params);
  }

  /// 刷新视频来留住用户（iOS专用）
  /// [videoId] 视频ID
  static Future<bool> refreshVideoToStayUser(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('refreshVideoToStayUser', params);
  }

  /// 显示Toast留住用户（iOS专用）
  /// [videoId] 视频ID
  static Future<bool> showToastToStayUser(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('showToastToStayUser', params);
  }

  /// 设置唤醒数据
  /// [videoId] 视频ID
  /// [data] 加密的播放数据
  static Future<bool> setAwakeData(String videoId, String data) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    if (data.isEmpty) {
      throw ArgumentError('data cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId, 'data': data};

    return _invokeBool('setAwakeData', params);
  }

  /// 播放指定位置视频到指定时间点
  /// [videoId] 视频ID
  /// [position] 当前列表位置
  /// [time] 指定时间点，单位毫秒
  static Future<Map<String, dynamic>> seekToPosition(
    String videoId,
    int position,
    int time,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'videoId': videoId,
      'position': position,
      'time': time,
    };

    return _invokeMap('seekToPosition', params);
  }

  /// 设置播放特定位置的视频
  /// [videoId] 视频ID
  /// [position] 当前列表位置
  static Future<Map<String, dynamic>> setCurrentPage(
    String videoId,
    int position,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'videoId': videoId,
      'position': position,
    };

    return _invokeMap('setCurrentPage', params);
  }

  /// 设置播放数据（一起看视频功能）
  /// [videoId] 视频ID
  /// [data] 加密数据
  /// [type] 数据类型：1-刷新，2-追加
  static Future<Map<String, dynamic>> setSyncData(
    String videoId,
    String data,
    int type,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    if (data.isEmpty) {
      throw ArgumentError('data cannot be empty');
    }

    final Map<String, dynamic> params = {
      'videoId': videoId,
      'data': data,
      'type': type,
    };

    return _invokeMap('setSyncData', params);
  }

  /// 一起看视频 - 暂停播放
  /// [videoId] 视频ID
  static Future<bool> pauseForWatchTogether(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('pauseForWatchTogether', params);
  }

  /// 一起看视频 - 恢复播放
  /// [videoId] 视频ID
  static Future<bool> resumeForWatchTogether(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('resumeForWatchTogether', params);
  }

  /// 获取当前视频在列表中的位置（iOS专用）
  /// [videoId] 视频ID
  static Future<Map<String, dynamic>> getCurrentIndex(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeMap('getCurrentIndex', params);
  }

  /// 滚动到指定位置（iOS专用）
  /// [videoId] 视频ID
  /// [index] 目标位置
  static Future<Map<String, dynamic>> scrollToIndex(
    String videoId,
    int index,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId, 'index': index};

    return _invokeMap('scrollToIndex', params);
  }

  /// 暂停当前视频（iOS专用）
  /// [videoId] 视频ID
  static Future<bool> pauseCurrentVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('pauseCurrentVideo', params);
  }

  /// 播放当前视频（iOS专用）
  /// [videoId] 视频ID
  static Future<bool> playCurrentVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('playCurrentVideo', params);
  }

  /// 控制播放进度（iOS专用）
  /// [videoId] 视频ID
  /// [mSeconds] 毫秒
  static Future<Map<String, dynamic>> seekVideoToMSeconds(
    String videoId,
    double mSeconds,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {
      'videoId': videoId,
      'mSeconds': mSeconds,
    };

    return _invokeMap('seekVideoToMSeconds', params);
  }

  /// 创建举报内容页面（iOS专用）
  /// [videoId] 视频ID
  static Future<Map<String, dynamic>> createReportContent(
    String videoId,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeMap('createReportContent', params);
  }

  /// 销毁小视频
  /// [videoId] 视频ID
  static Future<bool> destroyVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('destroyVideo', params);
  }

  // MARK: - Grid Video API

  /// 创建宫格小视频
  /// [config] 宫格视频配置参数
  /// 返回创建结果，包含videoId和success状态
  static Future<Map<String, dynamic>> createGridVideo(
    GridVideoConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createGridVideo', params);
  }

  /// 创建双Feed小视频
  static Future<Map<String, dynamic>> createDoubleFeedVideo(
    GridVideoConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createDoubleFeedVideo', params);
  }

  /// 刷新宫格/双Feed小视频
  static Future<Map<String, dynamic>> refreshGridVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeMap('refreshGridVideo', {'videoId': videoId});
  }

  /// 滚动到顶部
  static Future<Map<String, dynamic>> scrollGridVideoToTop(
    String videoId,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeMap('scrollGridVideoToTop', {'videoId': videoId});
  }

  /// 返回场景挽留刷新
  static Future<Map<String, dynamic>> backRefreshGridVideo(
    String videoId,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeMap('backRefreshGridVideo', {'videoId': videoId});
  }

  /// 设置宫格/双Feed 可见性（控制暂停/恢复）
  static Future<bool> setGridVideoUserVisible(
    String videoId,
    bool isVisible,
  ) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeBool('setGridVideoUserVisible', {
      'videoId': videoId,
      'isVisible': isVisible,
    });
  }

  /// 判断返回键是否可以关闭页面
  static Future<bool> canBackPressGridVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeBool('canBackPressGridVideo', {'videoId': videoId});
  }

  /// 展示宫格小视频
  /// [videoId] 视频ID，通过createGridVideo获得
  /// [containerId] 容器ID（Android专用），默认使用android.R.id.content
  /// [presentationStyle] 展示样式（iOS专用）：'fullScreen', 'pageSheet', 'formSheet'
  /// 返回展示结果，包含videoId和shown状态
  static Future<Map<String, dynamic>> showGridVideo(
    String videoId, {
    int? containerId,
    String? presentationStyle,
  }) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    if (containerId != null) {
      params['containerId'] = containerId;
    }
    if (presentationStyle != null) {
      params['presentationStyle'] = presentationStyle;
    }

    return _invokeMap('showGridVideo', params);
  }

  /// 展示双Feed小视频
  static Future<Map<String, dynamic>> showDoubleFeedVideo(
    String videoId, {
    int? containerId,
    String? presentationStyle,
  }) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    final Map<String, dynamic> params = {'videoId': videoId};
    if (containerId != null) {
      params['containerId'] = containerId;
    }
    if (presentationStyle != null) {
      params['presentationStyle'] = presentationStyle;
    }
    return _invokeMap('showDoubleFeedVideo', params);
  }

  /// 销毁宫格小视频
  /// [videoId] 视频ID
  static Future<bool> destroyGridVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('destroyGridVideo', params);
  }

  /// 销毁双Feed小视频
  static Future<bool> destroyDoubleFeedVideo(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }
    return _invokeBool('destroyDoubleFeedVideo', {'videoId': videoId});
  }

  // MARK: - User Profile API

  /// 创建个人主页组件
  static Future<Map<String, dynamic>> createUserProfile(
    UserProfileConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createUserProfile', params);
  }

  /// 展示个人主页组件
  static Future<Map<String, dynamic>> showUserProfile(
    String profileId, {
    int? containerId,
    String? presentationStyle,
  }) async {
    if (profileId.isEmpty) {
      throw ArgumentError('profileId cannot be empty');
    }
    final Map<String, dynamic> params = {'profileId': profileId};
    if (containerId != null) {
      params['containerId'] = containerId;
    }
    if (presentationStyle != null) {
      params['presentationStyle'] = presentationStyle;
    }
    return _invokeMap('showUserProfile', params);
  }

  /// 刷新个人主页
  static Future<Map<String, dynamic>> refreshUserProfile(
    String profileId,
  ) async {
    if (profileId.isEmpty) {
      throw ArgumentError('profileId cannot be empty');
    }
    return _invokeMap('refreshUserProfile', {'profileId': profileId});
  }

  /// 返回场景挽留刷新
  static Future<Map<String, dynamic>> backRefreshUserProfile(
    String profileId,
  ) async {
    if (profileId.isEmpty) {
      throw ArgumentError('profileId cannot be empty');
    }
    return _invokeMap('backRefreshUserProfile', {'profileId': profileId});
  }

  /// 判断返回键是否可以关闭个人主页
  static Future<bool> canBackPressUserProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('profileId cannot be empty');
    }
    return _invokeBool('canBackPressUserProfile', {'profileId': profileId});
  }

  /// 销毁个人主页组件
  static Future<bool> destroyUserProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('profileId cannot be empty');
    }
    return _invokeBool('destroyUserProfile', {'profileId': profileId});
  }

  // MARK: - Video Card API

  /// 创建小视频卡片-信息流场景
  /// [config] 视频卡片配置参数
  /// 返回创建结果，包含videoId、success状态和视频信息
  static Future<Map<String, dynamic>> createVideoCardForNews(
    VideoCardConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createVideoCardForNews', params);
  }

  /// 创建小视频卡片-推荐流场景
  /// [config] 视频卡片配置参数
  /// 返回创建结果，包含videoId、success状态和视频信息
  static Future<Map<String, dynamic>> createVideoCardForRecommend(
    VideoCardConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createVideoCardForRecommend', params);
  }

  /// 创建小视频卡片-搜索场景
  /// [config] 视频卡片配置参数
  /// 返回创建结果，包含videoId、success状态和视频信息
  static Future<Map<String, dynamic>> createVideoCardForSearch(
    VideoCardConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createVideoCardForSearch', params);
  }

  /// 销毁小视频卡片
  /// [videoId] 视频ID
  static Future<bool> destroyVideoCard(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('destroyVideoCard', params);
  }

  // MARK: - Video Single Card API

  /// 创建小视频单卡片-信息流场景
  /// [config] 视频单卡片配置参数
  /// 返回创建结果，包含videoId、success状态和视频信息
  static Future<Map<String, dynamic>> createVideoSingleCardForNews(
    VideoSingleCardConfig config,
  ) async {
    final Map<String, dynamic> params = config.toMap();
    return _invokeMap('createVideoSingleCardForNews', params);
  }

  /// 销毁小视频单卡片
  /// [videoId] 视频ID
  static Future<bool> destroyVideoSingleCard(String videoId) async {
    if (videoId.isEmpty) {
      throw ArgumentError('videoId cannot be empty');
    }

    final Map<String, dynamic> params = {'videoId': videoId};

    return _invokeBool('destroyVideoSingleCard', params);
  }
}
