import 'package:flutter/foundation.dart';

import '../pangrowth_content.dart';

/// 安全地从原生 Map 转换为 `Map<String, dynamic>`
///
/// 原生层（Android/iOS）通过 EventChannel 传递的 Map 类型是 `Map<Object?, Object?>`
/// 需要安全转换为 `Map<String, dynamic>` 避免类型转换异常
Map<String, dynamic>? _safeMapConvert(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

/// 转发事件到注册的 VideoListener
void _forwardToVideoListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[VideoDebug] 🔄 转发事件: $eventType');
    debugPrint('[VideoDebug] 📦 事件数据: $data');

    // 获取 videoId
    final videoId = data['videoId'] as String?;
    if (videoId == null) {
      debugPrint('[VideoDebug] ❌ videoId 为空');
      return;
    }
    debugPrint('[VideoDebug] 🎯 videoId: $videoId');

    // 获取注册的 listener
    final videoListener = PangrowthContent.getVideoListener(videoId);
    if (videoListener == null) {
      debugPrint('[VideoDebug] ❌ 未找到 listener (videoId=$videoId)');
      return;
    }
    debugPrint('[VideoDebug] ✅ 找到 listener');

    // 根据事件类型调用对应的回调
    switch (eventType) {
      // ==================== 生命周期事件 ====================
      case 'video_created':
        videoListener.onVideoReady?.call(videoId);
        break;

      case 'video_create_failed':
      case 'video_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        videoListener.onVideoError?.call(error);
        break;

      case 'video_close':
        videoListener.onVideoClose?.call();
        break;

      case 'video_destroyed':
        videoListener.onVideoDisposed?.call();
        break;

      // ==================== 播放控制事件 ====================
      case 'video_play':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onVideoPlay?.call(extraInfo);
        break;

      case 'video_pause':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onVideoPause?.call(extraInfo);
        break;

      case 'video_continue':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onVideoContinue?.call(extraInfo);
        break;

      case 'video_completion':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onVideoCompletion?.call(extraInfo);
        break;

      case 'video_over':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onVideoOver?.call(extraInfo);
        break;

      case 'video_page_change':
        final position = data['position'] as int? ?? 0;
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onPageChange?.call(position, extraInfo);
        break;

      case 'video_seek':
        final position = data['position'] as int? ?? 0;
        final time = data['time'] as int? ?? 0;
        videoListener.onSeekTo?.call(position, time);
        break;

      // ==================== 数据请求事件 ====================
      case 'video_request_start':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onRequestStart?.call(extraInfo);
        break;

      case 'video_request_fail':
        final code = data['code'] as int? ?? -1;
        final message = data['message'] as String? ?? 'Request failed';
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onRequestFail?.call(code, message, extraInfo);
        break;

      case 'video_request_success':
        final rawList = data['list'] ?? data['data'];
        final List<Map<String, dynamic>> list = [];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
        videoListener.onRequestSuccess?.call(list);
        break;

      case 'video_refresh_complete':
        videoListener.onRefreshComplete?.call();
        break;

      // ==================== 广告事件 ====================
      case 'video_ad_request':
        videoListener.onAdRequest?.call();
        break;

      case 'video_ad_load_success':
        videoListener.onAdLoadSuccess?.call();
        break;

      case 'video_ad_load_fail':
        final errorCode =
            data['errorCode'] as int? ?? data['code'] as int? ?? -1;
        final errorMessage =
            data['errorMessage'] as String? ??
            data['message'] as String? ??
            'Ad load failed';
        videoListener.onAdLoadFail?.call(errorCode, errorMessage);
        break;

      case 'video_ad_fill_fail':
        final errorCode =
            data['errorCode'] as int? ?? data['code'] as int? ?? -1;
        final errorMessage =
            data['errorMessage'] as String? ??
            data['message'] as String? ??
            'Ad fill failed';
        videoListener.onAdFillFail?.call(errorCode, errorMessage);
        break;

      case 'video_ad_show':
        videoListener.onAdShow?.call();
        break;

      case 'video_ad_click':
        videoListener.onAdClick?.call();
        break;

      case 'video_ad_play_start':
        videoListener.onAdPlayStart?.call();
        break;

      case 'video_ad_play_pause':
        videoListener.onAdPlayPause?.call();
        break;

      case 'video_ad_play_continue':
        videoListener.onAdPlayContinue?.call();
        break;

      case 'video_ad_play_complete':
        videoListener.onAdPlayComplete?.call();
        break;

      // ==================== 交互事件 ====================
      case 'video_click_author_avatar':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onClickAuthorAvatar?.call(extraInfo);
        break;

      case 'video_click_author_name':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onClickAuthorName?.call(extraInfo);
        break;

      case 'video_click_comment':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onClickComment?.call(extraInfo);
        break;

      case 'video_click_like':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        videoListener.onClickLike?.call(extraInfo);
        break;

      case 'video_report_result':
        final success = data['success'] as bool? ?? false;
        final message = data['message'] as String?;
        videoListener.onReportResult?.call(success, message);
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[VideoDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 GridVideoListener
void _forwardToGridVideoListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[GridVideoDebug] 🔄 转发事件: $eventType');

    // 获取 gridId
    final gridId = data['gridId'] as String?;
    if (gridId == null) {
      debugPrint('[GridVideoDebug] ❌ gridId 为空');
      return;
    }

    // 获取注册的 listener
    final gridVideoListener = PangrowthContent.getGridVideoListener(gridId);
    if (gridVideoListener == null) {
      debugPrint('[GridVideoDebug] ❌ 未找到 listener (gridId=$gridId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      // ==================== 生命周期事件 ====================
      case 'grid_video_created':
        gridVideoListener.onGridReady?.call(gridId);
        break;

      case 'grid_video_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        gridVideoListener.onGridError?.call(error);
        break;

      case 'grid_video_destroyed':
        gridVideoListener.onGridDisposed?.call();
        break;

      // ==================== 播放控制事件 ====================
      case 'grid_video_play':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onVideoPlay?.call(extraInfo);
        break;

      case 'grid_video_pause':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onVideoPause?.call(extraInfo);
        break;

      case 'grid_video_continue':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onVideoContinue?.call(extraInfo);
        break;

      case 'grid_video_completion':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onVideoCompletion?.call(extraInfo);
        break;

      case 'grid_video_over':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onVideoOver?.call(extraInfo);
        break;

      // ==================== 交互事件 ====================
      case 'grid_video_item_click':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onItemClick?.call(extraInfo);
        break;

      case 'grid_video_item_show':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onItemShow?.call(extraInfo);
        break;

      case 'grid_video_click_author_avatar':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onClickAuthorAvatar?.call(extraInfo);
        break;

      case 'grid_video_click_author_name':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onClickAuthorName?.call(extraInfo);
        break;

      case 'grid_video_click_comment':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onClickComment?.call(extraInfo);
        break;

      case 'grid_video_click_like':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onClickLike?.call(extraInfo);
        break;

      // ==================== 数据请求事件 ====================
      case 'grid_video_request_start':
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onRequestStart?.call(extraInfo);
        break;

      case 'grid_video_request_fail':
        final code = data['code'] as int? ?? -1;
        final message = data['message'] as String? ?? 'Request failed';
        final extraInfo = data['extra'] as Map<String, dynamic>?;
        gridVideoListener.onRequestFail?.call(code, message, extraInfo);
        break;

      case 'grid_video_request_success':
        final rawList = data['list'] ?? data['data'];
        final List<Map<String, dynamic>> list = [];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
        gridVideoListener.onRequestSuccess?.call(list);
        break;

      case 'grid_video_refresh_complete':
        gridVideoListener.onRefreshComplete?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[GridVideoDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 DramaCardListener
void _forwardToCardListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[DramaCardDebug] 🔄 转发事件: $eventType');

    // 获取 cardId
    final cardId = data['cardId'] as String?;
    if (cardId == null) {
      debugPrint('[DramaCardDebug] ❌ cardId 为空');
      return;
    }

    // 获取注册的 listener
    final cardListener = PangrowthContent.getDramaCardListener(cardId);
    if (cardListener == null) {
      debugPrint('[DramaCardDebug] ❌ 未找到 listener (cardId=$cardId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'card_created':
      case 'card_ready':
        cardListener.onCardReady?.call(cardId);
        break;

      case 'card_create_failed':
      case 'card_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        cardListener.onCardError?.call(error);
        break;

      case 'card_data_loaded':
        final dramaData = data['drama'] as Map<String, dynamic>?;
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        cardListener.onDataLoaded?.call(dramaInfo);
        break;

      case 'card_clicked':
        final dramaData = data['drama'] as Map<String, dynamic>?;
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        cardListener.onCardClicked?.call(dramaInfo);
        break;

      case 'card_playback_state_changed':
        final isPlaying = data['isPlaying'] as bool? ?? false;
        // ignore: deprecated_member_use_from_same_package
        // 保持向后兼容：原生SDK仍在使用该事件，待原生SDK更新后再移除
        cardListener.onPlaybackStateChanged?.call(isPlaying);
        break;

      case 'card_destroyed':
        cardListener.onCardDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[DramaCardDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 DramaSwipeFlowListener
void _forwardToSwipeFlowListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[DramaSwipeFlowDebug] 🔄 转发事件: $eventType');

    // 获取 swipeFlowId
    final swipeFlowId = data['swipeFlowId'] as String?;
    if (swipeFlowId == null) {
      debugPrint('[DramaSwipeFlowDebug] ❌ swipeFlowId 为空');
      return;
    }

    // 获取注册的 listener
    final swipeFlowListener = PangrowthContent.getDramaSwipeFlowListener(
      swipeFlowId,
    );
    if (swipeFlowListener == null) {
      debugPrint(
        '[DramaSwipeFlowDebug] ❌ 未找到 listener (swipeFlowId=$swipeFlowId)',
      );
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'swipe_flow_created':
      case 'swipe_flow_ready':
        swipeFlowListener.onSwipeFlowReady?.call(swipeFlowId);
        break;

      case 'swipe_flow_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        swipeFlowListener.onSwipeFlowError?.call(error);
        break;

      case 'swipe_flow_open_detail':
        final dramaData = data['drama'] as Map<String, dynamic>?;
        if (dramaData != null) {
          final dramaInfo = DramaInfo.fromMap(dramaData);
          swipeFlowListener.onOpenDetail?.call(dramaInfo);
        }
        break;

      case 'swipe_flow_destroyed':
        swipeFlowListener.onSwipeFlowDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[DramaSwipeFlowDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 UserProfileListener
void _forwardToUserProfileListener(
  String eventType,
  Map<String, dynamic> data,
) {
  try {
    debugPrint('[UserProfileDebug] 🔄 转发事件: $eventType');

    // 获取 profileId
    final profileId = data['profileId'] as String?;
    if (profileId == null) {
      debugPrint('[UserProfileDebug] ❌ profileId 为空');
      return;
    }

    // 获取注册的 listener
    final profileListener = PangrowthContent.getUserProfileListener(profileId);
    if (profileListener == null) {
      debugPrint('[UserProfileDebug] ❌ 未找到 listener (profileId=$profileId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'user_profile_created':
      case 'user_profile_ready':
        profileListener.onProfileReady?.call(profileId);
        break;

      case 'user_profile_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        profileListener.onProfileError?.call(error);
        break;

      case 'user_profile_destroyed':
        profileListener.onProfileDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[UserProfileDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 DramaHomeListener
void _forwardToDramaHomeListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[DramaHomeDebug] 🔄 转发事件: $eventType');

    // 获取 widgetId (DramaHome使用widgetId而不是homeId)
    final widgetId = data['widgetId'] as String?;
    if (widgetId == null) {
      debugPrint('[DramaHomeDebug] ❌ widgetId 为空');
      return;
    }

    // 获取注册的 listener
    final homeListener = PangrowthContent.getDramaHomeListener(widgetId);
    if (homeListener == null) {
      debugPrint('[DramaHomeDebug] ❌ 未找到 listener (widgetId=$widgetId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'drama_home_created':
      case 'drama_home_ready':
        homeListener.onHomeReady?.call(widgetId);
        break;

      case 'drama_home_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        homeListener.onHomeError?.call(error);
        break;

      case 'drama_home_item_click':
        final dramaData = data['drama'] as Map<String, dynamic>?;
        if (dramaData != null) {
          final dramaInfo = DramaInfo.fromMap(dramaData);
          final extraInfo = _safeMapConvert(data['extra']);
          homeListener.onItemClick?.call(dramaInfo, extraInfo);
        }
        break;

      case 'drama_home_search':
        final keyword = data['keyword'] as String? ?? '';
        homeListener.onSearch?.call(keyword);
        break;

      case 'drama_home_category_switch':
        final category = data['category'] as String? ?? '';
        homeListener.onCategorySwitch?.call(category);
        break;

      case 'drama_home_destroyed':
        homeListener.onHomeDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[DramaHomeDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 StoryHomeListener
void _forwardToStoryHomeListener(String eventType, Map<String, dynamic> data) {
  try {
    debugPrint('[StoryHomeDebug] 🔄 转发事件: $eventType');

    // 获取 widgetId
    final widgetId = data['widgetId'] as String?;
    if (widgetId == null) {
      debugPrint('[StoryHomeDebug] ❌ widgetId 为空');
      return;
    }

    // 获取注册的 listener
    final storyHomeListener = PangrowthContent.getStoryHomeListener(widgetId);
    if (storyHomeListener == null) {
      debugPrint('[StoryHomeDebug] ❌ 未找到 listener (widgetId=$widgetId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'story_home_created':
      case 'story_home_ready':
        storyHomeListener.onStoryHomeReady?.call(widgetId);
        break;

      case 'story_home_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        storyHomeListener.onStoryHomeError?.call(error);
        break;

      case 'story_home_item_click':
        final storyData = data['story'] as Map<String, dynamic>?;
        if (storyData != null) {
          final storyInfo = StoryInfo.fromMap(storyData);
          storyHomeListener.onItemClick?.call(storyInfo);
        }
        break;

      case 'story_home_destroyed':
        storyHomeListener.onStoryHomeDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[StoryHomeDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 StoryReaderListener
void _forwardToStoryReaderListener(
  String eventType,
  Map<String, dynamic> data,
) {
  try {
    debugPrint('[StoryReaderDebug] 🔄 转发事件: $eventType');

    // 获取 readerId
    final readerId = data['readerId'] as String?;
    if (readerId == null) {
      debugPrint('[StoryReaderDebug] ❌ readerId 为空');
      return;
    }

    // 获取注册的 listener
    final readerListener = PangrowthContent.getStoryReaderListener(readerId);
    if (readerListener == null) {
      debugPrint('[StoryReaderDebug] ❌ 未找到 listener (readerId=$readerId)');
      return;
    }

    // 根据事件类型调用对应的回调
    switch (eventType) {
      case 'story_reader_created':
      case 'story_reader_ready':
        readerListener.onReaderReady?.call(readerId);
        break;

      case 'story_reader_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        readerListener.onReaderError?.call(error);
        break;

      case 'story_reader_chapter_changed':
        final chapter = data['chapter'] as int? ?? 0;
        readerListener.onChapterChanged?.call(chapter);
        break;

      case 'story_reader_progress_changed':
        final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        readerListener.onProgressChanged?.call(progress);
        break;

      case 'story_reader_favorite_changed':
        final isFavorite = data['isFavorite'] as bool? ?? false;
        readerListener.onFavoriteChanged?.call(isFavorite);
        break;

      case 'story_reader_middle_page_ad_show':
        readerListener.onMiddlePageAdShow?.call();
        break;

      case 'story_reader_middle_page_ad_click':
        readerListener.onMiddlePageAdClick?.call();
        break;

      case 'story_reader_middle_page_ad_close':
        readerListener.onMiddlePageAdClose?.call();
        break;

      case 'story_reader_middle_line_ad_show':
        final lineNumber = data['lineNumber'] as int? ?? 0;
        readerListener.onMiddleLineAdShow?.call(lineNumber);
        break;

      case 'story_reader_middle_line_ad_click':
        readerListener.onMiddleLineAdClick?.call();
        break;

      case 'story_reader_banner_ad_show':
        readerListener.onBannerAdShow?.call();
        break;

      case 'story_reader_banner_ad_click':
        readerListener.onBannerAdClick?.call();
        break;

      case 'story_reader_destroyed':
        readerListener.onReaderDisposed?.call();
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[StoryReaderDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 转发事件到注册的 DramaPlayerListener
void _forwardToDramaPlayerListener(
  String eventType,
  Map<String, dynamic> data,
) {
  try {
    debugPrint('[DramaPlayerDebug] 🔄 转发事件: $eventType');
    debugPrint('[DramaPlayerDebug] 📦 事件数据: $data');

    // 获取 playerId
    final playerId = data['playerId'] as String?;
    if (playerId == null) {
      debugPrint('[DramaPlayerDebug] ❌ playerId 为空');
      return;
    }
    debugPrint('[DramaPlayerDebug] 🎯 playerId: $playerId');

    // 获取注册的 listener
    final dramaPlayerListener = PangrowthContent.getDramaPlayerListener(
      playerId,
    );
    if (dramaPlayerListener == null) {
      debugPrint('[DramaPlayerDebug] ❌ 未找到 listener (playerId=$playerId)');
      return;
    }
    debugPrint('[DramaPlayerDebug] ✅ 找到 listener');

    // 根据事件类型调用对应的回调
    switch (eventType) {
      // ==================== 生命周期事件 ====================
      case 'drama_player_created':
        dramaPlayerListener.onPlayerReady?.call(playerId);
        break;

      case 'drama_player_create_failed':
      case 'sdk_error':
        final error =
            data['error'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        dramaPlayerListener.onPlayerError?.call(error);
        break;

      case 'drama_close':
        dramaPlayerListener.onPlayerClose?.call();
        break;

      case 'drama_player_destroyed':
        dramaPlayerListener.onPlayerDisposed?.call();
        break;

      // ==================== 播放控制事件 ====================
      case 'drama_video_start_play':
        final dramaData = _safeMapConvert(data['drama']);
        final extraInfo = _safeMapConvert(data['extra']);
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        dramaPlayerListener.onVideoStart?.call(dramaInfo, extraInfo);
        break;

      case 'drama_video_over_play':
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onVideoOverPlay?.call(extraInfo);
        break;

      case 'drama_video_pause':
        debugPrint('[DramaPlayerDebug] 📞 调用 onVideoPause');
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onVideoPause?.call(extraInfo);
        break;

      case 'drama_video_continue':
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onVideoContinue?.call(extraInfo);
        break;

      case 'drama_video_completion':
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onVideoCompletion?.call(extraInfo);
        break;

      case 'drama_video_seek':
        final position = data['position'] as int? ?? 0;
        final time = data['time'] as int? ?? 0;
        dramaPlayerListener.onSeekTo?.call(position, time);
        break;

      case 'drama_duration_change':
        final current = data['current'] as int? ?? 0;
        dramaPlayerListener.onDurationChange?.call(current);
        break;

      case 'drama_video_progress':
        final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        final dramaData = _safeMapConvert(data['drama']);
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        dramaPlayerListener.onVideoProgress?.call(progress, dramaInfo);
        break;

      // ==================== 集数与短剧切换 ====================
      case 'drama_page_change':
        final position = data['position'] as int? ?? 0;
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        // 兼容旧的onEpisodeChange回调
        final episode = extraInfo['index'] as int? ?? position;
        dramaPlayerListener.onPageChange?.call(position, extraInfo);
        // ignore: deprecated_member_use_from_same_package
        dramaPlayerListener.onEpisodeChange?.call(episode);
        break;

      case 'drama_episode_change':
        // 旧的单纯的集数切换事件,现在推荐使用drama_page_change
        final episode = data['episode'] as int?;
        if (episode != null) {
          // ignore: deprecated_member_use_from_same_package
          dramaPlayerListener.onEpisodeChange?.call(episode);
        }
        break;

      case 'drama_switch':
        final dramaData = _safeMapConvert(data['drama']);
        if (dramaData != null) {
          final dramaInfo = DramaInfo.fromMap(dramaData);
          dramaPlayerListener.onDramaSwitch?.call(dramaInfo);
        }
        break;

      case 'drama_gallery_show':
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        dramaPlayerListener.onDramaGalleryShow?.call(extraInfo);
        break;

      case 'drama_gallery_click':
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        dramaPlayerListener.onDramaGalleryClick?.call(extraInfo);
        break;

      case 'drama_click_enter':
        final dramaData = _safeMapConvert(data['drama']);
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        dramaPlayerListener.onClickEnter?.call(dramaInfo);
        break;

      case 'drama_next_will_play':
      case 'drama_next_playlet':
        final dramaData = _safeMapConvert(data['drama']);
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        dramaPlayerListener.onNextPlayletWillPlay?.call(dramaInfo);
        break;

      // ==================== 解锁流程事件 ====================
      case 'drama_unlock_start':
        debugPrint('[DramaPlayerDebug] 📞 调用 onUnlockStart');
        final dramaData = _safeMapConvert(data['drama']);
        final extraInfo = _safeMapConvert(data['extra']);

        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }

        // ✅ 传递完整的extraInfo参数,保持与原生SDK一致的1:1结构
        dramaPlayerListener.onUnlockStart?.call(dramaInfo, extraInfo);
        break;

      case 'drama_unlock_end':
        // success 在 data 顶层,不在 extra 中
        final success = data['success'] as bool? ?? false;
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onUnlockEnd?.call(success, extraInfo);
        break;

      case 'drama_show_custom_ad':
        final dramaData = _safeMapConvert(data['drama']);
        DramaInfo? dramaInfo;
        if (dramaData != null) {
          dramaInfo = DramaInfo.fromMap(dramaData);
        }
        dramaPlayerListener.onShowCustomAd?.call(dramaInfo);
        break;

      case 'drama_reward_dialog_show':
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        dramaPlayerListener.onRewardDialogShow?.call(extraInfo);
        break;

      case 'drama_unlock_dialog_action':
        final action = data['action'] as String? ?? '';
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        dramaPlayerListener.onUnlockDialogAction?.call(action, extraInfo);
        break;

      // ==================== 广告事件 ====================
      case 'drama_ad_request':
        dramaPlayerListener.onAdRequest?.call();
        break;

      case 'drama_ad_load_success':
        dramaPlayerListener.onAdLoadSuccess?.call();
        break;

      case 'drama_ad_load_fail':
        final errorCode =
            data['errorCode'] as int? ?? data['code'] as int? ?? -1;
        final errorMessage =
            data['errorMessage'] as String? ??
            data['message'] as String? ??
            'Unknown error';
        dramaPlayerListener.onAdLoadFail?.call(errorCode, errorMessage);
        break;

      case 'drama_ad_fill_fail':
        final errorCode =
            data['errorCode'] as int? ?? data['code'] as int? ?? -1;
        final errorMessage =
            data['errorMessage'] as String? ??
            data['message'] as String? ??
            'Ad fill failed';
        dramaPlayerListener.onAdFillFail?.call(errorCode, errorMessage);
        break;

      case 'drama_ad_show':
        dramaPlayerListener.onAdShow?.call();
        break;

      case 'drama_ad_click':
        dramaPlayerListener.onAdClick?.call();
        break;

      case 'drama_ad_play_start':
        dramaPlayerListener.onAdPlayStart?.call();
        break;

      case 'drama_ad_play_pause':
        dramaPlayerListener.onAdPlayPause?.call();
        break;

      case 'drama_ad_play_continue':
        dramaPlayerListener.onAdPlayContinue?.call();
        break;

      case 'drama_ad_play_finish':
      case 'drama_ad_play_complete':
        dramaPlayerListener.onAdPlayComplete?.call();
        break;

      case 'drama_ad_reward_finish':
        dramaPlayerListener.onAdRewardFinish?.call();
        break;

      case 'drama_ad_reward_skip':
        dramaPlayerListener.onAdSkip?.call();
        break;

      case 'drama_ad_buffer':
        dramaPlayerListener.onAdBuffer?.call();
        break;

      // ==================== 数据请求事件 ====================
      case 'drama_request_start':
        final extraInfo = _safeMapConvert(data['extra']) ?? data;
        dramaPlayerListener.onRequestStart?.call(extraInfo);
        break;

      case 'drama_request_fail':
        final code = data['code'] as int? ?? -1;
        final message = data['message'] as String? ?? 'Request failed';
        final extraInfo = _safeMapConvert(data['extra']);
        dramaPlayerListener.onRequestFail?.call(code, message, extraInfo);
        break;

      case 'drama_request_success':
        final rawList = data['list'] ?? data['data'];
        final List<Map<String, dynamic>> list = [];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
        dramaPlayerListener.onRequestSuccess?.call(list);
        break;

      default:
        // 其他事件暂不处理
        break;
    }
  } catch (e) {
    debugPrint('[DramaPlayerDebug] ❌ 转发事件失败: $e');
    // 转发失败不影响主流程
  }
}

/// 处理内容事件
///
/// 直接转发到对应的专用Listener (DramaPlayerListener, VideoListener等)
void handleContentEvent(Map<String, dynamic> data) {
  try {
    // 原生端发送的是 'type' 字段
    final String eventType = data['type'] as String? ?? 'unknown';
    debugPrint('[ContentEvent] 📥 收到事件: $eventType');

    // 根据事件类型转发到对应的Listener
    switch (eventType) {
      // 短剧播放页事件 - 转发到DramaPlayerListener
      case 'drama_player_created':
      case 'drama_player_create_failed':
      case 'sdk_error':
      case 'drama_player_shown':
      case 'drama_player_hidden':
      case 'drama_player_destroyed':
      case 'drama_video_start_play':
      case 'drama_video_over_play':
      case 'drama_video_pause':
      case 'drama_video_continue':
      case 'drama_video_completion':
      case 'drama_video_seek':
      case 'drama_duration_change':
      case 'drama_video_progress':
      case 'drama_page_change':
      case 'drama_episode_change':
      case 'drama_close':
      case 'drama_switch':
      case 'drama_gallery_show':
      case 'drama_gallery_click':
      case 'drama_click_enter':
      case 'drama_next_will_play':
      case 'drama_next_playlet':
      case 'drama_unlock_start':
      case 'drama_unlock_end':
      case 'drama_show_custom_ad':
      case 'drama_reward_dialog_show':
      case 'drama_unlock_dialog_action':
      case 'drama_ad_request':
      case 'drama_ad_load_success':
      case 'drama_ad_load_fail':
      case 'drama_ad_fill_fail':
      case 'drama_ad_show':
      case 'drama_ad_click':
      case 'drama_ad_play_start':
      case 'drama_ad_play_pause':
      case 'drama_ad_play_continue':
      case 'drama_ad_play_finish':
      case 'drama_ad_play_complete':
      case 'drama_ad_reward_finish':
      case 'drama_ad_reward_skip':
      case 'drama_ad_buffer':
      case 'drama_request_start':
      case 'drama_request_fail':
      case 'drama_request_success':
        debugPrint('[ContentEvent] 🎮 转发到 DramaPlayerListener');
        _forwardToDramaPlayerListener(eventType, data);
        break;

      // Video事件 - 转发到VideoListener
      case 'video_created':
      case 'video_create_failed':
      case 'video_error':
      case 'video_close':
      case 'video_destroyed':
      case 'video_play':
      case 'video_pause':
      case 'video_continue':
      case 'video_completion':
      case 'video_over':
      case 'video_page_change':
      case 'video_seek':
      case 'video_request_start':
      case 'video_request_fail':
      case 'video_request_success':
      case 'video_refresh_complete':
      case 'video_ad_request':
      case 'video_ad_load_success':
      case 'video_ad_load_fail':
      case 'video_ad_fill_fail':
      case 'video_ad_show':
      case 'video_ad_click':
      case 'video_ad_play_start':
      case 'video_ad_play_pause':
      case 'video_ad_play_continue':
      case 'video_ad_play_complete':
      case 'video_click_author_avatar':
      case 'video_click_author_name':
      case 'video_click_comment':
      case 'video_click_like':
      case 'video_report_result':
        debugPrint('[ContentEvent] 🎬 转发到 VideoListener');
        _forwardToVideoListener(eventType, data);
        break;

      // GridVideo事件 - 转发到GridVideoListener
      case 'grid_video_created':
      case 'grid_video_error':
      case 'grid_video_destroyed':
      case 'grid_video_play':
      case 'grid_video_pause':
      case 'grid_video_continue':
      case 'grid_video_completion':
      case 'grid_video_over':
      case 'grid_video_item_click':
      case 'grid_video_item_show':
      case 'grid_video_click_author_avatar':
      case 'grid_video_click_author_name':
      case 'grid_video_click_comment':
      case 'grid_video_click_like':
      case 'grid_video_request_start':
      case 'grid_video_request_fail':
      case 'grid_video_request_success':
      case 'grid_video_refresh_complete':
        debugPrint('[ContentEvent] 📱 转发到 GridVideoListener');
        _forwardToGridVideoListener(eventType, data);
        break;

      // DramaCard事件 - 转发到DramaCardListener
      case 'card_created':
      case 'card_ready':
      case 'card_create_failed':
      case 'card_error':
      case 'card_data_loaded':
      case 'card_clicked':
      case 'card_playback_state_changed':
      case 'card_destroyed':
        debugPrint('[ContentEvent] 🎴 转发到 DramaCardListener');
        _forwardToCardListener(eventType, data);
        break;

      // DramaSwipeFlow事件 - 转发到DramaSwipeFlowListener
      case 'swipe_flow_created':
      case 'swipe_flow_ready':
      case 'swipe_flow_error':
      case 'swipe_flow_open_detail':
      case 'swipe_flow_destroyed':
        debugPrint('[ContentEvent] 🌊 转发到 DramaSwipeFlowListener');
        _forwardToSwipeFlowListener(eventType, data);
        break;

      // UserProfile事件 - 转发到UserProfileListener
      case 'user_profile_created':
      case 'user_profile_ready':
      case 'user_profile_error':
      case 'user_profile_destroyed':
        debugPrint('[ContentEvent] 👤 转发到 UserProfileListener');
        _forwardToUserProfileListener(eventType, data);
        break;

      // DramaHome事件 - 转发到DramaHomeListener
      case 'drama_home_created':
      case 'drama_home_ready':
      case 'drama_home_error':
      case 'drama_home_item_click':
      case 'drama_home_search':
      case 'drama_home_category_switch':
      case 'drama_home_destroyed':
        debugPrint('[ContentEvent] 🏠 转发到 DramaHomeListener');
        _forwardToDramaHomeListener(eventType, data);
        break;

      // StoryHome事件 - 转发到StoryHomeListener
      case 'story_home_created':
      case 'story_home_ready':
      case 'story_home_error':
      case 'story_home_item_click':
      case 'story_home_destroyed':
        debugPrint('[ContentEvent] 📚 转发到 StoryHomeListener');
        _forwardToStoryHomeListener(eventType, data);
        break;

      // StoryReader事件 - 转发到StoryReaderListener
      case 'story_reader_created':
      case 'story_reader_ready':
      case 'story_reader_error':
      case 'story_reader_chapter_changed':
      case 'story_reader_progress_changed':
      case 'story_reader_favorite_changed':
      case 'story_reader_middle_page_ad_show':
      case 'story_reader_middle_page_ad_click':
      case 'story_reader_middle_page_ad_close':
      case 'story_reader_middle_line_ad_show':
      case 'story_reader_middle_line_ad_click':
      case 'story_reader_banner_ad_show':
      case 'story_reader_banner_ad_click':
      case 'story_reader_destroyed':
        debugPrint('[ContentEvent] 📖 转发到 StoryReaderListener');
        _forwardToStoryReaderListener(eventType, data);
        break;

      default:
        debugPrint('[ContentEvent] ⚠️ 未处理的事件类型: $eventType');
        break;
    }
  } catch (e, stackTrace) {
    debugPrint('[ContentEvent] ❌ 处理事件失败: $e');
    debugPrint('[ContentEvent] 堆栈: $stackTrace');
  }
}
