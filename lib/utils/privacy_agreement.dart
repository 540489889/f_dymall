/// 首次启动隐私政策概要同意状态管理
/// * 用 GetStorage 持久化 privacy_agreed 标志
/// * ValueNotifier 用于在 MyApp 中切换「隐私同意页 / 正常启动流程」
library;

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class PrivacyAgreement {
  PrivacyAgreement._();

  static final GetStorage _box = GetStorage();

  /// 是否已同意隐私政策概要(首次进入 App 会弹窗)
  static final ValueNotifier<bool> agreedNotifier = ValueNotifier<bool>(false);

  static bool get agreed => agreedNotifier.value;

  /// 从本地存储读取同意状态(在 main 中 GetStorage.init 后调用)
  static Future<void> init() async {
    try {
      agreedNotifier.value = _box.read<bool>('privacy_agreed') ?? false;
    } catch (e) {
      debugPrint('[PrivacyAgreement] init 异常: $e');
      agreedNotifier.value = false;
    }
  }

  /// 设置同意状态并持久化
  static Future<void> setAgreed(bool value) async {
    agreedNotifier.value = value;
    try {
      await _box.write('privacy_agreed', value);
    } catch (e) {
      debugPrint('[PrivacyAgreement] write 异常: $e');
    }
  }
}
