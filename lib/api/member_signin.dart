/// 会员签到接口(membersignin 插件)
/// 对齐 H5: pages_tool/member/public/js/signin.js
/// * 签到开关 /api/membersignin/getSignStatus(data.is_use)
/// * 今日是否签到 /api/membersignin/issign(data: 0/1)
/// * 奖励规则 /api/membersignin/award(data: { cycle, reward: [{ day, point }] })
/// * 执行签到 /api/membersignin/signin(data: 本次奖励)
/// * 签到累计 /api/memberaccount/sum(account_type + from_type)
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class MemberSigninApi {
  /// 签到开关(/api/membersignin/getSignStatus),1 开启
  static Future<int> status() async {
    try {
      final dynamic res = await Request().get('/api/membersignin/getSignStatus');
      if (res is Map) return int.tryParse('${res['is_use'] ?? 0}') ?? 0;
    } catch (_) {}
    return 0;
  }

  /// 今日是否已签到(/api/membersignin/issign),1 已签
  static Future<int> isSign() async {
    try {
      final dynamic res = await Request().get('/api/membersignin/issign');
      return int.tryParse('$res') ?? 0;
    } catch (_) {}
    return 0;
  }

  /// 奖励规则(/api/membersignin/award)
  /// 返回 { cycle: 周期天数, reward: [{ day, point, growth }] }
  static Future<Map<String, dynamic>> award() async {
    final dynamic res = await Request().get('/api/membersignin/award');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 执行签到(/api/membersignin/signin),返回本次奖励 { point, growth }
  static Future<Map<String, dynamic>> signin() async {
    final dynamic res = await Request().get('/api/membersignin/signin');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 签到累计(/api/memberaccount/sum)
  /// * [accountType] point 积分 / growth 成长值;[fromType] 固定 signin
  static Future<num> sum({String accountType = 'point', String fromType = 'signin'}) async {
    try {
      final dynamic res = await Request().get(
        '/api/memberaccount/sum',
        queryParameters: <String, dynamic>{'account_type': accountType, 'from_type': fromType},
      );
      return num.tryParse('$res') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '操作失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }
}
