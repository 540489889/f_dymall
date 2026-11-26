/// 小视频卡片配置
/// 基于官方SDK的DPWidgetVideoCardParams（Android）和LCDVideoCardConfig（iOS）
class VideoCardConfig {
  /// 场景标识
  final String? scene;

  /// 卡片类型：'news'-信息流场景，'recommend'-推荐流场景，'search'-搜索场景
  final String? cardType;

  /// 卡片宽度
  final int? cardWidth;

  /// 卡片高度
  final int? cardHeight;

  /// 封面图片宽度
  final int? coverWidth;

  /// 封面图片高度
  final int? coverHeight;

  /// 是否显示标题
  final bool? showTitle;

  /// 是否显示用户名
  final bool? showUserName;

  /// 是否显示播放按钮
  final bool? showPlayButton;

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

  const VideoCardConfig({
    this.scene,
    this.cardType,
    this.cardWidth,
    this.cardHeight,
    this.coverWidth,
    this.coverHeight,
    this.showTitle,
    this.showUserName,
    this.showPlayButton,
    this.showDuration,
    this.showViewCount,
    this.showLikeCount,
    this.showCommentCount,
    this.showShareButton,
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
  });

  /// 转换为Map - 只包含非null的参数
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    if (scene != null) map['scene'] = scene;
    if (cardType != null) map['cardType'] = cardType;
    if (cardWidth != null) map['cardWidth'] = cardWidth;
    if (cardHeight != null) map['cardHeight'] = cardHeight;
    if (coverWidth != null) map['coverWidth'] = coverWidth;
    if (coverHeight != null) map['coverHeight'] = coverHeight;
    if (showTitle != null) map['showTitle'] = showTitle;
    if (showUserName != null) map['showUserName'] = showUserName;
    if (showPlayButton != null) map['showPlayButton'] = showPlayButton;
    if (showDuration != null) map['showDuration'] = showDuration;
    if (showViewCount != null) map['showViewCount'] = showViewCount;
    if (showLikeCount != null) map['showLikeCount'] = showLikeCount;
    if (showCommentCount != null) map['showCommentCount'] = showCommentCount;
    if (showShareButton != null) map['showShareButton'] = showShareButton;
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

    return map;
  }

  /// 从Map创建配置
  factory VideoCardConfig.fromMap(Map<String, dynamic> map) {
    return VideoCardConfig(
      scene: map['scene'] as String?,
      cardType: map['cardType'] as String?,
      cardWidth: map['cardWidth'] as int?,
      cardHeight: map['cardHeight'] as int?,
      coverWidth: map['coverWidth'] as int?,
      coverHeight: map['coverHeight'] as int?,
      showTitle: map['showTitle'] as bool?,
      showUserName: map['showUserName'] as bool?,
      showPlayButton: map['showPlayButton'] as bool?,
      showDuration: map['showDuration'] as bool?,
      showViewCount: map['showViewCount'] as bool?,
      showLikeCount: map['showLikeCount'] as bool?,
      showCommentCount: map['showCommentCount'] as bool?,
      showShareButton: map['showShareButton'] as bool?,
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
    );
  }

  @override
  String toString() {
    return 'VideoCardConfig(scene: $scene, cardType: $cardType, cardWidth: $cardWidth, cardHeight: $cardHeight, showTitle: $showTitle, autoPlay: $autoPlay)';
  }
}
