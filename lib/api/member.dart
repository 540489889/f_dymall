/// 会员相关接口
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class MemberApi {
  /// 绑定门店
  /// * [type] 绑定方式: input 输入店员账号 / scan 扫码
  /// * [nickname] 姓名(店员昵称)
  /// * [value] 店员手机号码或扫码结果
  static Future<dynamic> bindStore({
    required String type,
    required String nickname,
    required String value,
  }) async {
    return Request().post(
      '/api/member/bindStore',
      data: <String, dynamic>{
        'type': type,
        'nickname': nickname,
        'value': value,
      },
    );
  }

  /// 会员信息
  /// 返回昵称/头像/余额/门店等会员资料
  static Future<dynamic> info() async {
    return Request().get('/api/member/info');
  }

  // ===== 个人资料修改(对齐 H5 pages_tool/member/public/js/info.js) =====

  /// 修改账号(/api/member/modifyusername)
  /// * H5: 与当前账号一致时不请求,直接提示「与原账号一致」
  static Future<dynamic> modifyUsername(String username) {
    return Request().post(
      '/api/member/modifyusername',
      data: <String, dynamic>{'username': username},
    );
  }

  /// 修改昵称(/api/member/modifynickname)
  static Future<dynamic> modifyNickname(String nickname) {
    return Request().post(
      '/api/member/modifynickname',
      data: <String, dynamic>{'nickname': nickname},
    );
  }

  /// 修改真实姓名(/api/member/modifyrealname)
  static Future<dynamic> modifyRealName(String realname) {
    return Request().post(
      '/api/member/modifyrealname',
      data: <String, dynamic>{'realname': realname},
    );
  }

  /// 修改性别(/api/member/modifysex)
  /// * [sex] 0 未知 / 1 男 / 2 女
  static Future<dynamic> modifySex(int sex) {
    return Request().post(
      '/api/member/modifysex',
      data: <String, dynamic>{'sex': sex},
    );
  }

  /// 修改生日(/api/member/modifybirthday)
  /// * [birthday] 秒级时间戳(H5 timeTurnTimeStamp)
  static Future<dynamic> modifyBirthday(int birthday) {
    return Request().post(
      '/api/member/modifybirthday',
      data: <String, dynamic>{'birthday': birthday},
    );
  }

  /// 修改头像(/api/member/modifyheadimg)
  /// * [headimg] 上传接口返回的 pic_path(/api/upload/headimg)
  /// * 该接口成功码也可能为非 0(如 10067),用 postRaw 取原始响应,
  ///   仅当 code < 0 视为失败,其余(0 / 10067 等)均当作成功
  static Future<dynamic> modifyHeadImg(String headimg) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/member/modifyheadimg',
      data: <String, dynamic>{'headimg': headimg},
    );
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: '${res['message'] ?? '头像修改失败'}',
      );
    }
    return res['data'];
  }

  /// 上传头像文件(/api/upload/headimg)
  /// * 以 multipart/form-data 提交,表单字段名 file
  /// * 该接口成功码为 10067(非 0),用 postRaw 取原始响应,再取 data.pic_path
  /// * 返回 pic_path(供 modifyHeadImg 使用)
  static Future<String> uploadHeadImg(String filePath) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
    });
    final Map<String, dynamic> res = await Request().postRaw('/api/upload/headimg', data: formData);
    final dynamic data = res['data'];
    if (data is Map) {
      final dynamic pic = data['pic_path'] ?? data['pic'] ?? data['src'] ?? data['url'] ?? data['path'];
      if (pic is String && pic.isNotEmpty) return pic;
    }
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: '${res['message'] ?? '头像上传失败'}',
    );
  }

  /// 修改密码(/api/member/modifypassword)
  /// * 已设密码: 传 [oldPassword];未设密码: 传短信 [code] + [key]
  static Future<dynamic> modifyPassword({
    required String newPassword,
    String oldPassword = '',
    String code = '',
    String key = '',
  }) {
    return Request().post(
      '/api/member/modifypassword',
      data: <String, dynamic>{
        'new_password': newPassword,
        'old_password': oldPassword,
        'code': code,
        'key': key,
      },
    );
  }

  /// 修改手机号(/api/member/modifymobile)
  static Future<dynamic> modifyMobile({
    required String mobile,
    required String code,
    required String key,
    String captchaId = '',
    String captchaCode = '',
  }) {
    return Request().post(
      '/api/member/modifymobile',
      data: <String, dynamic>{
        'mobile': mobile,
        'captcha_id': captchaId,
        'captcha_code': captchaCode,
        'code': code,
        'key': key,
      },
    );
  }

  /// 修改所在地址(/api/member/modifyaddress)
  static Future<dynamic> modifyAddress({
    required int provinceId,
    required int cityId,
    required int districtId,
    required String address,
    required String fullAddress,
  }) {
    return Request().post(
      '/api/member/modifyaddress',
      data: <String, dynamic>{
        'province_id': provinceId,
        'city_id': cityId,
        'district_id': districtId,
        'address': address,
        'full_address': fullAddress,
      },
    );
  }

  /// 绑定微信(/api/member/bindWxopen)
  /// * [code] 微信授权 code(H5 uni.login provider=weixin onlyAuthorize)
  static Future<dynamic> bindWxopen(String code) {
    return Request().post(
      '/api/member/bindWxopen',
      data: <String, dynamic>{'code': code},
    );
  }

  // ===== 验证码(改手机 / 改密码) =====

  /// 图形验证码(/api/captcha/captcha)
  /// * 返回 {id, img}, img 为 base64(H5 会去掉 \r\n)
  static Future<Map<String, dynamic>> captcha({String captchaId = ''}) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/captcha/captcha',
      data: <String, dynamic>{'captcha_id': captchaId},
    );
    return _dataOf(res);
  }

  /// 检测手机号是否已存在(/api/member/checkmobile)
  /// * 已存在(或格式错误)抛异常,未占用返回 true
  static Future<bool> checkMobile(String mobile) async {
    await Request().post(
      '/api/member/checkmobile',
      data: <String, dynamic>{'mobile': mobile},
    );
    return true;
  }

  /// 绑定手机号: 发短信动态码(/api/member/bindmobliecode)
  /// * 返回短信 key(H5 存 storage: mobile_key)
  static Future<String> bindMobileCode({
    required String mobile,
    required String captchaId,
    required String captchaCode,
  }) async {
    final dynamic res = await Request().post(
      '/api/member/bindmobliecode',
      data: <String, dynamic>{
        'mobile': mobile,
        'captcha_id': captchaId,
        'captcha_code': captchaCode,
      },
    );
    final String key = res is Map ? '${res['key'] ?? ''}' : '';
    if (key.isEmpty) {
      throw DioException(requestOptions: RequestOptions(path: ''), message: '动态码发送失败');
    }
    return key;
  }

  /// 修改密码: 发短信动态码(/api/member/pwdmobliecode)
  /// * 未设置过密码时用,返回短信 key(H5 存 storage: password_mobile_key)
  static Future<String> pwdMobileCode({
    required String captchaId,
    required String captchaCode,
  }) async {
    final dynamic res = await Request().post(
      '/api/member/pwdmobliecode',
      data: <String, dynamic>{
        'captcha_id': captchaId,
        'captcha_code': captchaCode,
      },
    );
    final String key = res is Map ? '${res['key'] ?? ''}' : '';
    if (key.isEmpty) {
      throw DioException(requestOptions: RequestOptions(path: ''), message: '动态码发送失败');
    }
    return key;
  }

  // ===== 协议 / 注销(membercancel 插件) =====

  /// 注册协议内容(/api/register/aggrement)
  /// * [type] PRIVACY 隐私协议 / SERVICE 用户协议,返回 {title, content}
  static Future<Map<String, dynamic>> aggrement(String type) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/register/aggrement',
      data: <String, dynamic>{'type': type},
    );
    return _dataOf(res);
  }

  /// 注销配置(/membercancel/api/membercancel/config)
  /// * is_enable == 1 才展示「注销账号」入口
  static Future<Map<String, dynamic>> cancelConfig() async {
    return _dataOf(await Request().postRaw('/membercancel/api/membercancel/config'));
  }

  /// 注销申请状态(/membercancel/api/membercancel/info)
  /// * 无数据时表示未申请过;status 0 审核中 / 1 已注销 / 2 已拒绝
  static Future<Map<String, dynamic>> cancelInfo() async {
    return _dataOf(await Request().postRaw('/membercancel/api/membercancel/info'));
  }

  /// 注销协议(/membercancel/api/membercancel/agreement)
  static Future<Map<String, dynamic>> cancelAgreement() async {
    return _dataOf(await Request().postRaw('/membercancel/api/membercancel/agreement'));
  }

  /// 提交注销申请(/membercancel/api/membercancel/apply)
  static Future<dynamic> cancelApply() {
    return Request().post('/membercancel/api/membercancel/apply');
  }

  /// 原始响应取 data: code >= 0 视为成功(H5 口径),否则返回空 Map
  static Map<String, dynamic> _dataOf(Map<String, dynamic> res) {
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) return <String, dynamic>{};
    final dynamic data = res['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 统一取错误提示
  /// * [fallback] 异常/接口没给出文案时的兜底提示(如 '修改失败'), 不传时为通用文案
  static String errorMsg(dynamic error, [String fallback = '操作失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
