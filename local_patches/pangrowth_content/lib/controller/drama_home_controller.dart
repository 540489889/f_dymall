import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短剧聚合页控制器
///
/// 封装聚合页ID管理和控制方法，简化使用。
/// 配合 DramaHomeNativeView 使用，自动处理聚合页生命周期。
///
/// 使用示例：
/// ```dart
/// final controller = DramaHomeController();
///
/// DramaHomeNativeView(
///   config: DramaHomeConfig(...),
///   controller: controller,
/// )
///
/// // 控制播放和页面切换
/// controller.seekTo(5000);  // 跳转到5秒位置
/// controller.setCurrentPage(2);  // 切换到第3页
/// controller.setCurrentDramaIndex(10);  // 切换到第11集
/// controller.openMoreDialog();  // 打开更多弹窗
/// controller.backRefresh();  // 返回并刷新
///
/// // 销毁时自动调用
/// controller.dispose();
/// ```
class DramaHomeController {
  String? _homeId;

  /// 初始化聚合页ID（由 Widget 内部调用）
  void initialize(String homeId) {
    _homeId = homeId;
    debugPrint('DramaHomeController: 聚合页ID已初始化 - $homeId');
  }

  /// 清除聚合页ID
  Future<void> dispose() async {
    if (_homeId != null && _homeId!.isNotEmpty) {
      debugPrint('DramaHomeController: 清除聚合页ID - $_homeId');
    }
    _homeId = null;
  }

  /// 聚合页是否已准备就绪
  bool get isReady => _homeId != null && _homeId!.isNotEmpty;

  /// 获取聚合页ID（如果需要直接访问）
  String? get homeId => _homeId;

  /// 私有方法：检查聚合页是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('聚合页未初始化或已销毁，无法调用控制方法');
    }
  }

  /// 跳转到指定播放位置
  /// [time] 跳转位置（毫秒）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.seekTo(time)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<bool> seekTo(int time) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.seekToDramaHome(_homeId!, time);
      debugPrint('DramaHomeController: 跳转播放进度到 ${time}ms - $_homeId');
      return result;
    } catch (e) {
      debugPrint('DramaHomeController: 跳转播放进度失败 - $e');
      rethrow;
    }
  }

  /// 设置当前页面位置
  /// [position] 页面索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentPage(position)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<bool> setCurrentPage(int position) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.setCurrentPageDramaHome(
        _homeId!,
        position,
      );
      debugPrint('DramaHomeController: 设置当前页到 $position - $_homeId');
      return result;
    } catch (e) {
      debugPrint('DramaHomeController: 设置当前页失败 - $e');
      rethrow;
    }
  }

  /// 获取当前短剧集数索引
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.getCurrentDramaIndex()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<int> getCurrentDramaIndex() async {
    _ensureReady();
    try {
      final index = await PangrowthContent.getCurrentDramaIndexDramaHome(
        _homeId!,
      );
      debugPrint('DramaHomeController: 获取当前集数 $index - $_homeId');
      return index;
    } catch (e) {
      debugPrint('DramaHomeController: 获取当前集数失败 - $e');
      rethrow;
    }
  }

  /// 设置当前短剧集数索引
  /// [index] 集数索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentDramaIndex(index)`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<bool> setCurrentDramaIndex(int index) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.setCurrentDramaIndexDramaHome(
        _homeId!,
        index,
      );
      debugPrint('DramaHomeController: 设置当前集数到 $index - $_homeId');
      return result;
    } catch (e) {
      debugPrint('DramaHomeController: 设置当前集数失败 - $e');
      rethrow;
    }
  }

  /// 打开更多弹窗（举报、设置等）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.openMoreDialog()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<bool> openMoreDialog() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.openMoreDialogDramaHome(_homeId!);
      debugPrint('DramaHomeController: 打开更多弹窗 - $_homeId');
      return result;
    } catch (e) {
      debugPrint('DramaHomeController: 打开更多弹窗失败 - $e');
      rethrow;
    }
  }

  /// 返回并刷新页面
  ///
  /// 用于从详情页返回聚合页时刷新数据。
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.backRefresh()`
  /// - ❌ iOS: DramaHome不支持iOS
  ///
  /// 🔵 Android 独有方法
  Future<bool> backRefresh() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.backRefreshDramaHome(_homeId!);
      debugPrint('DramaHomeController: 返回并刷新 - $_homeId');
      return result;
    } catch (e) {
      debugPrint('DramaHomeController: 返回并刷新失败 - $e');
      rethrow;
    }
  }
}
