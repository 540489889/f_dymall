import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短故事阅读器控制器
///
/// 用于控制阅读器的播放、暂停、章节切换等功能
///
/// 使用方式:
/// ```dart
/// final controller = StoryReaderController();
///
/// StoryReaderNativeView(
///   config: StoryReaderConfig(storyId: 123),
///   controller: controller,
/// )
///
/// // 跳转到指定章节
/// controller.jumpToChapter(5);
///
/// // 收藏/取消收藏
/// controller.toggleFavorite();
/// ```
class StoryReaderController {
  String? _readerId;
  bool _isInitialized = false;
  bool _disposed = false;

  /// 阅读器ID
  String? get readerId => _readerId;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否已销毁
  bool get isDisposed => _disposed;

  /// 初始化控制器
  ///
  /// 由NativeView自动调用,无需手动调用
  void initialize(String readerId) {
    if (_disposed) {
      debugPrint('StoryReaderController: 控制器已销毁,无法初始化');
      return;
    }

    _readerId = readerId;
    _isInitialized = true;
    debugPrint('StoryReaderController: 控制器已初始化 readerId=$readerId');
  }

  /// 跳转到指定章节
  ///
  /// [chapter] 章节索引(从0开始)
  Future<void> jumpToChapter(int chapter) async {
    if (!_checkInitialized('jumpToChapter')) return;

    try {
      await PangrowthContent.invoke('storyReaderJumpToChapter', {
        'readerId': _readerId,
        'chapter': chapter,
      });
    } catch (e) {
      debugPrint('StoryReaderController: jumpToChapter失败: $e');
    }
  }

  /// 切换收藏状态
  Future<void> toggleFavorite() async {
    if (!_checkInitialized('toggleFavorite')) return;

    try {
      await PangrowthContent.invoke('storyReaderToggleFavorite', {
        'readerId': _readerId,
      });
    } catch (e) {
      debugPrint('StoryReaderController: toggleFavorite失败: $e');
    }
  }

  /// 获取当前章节
  Future<int?> getCurrentChapter() async {
    if (!_checkInitialized('getCurrentChapter')) return null;

    try {
      final result = await PangrowthContent.invoke(
        'storyReaderGetCurrentChapter',
        {'readerId': _readerId},
      );
      return result['chapter'] as int?;
    } catch (e) {
      debugPrint('StoryReaderController: getCurrentChapter失败: $e');
      return null;
    }
  }

  /// 获取阅读进度
  ///
  /// 返回值范围: 0-100
  Future<double?> getProgress() async {
    if (!_checkInitialized('getProgress')) return null;

    try {
      final result = await PangrowthContent.invoke('storyReaderGetProgress', {
        'readerId': _readerId,
      });
      return result['progress'] as double?;
    } catch (e) {
      debugPrint('StoryReaderController: getProgress失败: $e');
      return null;
    }
  }

  /// 设置字体大小
  ///
  /// [fontSize] 字体大小(单位: sp)
  Future<void> setFontSize(int fontSize) async {
    if (!_checkInitialized('setFontSize')) return;

    try {
      await PangrowthContent.invoke('storyReaderSetFontSize', {
        'readerId': _readerId,
        'fontSize': fontSize,
      });
    } catch (e) {
      debugPrint('StoryReaderController: setFontSize失败: $e');
    }
  }

  /// 销毁控制器
  ///
  /// 由NativeView自动调用,无需手动调用
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _isInitialized = false;
    _readerId = null;
    debugPrint('StoryReaderController: 控制器已销毁');
  }

  /// 检查是否已初始化
  bool _checkInitialized(String methodName) {
    if (_disposed) {
      debugPrint('StoryReaderController: $methodName失败 - 控制器已销毁');
      return false;
    }

    if (!_isInitialized || _readerId == null) {
      debugPrint('StoryReaderController: $methodName失败 - 控制器未初始化');
      return false;
    }

    return true;
  }
}
