/// 订单结算/创建相关接口
/// 对齐 H5: pages/order/payment.vue + components/common-payment(payment.js)
/// * /api/ordercreate/payment     结算页数据
/// * /api/ordercreate/calculate   金额计算
/// * /api/ordercreate/create      创建订单
/// * /api/ordercreate/getcouponlist 可用优惠券
/// * /api/store/getStorePage      门店(自提点)列表
library;

import 'dart:convert';

import '../utils/request.dart';

class OrderApi {
  /// 配送方式: 快递发货
  static const String express = 'express';
  /// 配送方式: 门店自提
  static const String store = 'store';
  /// 配送方式: 同城配送
  static const String local = 'local';
  /// 普通下单接口前缀
  static const String api = '/api/ordercreate';
  /// 秒杀下单接口前缀(对齐 H5 pages_promotion/seckill/payment.vue)
  static const String seckillApi = '/seckill/api/ordercreate';

  /// 初始下单参数(字段与 H5 data.orderCreateData 一致)
  /// * [cartIds] 购物车结算: 逗号拼接的 cart_id,如 '81,82'
  /// * [skuId]/[num] 立即购买: sku_id + 数量
  /// * [seckillId] 秒杀下单: seckill_id(H5 ns-goods-sku 的秒杀下单数据)
  /// * [liveRoomId] 直播间下单场景
  static Map<String, dynamic> createData({
    String? cartIds,
    int? skuId,
    int? num,
    int? seckillId,
    int? liveRoomId,
    String latitude = '',
    String longitude = '',
  }) {
    return <String, dynamic>{
      if (cartIds != null && cartIds.isNotEmpty) 'cart_ids': cartIds,
      if (skuId != null) 'sku_id': skuId,
      if (num != null) 'num': num,
      if (seckillId != null) 'seckill_id': seckillId,
      if (liveRoomId != null) 'live_roomid': liveRoomId,
      // 门店自提/同城配送按距离排序用,未定位时不传
      if (latitude.isNotEmpty) 'latitude': latitude,
      if (longitude.isNotEmpty) 'longitude': longitude,
      'is_balance': 0,
      'is_point': 1,
      'is_invoice': 0,
      'invoice_type': 0,
      'invoice_title_type': 1,
      'is_tax_invoice': 0,
      'coupon': <String, dynamic>{'coupon_id': 0},
      'delivery': <String, dynamic>{},
      'member_goods_card': <String, dynamic>{},
      'order_key': '',
      'buyer_message': '',
    };
  }

  /// 结算页数据: goods_list / delivery.express_type / member_account / order_key
  /// * [prefix] 接口前缀,秒杀下单传 [seckillApi]
  static Future<Map<String, dynamic>> payment(Map<String, dynamic> data, {String prefix = api}) async {
    final dynamic res = await Request().post('$prefix/payment', data: _body(data));
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 金额计算: pay_money / goods_money / delivery_money / coupon_money / point_money / promotion_money
  static Future<Map<String, dynamic>> calculate(Map<String, dynamic> data, {String prefix = api}) async {
    final dynamic res = await Request().post('$prefix/calculate', data: _body(data));
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 创建订单: 返回 out_trade_no(支付单号)
  static Future<String> create(Map<String, dynamic> data, {String prefix = api}) async {
    final dynamic res = await Request().post('$prefix/create', data: _body(data));
    if (res is Map) return '${res['out_trade_no'] ?? res['data'] ?? ''}';
    return '$res';
  }

  /// 可用优惠券列表($prefix/getcouponlist)
  static Future<List<Map<String, dynamic>>> couponList(Map<String, dynamic> data, {String prefix = api}) async {
    final dynamic res = await Request().post('$prefix/getcouponlist', data: _body(data));
    if (res is List) return res.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// 购买须知/交易协议(/api/order/transactionagreement)
  /// * 返回 { title, content } content 为富文本
  static Future<Map<String, dynamic>> transactionAgreement() async {
    final dynamic res = await Request().post('/api/order/transactionagreement');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 订单详情(/api/order/detail)
  /// * [orderId] 订单id(payInfo.order_id)
  /// * [merchantTradeNo] 商户单号,可选
  static Future<Map<String, dynamic>> detail({int orderId = 0, String merchantTradeNo = ''}) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/order/detail',
      data: <String, dynamic>{
        'order_id': orderId,
        if (merchantTradeNo.isNotEmpty) 'merchant_trade_no': merchantTradeNo,
      },
    );
    // 与 H5 一致: code >= 0 且 data 存在即视为成功
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) {
      throw Exception('${res['message'] ?? '未获取到订单信息'}');
    }
    return data.cast<String, dynamic>();
  }

  /// 订单列表(/api/order/lists)
  /// * [orderStatus] 与 H5 一致: all/waitpay/waitsend/waitconfirm/wait_use
  /// * 返回 { list: [...], auto_close: 秒 }
  static Future<Map<String, dynamic>> lists({
    int page = 1,
    int pageSize = 10,
    String orderStatus = 'all',
    String searchText = '',
  }) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/order/lists',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'order_status': orderStatus,
        if (searchText.isNotEmpty) 'searchText': searchText,
      },
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    if (code < 0) throw Exception('${res['message'] ?? '订单加载失败'}');
    final dynamic data = res['data'];
    if (data is! Map) return <String, dynamic>{'list': <dynamic>[], 'auto_close': 0};
    return data.cast<String, dynamic>();
  }

  /// 列表数据: data.list
  static List<Map<String, dynamic>> listOf(Map<String, dynamic> data) {
    final dynamic list = data['list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 订单商品: 列表/详情均为 order_goods,结算页为 goods_list
  static List<Map<String, dynamic>> orderGoodsOf(Map<String, dynamic> data) {
    final dynamic list = data['order_goods'] ?? data['goods_list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 订单支付(/api/order/pay): 传入 order_id,返回 out_trade_no
  /// * 与 H5 orderMethod.pay() 一致
  static Future<String> pay(int orderId) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/order/pay',
      data: <String, dynamic>{'order_ids': orderId},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    if (code < 0) throw Exception('${res['message'] ?? '获取支付信息失败'}');
    final dynamic data = res['data'];
    if (data is Map) return '${data['out_trade_no'] ?? ''}';
    return '$data';
  }

  /// 关闭(取消)订单(/api/order/close)
  static Future<void> close(int orderId) async {
    await Request().post('/api/order/close', data: <String, dynamic>{'order_id': orderId});
  }

  /// 确认收货(/api/order/takedelivery)
  static Future<void> takeDelivery(int orderId) async {
    await Request().post('/api/order/takedelivery', data: <String, dynamic>{'order_id': orderId});
  }

  /// 删除订单(/api/order/delete)
  static Future<void> delete(int orderId) async {
    await Request().post('/api/order/delete', data: <String, dynamic>{'order_id': orderId});
  }

  /// 订单包裹(物流)信息(/api/order/package)
  /// * 返回数组: package_name / goods_list / delivery_type(1快递) / express_company_name
  /// * express_company_image / delivery_no / trace:{ success, list:[{remark,datetime}], reason }
  /// * 与 H5 一致: trace.list 倒序(最新在前)
  static Future<List<Map<String, dynamic>>> packageList(int orderId) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/order/package',
      data: <String, dynamic>{'order_id': orderId},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! List) throw Exception('${res['message'] ?? '未获取到订单信息'}');
    final List<Map<String, dynamic>> list = data.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    for (final Map<String, dynamic> item in list) {
      dynamic trace = item['trace'];
      if (trace is String) {
        try {
          trace = jsonDecode(trace);
        } catch (_) {
          trace = null;
        }
      }
      if (trace is! Map) continue;
      final dynamic record = trace['list'];
      if (record is List) item['trace'] = <String, dynamic>{
        ...trace.cast<String, dynamic>(),
        'list': record.reversed.toList(),
      };
    }
    return list;
  }

  /// 虚拟商品收货(/api/order/membervirtualtakedelivery)
  static Future<void> virtualTakeDelivery(int orderId) async {
    await Request().post('/api/order/membervirtualtakedelivery', data: <String, dynamic>{'order_id': orderId});
  }

  /// 评价配置(/api/goodsevaluate/config)
  /// * evaluate_status: 1开启评价(详情页展示评价/追评按钮)
  static Future<Map<String, dynamic>> evaluateConfig() async {
    final dynamic res = await Request().post('/api/goodsevaluate/config');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 待评价商品(/api/order/evluateinfo)
  /// * 返回 { evaluate_status: 0评价/1追评, list: [order_goods] }
  static Future<Map<String, dynamic>> evaluateInfo(int orderId) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/order/evluateinfo',
      data: <String, dynamic>{'order_id': orderId},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) throw Exception('${res['message'] ?? '未获取到订单数据'}');
    return data.cast<String, dynamic>();
  }

  /// 提交评价(/api/goodsevaluate/add)
  /// * [goodsEvaluate] 每项: content/images/scores/explain_type/order_goods_id/goods_id/sku_id/sku_name/sku_price/sku_image
  static Future<void> addEvaluate({
    required int orderId,
    required List<Map<String, dynamic>> goodsEvaluate,
    String orderNo = '',
    String memberName = '',
    String memberHeadimg = '',
    int isAnonymous = 0,
  }) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/goodsevaluate/add',
      data: <String, dynamic>{
        'order_id': orderId,
        'goods_evaluate': jsonEncode(goodsEvaluate),
        'order_no': orderNo,
        'member_name': memberName,
        'member_headimg': memberHeadimg,
        'is_anonymous': isAnonymous,
      },
    );
    if ((int.tryParse('${res['code']}') ?? -1) < 0) throw Exception('${res['message'] ?? '评价失败'}');
  }

  /// 提交追评(/api/goodsevaluate/again)
  /// * [goodsEvaluate] 每项: order_goods_id/goods_id/sku_id/again_content/again_images
  static Future<void> againEvaluate({
    required int orderId,
    required List<Map<String, dynamic>> goodsEvaluate,
  }) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/goodsevaluate/again',
      data: <String, dynamic>{
        'order_id': orderId,
        'goods_evaluate': jsonEncode(goodsEvaluate),
      },
    );
    if ((int.tryParse('${res['code']}') ?? -1) < 0) throw Exception('${res['message'] ?? '追评失败'}');
  }

  /// 订单可执行操作: 详情页 order_status_action / 列表页 action(JSON字符串或数组)
  /// * 结构 [{ action: 'orderPay', title: '支付' } ...]
  static List<Map<String, dynamic>> actionsOf(Map<String, dynamic> data) {
    dynamic list = data['action'] ?? data['order_status_action'];
    if (list is String) {
      if (list.trim().isEmpty) return <Map<String, dynamic>>[];
      try {
        list = jsonDecode(list);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 门店(自提点)列表(/api/store/getStorePage)
  /// * [type] 配送方式: express/store/local
  static Future<List<Map<String, dynamic>>> storePage({
    int page = 1,
    int pageSize = 20,
    String latitude = '',
    String longitude = '',
    required String type,
    String storeIds = '',
  }) async {
    final dynamic res = await Request().post(
      '/api/store/getStorePage',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'store_ids': storeIds,
      },
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// 请求体转换(与 H5 handleCreateData 一致)
  /// * 值为对象/数组时转成 JSON 字符串
  /// * 非门店自提时移除 member_address
  static Map<String, dynamic> _body(Map<String, dynamic> data) {
    final Map<String, dynamic> body = <String, dynamic>{};
    data.forEach((String key, dynamic value) {
      if (value is Map || value is List) {
        body[key] = jsonEncode(value);
      } else {
        body[key] = value;
      }
    });
    final dynamic delivery = data['delivery'];
    final String deliveryType = delivery is Map ? '${delivery['delivery_type'] ?? ''}' : '';
    if (deliveryType != store) body.remove('member_address');
    return body;
  }

  /// 取金额: 字符串/数字容错,取不到返回 [fallback]
  static num moneyOf(dynamic value, [num fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value;
    final String text = '$value'.trim().replaceAll(',', '').replaceAll('¥', '');
    if (text.isEmpty) return fallback;
    return num.tryParse(text) ?? fallback;
  }

  /// 配送方式列表: data.delivery.express_type
  static List<Map<String, dynamic>> expressTypesOf(Map<String, dynamic> data) {
    final dynamic delivery = data['delivery'];
    if (delivery is! Map) return <Map<String, dynamic>>[];
    final dynamic list = delivery['express_type'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 配送方式下的门店列表: express_type[i].store_list
  static List<Map<String, dynamic>> storeListOf(Map<String, dynamic> expressType) {
    final dynamic list = expressType['store_list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 商品列表: data.goods_list
  static List<Map<String, dynamic>> goodsListOf(Map<String, dynamic> data) {
    final dynamic list = data['goods_list'];
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 规格文本: sku_spec_format 可能是 JSON 字符串或数组
  static String specTextOf(dynamic value) {
    dynamic data = value;
    if (data is String) {
      if (data.trim().isEmpty) return '';
      try {
        data = jsonDecode(data);
      } catch (_) {
        return '';
      }
    }
    if (data is! List) return '';
    return data
        .whereType<Map>()
        .map((Map e) => '${e['spec_name'] ?? ''}:${e['spec_value_name'] ?? ''}')
        .where((String e) => e.trim().isNotEmpty && e != ':')
        .join('; ');
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '请求失败']) {
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
