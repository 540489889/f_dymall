/// 短故事聚合页配置参数
class StoryHomeConfig {
  /// 是否支持下拉刷新
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：false（不支持下拉刷新）
  final bool? canPullRefresh;

  /// 布局Y轴偏移量，单位dp
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：-1（无偏移）
  final int? topOffset;

  /// 推荐榜请求分页大小
  ///
  /// **平台限制**：仅Android支持，iOS上此参数会被忽略
  ///
  /// @android
  /// SDK默认值：9
  final int? recPageSize;

  /// 阅读器的个性化配置
  /// 对应原生 NovReaderConfig / MNStoryReaderOpenParams 的自定义字段
  ///
  /// Android支持的配置项请参考官方文档
  /// iOS支持的配置项：
  /// - customRewardAD: 是否自定义激励广告
  /// - addCustomRewardPoint: 是否增加自定义解锁点
  /// - showCustomBottomBannerAD: 是否显示banner广告
  /// - showCustomMiddleAD: 是否显示章间广告
  /// - pageIntervalForMiddleAD: 章间广告显示间隔
  final Map<String, dynamic>? readerConfig;

  /// 透传给原生侧的额外配置项
  final Map<String, dynamic>? extra;

  const StoryHomeConfig({
    this.canPullRefresh,
    this.topOffset,
    this.recPageSize,
    this.readerConfig,
    this.extra,
  });

  /// 转换为Map，用于传递给原生端
  /// 只传递用户明确指定的非null参数，让SDK使用原生默认值
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};

    // 只传递非null参数
    if (canPullRefresh != null) {
      map['canPullRefresh'] = canPullRefresh;
    }
    if (topOffset != null) {
      map['topOffset'] = topOffset;
    }
    if (recPageSize != null) {
      map['recPageSize'] = recPageSize;
    }

    if (readerConfig != null && readerConfig!.isNotEmpty) {
      map['readerConfig'] = Map<String, dynamic>.from(readerConfig!);
    }

    if (extra != null && extra!.isNotEmpty) {
      map['extra'] = Map<String, dynamic>.from(extra!);
    }

    return map;
  }

  /// 从Map创建配置对象
  factory StoryHomeConfig.fromMap(Map<String, dynamic> map) {
    return StoryHomeConfig(
      canPullRefresh: map['canPullRefresh'] as bool?,
      topOffset: map['topOffset'] as int?,
      recPageSize: map['recPageSize'] as int?,
      readerConfig: (map['readerConfig'] as Map?)?.cast<String, dynamic>(),
      extra: (map['extra'] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  String toString() {
    return 'StoryHomeConfig(canPullRefresh: $canPullRefresh, topOffset: $topOffset, recPageSize: $recPageSize, readerConfig: $readerConfig, extra: $extra)';
  }
}
