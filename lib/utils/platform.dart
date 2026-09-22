/// 运行平台信息(请求公共参数: os_type / app_type / app_type_name)
library;

import 'package:flutter/foundation.dart';

class PlatformInfo {
  /// android / ios / unknown(与H5枚举保持一致)
  static String get osType {
    if (kIsWeb) return 'unknown';
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
    }
  }

  /// 中文名: 安卓 / iOS / 未知设备
  static String get osName {
    if (kIsWeb) return '未知设备';
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
    }
  }

  /// h5 / app(桌面端按 app 处理,与后端枚举一致)
  static String get appType => kIsWeb ? 'h5' : 'app';

  /// H5 / APP
  static String get appTypeName => kIsWeb ? 'H5' : 'APP';
}
