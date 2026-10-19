/// 运行平台信息(请求公共参数: os_type / app_type / app_type_name)
library;

import 'package:flutter/foundation.dart';

class PlatformInfo {
  /// android / ios / harmony / unknown(与H5枚举保持一致)
  static String get osType {
    if (kIsWeb) return 'unknown';
    // 官方 SDK 没有 TargetPlatform.ohos 枚举成员，直接引用会编译失败；
    // 鸿蒙 SDK 下该枚举含 ohos 且要求 switch 穷举。两者兼容做法：
    // 运行时字符串判定 + switch 内 default 兜底。
    if (defaultTargetPlatform.toString().contains('ohos')) return 'harmony';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'unknown';
      default:
        return 'unknown';
    }
  }

  /// 中文名: 安卓 / iOS / 鸿蒙 / 未知设备
  static String get osName {
    if (kIsWeb) return '未知设备';
    if (defaultTargetPlatform.toString().contains('ohos')) return '鸿蒙';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '安卓';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return '未知设备';
      default:
        return '未知设备';
    }
  }

  /// h5 / app(桌面端按 app 处理,与后端枚举一致)
  static String get appType => kIsWeb ? 'h5' : 'app';

  /// H5 / APP
  static String get appTypeName => kIsWeb ? 'H5' : 'APP';
}
