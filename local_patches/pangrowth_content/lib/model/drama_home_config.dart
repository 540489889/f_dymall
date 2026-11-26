/// 短剧聚合页配置
///
/// 对应原生SDK:
/// - Android: `DJXWidgetDramaHomeParams` + `DJXDramaDetailConfig`
/// - iOS: `DJXPlayletAggregatePageVCConfig` + `DJXPlayletConfig`
class DramaHomeConfig {
  // ========== 聚合页界面配置 ==========

  /// 是否展示换一换按钮
  ///
  /// 💡 **仅Android支持**
  /// - Android: 控制热门推荐区域的"换一换"按钮显示
  /// - iOS: 不支持此功能，会忽略此参数
  final bool? showChangeBtn;

  /// 是否展示页面标题栏
  ///
  /// 💡 **仅Android支持**
  /// - Android: 控制聚合页顶部标题栏是否显示
  /// - iOS: 使用导航栏机制，请使用 [isShowNavigationItemTitle]
  final bool? showPageTitle;

  /// 是否展示返回按钮
  ///
  /// ⚙️ **双端支持，行为略有差异**
  /// - Android: 控制标题栏中的返回按钮
  /// - iOS: 自动映射到导航栏返回按钮 (isShowNavigationItemBackButton)
  ///
  /// 💡 建议统一使用此参数，Flutter层会自动处理平台差异
  final bool? showBackBtn;

  /// 布局顶部偏移量，单位 dp
  ///
  /// 💡 **仅Android支持**
  /// - Android: 调整聚合页内容的顶部偏移，用于适配自定义标题栏
  /// - iOS: 不支持此功能，会忽略此参数
  final int? topOffset;

  /// 单个置顶短剧 id
  ///
  /// ✅ **双端支持**
  ///
  /// 设置一个置顶显示的短剧ID，该短剧会显示在热门推荐的最左侧
  final int? topDramaId;

  /// 多个置顶短剧 id 列表
  ///
  /// ✅ **双端支持**
  ///
  /// 设置多个置顶短剧ID，优先级高于 [topDramaId]
  /// - Android: 对应 mTopDramaIds
  /// - iOS: 对应 topSkitIds
  final List<String>? topDramaIds;

  // ========== 短剧播放配置 ==========

  /// 免费观看集数
  ///
  /// ✅ **双端支持**
  ///
  /// 用户无需任何解锁动作，从第一集开始可以免费连续观看的集数。
  ///
  /// **强规则约束**：
  /// 1. 最大不超过20集
  /// 2. 不超过每部剧总集数的前20%（四舍五入）
  /// 3. 取两者中的最大值
  final int? freeEpisodesCount;

  /// 观看广告解锁的集数
  ///
  /// ✅ **双端支持**
  ///
  /// 用户观看一个激励视频广告后可以解锁的集数。
  ///
  /// **强规则约束**：
  /// - 一个激励视频最多解锁10集
  final int? unlockEpisodesCountUsingAd;

  // ========== 播放详情页UI配置 ==========

  /// 是否隐藏短剧详情页顶部信息
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页顶部的短剧信息区域（如剧名、集数等）
  final bool? hideTopInfo;

  /// 是否隐藏短剧详情页底部信息
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页底部的交互按钮区域
  final bool? hideBottomInfo;

  /// 是否隐藏播放详情页的返回按钮
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页内的返回按钮（不同于聚合页的返回按钮）
  /// - Android: 对应 hideBack
  /// - iOS: 对应 hideBackButton
  final bool? hideBack;

  /// 是否隐藏更多按钮
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页的"更多"功能按钮（包括举报等）
  /// - Android: 对应 hideMore
  /// - iOS: 对应 hideMoreButton
  final bool? hideMore;

  /// 是否隐藏点赞按钮
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页的点赞按钮
  final bool? hideLikeIcon;

  /// 是否隐藏收藏按钮
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏播放详情页的收藏按钮
  /// - Android: 对应 hideFavorButton
  /// - iOS: 对应 hideCollectIcon
  final bool? hideFavorIcon;

  /// 是否隐藏 SDK 激励解锁弹窗
  ///
  /// ✅ **双端支持**
  ///
  /// 隐藏SDK内置的激励视频解锁提示弹窗，开发者可自行实现解锁UI
  final bool? hideRewardDialog;

  /// 是否允许无限滑动播放
  ///
  /// ✅ **双端支持**
  ///
  /// 开启后，一部短剧播放完成会自动播放下一部推荐短剧
  /// - Android: 对应 infiniteScrollEnabled
  /// - iOS: 对应 closeInfiniteScroll (逻辑相反，Flutter层自动转换)
  final bool? enableInfiniteScroll;

  // ========== iOS专用导航栏配置 ==========

  /// 是否展示导航栏返回按钮
  ///
  /// 💡 **仅iOS支持**
  ///
  /// 控制iOS导航栏左侧的返回按钮显示
  ///
  /// **建议**: 优先使用通用参数 [showBackBtn]，它会自动映射到此参数
  final bool? isShowNavigationItemBackButton;

  /// 是否展示导航栏标题
  ///
  /// 💡 **仅iOS支持**
  ///
  /// 控制iOS导航栏中间的标题显示
  ///
  /// **建议**: 优先使用通用参数 [showPageTitle]，它会自动映射到此参数
  final bool? isShowNavigationItemTitle;

  // ========== 其他配置 ==========

  /// 自定义埋点扩展参数
  ///
  /// ✅ **双端支持**
  ///
  /// 用于传递自定义的业务参数，会在事件回调中返回
  final Map<String, dynamic>? extra;

  const DramaHomeConfig({
    this.showChangeBtn,
    this.showPageTitle,
    this.showBackBtn,
    this.topOffset,
    this.topDramaId,
    this.topDramaIds,
    this.freeEpisodesCount,
    this.unlockEpisodesCountUsingAd,
    this.hideTopInfo,
    this.hideBottomInfo,
    this.hideBack,
    this.hideMore,
    this.hideLikeIcon,
    this.hideFavorIcon,
    this.hideRewardDialog,
    this.enableInfiniteScroll,
    this.isShowNavigationItemBackButton,
    this.isShowNavigationItemTitle,
    this.extra,
  });

  /// 转为原生参数 Map，仅包含非 null 字段
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    if (showChangeBtn != null) map['showChangeBtn'] = showChangeBtn;
    if (showPageTitle != null) map['showPageTitle'] = showPageTitle;
    if (showBackBtn != null) map['showBackBtn'] = showBackBtn;
    if (topOffset != null) map['topOffset'] = topOffset;
    if (topDramaId != null) map['topDramaId'] = topDramaId;
    if (topDramaIds != null) map['topDramaIds'] = topDramaIds;
    if (freeEpisodesCount != null) map['freeEpisodesCount'] = freeEpisodesCount;
    if (unlockEpisodesCountUsingAd != null) {
      map['unlockEpisodesCountUsingAD'] = unlockEpisodesCountUsingAd;
    }
    if (hideTopInfo != null) map['hideTopInfo'] = hideTopInfo;
    if (hideBottomInfo != null) map['hideBottomInfo'] = hideBottomInfo;
    if (hideBack != null) map['hideBack'] = hideBack;
    if (hideMore != null) map['hideMore'] = hideMore;
    if (hideLikeIcon != null) map['hideLikeIcon'] = hideLikeIcon;
    if (hideFavorIcon != null) map['hideFavorIcon'] = hideFavorIcon;
    if (hideRewardDialog != null) map['hideRewardDialog'] = hideRewardDialog;
    if (enableInfiniteScroll != null) {
      map['enableInfiniteScroll'] = enableInfiniteScroll;
    }
    if (isShowNavigationItemBackButton != null) {
      map['isShowNavigationItemBackButton'] = isShowNavigationItemBackButton;
    }
    if (isShowNavigationItemTitle != null) {
      map['isShowNavigationItemTitle'] = isShowNavigationItemTitle;
    }
    if (extra != null && extra!.isNotEmpty) {
      map['extra'] = extra;
    }

    return map;
  }

  /// 从 Map 构建配置
  factory DramaHomeConfig.fromMap(Map<String, dynamic> map) {
    return DramaHomeConfig(
      showChangeBtn: map['showChangeBtn'] as bool?,
      showPageTitle: map['showPageTitle'] as bool?,
      showBackBtn: map['showBackBtn'] as bool?,
      topOffset: map['topOffset'] as int?,
      topDramaId: map['topDramaId'] as int?,
      topDramaIds: map['topDramaIds'] != null
          ? List<String>.from(map['topDramaIds'] as Iterable)
          : null,
      freeEpisodesCount: map['freeEpisodesCount'] as int?,
      unlockEpisodesCountUsingAd: map['unlockEpisodesCountUsingAD'] as int?,
      hideTopInfo: map['hideTopInfo'] as bool?,
      hideBottomInfo: map['hideBottomInfo'] as bool?,
      hideBack: map['hideBack'] as bool?,
      hideMore: map['hideMore'] as bool?,
      hideLikeIcon: map['hideLikeIcon'] as bool?,
      hideFavorIcon: map['hideFavorIcon'] as bool?,
      hideRewardDialog: map['hideRewardDialog'] as bool?,
      enableInfiniteScroll: map['enableInfiniteScroll'] as bool?,
      isShowNavigationItemBackButton:
          map['isShowNavigationItemBackButton'] as bool?,
      isShowNavigationItemTitle: map['isShowNavigationItemTitle'] as bool?,
      extra: map['extra'] != null
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : null,
    );
  }

  @override
  String toString() {
    return 'DramaHomeConfig(showChangeBtn: $showChangeBtn, showPageTitle: $showPageTitle, '
        'showBackBtn: $showBackBtn, topOffset: $topOffset, topDramaId: $topDramaId, '
        'topDramaIds: $topDramaIds, freeEpisodesCount: $freeEpisodesCount, '
        'unlockEpisodesCountUsingAd: $unlockEpisodesCountUsingAd, '
        'hideTopInfo: $hideTopInfo, hideBottomInfo: $hideBottomInfo, hideBack: $hideBack, '
        'hideMore: $hideMore, hideLikeIcon: $hideLikeIcon, hideFavorIcon: $hideFavorIcon, '
        'hideRewardDialog: $hideRewardDialog, enableInfiniteScroll: $enableInfiniteScroll, '
        'isShowNavigationItemBackButton: $isShowNavigationItemBackButton, '
        'isShowNavigationItemTitle: $isShowNavigationItemTitle, extra: $extra)';
  }
}
