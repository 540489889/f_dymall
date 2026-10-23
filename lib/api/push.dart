/// 极光推送(离线推送)接口
/// * 对齐后端《APP推送接口文档》: 只接 bind / unbind 两个
///   (消息列表/未读/已读/删除/点击上报属于「消息中心」, 暂不接入)
library;

import '../utils/request.dart';

class PushApi {
  /// 绑定设备(POST /api/push/bind)
  /// * APP 拿到 registrationID 后调用; 未登录也可调用(服务端只登记设备, 不清 member_id),
  ///   **登录成功后再带 token 调一次**才会把设备与用户绑定
  /// * 参数与后端文档一致: registration_id / platform / app_type /
  ///   device_brand / device_model / system_version / app_version
  /// * token 由 Request 拦截器自动从 AuthStore 带上, 这里不用手动传
  static Future<bool> bind({
    required String registrationId,
    required String platform, // ios / android(小写, 取 PlatformInfo.osType)
    String appType = 'mall',
    String deviceBrand = '',
    String deviceModel = '',
    String systemVersion = '',
    String appVersion = '',
  }) async {
    if (registrationId.isEmpty) return false;
    try {
      final dynamic res = await Request().post(
        '/api/push/bind',
        data: <String, dynamic>{
          'registration_id': registrationId,
          'platform': platform,
          'app_type': appType,
          'device_brand': deviceBrand,
          'device_model': deviceModel,
          'system_version': systemVersion,
          'app_version': appVersion,
        },
      );
      return res != null;
    } catch (_) {
      // 上报失败不影响任何功能, 下次启动/登录/rid 变化会再试
      return false;
    }
  }

  /// 解绑(POST /api/push/unbind)
  /// * 退出登录 / 切换账号 / 用户关闭推送时调用, 否则换账号后会收到上一账号的消息
  /// * [registrationId] 不传且已登录时, 服务端解绑该用户**所有**设备
  static Future<bool> unbind({String registrationId = ''}) async {
    try {
      final dynamic res = await Request().post(
        '/api/push/unbind',
        data: <String, dynamic>{'registration_id': registrationId},
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }
}
