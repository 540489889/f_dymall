/// 购物车相关接口
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../utils/request.dart';

class CartApi {
  /// 加入购物车
  /// * [skuId] 规格 sku id
  /// * [num] 加入数量
  /// * [liveRoomId] 直播间id: 直播间加购场景传,普通商品加购传 null
  static Future<dynamic> add({
    required int skuId,
    int num = 1,
    int? liveRoomId,
  }) async {
    return Request().post(
      '/api/cart/add',
      data: <String, dynamic>{
        'sku_id': skuId,
        'num': num,
        'live_roomid': liveRoomId,
      },
    );
  }

  /// 购物车列表(/api/cart/goodslists,与 H5 一致)
  /// 返回平铺的购物车条目列表(含 sku_image/sku_spec_format/member_price 等),接口异常时抛异常
  static Future<List<Map<String, dynamic>>> lists() async {
    final dynamic res = await Request().post('/api/cart/goodslists');
    if (res is! List) return const <Map<String, dynamic>>[];
    return res.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 购物车商品总件数: 各条目 num 之和
  static Future<int> count() async {
    final List<Map<String, dynamic>> list = await lists();
    int total = 0;
    for (final Map<String, dynamic> item in list) {
      total += num.tryParse('${item['num'] ?? 0}')?.toInt() ?? 0;
    }
    return total;
  }

  /// 修改购物车商品数量(/api/cart/edit)
  /// * [cartId] 购物车id
  /// * [num] 修改后的数量
  static Future<dynamic> editNum({required int cartId, required int num}) async {
    return Request().post(
      '/api/cart/edit',
      data: <String, dynamic>{'cart_id': cartId, 'num': num},
    );
  }

  /// 购物车金额计算(/api/cartcalculate/calculate)
  /// * [skus] 形如 [{'sku_id': 336, 'num': 1}]
  /// * 返回后台计算结果原始 Map,接口异常时抛异常
  static Future<Map<String, dynamic>> calculate(List<Map<String, dynamic>> skus) async {
    final dynamic res = await Request().post(
      '/api/cartcalculate/calculate',
      // 与 H5 一致: sku_ids 传 JSON 字符串
      data: <String, dynamic>{'sku_ids': jsonEncode(skus)},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 从计算结果中取金额: 依次尝试字段名,并向下找一层嵌套
  /// 取不到返回 0
  static num calcMoney(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final num? money = _toMoney(data[key]);
      if (money != null) return money;
    }
    for (final dynamic value in data.values) {
      if (value is Map) {
        for (final String key in keys) {
          final num? money = _toMoney(value[key]);
          if (money != null) return money;
        }
      }
    }
    return 0;
  }

  static num? _toMoney(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse('$value'.replaceAll(',', '').replaceAll('¥', ''));
  }

  /// 删除购物车商品(/api/cart/delete)
  /// * [cartIds] 购物车id列表,多个用逗号拼接
  static Future<dynamic> delete({required List<int> cartIds}) async {
    return Request().post(
      '/api/cart/delete',
      data: <String, dynamic>{'cart_id': cartIds.join(',')},
    );
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '操作失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      return message.isEmpty ? fallback : message;
    }
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
