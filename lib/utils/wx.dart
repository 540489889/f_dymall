/// 微信 APP 授权登录统一入口
/// * 条件导出: 移动端(Android/iOS)用 fluwx 实现,web/其他端用空实现
///   —— 避免 web 编译期引入 fluwx(内部 dart:io 会导致 flutter build web 失败)
/// * 用法统一: WxAuth.supported / WxAuth.authCode() / WxAuth.requestMerchantTransfer() / WxAuth.errorMsg(e)
library;

export 'wx_stub.dart' if (dart.library.io) 'wx_native.dart';
