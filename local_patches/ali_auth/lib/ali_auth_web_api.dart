/// 阿里云号码认证 Web 插件（Dart 封装）—— Web 占位实现
///
/// 说明: Web 平台本就不支持本机号码一键登录(ali_auth 也没有可用的 web JS 实现)。
/// 这里仅提供与原生同名的公开方法签名, 方法体直接返回默认值, 目的是让 Web 编译通过。
/// 业务侧实际使用的是 lib/utils/ali_one_key_web.dart 的占位, 不会走到本文件的逻辑,
/// 因此不需要 dart:js_interop 的静态互操作。

class AliAuthPluginWebApi {
  /// 网络类型检查接口
  Future<String?> getConnection() async => null;

  /// 设置 SDK 是否开启日志。
  Future<void> setLoggerEnable(bool isEnable) async {}

  /// 获取版本号
  Future<String?> getVersion() async => null;

  /// 调用之前先去用户服务端获取 accessToken 和 jwtToken
  Future<void> checkAuthAvailable(
    String accessToken,
    String jwtToken,
    void Function(dynamic status) success,
    void Function(dynamic status) error,
  ) async {
    error('Web 平台不支持号码认证');
  }

  /// 身份鉴权成功后才可调用获取 Token 接口
  Future<void> getVerifyToken(
    void Function(dynamic status) success,
    void Function(dynamic status) error,
  ) async {
    error('Web 平台不支持号码认证');
  }
}
