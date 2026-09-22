/// 积分商城(积分兑换)接口
/// 对齐 H5: pages_promotion/point/*
/// * 兑换商品 /pointexchange/api/goods/page(type: 1 商品 / 2 优惠券 / 3 红包)
/// * 兑换商品详情 /pointexchange/api/goods/detail(id)
/// * 下单结算 /pointexchange/api/ordercreate/payment|calculate|create
/// * 兑换订单 /pointexchange/api/order/page|close
library;

import 'package:dio/dio.dart';

import '../config/index.dart';
import '../utils/request.dart';

class PointExchangeApi {
  /// 兑换类型: 1 商品 2 优惠券 3 红包
  static const int typeGoods = 1;
  static const int typeCoupon = 2;
  static const int typeHongbao = 3;

  /// 兑换商品列表(/pointexchange/api/goods/page)
  /// 返回 { list: [...], page_count: 总页数, count: 总数 }
  static Future<Map<String, dynamic>> goodsPage({
    int page = 1,
    int pageSize = 10,
    int type = typeGoods,
    String keyword = '',
    int categoryId = 0,
    String minPoint = '',
    String maxPoint = '',
    int isFreeShipping = 0,
    String order = '',
    String sort = '',
  }) async {
    final dynamic res = await Request().get(
      '/pointexchange/api/goods/page',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'type': type,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (categoryId > 0) 'category_id': categoryId,
        if (minPoint.isNotEmpty) 'min_point': minPoint,
        if (maxPoint.isNotEmpty) 'max_point': maxPoint,
        if (isFreeShipping == 1) 'is_free_shipping': 1,
        if (order.isNotEmpty) 'order': order,
        if (sort.isNotEmpty) 'sort': sort,
      },
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 兑换商品详情(/pointexchange/api/goods/detail)
  /// * type=1 商品: 含 sku_id / sku_image / sku_name / sku_spec_format(JSON字符串) / goods_spec_format
  /// * type=2/3: 含 name / image / coupon_type(优惠券) / balance(红包)
  static Future<Map<String, dynamic>> goodsDetail(int id) async {
    final dynamic res = await Request().get(
      '/pointexchange/api/goods/detail',
      queryParameters: <String, dynamic>{'id': id},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 兑换商品 SKU 列表(/pointexchange/api/goods/goodsSku)
  /// * 仅 type=1 且存在多规格时查询;返回项整体覆盖到详情上(H5 Object.assign(pointInfo, sku))
  static Future<List<Map<String, dynamic>>> goodsSku({
    required int goodsId,
    required int exchangeId,
    int type = typeGoods,
  }) async {
    final dynamic res = await Request().get(
      '/pointexchange/api/goods/goodsSku',
      queryParameters: <String, dynamic>{
        'goods_id': goodsId,
        'exchange_id': exchangeId,
        'type': type,
      },
    );
    if (res is List) {
      return res.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// 订单初始化数据(/pointexchange/api/ordercreate/payment)
  /// * [data] { id: 兑换活动id, sku_id, num }
  /// * 返回 { exchange_info, is_virtual, delivery, member_account, goods_num, point, ... }
  static Future<Map<String, dynamic>> orderPayment(Map<String, dynamic> data) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/pointexchange/api/ordercreate/payment',
      data: data,
    );
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: '${res['message'] ?? '未获取到创建订单所需数据'}',
      );
    }
    final dynamic body = res['data'];
    if (body is Map) return body.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 订单计算(/pointexchange/api/ordercreate/calculate)
  /// * [data] { ...orderCreateData, delivery: JSON字符串, member_address: JSON字符串 }
  /// * 返回 { member_address, delivery_money, order_money, delivery }
  static Future<Map<String, dynamic>> orderCalculate(Map<String, dynamic> data) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/pointexchange/api/ordercreate/calculate',
      data: data,
    );
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: '${res['message'] ?? '订单计算失败'}',
      );
    }
    final dynamic body = res['data'];
    if (body is Map) return body.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 订单创建(/pointexchange/api/ordercreate/create),返回支付单号 out_trade_no
  /// * 纯积分兑换(无需支付现金)时后端直接完成,单号可不用于支付
  static Future<String> orderCreate(Map<String, dynamic> data) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/pointexchange/api/ordercreate/create',
      data: data,
    );
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: '${res['message'] ?? '订单创建失败'}',
      );
    }
    final String outTradeNo = '${res['data'] ?? ''}';
    return outTradeNo == 'null' ? '' : outTradeNo;
  }

  /// 兑换订单列表(/pointexchange/api/order/page)
  /// * [orderStatus] all / 0(待支付) / 1(已完成)
  static Future<List<Map<String, dynamic>>> orderPage({
    int page = 1,
    int pageSize = 10,
    String orderStatus = 'all',
  }) async {
    final dynamic res = await Request().get(
      '/pointexchange/api/order/page',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'order_status': orderStatus,
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

  /// 关闭兑换订单(/pointexchange/api/order/close)
  static Future<void> orderClose(int orderId) async {
    await Request().post(
      '/pointexchange/api/order/close',
      data: <String, dynamic>{'order_id': orderId},
    );
  }

  /// 图片地址(H5 $util.img): 相对路径拼接 Config.imgDomain
  static String img(dynamic url) {
    final String path = '$url'.trim();
    if (path.isEmpty || path == 'null') return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${Config.imgDomain}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '加载失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message.replaceAll(RegExp(r'^DioException.*message: '), '');
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
