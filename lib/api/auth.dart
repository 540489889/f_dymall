/// 登录相关接口
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class AuthApi {
  /// 账号密码登录
  /// 返回 {'token': 登录凭证, 'data': 接口原始 data}
  /// * [username] 用户名/手机号
  /// * [password] 密码
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    // Request 已统一解包: code == 0 时返回业务 data
    final dynamic res = await Request().post(
      '/api/login/login',
      data: <String, dynamic>{'username': username, 'password': password},
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 从接口 data 中取登录凭证(兼容字符串与多种字段名)
  static String _pickToken(dynamic data) {
    if (data == null) return '';
    if (data is String) return data.trim();
    if (data is! Map) return '';

    const List<String> tokenKeys = <String>['token', 'access_token', 'accessToken', 'authorization', 'api_token'];
    for (final String key in tokenKeys) {
      final dynamic value = data[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
    }

    // 凭证可能在 member / user_info 等子对象里
    const List<String> dataKeys = <String>['member', 'member_info', 'user', 'user_info', 'userInfo'];
    for (final String key in dataKeys) {
      final dynamic value = data[key];
      if (value is Map) {
        final String token = _pickToken(value);
        if (token.isNotEmpty) return token;
      }
    }
    return '';
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.trim();
    return message.isEmpty ? '登录失败' : message;
  }
}
