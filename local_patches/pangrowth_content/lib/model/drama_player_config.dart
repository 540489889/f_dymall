/// 短剧播放页配置模型
class DramaPlayerConfig {
  /// 短剧ID（必填）
  final int dramaId;

  /// 播放集数（必填，默认从第1集开始）
  final int episode;

  /// 解锁广告模式
  /// 'common' - SDK广告（默认）
  /// 'specific' - 开发者自定义广告
  final String adMode;

  /// 免费集数（默认5集）
  final int? freeSet;

  /// 每次解锁的集数（默认10集）
  final int? unlockSet;

  /// 当前播放进度（毫秒）
  final int? currentDuration;

  /// 入口视频Gid（用于推荐算法）
  final String? fromGid;

  /// 详情页入口来源
  /// 'default', 'skit_mixed', 'drama_home_recently_watched',
  /// 'drama_home', 'drama_history', 'drama_card'
  final String? fromSource;

  /// 推荐埋点参数
  final Map<String, dynamic>? recMap;

  /// UI配置 - 是否隐藏SDK的解锁弹窗
  final bool? hideRewardDialog;

  /// UI配置 - 是否隐藏返回按钮
  final bool? hideBack;

  /// UI配置 - 是否隐藏顶部集数信息
  final bool? hideTopInfo;

  /// UI配置 - 是否隐藏底部信息
  final bool? hideBottomInfo;

  /// UI配置 - 是否隐藏更多按钮
  final bool? hideMore;

  /// UI配置 - 是否隐藏点赞按钮
  final bool? hideLikeIcon;

  /// UI配置 - 是否隐藏收藏按钮
  final bool? hideCollectIcon;

  /// UI配置 - 是否支持无限下滑（默认true）
  final bool? infiniteScrollEnabled;

  /// UI配置 - 是否关闭无限滚动功能
  final bool? closeInfiniteScroll;

  /// UI配置 - 是否隐藏流量播放提醒Toast
  final bool? hideCellularToast;

  /// UI配置 - 是否禁用双击点赞
  final bool? disableDoubleClickLike;

  /// UI配置 - 底部间距（dp）
  final int? bottomOffset;

  /// UI配置 - 顶部间距（dp）
  final int? topOffset;

  /// UI配置 - 改编小说提示文案顶部间距（dp）
  final int? scriptTipsTopMargin;

  /// UI配置 - 来源信息上边距（iOS专用）
  final double? fromTopMargin;

  /// 播放配置 - 起播时间点（秒，iOS专用）
  final double? playStartTime;

  /// 展示配置 - 弹窗展示样式（iOS专用）
  /// 'fullScreen', 'pageSheet', 'formSheet'
  final String? presentationStyle;

  /// 容器ID（Android专用，Fragment容器）
  final int? containerId;

  /// 自定义广告配置 - Draw广告插入位置数组
  ///
  /// 例如: [3, 6, 9] 表示在第3、6、9个位置插入Draw广告
  /// 仅在提供customDrawAdViewId时生效
  final List<int>? drawAdPositions;

  /// 自定义广告配置 - Draw广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 配合drawAdPositions使用,插入自定义的竖版视频广告
  final String? customDrawAdViewId;

  /// 自定义广告配置 - Banner广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 用于在播放页底部显示自定义Banner广告
  final String? customBannerAdViewId;

  const DramaPlayerConfig({
    required this.dramaId,
    this.episode = 1,
    this.adMode = 'common',
    this.freeSet,
    this.unlockSet,
    this.currentDuration,
    this.fromGid,
    this.fromSource,
    this.recMap,
    this.hideRewardDialog,
    this.hideBack,
    this.hideTopInfo,
    this.hideBottomInfo,
    this.hideMore,
    this.hideLikeIcon,
    this.hideCollectIcon,
    this.infiniteScrollEnabled,
    this.closeInfiniteScroll,
    this.hideCellularToast,
    this.disableDoubleClickLike,
    this.bottomOffset,
    this.topOffset,
    this.scriptTipsTopMargin,
    this.fromTopMargin,
    this.playStartTime,
    this.presentationStyle,
    this.containerId,
    this.drawAdPositions,
    this.customDrawAdViewId,
    this.customBannerAdViewId,
  });

  /// 从Map创建配置
  factory DramaPlayerConfig.fromMap(Map<String, dynamic> map) {
    return DramaPlayerConfig(
      dramaId: map['dramaId'] as int,
      episode: map['episode'] as int? ?? 1,
      adMode: map['adMode'] as String? ?? 'common',
      freeSet: map['freeSet'] as int?,
      unlockSet: map['unlockSet'] as int?,
      currentDuration: map['currentDuration'] as int?,
      fromGid: map['fromGid'] as String?,
      fromSource: map['fromSource'] as String?,
      recMap: map['recMap'] as Map<String, dynamic>?,
      hideRewardDialog: map['hideRewardDialog'] as bool?,
      hideBack: map['hideBack'] as bool?,
      hideTopInfo: map['hideTopInfo'] as bool?,
      hideBottomInfo: map['hideBottomInfo'] as bool?,
      hideMore: map['hideMore'] as bool?,
      hideLikeIcon: map['hideLikeIcon'] as bool?,
      hideCollectIcon: map['hideCollectIcon'] as bool?,
      infiniteScrollEnabled: map['infiniteScrollEnabled'] as bool?,
      closeInfiniteScroll: map['closeInfiniteScroll'] as bool?,
      hideCellularToast: map['hideCellularToast'] as bool?,
      disableDoubleClickLike: map['disableDoubleClickLike'] as bool?,
      bottomOffset: map['bottomOffset'] as int?,
      topOffset: map['topOffset'] as int?,
      scriptTipsTopMargin: map['scriptTipsTopMargin'] as int?,
      fromTopMargin: map['fromTopMargin'] as double?,
      playStartTime: map['playStartTime'] as double?,
      presentationStyle: map['presentationStyle'] as String?,
      containerId: map['containerId'] as int?,
      drawAdPositions: map['drawAdPositions'] != null
          ? List<int>.from(map['drawAdPositions'] as List)
          : null,
      customDrawAdViewId: map['customDrawAdViewId'] as String?,
      customBannerAdViewId: map['customBannerAdViewId'] as String?,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    // 必填参数
    map['dramaId'] = dramaId;
    map['episode'] = episode;
    map['adMode'] = adMode;

    // 可选参数 - 只有非null的才添加
    if (freeSet != null) map['freeSet'] = freeSet;
    if (unlockSet != null) map['unlockSet'] = unlockSet;
    if (currentDuration != null) map['currentDuration'] = currentDuration;
    if (fromGid != null) map['fromGid'] = fromGid;
    if (fromSource != null) map['fromSource'] = fromSource;
    if (recMap != null) map['recMap'] = recMap;

    // UI配置参数
    if (hideRewardDialog != null) map['hideRewardDialog'] = hideRewardDialog;
    if (hideBack != null) map['hideBack'] = hideBack;
    if (hideTopInfo != null) map['hideTopInfo'] = hideTopInfo;
    if (hideBottomInfo != null) map['hideBottomInfo'] = hideBottomInfo;
    if (hideMore != null) map['hideMore'] = hideMore;
    if (hideLikeIcon != null) map['hideLikeIcon'] = hideLikeIcon;
    if (hideCollectIcon != null) map['hideCollectIcon'] = hideCollectIcon;
    if (infiniteScrollEnabled != null)
      map['infiniteScrollEnabled'] = infiniteScrollEnabled;
    if (closeInfiniteScroll != null)
      map['closeInfiniteScroll'] = closeInfiniteScroll;
    if (hideCellularToast != null) map['hideCellularToast'] = hideCellularToast;
    if (disableDoubleClickLike != null)
      map['disableDoubleClickLike'] = disableDoubleClickLike;

    // 间距配置参数
    if (bottomOffset != null) map['bottomOffset'] = bottomOffset;
    if (topOffset != null) map['topOffset'] = topOffset;
    if (scriptTipsTopMargin != null)
      map['scriptTipsTopMargin'] = scriptTipsTopMargin;
    if (fromTopMargin != null) map['fromTopMargin'] = fromTopMargin;

    // 播放配置参数
    if (playStartTime != null) map['playStartTime'] = playStartTime;

    // 展示配置参数
    if (presentationStyle != null) map['presentationStyle'] = presentationStyle;
    if (containerId != null) map['containerId'] = containerId;

    // 自定义广告参数
    if (drawAdPositions != null && drawAdPositions!.isNotEmpty) {
      map['drawAdPositions'] = drawAdPositions;
    }
    if (customDrawAdViewId != null)
      map['customDrawAdViewId'] = customDrawAdViewId;
    if (customBannerAdViewId != null)
      map['customBannerAdViewId'] = customBannerAdViewId;

    return map;
  }

  /// 复制配置（可修改部分参数）
  DramaPlayerConfig copyWith({
    int? dramaId,
    int? episode,
    String? adMode,
    int? freeSet,
    int? unlockSet,
    int? currentDuration,
    String? fromGid,
    String? fromSource,
    Map<String, dynamic>? recMap,
    bool? hideRewardDialog,
    bool? hideBack,
    bool? hideTopInfo,
    bool? hideBottomInfo,
    bool? hideMore,
    bool? hideLikeIcon,
    bool? hideCollectIcon,
    bool? infiniteScrollEnabled,
    bool? closeInfiniteScroll,
    bool? hideCellularToast,
    bool? disableDoubleClickLike,
    int? bottomOffset,
    int? topOffset,
    int? scriptTipsTopMargin,
    double? fromTopMargin,
    double? playStartTime,
    String? presentationStyle,
    int? containerId,
    List<int>? drawAdPositions,
    String? customDrawAdViewId,
    String? customBannerAdViewId,
  }) {
    return DramaPlayerConfig(
      dramaId: dramaId ?? this.dramaId,
      episode: episode ?? this.episode,
      adMode: adMode ?? this.adMode,
      freeSet: freeSet ?? this.freeSet,
      unlockSet: unlockSet ?? this.unlockSet,
      currentDuration: currentDuration ?? this.currentDuration,
      fromGid: fromGid ?? this.fromGid,
      fromSource: fromSource ?? this.fromSource,
      recMap: recMap ?? this.recMap,
      hideRewardDialog: hideRewardDialog ?? this.hideRewardDialog,
      hideBack: hideBack ?? this.hideBack,
      hideTopInfo: hideTopInfo ?? this.hideTopInfo,
      hideBottomInfo: hideBottomInfo ?? this.hideBottomInfo,
      hideMore: hideMore ?? this.hideMore,
      hideLikeIcon: hideLikeIcon ?? this.hideLikeIcon,
      hideCollectIcon: hideCollectIcon ?? this.hideCollectIcon,
      infiniteScrollEnabled:
          infiniteScrollEnabled ?? this.infiniteScrollEnabled,
      closeInfiniteScroll: closeInfiniteScroll ?? this.closeInfiniteScroll,
      hideCellularToast: hideCellularToast ?? this.hideCellularToast,
      disableDoubleClickLike:
          disableDoubleClickLike ?? this.disableDoubleClickLike,
      bottomOffset: bottomOffset ?? this.bottomOffset,
      topOffset: topOffset ?? this.topOffset,
      scriptTipsTopMargin: scriptTipsTopMargin ?? this.scriptTipsTopMargin,
      fromTopMargin: fromTopMargin ?? this.fromTopMargin,
      playStartTime: playStartTime ?? this.playStartTime,
      presentationStyle: presentationStyle ?? this.presentationStyle,
      containerId: containerId ?? this.containerId,
      drawAdPositions: drawAdPositions ?? this.drawAdPositions,
      customDrawAdViewId: customDrawAdViewId ?? this.customDrawAdViewId,
      customBannerAdViewId: customBannerAdViewId ?? this.customBannerAdViewId,
    );
  }

  @override
  String toString() {
    return 'DramaPlayerConfig{dramaId: $dramaId, episode: $episode, adMode: $adMode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DramaPlayerConfig &&
        other.dramaId == dramaId &&
        other.episode == episode &&
        other.adMode == adMode;
  }

  @override
  int get hashCode {
    return dramaId.hashCode ^ episode.hashCode ^ adMode.hashCode;
  }
}

/// 播放页入口来源枚举
class DramaPlayerEntranceType {
  static const String defaultType = 'default';
  static const String skitMixed = 'skit_mixed';
  static const String dramaHomeRecentlyWatched = 'drama_home_recently_watched';
  static const String dramaHome = 'drama_home';
  static const String dramaHistory = 'drama_history';
  static const String dramaCard = 'drama_card';
}

/// 播放页广告模式枚举
class DramaPlayerAdMode {
  static const String common = 'common';
  static const String specific = 'specific';
}

/// 播放页展示样式枚举（iOS专用）
class DramaPlayerPresentationStyle {
  static const String fullScreen = 'fullScreen';
  static const String pageSheet = 'pageSheet';
  static const String formSheet = 'formSheet';
}
