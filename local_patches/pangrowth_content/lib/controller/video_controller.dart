import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 小视频控制器
///
/// 封装 videoId 管理和视频控制方法，简化使用。
/// 配合 VideoNativeView 使用，自动处理视频生命周期。
///
/// 使用示例：
/// ```dart
/// final controller = VideoController();
///
/// VideoNativeView(
///   channelType: 1,
///   contentType: 1,
///   controller: controller,
/// )
///
/// // 销毁时自动调用
/// controller.dispose();
/// ```
class VideoController {
  String? _videoId;

  /// 初始化视频ID（由 Widget 内部调用）
  void initialize(String videoId) {
    _videoId = videoId;
    debugPrint('VideoController: 视频ID已初始化 - $videoId');
  }

  /// 清除视频ID并销毁视频实例
  Future<void> dispose() async {
    if (_videoId != null && _videoId!.isNotEmpty) {
      debugPrint('VideoController: 正在销毁视频实例 - $_videoId');
      try {
        await PangrowthContent.destroyVideo(_videoId!);
      } catch (e) {
        debugPrint('VideoController: 销毁视频失败 - $e');
      }
    }
    _videoId = null;
  }

  /// 视频是否已准备就绪
  bool get isReady => _videoId != null && _videoId!.isNotEmpty;

  /// 获取视频ID（如果需要直接访问）
  String? get videoId => _videoId;

  /// 私有方法：检查视频是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('视频未初始化或已销毁，无法调用控制方法');
    }
  }

  /// 手动销毁视频实例
  /// 注意：通常在 dispose() 中自动调用，无需手动调用
  Future<void> destroy() async {
    _ensureReady();
    await PangrowthContent.destroyVideo(_videoId!);
    _videoId = null;
  }

  /// 暂停视频播放
  ///
  /// 适用于 TabBar 切换等场景，需要暂停视频播放时调用。
  /// 调用 SDK 的 `pauseVideo` 方法，原生层会调用视频 Widget 的生命周期方法。
  Future<void> pause() async {
    _ensureReady();
    try {
      await PangrowthContent.pauseVideo(_videoId!);
      debugPrint('VideoController: 视频已暂停 - $_videoId');
    } catch (e) {
      debugPrint('VideoController: 暂停视频失败 - $e');
      rethrow;
    }
  }

  /// 恢复视频播放
  ///
  /// 适用于 TabBar 切换回来等场景，需要恢复视频播放时调用。
  /// 调用 SDK 的 `resumeVideo` 方法，原生层会调用视频 Widget 的生命周期方法。
  Future<void> resume() async {
    _ensureReady();
    try {
      await PangrowthContent.resumeVideo(_videoId!);
      debugPrint('VideoController: 视频已恢复 - $_videoId');
    } catch (e) {
      debugPrint('VideoController: 恢复视频失败 - $e');
      rethrow;
    }
  }
}
