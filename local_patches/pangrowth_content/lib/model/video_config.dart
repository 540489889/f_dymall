/// 小视频配置
/// 基于官方SDK的DPWidgetDrawParams（Android）和LCDDrawVideoVCConfig（iOS）
///
/// **使用示例**：
///
/// 基础配置：
/// ```dart
/// final config = VideoConfig(
///   showBackBtn: true,
///   enableRefresh: true,
/// );
/// ```
///
/// Android自定义样式：
/// ```dart
/// final config = VideoConfig(
///   showBackBtn: true,
///   isShowActionBar: true,
///   actionBarBackgroundColor: '#FF6200EE',
///   fontSize: 16,
///   isBold: true,
///   topMargin: 20,
/// );
/// ```
///
/// iOS自定义导航栏：
/// ```dart
/// final config = VideoConfig(
///   showBackBtn: true,
///   isShowNavigationBar: true,
///   navigationBarBackgroundColor: '#FFFFFF',
///   navigationBarTitleColor: '#000000',
///   navigationBarButtonColor: '#007AFF',
///   statusBarStyle: 'darkContent',
/// );
/// ```
///
/// 一起看视频配置：
/// ```dart
/// final config = VideoConfig(
///   showBackBtn: true,
///   watchTogetherRole: 'HOST',
///   hostGroupId: 12345,
/// );
/// ```
class VideoConfig {
  /// 是否展示返回按钮
  final bool? showBackBtn;

  /// 是否显示距离顶部的距离参数（仅Android）
  final bool? isShowNeedTopMargin;

  /// 距离顶部的距离，单位dp（仅Android）
  final int? topMargin;

  /// 是否展示ActionBar（仅Android）
  final bool? isShowActionBar;

  /// 字体大小（仅Android）
  final int? fontSize;

  /// 字体是否加粗（仅Android）
  final bool? isBold;

  /// ActionBar背景颜色（仅Android）
  final String? actionBarBackgroundColor;

  /// 是否支持横竖屏切换（仅Android）
  final bool? supportOrientationChange;

  /// 是否允许左滑返回（仅iOS）
  final bool? allowPanBack;

  /// 是否显示导航栏（仅iOS）
  final bool? isShowNavigationBar;

  /// 导航栏背景颜色（仅iOS）
  final String? navigationBarBackgroundColor;

  /// 导航栏标题颜色（仅iOS）
  final String? navigationBarTitleColor;

  /// 导航栏按钮颜色（仅iOS）
  final String? navigationBarButtonColor;

  /// 状态栏样式（仅iOS）
  /// 可选值：'default', 'lightContent', 'darkContent'
  final String? statusBarStyle;

  /// 广告偏移量（距离底部），单位dp
  final int? adOffset;

  /// 底部偏移量，单位dp
  final int? bottomOffset;

  /// 是否隐藏关闭按钮
  final bool? hideClose;

  /// 进度条样式：1-浅色（白色），2-深色（蓝色）
  final int? progressBarStyle;

  /// 自定义频道名称
  final String? customCategory;

  /// 场景标识
  final String? scene;

  /// 标题栏上边距，单位dp
  final int? titleTopMargin;

  /// 标题栏左边距，单位dp
  final int? titleLeftMargin;

  /// 标题栏右边距，单位dp
  final int? titleRightMargin;

  /// 频道类型：1-推荐，2-关注，3-推荐+关注
  final int? drawChannelType;

  /// 是否隐藏关注功能
  final bool? hideFollow;

  /// 是否隐藏频道名称
  final bool? hideChannelName;

  /// 是否支持下拉刷新
  final bool? enableRefresh;

  /// 一起看视频角色：'NONE', 'HOST', 'USER'
  final String? watchTogetherRole;

  /// 主控端GroupID（仅在一起看视频主控端生效）
  final int? hostGroupId;

  /// 是否显示关闭按钮（iOS专用）
  final bool? showCloseButton;

  /// 是否隐藏首次安装出现的引导手势图（iOS专用）
  final bool? hiddenGuideGeste;

  /// 外流进度条距离最低部的距离（iOS专用）
  final double? outBottomOffset;

  /// 支持的返回内容的类型（iOS专用）
  final List<String>? featureValuesArr;

  /// 个性化推荐关闭以后，推荐频道名称（iOS专用）
  final String? recommandTabName;

  /// 需要展示的tab（iOS专用）
  final int? drawVCTabOptions;

  /// 是否屏蔽关注功能（iOS专用）
  final bool? shouldDisableFollowingFunc;

  /// 是否隐藏频道tab（iOS专用）
  final bool? shouldHideTabBarView;

  /// 自定义刷新行为和手势（iOS专用）
  final bool? customRefresh;

  /// 导航栏内边距配置（iOS专用）
  final Map<String, double>? navBarInset;

  /// 是否隐藏短剧title（iOS专用）
  final bool? hiddenPlayletTitleView;

  /// 是否隐藏底部跳转区域（iOS专用）
  final bool? hiddenPlayletEnterView;

  const VideoConfig({
    this.showBackBtn,
    this.isShowNeedTopMargin,
    this.topMargin,
    this.isShowActionBar,
    this.fontSize,
    this.isBold,
    this.actionBarBackgroundColor,
    this.supportOrientationChange,
    this.allowPanBack,
    this.isShowNavigationBar,
    this.navigationBarBackgroundColor,
    this.navigationBarTitleColor,
    this.navigationBarButtonColor,
    this.statusBarStyle,
    this.adOffset,
    this.bottomOffset,
    this.hideClose,
    this.progressBarStyle,
    this.customCategory,
    this.scene,
    this.titleTopMargin,
    this.titleLeftMargin,
    this.titleRightMargin,
    this.drawChannelType,
    this.hideFollow,
    this.hideChannelName,
    this.enableRefresh,
    this.watchTogetherRole,
    this.hostGroupId,
    this.showCloseButton,
    this.hiddenGuideGeste,
    this.outBottomOffset,
    this.featureValuesArr,
    this.recommandTabName,
    this.drawVCTabOptions,
    this.shouldDisableFollowingFunc,
    this.shouldHideTabBarView,
    this.customRefresh,
    this.navBarInset,
    this.hiddenPlayletTitleView,
    this.hiddenPlayletEnterView,
  });

  /// 转换为Map - 只包含非null的参数
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    if (showBackBtn != null) map['showBackBtn'] = showBackBtn;
    if (isShowNeedTopMargin != null)
      map['isShowNeedTopMargin'] = isShowNeedTopMargin;
    if (topMargin != null) map['topMargin'] = topMargin;
    if (isShowActionBar != null) map['isShowActionBar'] = isShowActionBar;
    if (fontSize != null) map['fontSize'] = fontSize;
    if (isBold != null) map['isBold'] = isBold;
    if (actionBarBackgroundColor != null)
      map['actionBarBackgroundColor'] = actionBarBackgroundColor;
    if (supportOrientationChange != null)
      map['supportOrientationChange'] = supportOrientationChange;
    if (allowPanBack != null) map['allowPanBack'] = allowPanBack;
    if (isShowNavigationBar != null)
      map['isShowNavigationBar'] = isShowNavigationBar;
    if (navigationBarBackgroundColor != null)
      map['navigationBarBackgroundColor'] = navigationBarBackgroundColor;
    if (navigationBarTitleColor != null)
      map['navigationBarTitleColor'] = navigationBarTitleColor;
    if (navigationBarButtonColor != null)
      map['navigationBarButtonColor'] = navigationBarButtonColor;
    if (statusBarStyle != null) map['statusBarStyle'] = statusBarStyle;
    if (adOffset != null) map['adOffset'] = adOffset;
    if (bottomOffset != null) map['bottomOffset'] = bottomOffset;
    if (hideClose != null) map['hideClose'] = hideClose;
    if (progressBarStyle != null) map['progressBarStyle'] = progressBarStyle;
    if (customCategory != null) map['customCategory'] = customCategory;
    if (scene != null) map['scene'] = scene;
    if (titleTopMargin != null) map['titleTopMargin'] = titleTopMargin;
    if (titleLeftMargin != null) map['titleLeftMargin'] = titleLeftMargin;
    if (titleRightMargin != null) map['titleRightMargin'] = titleRightMargin;
    if (drawChannelType != null) map['drawChannelType'] = drawChannelType;
    if (hideFollow != null) map['hideFollow'] = hideFollow;
    if (hideChannelName != null) map['hideChannelName'] = hideChannelName;
    if (enableRefresh != null) map['enableRefresh'] = enableRefresh;
    if (watchTogetherRole != null) map['watchTogetherRole'] = watchTogetherRole;
    if (hostGroupId != null) map['hostGroupId'] = hostGroupId;
    if (showCloseButton != null) map['showCloseButton'] = showCloseButton;
    if (hiddenGuideGeste != null) map['hiddenGuideGeste'] = hiddenGuideGeste;
    if (outBottomOffset != null) map['outBottomOffset'] = outBottomOffset;
    if (featureValuesArr != null) map['featureValuesArr'] = featureValuesArr;
    if (recommandTabName != null) map['recommandTabName'] = recommandTabName;
    if (drawVCTabOptions != null) map['drawVCTabOptions'] = drawVCTabOptions;
    if (shouldDisableFollowingFunc != null)
      map['shouldDisableFollowingFunc'] = shouldDisableFollowingFunc;
    if (shouldHideTabBarView != null)
      map['shouldHideTabBarView'] = shouldHideTabBarView;
    if (customRefresh != null) map['customRefresh'] = customRefresh;
    if (navBarInset != null) map['navBarInset'] = navBarInset;
    if (hiddenPlayletTitleView != null)
      map['hiddenPlayletTitleView'] = hiddenPlayletTitleView;
    if (hiddenPlayletEnterView != null)
      map['hiddenPlayletEnterView'] = hiddenPlayletEnterView;

    return map;
  }

  /// 从Map创建配置
  factory VideoConfig.fromMap(Map<String, dynamic> map) {
    return VideoConfig(
      showBackBtn: map['showBackBtn'] as bool?,
      isShowNeedTopMargin: map['isShowNeedTopMargin'] as bool?,
      topMargin: map['topMargin'] as int?,
      isShowActionBar: map['isShowActionBar'] as bool?,
      fontSize: map['fontSize'] as int?,
      isBold: map['isBold'] as bool?,
      actionBarBackgroundColor: map['actionBarBackgroundColor'] as String?,
      supportOrientationChange: map['supportOrientationChange'] as bool?,
      allowPanBack: map['allowPanBack'] as bool?,
      isShowNavigationBar: map['isShowNavigationBar'] as bool?,
      navigationBarBackgroundColor:
          map['navigationBarBackgroundColor'] as String?,
      navigationBarTitleColor: map['navigationBarTitleColor'] as String?,
      navigationBarButtonColor: map['navigationBarButtonColor'] as String?,
      statusBarStyle: map['statusBarStyle'] as String?,
      adOffset: map['adOffset'] as int?,
      bottomOffset: map['bottomOffset'] as int?,
      hideClose: map['hideClose'] as bool?,
      progressBarStyle: map['progressBarStyle'] as int?,
      customCategory: map['customCategory'] as String?,
      scene: map['scene'] as String?,
      titleTopMargin: map['titleTopMargin'] as int?,
      titleLeftMargin: map['titleLeftMargin'] as int?,
      titleRightMargin: map['titleRightMargin'] as int?,
      drawChannelType: map['drawChannelType'] as int?,
      hideFollow: map['hideFollow'] as bool?,
      hideChannelName: map['hideChannelName'] as bool?,
      enableRefresh: map['enableRefresh'] as bool?,
      watchTogetherRole: map['watchTogetherRole'] as String?,
      hostGroupId: map['hostGroupId'] as int?,
      showCloseButton: map['showCloseButton'] as bool?,
      hiddenGuideGeste: map['hiddenGuideGeste'] as bool?,
      outBottomOffset: map['outBottomOffset'] as double?,
      featureValuesArr: map['featureValuesArr'] != null
          ? List<String>.from(map['featureValuesArr'])
          : null,
      recommandTabName: map['recommandTabName'] as String?,
      drawVCTabOptions: map['drawVCTabOptions'] as int?,
      shouldDisableFollowingFunc: map['shouldDisableFollowingFunc'] as bool?,
      shouldHideTabBarView: map['shouldHideTabBarView'] as bool?,
      customRefresh: map['customRefresh'] as bool?,
      navBarInset: map['navBarInset'] != null
          ? Map<String, double>.from(map['navBarInset'])
          : null,
      hiddenPlayletTitleView: map['hiddenPlayletTitleView'] as bool?,
      hiddenPlayletEnterView: map['hiddenPlayletEnterView'] as bool?,
    );
  }

  @override
  String toString() {
    return 'VideoConfig(showBackBtn: $showBackBtn, isShowNeedTopMargin: $isShowNeedTopMargin, topMargin: $topMargin, isShowActionBar: $isShowActionBar, fontSize: $fontSize, isBold: $isBold, actionBarBackgroundColor: $actionBarBackgroundColor, supportOrientationChange: $supportOrientationChange, allowPanBack: $allowPanBack, isShowNavigationBar: $isShowNavigationBar, navigationBarBackgroundColor: $navigationBarBackgroundColor, navigationBarTitleColor: $navigationBarTitleColor, navigationBarButtonColor: $navigationBarButtonColor, statusBarStyle: $statusBarStyle)';
  }
}
