/// 积分相关接口
/// 对齐 H5: pages_tool/member/point.vue + point_detail.vue
/// * 积分汇总 /api/memberaccount/point(point / point_all / point_use / point_today)
/// * 积分明细 /api/memberaccount/page(account_type: point)
/// * 来源类型 /api/memberaccount/fromType(point 分组)
/// * 明细月份 /api/memberaccount/monthData(与余额明细共用)
/// * 积分规则 /api/config/getPointRuleConfig
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class MemberPointApi {
  /// 账户类型(积分)
  static const String accountType = 'point';

  /// 积分汇总(/api/memberaccount/point)
  /// 返回 { point: 当前积分, point_all: 累计积分, point_use: 累计消费, point_today: 今日获得 }
  static Future<Map<String, dynamic>> point() async {
    final dynamic res = await Request().get('/api/memberaccount/point');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 积分明细(/api/memberaccount/page)
  /// * [fromType] 来源类型(0 全部,取 /api/memberaccount/fromType 的 point 分组)
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

  /// 积分来源类型(/api/memberaccount/fromType 的 point 分组)
  /// 返回 [{ label: 类型名, value: 类型key }],首项为「全部」
  static Future<List<Map<String, dynamic>>> fromType() async {
    final List<Map<String, dynamic>> types = <Map<String, dynamic>>[
      <String, dynamic>{'label': '全部', 'value': '0'},
    ];
    dynamic res = await Request().get('/api/memberaccount/fromType');
    Map<String, dynamic> src = <String, dynamic>{};
    if (res is Map) {
      src = res.cast<String, dynamic>();
      // 兼容多包一层 data 的情况
      if (!src.containsKey('point') && src['data'] is Map) {
        src = (src['data'] as Map).cast<String, dynamic>();
      }
    }
    final dynamic group = src['point'];
    if (group is Map) {
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

  /// 积分规则(/api/config/getPointRuleConfig),返回富文本内容
  /// H5: res.data.value.content(积分说明弹窗)
  static Future<String> ruleConfig() async {
    try {
      final dynamic res = await Request().get('/api/config/getPointRuleConfig');
      if (res is Map) {
        final Map<String, dynamic> data = res.cast<String, dynamic>();
        final dynamic value = data['value'];
        if (value is Map) {
          final String content = '${value['content'] ?? ''}';
          if (content.isNotEmpty) return content;
        }
        final String content = '${data['content'] ?? ''}';
        return content == 'null' ? '' : content;
      }
    } catch (_) {}
    return '';
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
