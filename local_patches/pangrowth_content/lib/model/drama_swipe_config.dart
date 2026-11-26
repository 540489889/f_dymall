/// 短剧滑滑流配置参数
class DramaSwipeConfig {
  /// 底部偏移量（dp）
  final int? bottomOffset;

  /// 标题栏上边距（dp）
  final int? titleTopMargin;

  /// 标题栏左边距（dp）
  final int? titleLeftMargin;

  /// 标题栏右边距（dp）
  final int? titleRightMargin;

  /// 是否隐藏频道名称
  final bool? hideChannelName;

  /// 是否隐藏底部短剧信息
  final bool? hideDramaInfo;

  /// 是否隐藏底部短剧入口
  final bool? hideDramaEnter;

  /// 是否支持下拉刷新
  final bool? enableRefresh;

  /// 是否隐藏关闭按钮
  final bool? hideClose;

  /// 自定义推荐频道名字
  final String? customCategory;

  /// 播放器进度条样式
  ///
  /// - `1`: 浅色进度条（适合深色背景）
  /// - `2`: 深色进度条（适合浅色背景）
  final int? progressBarStyle;

  /// 短剧免费集数
  final int? dramaFree;

  /// 每次解锁的集数（观看广告后解锁的集数）
  ///
  /// 当用户观看完解锁广告后，SDK会自动解锁指定数量的剧集。
  /// 例如：unlockEpisodesCount=3 表示每次观看广告可解锁3集
  ///
  /// **默认值**：1（每次解锁1集）
  final int? unlockEpisodesCount;

  /// 短剧置顶ID
  final int? topDramaId;

  /// 是否隐藏点赞按钮
  final bool? hideLikeButton;

  /// 是否隐藏收藏按钮
  final bool? hideFavorButton;

  /// 是否禁止双击点赞
  final bool? hideDoubleClickLike;

  /// 频道类型（控制显示哪些Tab）
  ///
  /// - `1`: 仅显示推荐Tab
  /// - `2`: 仅显示剧场Tab
  /// - `3`: 同时显示推荐和剧场两个Tab
  ///
  /// **默认值**：SDK内部默认值（通常为推荐Tab）
  final int? channelType;

  /// 💡 **仅Android支持**
  ///
  /// 内容类型
  ///
  /// - `1`: 仅显示短剧内容
  ///
  /// **注意**：iOS平台会忽略此参数，不会报错但也不会生效
  final int? contentType;

  const DramaSwipeConfig({
    this.bottomOffset,
    this.titleTopMargin,
    this.titleLeftMargin,
    this.titleRightMargin,
    this.hideChannelName,
    this.hideDramaInfo,
    this.hideDramaEnter,
    this.enableRefresh,
    this.hideClose,
    this.customCategory,
    this.progressBarStyle,
    this.dramaFree,
    this.unlockEpisodesCount,
    this.topDramaId,
    this.hideLikeButton,
    this.hideFavorButton,
    this.hideDoubleClickLike,
    this.channelType,
    this.contentType,
  });

  /// 转换为Map，只包含非null的值
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    if (bottomOffset != null) map['bottomOffset'] = bottomOffset;
    if (titleTopMargin != null) map['titleTopMargin'] = titleTopMargin;
    if (titleLeftMargin != null) map['titleLeftMargin'] = titleLeftMargin;
    if (titleRightMargin != null) map['titleRightMargin'] = titleRightMargin;
    if (hideChannelName != null) map['hideChannelName'] = hideChannelName;
    if (hideDramaInfo != null) map['hideDramaInfo'] = hideDramaInfo;
    if (hideDramaEnter != null) map['hideDramaEnter'] = hideDramaEnter;
    if (enableRefresh != null) map['enableRefresh'] = enableRefresh;
    if (hideClose != null) map['hideClose'] = hideClose;
    if (customCategory != null) map['customCategory'] = customCategory;
    if (progressBarStyle != null) map['progressBarStyle'] = progressBarStyle;
    if (dramaFree != null) map['dramaFree'] = dramaFree;
    if (unlockEpisodesCount != null)
      map['unlockEpisodesCount'] = unlockEpisodesCount;
    if (topDramaId != null) map['topDramaId'] = topDramaId;
    if (hideLikeButton != null) map['hideLikeButton'] = hideLikeButton;
    if (hideFavorButton != null) map['hideFavorButton'] = hideFavorButton;
    if (hideDoubleClickLike != null)
      map['hideDoubleClickLike'] = hideDoubleClickLike;
    if (channelType != null) map['channelType'] = channelType;
    if (contentType != null) map['contentType'] = contentType;

    return map;
  }

  /// 从Map创建实例
  factory DramaSwipeConfig.fromMap(Map<String, dynamic> map) {
    return DramaSwipeConfig(
      bottomOffset: map['bottomOffset'] as int?,
      titleTopMargin: map['titleTopMargin'] as int?,
      titleLeftMargin: map['titleLeftMargin'] as int?,
      titleRightMargin: map['titleRightMargin'] as int?,
      hideChannelName: map['hideChannelName'] as bool?,
      hideDramaInfo: map['hideDramaInfo'] as bool?,
      hideDramaEnter: map['hideDramaEnter'] as bool?,
      enableRefresh: map['enableRefresh'] as bool?,
      hideClose: map['hideClose'] as bool?,
      customCategory: map['customCategory'] as String?,
      progressBarStyle: map['progressBarStyle'] as int?,
      dramaFree: map['dramaFree'] as int?,
      unlockEpisodesCount: map['unlockEpisodesCount'] as int?,
      topDramaId: map['topDramaId'] as int?,
      hideLikeButton: map['hideLikeButton'] as bool?,
      hideFavorButton: map['hideFavorButton'] as bool?,
      hideDoubleClickLike: map['hideDoubleClickLike'] as bool?,
      channelType: map['channelType'] as int?,
      contentType: map['contentType'] as int?,
    );
  }

  @override
  String toString() {
    return 'DramaSwipeConfig{bottomOffset: $bottomOffset, titleTopMargin: $titleTopMargin, '
        'titleLeftMargin: $titleLeftMargin, titleRightMargin: $titleRightMargin, '
        'hideChannelName: $hideChannelName, hideDramaInfo: $hideDramaInfo, '
        'hideDramaEnter: $hideDramaEnter, enableRefresh: $enableRefresh, '
        'hideClose: $hideClose, customCategory: $customCategory, '
        'progressBarStyle: $progressBarStyle, dramaFree: $dramaFree, '
        'unlockEpisodesCount: $unlockEpisodesCount, '
        'topDramaId: $topDramaId, hideLikeButton: $hideLikeButton, '
        'hideFavorButton: $hideFavorButton, hideDoubleClickLike: $hideDoubleClickLike, '
        'channelType: $channelType, contentType: $contentType}';
  }
}
