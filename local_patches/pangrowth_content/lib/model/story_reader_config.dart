/// 短故事阅读器配置模型
class StoryReaderConfig {
  /// 故事ID（必填）
  final int storyId;

  /// 起始章节索引（可选，默认从第0章开始）
  final int? startChapter;

  /// UI配置 - 默认字体大小
  final int? defaultTextSize;

  /// UI配置 - 文末推荐数量
  final int? endPageRecSize;

  /// UI配置 - 是否隐藏返回按钮
  final bool? hideBack;

  /// UI配置 - 翻页模式 (iOS专用)
  /// 0:仿真, 1:滑页, 2:平移, 3:上下滚动
  final int? pageTurnType;

  /// UI配置 - 字体大小档位 (iOS专用)
  final int? fontSizeLevel;

  /// 自定义广告配置 - 章间广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 在章节切换时插入的全屏广告
  final String? customMiddlePageAdViewId;

  /// 自定义广告配置 - 章间广告插入间隔（页数）
  ///
  /// 例如: 5 表示每5页插入一次章间广告
  /// 仅在提供customMiddlePageAdViewId时生效
  final int? middlePageInterval;

  /// 自定义广告配置 - 段间广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 在段落间插入的行内广告
  final String? customMiddleLineAdViewId;

  /// 自定义广告配置 - 段间广告起始行数
  ///
  /// 从第几行开始插入段间广告
  /// 仅在提供customMiddleLineAdViewId时生效
  final int? middleLineStartLine;

  /// 自定义广告配置 - 段间广告插入间隔（行数）
  ///
  /// 例如: 10 表示每10行插入一次段间广告
  /// 仅在提供customMiddleLineAdViewId时生效
  final int? middleLineInterval;

  /// 自定义广告配置 - Banner广告视图ID
  ///
  /// 由Flutter层的PlatformView生成,传递给原生层使用
  /// 用于在阅读器底部显示自定义Banner广告
  final String? customBannerAdViewId;

  const StoryReaderConfig({
    required this.storyId,
    this.startChapter,
    this.defaultTextSize,
    this.endPageRecSize,
    this.hideBack,
    this.pageTurnType,
    this.fontSizeLevel,
    this.customMiddlePageAdViewId,
    this.middlePageInterval,
    this.customMiddleLineAdViewId,
    this.middleLineStartLine,
    this.middleLineInterval,
    this.customBannerAdViewId,
  });

  /// 从Map创建配置
  factory StoryReaderConfig.fromMap(Map<String, dynamic> map) {
    return StoryReaderConfig(
      storyId: map['storyId'] as int,
      startChapter: map['startChapter'] as int?,
      defaultTextSize: map['defaultTextSize'] as int?,
      endPageRecSize: map['endPageRecSize'] as int?,
      hideBack: map['hideBack'] as bool?,
      pageTurnType: map['pageTurnType'] as int?,
      fontSizeLevel: map['fontSizeLevel'] as int?,
      customMiddlePageAdViewId: map['customMiddlePageAdViewId'] as String?,
      middlePageInterval: map['middlePageInterval'] as int?,
      customMiddleLineAdViewId: map['customMiddleLineAdViewId'] as String?,
      middleLineStartLine: map['middleLineStartLine'] as int?,
      middleLineInterval: map['middleLineInterval'] as int?,
      customBannerAdViewId: map['customBannerAdViewId'] as String?,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    // 必填参数
    map['storyId'] = storyId;

    // 可选参数 - 只有非null的才添加
    if (startChapter != null) map['startChapter'] = startChapter;
    if (defaultTextSize != null) map['defaultTextSize'] = defaultTextSize;
    if (endPageRecSize != null) map['endPageRecSize'] = endPageRecSize;
    if (hideBack != null) map['hideBack'] = hideBack;
    if (pageTurnType != null) map['pageTurnType'] = pageTurnType;
    if (fontSizeLevel != null) map['fontSizeLevel'] = fontSizeLevel;

    // 自定义广告参数 - 章间广告
    if (customMiddlePageAdViewId != null) {
      map['customMiddlePageAdViewId'] = customMiddlePageAdViewId;
    }
    if (middlePageInterval != null) {
      map['middlePageInterval'] = middlePageInterval;
    }

    // 自定义广告参数 - 段间广告
    if (customMiddleLineAdViewId != null) {
      map['customMiddleLineAdViewId'] = customMiddleLineAdViewId;
    }
    if (middleLineStartLine != null) {
      map['middleLineStartLine'] = middleLineStartLine;
    }
    if (middleLineInterval != null) {
      map['middleLineInterval'] = middleLineInterval;
    }

    // 自定义广告参数 - Banner广告
    if (customBannerAdViewId != null) {
      map['customBannerAdViewId'] = customBannerAdViewId;
    }

    return map;
  }

  /// 复制配置（可修改部分参数）
  StoryReaderConfig copyWith({
    int? storyId,
    int? startChapter,
    int? defaultTextSize,
    int? endPageRecSize,
    bool? hideBack,
    int? pageTurnType,
    int? fontSizeLevel,
    String? customMiddlePageAdViewId,
    int? middlePageInterval,
    String? customMiddleLineAdViewId,
    int? middleLineStartLine,
    int? middleLineInterval,
    String? customBannerAdViewId,
  }) {
    return StoryReaderConfig(
      storyId: storyId ?? this.storyId,
      startChapter: startChapter ?? this.startChapter,
      defaultTextSize: defaultTextSize ?? this.defaultTextSize,
      endPageRecSize: endPageRecSize ?? this.endPageRecSize,
      hideBack: hideBack ?? this.hideBack,
      pageTurnType: pageTurnType ?? this.pageTurnType,
      fontSizeLevel: fontSizeLevel ?? this.fontSizeLevel,
      customMiddlePageAdViewId:
          customMiddlePageAdViewId ?? this.customMiddlePageAdViewId,
      middlePageInterval: middlePageInterval ?? this.middlePageInterval,
      customMiddleLineAdViewId:
          customMiddleLineAdViewId ?? this.customMiddleLineAdViewId,
      middleLineStartLine: middleLineStartLine ?? this.middleLineStartLine,
      middleLineInterval: middleLineInterval ?? this.middleLineInterval,
      customBannerAdViewId: customBannerAdViewId ?? this.customBannerAdViewId,
    );
  }

  @override
  String toString() {
    return 'StoryReaderConfig{storyId: $storyId, startChapter: $startChapter}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryReaderConfig &&
        other.storyId == storyId &&
        other.startChapter == startChapter;
  }

  @override
  int get hashCode {
    return storyId.hashCode ^ startChapter.hashCode;
  }
}
