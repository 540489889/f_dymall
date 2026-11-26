import '../model/story_info.dart';

/// 短故事聚合页事件监听器
///
/// 用于监听短故事聚合页的各种事件，包括生命周期和交互事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class StoryHomeListener {
  /// 短故事聚合页创建完成并准备就绪
  /// [homeId] 聚合页唯一标识
  final void Function(String homeId)? onStoryHomeReady;

  /// 短故事聚合页发生错误
  /// [error] 错误信息
  final void Function(String error)? onStoryHomeError;

  /// 短故事项点击
  /// [story] 被点击的短故事信息
  final void Function(StoryInfo story)? onItemClick;

  /// 短故事聚合页销毁
  final void Function()? onStoryHomeDisposed;

  const StoryHomeListener({
    this.onStoryHomeReady,
    this.onStoryHomeError,
    this.onItemClick,
    this.onStoryHomeDisposed,
  });
}
