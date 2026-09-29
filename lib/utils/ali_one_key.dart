/// 阿里云号码认证一键登录(ali_auth)平台分发入口
/// * 存在 dart:io 的平台(Android / iOS)走真实实现 ali_one_key_native.dart
/// * Web(dart:io 不存在)走占位实现 ali_one_key_web.dart,直接返回"不支持"
/// 通过条件导出,使 Web 编译期完全不引入 ali_auth,规避其 web 实现与当前 Dart SDK 不兼容的问题
export 'ali_one_key_web.dart'
    if (dart.library.io) 'ali_one_key_native.dart';
