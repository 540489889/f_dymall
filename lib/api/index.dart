/// 首页聚合配置接口(/api/index/index)
/// 返回 banner_info(轮播) / nav_info(金刚区) / popup_info(弹窗) / timestamp
library;

import '../utils/request.dart';

class IndexApi {
  /// 首页聚合配置
  /// * 返回 { popup_info, banner_info, nav_info, timestamp }
  static Future<Map<String, dynamic>> index() async {
    final dynamic res = await Request().get('/api/index/index');
    if (res is Map) return Map<String, dynamic>.from(res);
    return const {};
  }
}
