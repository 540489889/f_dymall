/// 短故事阅读器事件监听器
///
/// 使用Listener模式统一管理所有回调事件,与gromore_ads保持一致的设计风格。
///
/// 示例:
/// ```dart
/// StoryReaderNativeView(
///   config: StoryReaderConfig(storyId: 123),
///   listener: StoryReaderListener(
///     onReaderReady: (readerId) => print('阅读器就绪: $readerId'),
///     onReaderError: (error) => print('阅读器错误: $error'),
///     onChapterChanged: (chapter) => print('章节切换: $chapter'),
///   ),
/// )
/// ```
class StoryReaderListener {
  /// 阅读器创建完成回调
  ///
  /// [readerId] 阅读器ID
  final void Function(String readerId)? onReaderReady;

  /// 阅读器销毁回调
  final void Function()? onReaderDisposed;

  /// 阅读器错误回调
  ///
  /// [error] 错误信息
  final void Function(String error)? onReaderError;

  /// 章节切换回调
  ///
  /// [chapter] 当前章节索引
  final void Function(int chapter)? onChapterChanged;

  /// 阅读进度变化回调
  ///
  /// [progress] 阅读进度百分比(0-100)
  final void Function(double progress)? onProgressChanged;

  /// 收藏状态变化回调
  ///
  /// [isFavorite] 是否已收藏
  final void Function(bool isFavorite)? onFavoriteChanged;

  /// 章间广告显示回调
  ///
  /// 当章间广告即将显示时触发
  final void Function()? onMiddlePageAdShow;

  /// 章间广告点击回调
  final void Function()? onMiddlePageAdClick;

  /// 章间广告关闭回调
  final void Function()? onMiddlePageAdClose;

  /// 段间广告显示回调
  ///
  /// 当段间广告即将显示时触发
  /// [lineNumber] 广告插入的行号
  final void Function(int lineNumber)? onMiddleLineAdShow;

  /// 段间广告点击回调
  final void Function()? onMiddleLineAdClick;

  /// Banner广告显示回调
  final void Function()? onBannerAdShow;

  /// Banner广告点击回调
  final void Function()? onBannerAdClick;

  const StoryReaderListener({
    this.onReaderReady,
    this.onReaderDisposed,
    this.onReaderError,
    this.onChapterChanged,
    this.onProgressChanged,
    this.onFavoriteChanged,
    this.onMiddlePageAdShow,
    this.onMiddlePageAdClick,
    this.onMiddlePageAdClose,
    this.onMiddleLineAdShow,
    this.onMiddleLineAdClick,
    this.onBannerAdShow,
    this.onBannerAdClick,
  });

  /// 复制监听器（可修改部分回调）
  StoryReaderListener copyWith({
    void Function(String readerId)? onReaderReady,
    void Function()? onReaderDisposed,
    void Function(String error)? onReaderError,
    void Function(int chapter)? onChapterChanged,
    void Function(double progress)? onProgressChanged,
    void Function(bool isFavorite)? onFavoriteChanged,
    void Function()? onMiddlePageAdShow,
    void Function()? onMiddlePageAdClick,
    void Function()? onMiddlePageAdClose,
    void Function(int lineNumber)? onMiddleLineAdShow,
    void Function()? onMiddleLineAdClick,
    void Function()? onBannerAdShow,
    void Function()? onBannerAdClick,
  }) {
    return StoryReaderListener(
      onReaderReady: onReaderReady ?? this.onReaderReady,
      onReaderDisposed: onReaderDisposed ?? this.onReaderDisposed,
      onReaderError: onReaderError ?? this.onReaderError,
      onChapterChanged: onChapterChanged ?? this.onChapterChanged,
      onProgressChanged: onProgressChanged ?? this.onProgressChanged,
      onFavoriteChanged: onFavoriteChanged ?? this.onFavoriteChanged,
      onMiddlePageAdShow: onMiddlePageAdShow ?? this.onMiddlePageAdShow,
      onMiddlePageAdClick: onMiddlePageAdClick ?? this.onMiddlePageAdClick,
      onMiddlePageAdClose: onMiddlePageAdClose ?? this.onMiddlePageAdClose,
      onMiddleLineAdShow: onMiddleLineAdShow ?? this.onMiddleLineAdShow,
      onMiddleLineAdClick: onMiddleLineAdClick ?? this.onMiddleLineAdClick,
      onBannerAdShow: onBannerAdShow ?? this.onBannerAdShow,
      onBannerAdClick: onBannerAdClick ?? this.onBannerAdClick,
    );
  }
}
