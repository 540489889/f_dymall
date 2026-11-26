import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短故事聚合页控制器
///
/// 封装 widgetId 管理和聚合页控制方法，简化使用。
/// 配合 StoryHomeNativeView 使用，自动处理聚合页生命周期。
///
/// 使用示例：
/// ```dart
/// final controller = StoryHomeController();
///
/// StoryHomeNativeView(
///   onCreated: (viewId) {
///     controller.initialize(viewId);
///   },
/// )
///
/// // 手动展示聚合页(如果需要)
/// await controller.show();
///
/// // 销毁时自动调用
/// controller.dispose();
/// ```
class StoryHomeController {
  String? _widgetId;

  /// 初始化widgetId（由 Widget 内部调用）
  void initialize(String widgetId) {
    _widgetId = widgetId;
    debugPrint('StoryHomeController: widgetId已初始化 - $widgetId');
  }

  /// 清除widgetId并销毁聚合页实例
  Future<void> dispose() async {
    if (_widgetId != null && _widgetId!.isNotEmpty) {
      debugPrint('StoryHomeController: 正在销毁聚合页实例 - $_widgetId');
      try {
        await PangrowthContent.destroyStoryHome(_widgetId!);
      } catch (e) {
        debugPrint('StoryHomeController: 销毁聚合页失败 - $e');
      }
    }
    _widgetId = null;
  }

  /// 聚合页是否已准备就绪
  bool get isReady => _widgetId != null && _widgetId!.isNotEmpty;

  /// 获取widgetId（如果需要直接访问）
  String? get widgetId => _widgetId;

  /// 私有方法：检查聚合页是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('聚合页未初始化或已销毁，无法调用控制方法');
    }
  }

  /// 展示短故事聚合页
  ///
  /// 调用原生SDK展示已创建的聚合页。
  /// 如果聚合页未创建或已销毁，会抛出 StateError。
  Future<Map<String, dynamic>> show() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.showStoryHome(_widgetId!);
      debugPrint('StoryHomeController: 聚合页已展示 - $_widgetId');
      return result;
    } catch (e) {
      debugPrint('StoryHomeController: 展示聚合页失败 - $e');
      rethrow;
    }
  }

  /// 手动销毁聚合页实例
  ///
  /// 注意：通常在 dispose() 中自动调用，无需手动调用。
  /// 如果需要在Widget销毁前提前释放资源，可以调用此方法。
  Future<bool> destroy() async {
    _ensureReady();
    try {
      final destroyed = await PangrowthContent.destroyStoryHome(_widgetId!);
      if (destroyed) {
        _widgetId = null;
      }
      return destroyed;
    } catch (e) {
      debugPrint('StoryHomeController: 销毁聚合页失败 - $e');
      rethrow;
    }
  }
}
