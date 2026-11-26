import 'package:flutter/foundation.dart';

import '../pangrowth_content.dart';

/// 宫格/双Feed 小视频控制器
///
/// 负责管理 `GridVideoNativeView` 对应的原生实例，提供刷新、滚动、暂停等方法。
class GridVideoController {
  String? _videoId;

  /// 是否已经和原生实例绑定
  bool get isReady => _videoId != null && _videoId!.isNotEmpty;

  /// 当前绑定的视频 ID
  String? get videoId => _videoId;

  /// 由 Widget 内部调用，初始化视频 ID
  void initialize(String videoId) {
    _videoId = videoId;
    debugPrint('GridVideoController: videoId initialized -> $videoId');
  }

  /// 销毁视频实例并清理状态
  Future<void> dispose() async {
    if (_videoId != null && _videoId!.isNotEmpty) {
      try {
        await PangrowthContent.destroyGridVideo(_videoId!);
      } catch (error) {
        debugPrint('GridVideoController: destroy failed -> $error');
      }
    }
    _videoId = null;
  }

  void _ensureReady() {
    if (!isReady) {
      throw StateError(
        'GridVideoController: video is not initialized or already disposed.',
      );
    }
  }

  /// 刷新宫格/双Feed 数据
  Future<void> refresh() async {
    _ensureReady();
    await PangrowthContent.refreshGridVideo(_videoId!);
  }

  /// 滚动到顶部
  Future<void> scrollToTop() async {
    _ensureReady();
    await PangrowthContent.scrollGridVideoToTop(_videoId!);
  }

  /// 返回场景时的挽留刷新
  Future<void> backRefresh() async {
    _ensureReady();
    await PangrowthContent.backRefreshGridVideo(_videoId!);
  }

  /// 控制可见性（配合 Tab 切换暂停/恢复播放）
  Future<void> setUserVisible(bool isVisible) async {
    _ensureReady();
    await PangrowthContent.setGridVideoUserVisible(_videoId!, isVisible);
  }

  /// 校验返回键是否可以直接关闭页面
  Future<bool> canBackPress() async {
    _ensureReady();
    return PangrowthContent.canBackPressGridVideo(_videoId!);
  }
}
