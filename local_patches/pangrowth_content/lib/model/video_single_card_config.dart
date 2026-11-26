/// 小视频单卡片配置
/// 基于官方SDK的DPWidgetVideoSingleCardParams（Android）和LCDVideoSingleCardConfig（iOS）
class VideoSingleCardConfig {
  /// 场景标识
  final String? scene;

  /// 是否隐藏播放按钮
  final bool? hidePlay;

  /// 是否隐藏标题
  final bool? hideTitle;

  /// 是否显示标题（若设置则优先于 [hideTitle]）
  final bool? showTitle;

  /// 是否隐藏底部信息
  final bool? hideBottomInfo;

  /// 封面图片高度
  final int? coverHeight;

  /// 封面图片宽度
  final int? coverWidth;

  /// 组件位置：'top'-顶部，'bottom'-底部，'center'-居中
  final String? componentPosition;

  /// 举报按钮距顶部间距
  final int? reportTopPadding;

  /// 卡片宽度
  final int? cardWidth;

  /// 卡片高度
  final int? cardHeight;

  /// 是否显示用户名
  final bool? showUserName;

  /// 是否显示播放时长
  final bool? showDuration;

  /// 是否显示观看次数
  final bool? showViewCount;

  /// 是否显示点赞数
  final bool? showLikeCount;

  /// 是否显示评论数
  final bool? showCommentCount;

  /// 是否显示分享按钮
  final bool? showShareButton;

  /// 是否显示头像
  final bool? showAvatar;

  /// 是否显示关注按钮
  final bool? showFollowButton;

  /// 是否支持自动播放
  final bool? autoPlay;

  /// 是否循环播放
  final bool? loopPlay;

  /// 是否静音播放
  final bool? mutePlay;

  /// 预加载数量
  final int? preloadCount;

  /// 缓存大小限制（MB）
  final int? cacheSize;

  /// 网络状态：1-WiFi，2-移动网络，3-所有网络
  final int? networkType;

  /// 背景颜色
  final String? backgroundColor;

  /// 标题颜色
  final String? titleColor;

  /// 用户名颜色
  final String? userNameColor;

  /// 播放按钮颜色
  final String? playButtonColor;

  /// 统计信息颜色
  final String? statsColor;

  /// 边框颜色
  final String? borderColor;

  /// 边框宽度
  final int? borderWidth;

  /// 圆角半径
  final int? cornerRadius;

  /// 内边距
  final int? padding;

  /// 外边距
  final int? margin;

  /// 阴影效果
  final bool? enableShadow;

  /// 阴影颜色
  final String? shadowColor;

  /// 阴影偏移X
  final int? shadowOffsetX;

  /// 阴影偏移Y
  final int? shadowOffsetY;

  /// 阴影模糊半径
  final int? shadowBlurRadius;

  /// 文字字体大小
  final int? fontSize;

  /// 文字是否加粗
  final bool? fontBold;

  /// 标题最大行数
  final int? titleMaxLines;

  /// 用户名最大长度
  final int? userNameMaxLength;

  /// 播放按钮大小
  final int? playButtonSize;

  /// 头像大小
  final int? avatarSize;

  /// 关注按钮宽度
  final int? followButtonWidth;

  /// 关注按钮高度
  final int? followButtonHeight;

  /// 操作按钮间距
  final int? actionButtonSpacing;

  /// 底部信息区域高度
  final int? bottomInfoHeight;

  /// 顶部信息区域高度
  final int? topInfoHeight;

  const VideoSingleCardConfig({
    this.scene,
    this.hidePlay,
    this.hideTitle,
    this.showTitle,
    this.hideBottomInfo,
    this.coverHeight,
    this.coverWidth,
    this.componentPosition,
    this.reportTopPadding,
    this.cardWidth,
    this.cardHeight,
    this.showUserName,
    this.showDuration,
    this.showViewCount,
    this.showLikeCount,
    this.showCommentCount,
    this.showShareButton,
    this.showAvatar,
    this.showFollowButton,
    this.autoPlay,
    this.loopPlay,
    this.mutePlay,
    this.preloadCount,
    this.cacheSize,
    this.networkType,
    this.backgroundColor,
    this.titleColor,
    this.userNameColor,
    this.playButtonColor,
    this.statsColor,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius,
    this.padding,
    this.margin,
    this.enableShadow,
    this.shadowColor,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.shadowBlurRadius,
    this.fontSize,
    this.fontBold,
    this.titleMaxLines,
    this.userNameMaxLength,
    this.playButtonSize,
    this.avatarSize,
    this.followButtonWidth,
    this.followButtonHeight,
    this.actionButtonSpacing,
    this.bottomInfoHeight,
    this.topInfoHeight,
  });

  /// 转换为Map - 只包含非null的参数
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    if (scene != null) map['scene'] = scene;
    if (hidePlay != null) map['hidePlay'] = hidePlay;
    final bool? effectiveHideTitle = showTitle != null
        ? !showTitle!
        : hideTitle;
    if (effectiveHideTitle != null) map['hideTitle'] = effectiveHideTitle;
    if (hideBottomInfo != null) map['hideBottomInfo'] = hideBottomInfo;
    if (coverHeight != null) map['coverHeight'] = coverHeight;
    if (coverWidth != null) map['coverWidth'] = coverWidth;
    if (componentPosition != null) map['componentPosition'] = componentPosition;
    if (reportTopPadding != null) map['reportTopPadding'] = reportTopPadding;
    if (cardWidth != null) map['cardWidth'] = cardWidth;
    if (cardHeight != null) map['cardHeight'] = cardHeight;
    if (showUserName != null) map['showUserName'] = showUserName;
    if (showDuration != null) map['showDuration'] = showDuration;
    if (showViewCount != null) map['showViewCount'] = showViewCount;
    if (showLikeCount != null) map['showLikeCount'] = showLikeCount;
    if (showCommentCount != null) map['showCommentCount'] = showCommentCount;
    if (showShareButton != null) map['showShareButton'] = showShareButton;
    if (showAvatar != null) map['showAvatar'] = showAvatar;
    if (showFollowButton != null) map['showFollowButton'] = showFollowButton;
    if (autoPlay != null) map['autoPlay'] = autoPlay;
    if (loopPlay != null) map['loopPlay'] = loopPlay;
    if (mutePlay != null) map['mutePlay'] = mutePlay;
    if (preloadCount != null) map['preloadCount'] = preloadCount;
    if (cacheSize != null) map['cacheSize'] = cacheSize;
    if (networkType != null) map['networkType'] = networkType;
    if (backgroundColor != null) map['backgroundColor'] = backgroundColor;
    if (titleColor != null) map['titleColor'] = titleColor;
    if (userNameColor != null) map['userNameColor'] = userNameColor;
    if (playButtonColor != null) map['playButtonColor'] = playButtonColor;
    if (statsColor != null) map['statsColor'] = statsColor;
    if (borderColor != null) map['borderColor'] = borderColor;
    if (borderWidth != null) map['borderWidth'] = borderWidth;
    if (cornerRadius != null) map['cornerRadius'] = cornerRadius;
    if (padding != null) map['padding'] = padding;
    if (margin != null) map['margin'] = margin;
    if (enableShadow != null) map['enableShadow'] = enableShadow;
    if (shadowColor != null) map['shadowColor'] = shadowColor;
    if (shadowOffsetX != null) map['shadowOffsetX'] = shadowOffsetX;
    if (shadowOffsetY != null) map['shadowOffsetY'] = shadowOffsetY;
    if (shadowBlurRadius != null) map['shadowBlurRadius'] = shadowBlurRadius;
    if (fontSize != null) map['fontSize'] = fontSize;
    if (fontBold != null) map['fontBold'] = fontBold;
    if (titleMaxLines != null) map['titleMaxLines'] = titleMaxLines;
    if (userNameMaxLength != null) map['userNameMaxLength'] = userNameMaxLength;
    if (playButtonSize != null) map['playButtonSize'] = playButtonSize;
    if (avatarSize != null) map['avatarSize'] = avatarSize;
    if (followButtonWidth != null) map['followButtonWidth'] = followButtonWidth;
    if (followButtonHeight != null)
      map['followButtonHeight'] = followButtonHeight;
    if (actionButtonSpacing != null)
      map['actionButtonSpacing'] = actionButtonSpacing;
    if (bottomInfoHeight != null) map['bottomInfoHeight'] = bottomInfoHeight;
    if (topInfoHeight != null) map['topInfoHeight'] = topInfoHeight;

    return map;
  }

  /// 从Map创建配置
  factory VideoSingleCardConfig.fromMap(Map<String, dynamic> map) {
    final bool? hideTitleValue = map['hideTitle'] as bool?;
    final bool? showTitleValue = map.containsKey('showTitle')
        ? map['showTitle'] as bool?
        : (hideTitleValue != null ? !hideTitleValue : null);

    return VideoSingleCardConfig(
      scene: map['scene'] as String?,
      hidePlay: map['hidePlay'] as bool?,
      hideTitle: hideTitleValue,
      showTitle: showTitleValue,
      hideBottomInfo: map['hideBottomInfo'] as bool?,
      coverHeight: map['coverHeight'] as int?,
      coverWidth: map['coverWidth'] as int?,
      componentPosition: map['componentPosition'] as String?,
      reportTopPadding: map['reportTopPadding'] as int?,
      cardWidth: map['cardWidth'] as int?,
      cardHeight: map['cardHeight'] as int?,
      showUserName: map['showUserName'] as bool?,
      showDuration: map['showDuration'] as bool?,
      showViewCount: map['showViewCount'] as bool?,
      showLikeCount: map['showLikeCount'] as bool?,
      showCommentCount: map['showCommentCount'] as bool?,
      showShareButton: map['showShareButton'] as bool?,
      showAvatar: map['showAvatar'] as bool?,
      showFollowButton: map['showFollowButton'] as bool?,
      autoPlay: map['autoPlay'] as bool?,
      loopPlay: map['loopPlay'] as bool?,
      mutePlay: map['mutePlay'] as bool?,
      preloadCount: map['preloadCount'] as int?,
      cacheSize: map['cacheSize'] as int?,
      networkType: map['networkType'] as int?,
      backgroundColor: map['backgroundColor'] as String?,
      titleColor: map['titleColor'] as String?,
      userNameColor: map['userNameColor'] as String?,
      playButtonColor: map['playButtonColor'] as String?,
      statsColor: map['statsColor'] as String?,
      borderColor: map['borderColor'] as String?,
      borderWidth: map['borderWidth'] as int?,
      cornerRadius: map['cornerRadius'] as int?,
      padding: map['padding'] as int?,
      margin: map['margin'] as int?,
      enableShadow: map['enableShadow'] as bool?,
      shadowColor: map['shadowColor'] as String?,
      shadowOffsetX: map['shadowOffsetX'] as int?,
      shadowOffsetY: map['shadowOffsetY'] as int?,
      shadowBlurRadius: map['shadowBlurRadius'] as int?,
      fontSize: map['fontSize'] as int?,
      fontBold: map['fontBold'] as bool?,
      titleMaxLines: map['titleMaxLines'] as int?,
      userNameMaxLength: map['userNameMaxLength'] as int?,
      playButtonSize: map['playButtonSize'] as int?,
      avatarSize: map['avatarSize'] as int?,
      followButtonWidth: map['followButtonWidth'] as int?,
      followButtonHeight: map['followButtonHeight'] as int?,
      actionButtonSpacing: map['actionButtonSpacing'] as int?,
      bottomInfoHeight: map['bottomInfoHeight'] as int?,
      topInfoHeight: map['topInfoHeight'] as int?,
    );
  }

  @override
  String toString() {
    return 'VideoSingleCardConfig(scene: $scene, hidePlay: $hidePlay, hideTitle: $hideTitle, showTitle: $showTitle, hideBottomInfo: $hideBottomInfo, coverHeight: $coverHeight, coverWidth: $coverWidth, componentPosition: $componentPosition)';
  }
}
