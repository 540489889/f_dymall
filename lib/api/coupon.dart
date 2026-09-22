/// 优惠券相关接口
/// 对齐 H5: pages_tool/member/coupon.vue(我的优惠券) / pages_tool/goods/coupon.vue(领券)
/// * 我的券列表 /coupon/api/coupon/memberpage(state: 1未使用 2已使用 3已过期)
/// * 我的券数量 /coupon/api/coupon/num
/// * 领券 /coupon/api/coupon/receive
library;

import '../utils/request.dart';

class CouponApi {
  /// 券状态: 1 未使用 2 已使用 3 已过期
  static const int stateUnused = 1;
  static const int stateUsed = 2;
  static const int stateExpired = 3;

  /// 领取优惠券(/coupon/api/coupon/receive)
  /// * [couponTypeId] 优惠券类型id
  /// * [getType] 获取方式: 1订单 2直接领取 3活动领取
  static Future<dynamic> receive({required int couponTypeId, int getType = 2}) async {
    return Request().post(
      '/coupon/api/coupon/receive',
      data: <String, dynamic>{'coupon_type_id': couponTypeId, 'get_type': getType},
    );
  }

  /// 我的优惠券数量(/coupon/api/coupon/num)
  static Future<int> num() async {
    final dynamic res = await Request().get('/coupon/api/coupon/num');
    final dynamic val = res is Map ? (res['count'] ?? res['num'] ?? res['data']) : res;
    return int.tryParse('${val ?? ''}') ?? 0;
  }

  /// 我的优惠券列表(/coupon/api/coupon/memberpage)
  /// * [state] 1 未使用 / 2 已使用 / 3 已过期
  /// * 返回 { list: [...], count: 总数, page_count: 总页数 }
  /// * 券字段: coupon_name / type(reward满减|discount折扣|divideticket) / money / discount
  ///   at_least / state / end_time / coupon_type_id / goods_type_name / use_channel_name / use_store_name
  static Future<Map<String, dynamic>> memberPage({
    int page = 1,
    int pageSize = 10,
    int state = stateUnused,
  }) async {
    final dynamic res = await Request().get(
      '/coupon/api/coupon/memberpage',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'state': state,
      },
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 列表项(兼容接口直接返回数组的情况)
  static List<Map<String, dynamic>> listOf(dynamic res) {
    final dynamic list = res is Map ? res['list'] : res;
    if (list is List) {
      return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }
}
