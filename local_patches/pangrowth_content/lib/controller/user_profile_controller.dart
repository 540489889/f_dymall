import 'package:flutter/foundation.dart';

import '../pangrowth_content.dart';

/// 个人主页 NativeView 控制器
///
/// 对应穿山甲内容 SDK 的 `DPWidgetUserProfileParam` 组件。
/// 用于控制刷新、返回键校验等行为。
class UserProfileController {
  String? _profileId;

  /// 是否已经绑定原生实例
  bool get isReady => _profileId != null && _profileId!.isNotEmpty;

  /// 当前绑定的个人主页 ID
  String? get profileId => _profileId;

  /// 由 Widget 内部调用，初始化 profileId
  void initialize(String profileId) {
    _profileId = profileId;
    debugPrint('UserProfileController: profileId initialized -> $profileId');
  }

  /// 销毁个人主页实例
  Future<void> dispose() async {
    if (_profileId != null && _profileId!.isNotEmpty) {
      try {
        await PangrowthContent.destroyUserProfile(_profileId!);
      } catch (error) {
        debugPrint('UserProfileController: destroy failed -> $error');
      }
    }
    _profileId = null;
  }

  void _ensureReady() {
    if (!isReady) {
      throw StateError(
        'UserProfileController: profile view is not initialized or already disposed.',
      );
    }
  }

  /// 刷新页面
  Future<void> refresh() async {
    _ensureReady();
    await PangrowthContent.refreshUserProfile(_profileId!);
  }

  /// 返回场景时的挽留刷新
  Future<void> backRefresh() async {
    _ensureReady();
    await PangrowthContent.backRefreshUserProfile(_profileId!);
  }

  /// 校验返回键是否可以直接关闭页面
  Future<bool> canBackPress() async {
    _ensureReady();
    return PangrowthContent.canBackPressUserProfile(_profileId!);
  }
}
