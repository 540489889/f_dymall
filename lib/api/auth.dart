/// 登录 / 注册相关接口(对齐 H5: pages_tool/login)
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class AuthApi {
  /// 账号密码登录(/api/login/login)
  /// 返回 {'token': 登录凭证, 'data': 接口原始 data}
  /// * [username] 用户名
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

  /// 手机号 + 动态码登录(/api/login/mobile)
  /// * [mobile] 手机号
  /// * [key] 发送动态码时返回的 key
  /// * [code] 手机收到的动态码
  static Future<Map<String, dynamic>> loginMobile({
    required String mobile,
    required String key,
    required String code,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/login/mobile',
      data: <String, dynamic>{
        'mobile': mobile,
        'key': key,
        'code': code,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 发送登录动态码(/api/login/mobileCode),返回后续校验用的 key
  static Future<String> loginMobileCode({
    required String mobile,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/login/mobileCode',
      data: <String, dynamic>{
        'mobile': mobile,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return _pickString(res, 'key');
  }

  /// 用户名注册(/api/register/username)
  static Future<Map<String, dynamic>> registerUsername({
    required String username,
    required String password,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/register/username',
      data: <String, dynamic>{
        'username': username,
        'password': password,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 手机号注册(/api/register/mobile)
  /// * [key] 注册动态码返回的 key
  static Future<Map<String, dynamic>> registerMobile({
    required String mobile,
    required String key,
    required String code,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/register/mobile',
      data: <String, dynamic>{
        'mobile': mobile,
        'key': key,
        'code': code,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 发送注册动态码(/api/register/mobileCode),返回 key
  static Future<String> registerMobileCode({
    required String mobile,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/register/mobileCode',
      data: <String, dynamic>{
        'mobile': mobile,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return _pickString(res, 'key');
  }

  /// APP微信登录(/api/login/appWxLogin)
  /// * [code] fluwx 授权拿到的 code(与 H5 uni.login provider=weixin 的 code 等价)
  /// * 返回原始响应 {code, message, data}: code >= 0 成功(data.token);
  ///   code == -10016 表示该微信未绑定账号,需先手机号登录/注册再绑微信
  static Future<Map<String, dynamic>> appWxLogin(String code) {
    return Request().postRaw(
      '/api/login/appWxLogin',
      data: <String, dynamic>{'code': code},
    );
  }

  /// APP一键登录(阿里云号码认证, /api/login/phoneAuthLogin)
  /// * [accessToken] 阿里云授权页取到的 accessToken,后端用它换手机号再换登录态
  static Future<Map<String, dynamic>> phoneAuthLogin({
    required String accessToken,
  }) async {
    final dynamic res = await Request().post(
      '/api/login/phoneAuthLogin',
      data: <String, dynamic>{'access_token': accessToken},
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 微信登录未绑定账号时,发送绑定手机号动态码(/api/login/bindMobileCode)
  /// * 与登录动态码分开,后端按场景校验(H5 pages_tool/login/login.vue 同接口)
  static Future<String> bindMobileCode({
    required String mobile,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/login/bindMobileCode',
      data: <String, dynamic>{
        'mobile': mobile,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return _pickString(res, 'key');
  }

  /// 微信登录未绑定账号: 手机号绑定并登录(/api/login/appMobileBind)
  /// * [wxInfo] appWxLogin 返回 -10016 时的 data(openid/unionid/nickname/headimg + type)
  /// * 绑定成功返回 {token, data}(H5 同: 直接 setToken 视为登录完成)
  static Future<Map<String, dynamic>> appMobileBind({
    required String mobile,
    required String key,
    required String code,
    required Map<String, dynamic> wxInfo,
    String captchaId = '',
    String captchaCode = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/login/appMobileBind',
      data: <String, dynamic>{
        ...wxInfo,
        'mobile': mobile,
        'key': key,
        'code': code,
        if (captchaId.isNotEmpty) 'captcha_id': captchaId,
        if (captchaId.isNotEmpty) 'captcha_code': captchaCode,
      },
    );
    return <String, dynamic>{
      'token': _pickToken(res),
      'data': res,
    };
  }

  /// 注册/登录配置(/api/register/config)
  /// data.value: { register, login, agreement_show, pwd_len, pwd_complexity }
  /// * register/login 为 'mobile,username' 形式,为空表示平台未开启
  static Future<Map<String, dynamic>> registerConfig() async {
    final dynamic res = await Request().post('/api/register/config');
    if (res is Map) {
      final dynamic value = res['value'];
      if (value is Map) return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  /// 图形验证码配置(/api/config/getCaptchaConfig)
  /// data: { shop_reception_login: 1, shop_reception_register: 1 } 1 开启 / 0 关闭
  static Future<Map<String, dynamic>> captchaConfig() async {
    final dynamic res = await Request().post('/api/config/getCaptchaConfig');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 读取开关配置(1 开启,其余关闭)
  static bool isOn(Map<String, dynamic> config, String key) {
    final dynamic value = config[key];
    if (value is num) return value == 1;
    return '$value'.trim() == '1';
  }

  /// 获取图形验证码(/api/captcha/captcha)
  /// 返回 {'id': 验证码id, 'img': base64图片(img 可能是 data:image/...;base64,xxx)}
  static Future<Map<String, dynamic>> captcha({String id = ''}) async {
    final dynamic res = await Request().post(
      '/api/captcha/captcha',
      data: <String, dynamic>{'captcha_id': id},
    );
    if (res is Map) {
      return <String, dynamic>{
        'id': '${res['id'] ?? ''}',
        'img': '${res['img'] ?? ''}',
      };
    }
    return <String, dynamic>{'id': '', 'img': ''};
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

  /// 取 data 里的字符串字段
  static String _pickString(dynamic data, String key) {
    if (data is Map) return '${data[key] ?? ''}'.trim();
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
    return message.isEmpty ? '请求失败' : message;
  }
}
