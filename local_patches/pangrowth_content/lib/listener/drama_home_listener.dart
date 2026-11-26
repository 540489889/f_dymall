import '../model/drama_info.dart';

/// 短剧聚合页事件监听器
///
/// 用于监听短剧聚合页的各种事件，包括生命周期和交互事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class DramaHomeListener {
  /// 聚合页创建完成并准备就绪
  /// [homeId] 聚合页唯一标识
  final void Function(String homeId)? onHomeReady;

  /// 聚合页发生错误
  /// [error] 错误信息
  final void Function(String error)? onHomeError;

  /// 短剧项点击（Android专用）
  /// [drama] 被点击的短剧信息
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android独有
  /// - Android: `IDJXDramaHomeListener.onItemClick(drama, map)`
  ///
  /// 🔵 Android 独有回调
  final void Function(DramaInfo drama, Map<String, dynamic>? extraInfo)?
  onItemClick;

  /// 搜索触发
  /// [keyword] 搜索关键词
  final void Function(String keyword)? onSearch;

  /// 分类切换
  /// [category] 切换到的分类
  final void Function(String category)? onCategorySwitch;

  /// 聚合页销毁
  final void Function()? onHomeDisposed;

  const DramaHomeListener({
    this.onHomeReady,
    this.onHomeError,
    this.onItemClick,
    this.onSearch,
    this.onCategorySwitch,
    this.onHomeDisposed,
  });
}
