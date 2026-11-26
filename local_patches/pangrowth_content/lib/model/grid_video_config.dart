/// 宫格/双Feed 小视频布局类型
enum GridVideoLayout {
  /// 宫格布局，对应 `DPSdk.factory().createGrid(...)`
  grid,

  /// 双 Feed 布局，对应 `DPSdk.factory().createDoubleFeed(...)`
  doubleFeed,
}

/// 宫格卡片样式
enum GridVideoCardStyle {
  /// 普通样式
  normal,

  /// 瀑布流样式
  staggered,
}

/// 宫格/双Feed 小视频配置（对标 DPWidgetGridParams）
class GridVideoConfig {
  /// 卡片样式
  final GridVideoCardStyle? cardStyle;

  /// 场景标识（内容定制业务必传）
  final String? scene;

  /// 是否支持下拉刷新
  final bool? enableRefresh;

  /// 举报页面顶部 padding（单位 dp）
  final double? reportTopPadding;

  /// 自定义扩展参数，直接透传到原生端
  final Map<String, dynamic>? extra;

  const GridVideoConfig({
    this.cardStyle,
    this.scene,
    this.enableRefresh,
    this.reportTopPadding,
    this.extra,
  });

  /// 转换为 Map，仅包含非空字段
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{};

    if (cardStyle != null) {
      map['cardStyle'] = switch (cardStyle!) {
        GridVideoCardStyle.normal => 'normal',
        GridVideoCardStyle.staggered => 'staggered',
      };
    }
    if (scene != null && scene!.isNotEmpty) {
      map['scene'] = scene;
    }
    if (enableRefresh != null) {
      map['enableRefresh'] = enableRefresh;
    }
    if (reportTopPadding != null) {
      map['reportTopPadding'] = reportTopPadding;
    }
    if (extra != null && extra!.isNotEmpty) {
      map['extra'] = extra;
    }

    return map;
  }

  /// 从 Map 恢复配置
  factory GridVideoConfig.fromMap(Map<String, dynamic> map) {
    GridVideoCardStyle? parseStyle(String? value) {
      return switch (value) {
        'staggered' => GridVideoCardStyle.staggered,
        'normal' => GridVideoCardStyle.normal,
        _ => null,
      };
    }

    return GridVideoConfig(
      cardStyle: parseStyle(map['cardStyle'] as String?),
      scene: map['scene'] as String?,
      enableRefresh: map['enableRefresh'] as bool?,
      reportTopPadding: (map['reportTopPadding'] as num?)?.toDouble(),
      extra: (map['extra'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : null,
    );
  }

  GridVideoConfig copyWith({
    GridVideoCardStyle? cardStyle,
    String? scene,
    bool? enableRefresh,
    double? reportTopPadding,
    Map<String, dynamic>? extra,
  }) {
    return GridVideoConfig(
      cardStyle: cardStyle ?? this.cardStyle,
      scene: scene ?? this.scene,
      enableRefresh: enableRefresh ?? this.enableRefresh,
      reportTopPadding: reportTopPadding ?? this.reportTopPadding,
      extra: extra ?? this.extra,
    );
  }

  @override
  String toString() {
    return 'GridVideoConfig(cardStyle: $cardStyle, scene: $scene, enableRefresh: $enableRefresh, reportTopPadding: $reportTopPadding)';
  }
}
