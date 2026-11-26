/// 用户主页页面类型，对应 `DPWidgetUserProfileParam.PageType`
enum UserProfilePageType {
  /// 个人主页
  userHomePage,

  /// 喜欢的视频页
  userFavoriteVideoPage,

  /// 关注页
  userFocusPage,
}

UserProfilePageType? _parseUserProfilePageType(String? value) {
  switch (value) {
    case 'USER_HOME_PAGE':
      return UserProfilePageType.userHomePage;
    case 'USER_FAVORITE_VIDEO_PAGE':
      return UserProfilePageType.userFavoriteVideoPage;
    case 'USER_FOCUS_PAGE':
      return UserProfilePageType.userFocusPage;
  }
  return null;
}

String _pageTypeToNative(UserProfilePageType type) {
  switch (type) {
    case UserProfilePageType.userHomePage:
      return 'USER_HOME_PAGE';
    case UserProfilePageType.userFavoriteVideoPage:
      return 'USER_FAVORITE_VIDEO_PAGE';
    case UserProfilePageType.userFocusPage:
      return 'USER_FOCUS_PAGE';
  }
}

/// 个人主页配置，对应 `DPWidgetUserProfileParam`
class UserProfileConfig {
  /// 页面类型
  final UserProfilePageType? pageType;

  /// 是否隐藏关闭按钮
  final bool? hideCloseIcon;

  /// 组件宽度（dp，Android），未设置默认 match_parent
  final int? width;

  /// 组件高度（dp，Android），未设置默认 match_parent
  final int? height;

  /// 业务场景
  final String? scene;

  /// 扩展参数（原样透传）
  final Map<String, dynamic>? extra;

  const UserProfileConfig({
    this.pageType,
    this.hideCloseIcon,
    this.width,
    this.height,
    this.scene,
    this.extra,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{};

    if (pageType != null) {
      map['pageType'] = _pageTypeToNative(pageType!);
    }
    if (hideCloseIcon != null) {
      map['hideCloseIcon'] = hideCloseIcon;
    }
    if (width != null) {
      map['width'] = width;
    }
    if (height != null) {
      map['height'] = height;
    }
    if (scene != null && scene!.isNotEmpty) {
      map['scene'] = scene;
    }
    if (extra != null && extra!.isNotEmpty) {
      map['extra'] = extra;
    }

    return map;
  }

  factory UserProfileConfig.fromMap(Map<String, dynamic> map) {
    return UserProfileConfig(
      pageType: _parseUserProfilePageType(map['pageType'] as String?),
      hideCloseIcon: map['hideCloseIcon'] as bool?,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      scene: map['scene'] as String?,
      extra: (map['extra'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : null,
    );
  }

  UserProfileConfig copyWith({
    UserProfilePageType? pageType,
    bool? hideCloseIcon,
    int? width,
    int? height,
    String? scene,
    Map<String, dynamic>? extra,
  }) {
    return UserProfileConfig(
      pageType: pageType ?? this.pageType,
      hideCloseIcon: hideCloseIcon ?? this.hideCloseIcon,
      width: width ?? this.width,
      height: height ?? this.height,
      scene: scene ?? this.scene,
      extra: extra ?? this.extra,
    );
  }
}
