/// 退款/售后相关接口
/// 对齐 H5: pages_tool/order/refund.vue + refund_detail.vue + public/js/refundMethod.js
/// * /api/orderrefund/refundData  退款页数据(原因/金额/可退方式)
/// * /api/orderrefund/refund      申请退款
/// * /api/orderrefund/detail      退款详情
/// * /api/orderrefund/cancel      撤销退款
/// * /api/orderrefund/delivery    退货发货(买家回填物流)
library;

import '../utils/request.dart';

class RefundApi {
  /// 退款页数据(/api/orderrefund/refundData)
  /// * 返回 { refund_type: [1仅退款,2退货退款], refund_money, refund_reason_type: [], order_goods_info: {} }
  static Future<Map<String, dynamic>> refundData(int orderGoodsId) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/orderrefund/refundData',
      data: <String, dynamic>{'order_goods_id': orderGoodsId},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) throw Exception('${res['message'] ?? '未获取到该订单项退款信息'}');
    return data.cast<String, dynamic>();
  }

  /// 申请退款(/api/orderrefund/refund)
  /// * [orderGoodsIds] 订单商品id,批量时逗号拼接
  /// * [refundType] 1仅退款 2退货退款
  static Future<void> refund({
    required String orderGoodsIds,
    required int refundType,
    required String refundReason,
    String refundRemark = '',
    String refundImages = '',
  }) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/orderrefund/refund',
      data: <String, dynamic>{
        'order_goods_ids': orderGoodsIds,
        'refund_type': refundType,
        'refund_reason': refundReason,
        'refund_remark': refundRemark,
        'refund_images': refundImages,
      },
    );
    if ((int.tryParse('${res['code']}') ?? -1) < 0) throw Exception('${res['message'] ?? '申请失败'}');
  }

  /// 退款详情(/api/orderrefund/detail)
  static Future<Map<String, dynamic>> detail(int orderGoodsId) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/orderrefund/detail',
      data: <String, dynamic>{'order_goods_id': orderGoodsId},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) throw Exception('${res['message'] ?? '未获取到该订单项退款信息'}');
    return data.cast<String, dynamic>();
  }

  /// 撤销退款(/api/orderrefund/cancel)
  static Future<void> cancel(int orderGoodsId) async {
    await Request().post('/api/orderrefund/cancel', data: <String, dynamic>{'order_goods_id': orderGoodsId});
  }

  /// 退货发货(/api/orderrefund/delivery)
  static Future<void> delivery({
    required int orderGoodsId,
    required String name,
    required String no,
    String remark = '',
  }) async {
    await Request().post(
      '/api/orderrefund/delivery',
      data: <String, dynamic>{
        'order_goods_id': orderGoodsId,
        'refund_delivery_name': name,
        'refund_delivery_no': no,
        'refund_delivery_remark': remark,
      },
    );
  }

  /// 退款可执行操作: detail.refund_action = [{ event, title }]
  static List<Map<String, dynamic>> actionsOf(Map<String, dynamic> data) {
    final dynamic list = data['refund_action'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 协商记录: detail.refund_log_list
  static List<Map<String, dynamic>> logsOf(Map<String, dynamic> data) {
    final dynamic list = data['refund_log_list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 售后/退款列表(/api/orderrefund/lists)
  /// 对齐 H5: pages_tool/order/activist.vue
  static Future<Map<String, dynamic>> lists({int page = 1, int pageSize = 10}) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/orderrefund/lists',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    if (code < 0) throw Exception('${res['message'] ?? '获取售后列表失败'}');
    final dynamic data = res['data'];
    if (data is! Map) return <String, dynamic>{};
    return data.cast<String, dynamic>();
  }

  /// 列表项数组: lists.data.list
  static List<Map<String, dynamic>> listOf(Map<String, dynamic> data) {
    final dynamic list = data['list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 异常消息提取(与 OrderApi.errorMsg 一致)
  static String errorMsg(Object e, [String def = '操作失败']) {
    final String msg = '$e';
    return msg.startsWith('Exception: ') ? msg.substring(10) : def;
  }
}
