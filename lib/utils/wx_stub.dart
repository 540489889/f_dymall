/// 微信登录: web / 桌面端空实现
/// * fluwx 只有 Android / iOS 实现,web 端编译期不应引入它(会引入 dart:io)
/// * 这里保持与 wx_native.dart 完全一致的 API,所有能力返回「不支持」
library;

class WxAuth {
  /// 当前平台没有实现
  static bool get supported => false;

  /// 未配置
  static bool get configured => false;

  /// 永远注册失败
  static Future<bool> init() async => false;

  /// 永远视为未安装
  static Future<bool> isInstalled() async => false;

  /// 直接抛错(调用方 toast 提示)
  static Future<String> authCode({Duration timeout = const Duration(seconds: 60)}) async {
    throw '当前环境不支持微信登录';
  }

  /// 统一错误提示
  static String errorMsg(dynamic error) {
    final String message = '$error'.trim();
    return message.isEmpty ? '微信登录失败' : message;
  }
}
