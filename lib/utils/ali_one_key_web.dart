/// 阿里云号码认证: Web 占位实现
/// * Web 不支持本机号码一键登录(ali_auth 无可用 web 实现),
///   所有公开方法直接返回"不支持",调用方(登录页)据此隐藏一键登录入口
/// * 本文件不 import dart:io / package:ali_auth,避免 Web 编译期把这些不兼容代码拉进来

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

class AliOneKey {
  /// 当前平台是否有实现(Web 为 false)
  static bool get supported => false;

  /// 是否已配置密钥(Web 无密钥,返回 false)
  static bool get configured => false;

  /// 是否可以展示入口(Web 为 false,登录页据此隐藏一键登录按钮)
  static bool get available => false;

  /// 拉起一键登录授权页: Web 不支持,直接抛错
  static Future<String> login({Duration timeout = const Duration(seconds: 30)}) async {
    if (kDebugMode) debugPrint('[ali] Web 不支持一键登录');
    throw '当前环境(Web)不支持一键登录';
  }

  /// 主动关闭授权页(Web 空实现)
  static Future<void> quit() async {}

  /// 销毁监听(Web 空实现)
  static void dispose() {}
}
