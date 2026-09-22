/// 会员账户(余额)相关接口
/// 对齐 H5: pages_tool/member/balance.vue + balance_detail.vue
/// * 账户余额 /api/memberaccount/info
/// * 余额明细 /api/memberaccount/page
/// * 明细月份 /api/memberaccount/monthData
/// * 明细来源类型 /api/memberaccount/fromType
/// * 提现配置 /api/memberwithdraw/config
/// * 充值配置 /memberrecharge/api/memberrecharge/config
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/request.dart';

class MemberAccountApi {
  /// 账户类型: 储值余额 + 现金余额(H5 account_type 固定传这两个)
  static const String accountType = 'balance,balance_money';

  /// 账户余额(/api/memberaccount/info)
  /// 返回 { balance: 储值余额, balance_money: 现金余额 }
  static Future<Map<String, dynamic>> info() async {
    final dynamic res = await Request().post(
      '/api/memberaccount/info',
      data: <String, dynamic>{'account_type': accountType},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 余额明细(/api/memberaccount/page)
  /// * [fromType] 来源类型(0 全部,取 /api/memberaccount/fromType 的 value)
  /// * [date] 月份(取 /api/memberaccount/monthData,为空查全部)
  static Future<List<Map<String, dynamic>>> page({
    int page = 1,
    int pageSize = 20,
    String fromType = '0',
    String date = '',
    int relatedId = 0,
  }) async {
    final dynamic res = await Request().post(
      '/api/memberaccount/page',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'account_type': accountType,
        'from_type': fromType,
        'date': date,
        'related_id': relatedId,
      },
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// 明细月份(/api/memberaccount/monthData),如 ['2026-09', '2026-08']
  /// * H5 sendRequest 未传 data 时为 GET(见 common/js/http.js),这里优先 GET,取不到再回退 POST
  /// * 返回结构兼容: 字符串数组 / {'data'|'list': 数组} / {'2026-09': {...}}
  static Future<List<String>> monthData() async {
    List<String> months = <String>[];
    try {
      months = _monthsOf(await Request().get('/api/memberaccount/monthData'));
    } catch (e) {
      if (kDebugMode) debugPrint('[monthData] GET 失败: $e');
    }
    if (months.isNotEmpty) return months;
    try {
      months = _monthsOf(await Request().post('/api/memberaccount/monthData'));
    } catch (e) {
      if (kDebugMode) debugPrint('[monthData] POST 失败: $e');
    }
    // 返回空: 页面按「全部」处理
    return months;
  }

  /// 月份解析(H5 monthData 直接取 res.data 作为数组,这里多做几层兼容)
  static List<String> _monthsOf(dynamic res) {
    final List<String> months = <String>[];
    if (res is List) {
      for (final dynamic e in res) {
        if (e is Map) {
          final String m = '${e['date'] ?? e['month'] ?? e['name'] ?? ''}';
          if (m.isNotEmpty) months.add(m);
        } else {
          final String m = '$e';
          if (m.isNotEmpty && m != 'null') months.add(m);
        }
      }
      return months;
    }
    if (res is Map) {
      for (final String key in <String>['data', 'list', 'month', 'months']) {
        final dynamic v = res[key];
        if (v is List) return _monthsOf(v);
      }
      // 以 key 作为月份,如 {'2026-09': {...}}
      for (final dynamic key in res.keys) {
        final String m = '$key';
        if (RegExp(r'^\d{4}-\d{1,2}$').hasMatch(m)) months.add(m);
      }
    }
    return months;
  }

  /// 明细来源类型(/api/memberaccount/fromType)
  /// * H5 sendRequest 未传 data 时为 GET(见 common/js/http.js),这里用 GET
  /// * H5 取 res.balance 与 res.balance_money 两个分组,合并成 [{label, value}],首项为「全部」
  static Future<List<Map<String, dynamic>>> fromType() async {
    final dynamic res = await Request().get('/api/memberaccount/fromType');
    Map<String, dynamic> src = <String, dynamic>{};
    if (res is Map) {
      src = res.cast<String, dynamic>();
      // 兼容多包一层 data 的情况
      if (!src.containsKey('balance') && !src.containsKey('balance_money') && src['data'] is Map) {
        src = (src['data'] as Map).cast<String, dynamic>();
      }
    }
    final List<Map<String, dynamic>> types = <Map<String, dynamic>>[
      <String, dynamic>{'label': '全部', 'value': '0'},
    ];
    for (final String key in <String>['balance', 'balance_money']) {
      final dynamic group = src[key];
      if (group is! Map) continue;
      group.forEach((dynamic k, dynamic v) {
        final Map<String, dynamic> item = v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
        types.add(<String, dynamic>{
          'label': '${item['type_name'] ?? k}',
          'value': '$k',
        });
      });
    }
    return types;
  }

  /// 提现配置(/api/memberwithdraw/config),is_use == 1 才显示提现入口
  /// 插件未安装时接口会报错,这里静默返回空配置
  static Future<Map<String, dynamic>> withdrawConfig() async {
    try {
      final dynamic res = await Request().get('/api/memberwithdraw/config');
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// 充值配置(/memberrecharge/api/memberrecharge/config),is_use == 1 才显示充值入口
  static Future<Map<String, dynamic>> memberrechargeConfig() async {
    try {
      final dynamic res = await Request().get('/memberrecharge/api/memberrecharge/config');
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '加载失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
