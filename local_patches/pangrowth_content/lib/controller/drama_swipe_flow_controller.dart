import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短剧滑滑流控制器
///
/// 封装滑滑流ID管理和控制方法，简化使用。
/// 配合 DramaSwipeFlowNativeView 使用，自动处理滑滑流生命周期。
///
/// 使用示例：
/// ```dart
/// final controller = DramaSwipeFlowController();
///
/// DramaSwipeFlowNativeView(
///   config: DramaSwipeFlowConfig(...),
///   controller: controller,
/// )
///
/// // 在 TabBar 切换时控制暂停/恢复
/// controller.pause();  // 切换走时暂停
/// controller.resume(); // 切换回来时恢复
///
/// // 销毁时自动调用
/// controller.dispose();
/// ```
class DramaSwipeFlowController {
  String? _swipeFlowId;

  /// 初始化滑滑流ID（由 Widget 内部调用）
  void initialize(String swipeFlowId) {
    _swipeFlowId = swipeFlowId;
    debugPrint('DramaSwipeFlowController: 滑滑流ID已初始化 - $swipeFlowId');
  }

  /// 清除滑滑流ID
  Future<void> dispose() async {
    if (_swipeFlowId != null && _swipeFlowId!.isNotEmpty) {
      debugPrint('DramaSwipeFlowController: 清除滑滑流ID - $_swipeFlowId');
    }
    _swipeFlowId = null;
  }

  /// 滑滑流是否已准备就绪
  bool get isReady => _swipeFlowId != null && _swipeFlowId!.isNotEmpty;

  /// 获取滑滑流ID（如果需要直接访问）
  String? get swipeFlowId => _swipeFlowId;

  /// 私有方法：检查滑滑流是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('滑滑流未初始化或已销毁，无法调用控制方法');
    }
  }

  /// 暂停滑滑流播放
  ///
  /// 适用于 TabBar 切换等场景，需要暂停滑滑流播放时调用。
  ///
  /// **实现方式**:
  /// - **Android**: 通过设置 `Fragment.userVisibleHint = false` 来暂停播放
  /// - **iOS**: 通过调用 `DJXDrawVideoViewController.drawVideoViewControllerDidDisappear()` SDK专用方法
  ///
  /// **使用场景**:
  /// - ✅ 短时间切换（如 TabBar 切换、临时遮挡）
  /// - ✅ ViewPager 等多页面场景的可见性控制
  /// - ❌ 长时间停止播放建议直接销毁视图，需要时重新创建
  Future<void> pause() async {
    _ensureReady();
    try {
      await PangrowthContent.pauseDramaSwipeFlow(_swipeFlowId!);
      debugPrint('DramaSwipeFlowController: 滑滑流已暂停 - $_swipeFlowId');
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 暂停滑滑流失败 - $e');
      rethrow;
    }
  }

  /// 恢复滑滑流播放
  ///
  /// 适用于 TabBar 切换回来等场景，需要恢复滑滑流播放时调用。
  ///
  /// **实现方式**:
  /// - **Android**: 通过设置 `Fragment.userVisibleHint = true` 来恢复播放
  /// - **iOS**: 通过调用 `DJXDrawVideoViewController.drawVideoViewControllerDidAppear()` SDK专用方法
  ///
  /// **使用场景**:
  /// - ✅ 短时间切换（如 TabBar 切换、临时遮挡）
  /// - ✅ ViewPager 等多页面场景的可见性控制
  /// - ❌ 长时间停止播放建议直接销毁视图，需要时重新创建
  Future<void> resume() async {
    _ensureReady();
    try {
      await PangrowthContent.resumeDramaSwipeFlow(_swipeFlowId!);
      debugPrint('DramaSwipeFlowController: 滑滑流已恢复 - $_swipeFlowId');
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 恢复滑滑流失败 - $e');
      rethrow;
    }
  }

  /// 跳转到指定播放位置
  /// [time] 跳转位置（毫秒）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.seekTo(time)`
  /// - ✅ iOS: `DJXDrawVideoViewController.seekVideoToMSeconds(time)`
  Future<bool> seekTo(int time) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.seekToDramaSwipeFlow(
        _swipeFlowId!,
        time,
      );
      debugPrint('DramaSwipeFlowController: 跳转播放进度到 ${time}ms - $_swipeFlowId');
      return result;
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 跳转播放进度失败 - $e');
      rethrow;
    }
  }

  /// 设置当前页面位置
  /// [position] 页面索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentPage(position)`
  /// - ❌ iOS: 无对应方法
  ///
  /// 🔵 Android 独有方法
  Future<bool> setCurrentPage(int position) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.setCurrentPageDramaSwipeFlow(
        _swipeFlowId!,
        position,
      );
      debugPrint('DramaSwipeFlowController: 设置当前页到 $position - $_swipeFlowId');
      return result;
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 设置当前页失败 - $e');
      rethrow;
    }
  }

  /// 获取当前短剧集数索引
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.getCurrentDramaIndex()`
  /// - ❌ iOS: 无对应方法
  ///
  /// 🔵 Android 独有方法
  Future<int> getCurrentDramaIndex() async {
    _ensureReady();
    try {
      final index = await PangrowthContent.getCurrentDramaIndexDramaSwipeFlow(
        _swipeFlowId!,
      );
      debugPrint('DramaSwipeFlowController: 获取当前集数 $index - $_swipeFlowId');
      return index;
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 获取当前集数失败 - $e');
      rethrow;
    }
  }

  /// 设置当前短剧集数索引
  /// [index] 集数索引值
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.setCurrentDramaIndex(index)`
  /// - ✅ iOS: `DJXDrawVideoViewController.setCurrentPlayletEpisode(index)`
  Future<bool> setCurrentDramaIndex(int index) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.setCurrentDramaIndexDramaSwipeFlow(
        _swipeFlowId!,
        index,
      );
      debugPrint('DramaSwipeFlowController: 设置当前集数到 $index - $_swipeFlowId');
      return result;
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 设置当前集数失败 - $e');
      rethrow;
    }
  }

  /// 打开更多弹窗（举报、设置等）
  ///
  /// **平台支持**:
  /// - ✅ Android: `IDJXWidget.openMoreDialog()`
  /// - ✅ iOS: `DJXDrawVideoViewController.playletMoreButtonClick()`
  Future<bool> openMoreDialog() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.openMoreDialogDramaSwipeFlow(
        _swipeFlowId!,
      );
      debugPrint('DramaSwipeFlowController: 打开更多弹窗 - $_swipeFlowId');
      return result;
    } catch (e) {
      debugPrint('DramaSwipeFlowController: 打开更多弹窗失败 - $e');
      rethrow;
    }
  }
}
