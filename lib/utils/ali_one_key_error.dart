/// 阿里云号码认证失败信息(带错误码,便于业务层区分"环境不支持"与"其他错误")
/// * 由 ali_one_key_native.dart 抛出,登录页据此决定静默回退还是提示用户
/// * 本文件不依赖 dart:io / ali_auth,Web 端也能引用
class AliOneKeyFailure implements Exception {
  const AliOneKeyFailure(this.code, this.message);

  /// 阿里云返回的错误码(空字符串表示非 SDK 返回的失败,如超时/未配置密钥)
  final String code;

  /// 可读的失败原因
  final String message;

  /// 环境类错误码: 说明这台机器 / 当前网络用不了一键登录
  /// * 600004 获取运营商配置失败(密钥或签名与阿里云后台不一致)
  /// * 600005 终端环境不安全(VPN / 代理)
  /// * 600007 未检测到 SIM 卡
  /// * 600008 未开启移动数据
  /// * 600009 无法判断运营商(连着 WiFi)
  /// * 600024 终端环境检查失败(需开启移动数据)
  /// * 这几个属于"用户改不了或不该被打扰"的情况,业务层静默回退到表单登录
  static const Set<String> envCodes = <String>{
    '600004',
    '600005',
    '600007',
    '600008',
    '600009',
    '600024',
  };

  /// 是否为环境类错误(静默处理,不提示用户)
  bool get isEnvError => envCodes.contains(code);

  @override
  String toString() => message;
}
