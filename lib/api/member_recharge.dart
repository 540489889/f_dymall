/// 充值相关接口(memberrecharge 插件)
/// 对齐 H5: pages_tool/recharge/list.vue + order_list.vue
/// * 充值配置 /memberrecharge/api/memberrecharge/config
/// * 充值套餐 /memberrecharge/api/memberrecharge/page
/// * 创建充值单 /memberrecharge/api/ordercreate/create(返回支付单号)
/// * 充值记录 /memberrecharge/api/order/page
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class MemberRechargeApi {
  /// 充值配置(/memberrecharge/api/memberrecharge/config),is_use == 1 才可用
  static Future<Map<String, dynamic>> config() async {
    final dynamic res = await Request().get('/memberrecharge/api/memberrecharge/config');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 充值套餐(/memberrecharge/api/memberrecharge/page)
  /// * [faceValue] 面值(到账金额);[buyPrice] 售价(实付)
  static Future<List<Map<String, dynamic>>> page({int page = 1, int pageSize = 100}) async {
    final dynamic res = await Request().post(
      '/memberrecharge/api/memberrecharge/page',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// 创建充值单(/memberrecharge/api/ordercreate/create)
  /// * [rechargeId] > 0 按套餐下单;为 0 时按 [faceValue] 自定义金额下单
  /// * 返回支付单号 out_trade_no(交给 PopupPay 发起支付)
  static Future<String> create({int rechargeId = 0, String faceValue = ''}) async {
    final Map<String, dynamic> data = <String, dynamic>{'recharge_id': rechargeId};
    if (rechargeId <= 0) data['face_value'] = faceValue;
    final dynamic res = await Request().post('/memberrecharge/api/ordercreate/create', data: data);
    if (res is Map) {
      final String no = '${res['out_trade_no'] ?? ''}';
      if (no.isNotEmpty) return no;
      throw Exception('${res['message'] ?? '下单失败'}');
    }
    final String no = '$res'.trim();
    if (no.isEmpty || no == 'null') throw Exception('下单失败');
    return no;
  }

  /// 充值记录(/memberrecharge/api/order/page)
  static Future<List<Map<String, dynamic>>> orderPage({int page = 1, int pageSize = 20}) async {
    final dynamic res = await Request().post(
      '/memberrecharge/api/order/page',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
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
