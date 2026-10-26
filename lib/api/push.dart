/// 极光推送(离线推送)接口
/// * 对齐后端《APP推送接口文档》: 只接 bind / unbind 两个
///   (消息列表/未读/已读/删除/点击上报属于「消息中心」, 暂不接入)
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    final Map<String, dynamic> payload = <String, dynamic>{
      'registration_id': registrationId,
      'platform': platform,
      'app_type': appType,
      'device_brand': deviceBrand,
      'device_model': deviceModel,
      'system_version': systemVersion,
      'app_version': appVersion,
    };
    debugPrint('[push][bind] >>> 请求参数: $payload');
    try {
      final dynamic res = await Request().post(
        '/api/push/bind',
        data: payload,
      );
      debugPrint('[push][bind] <<< 响应结果: ${res ?? 'null'}');
      return res != null;
    } catch (e) {
      debugPrint('[push][bind] <<< 请求异常: $e');
      // 上报失败不影响任何功能, 下次启动/登录/rid 变化会再试
      return false;
    }
  }

  /// 解绑(POST /api/push/unbind)
  /// * 退出登录 / 切换账号 / 用户关闭推送时调用, 否则换账号后会收到上一账号的消息
  /// * 后端要求: 必须带 **registration_id**(本机设备) + **token**(拦截器从 AuthStore 取,
  ///   但退出时 token 已被 logout 清空, 所以这里用 [token] 显式带上本次登录的 token)
  /// * 退出时 [registrationId] 用本机真实 rid, [token] 用登录时记录下来的 token
  static Future<bool> unbind({
    required String registrationId,
    String token = '',
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'registration_id': registrationId,
    };
    debugPrint('[push][unbind] >>> 请求参数: $payload');
    debugPrint('[push][unbind] >>> 携带token: ${token.isNotEmpty ? '是(长度=${token.length})' : '否'}');
    try {
      // 退出时 AuthStore.authorization 已清空, 拦截器取不到 token, 这里用 Options 头显式带上。
      // 拦截器只在自身 token 非空时才写 'token' 头, 退出时它为空不会覆盖我们的值。
      final Options options = Options(
        headers: <String, dynamic>{
          if (token.isNotEmpty) 'token': token,
        },
      );
      final dynamic res = await Request().post(
        '/api/push/unbind',
        data: payload,
        options: options,
      );
      debugPrint('[push][unbind] <<< 响应结果: ${res ?? 'null'}');
      return res != null;
    } catch (e) {
      debugPrint('[push][unbind] <<< 请求异常: $e');
      return false;
    }
  }
}
