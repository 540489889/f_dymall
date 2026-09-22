/// 门店相关接口
library;

import '../config/index.dart';
import '../utils/request.dart';

class StoreApi {
  /// 门店列表(/api/store/page)
  /// * 返回 data.list, 单条门店含 store_id / store_name / full_address / address 等
  /// * full_address 为省市区文本, address 为详细地址(展示时两者拼接)
  static Future<List<Map<String, dynamic>>> page({
    int page = 1,
    int pageSize = 20,
  }) async {
    final dynamic res = await Request().get(
      '/api/store/page',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    final dynamic list = res is Map ? res['list'] : null;
    if (list is List) {
      return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// 门店详情(/api/store/info)
  /// * 返回 store_name / telphone / full_address / address / open_date / store_introduce 等
  static Future<Map<String, dynamic>> info(int storeId) async {
    final dynamic res = await Request().get(
      '/api/store/info',
      queryParameters: <String, dynamic>{'store_id': storeId},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 图片地址: 相对路径拼接 Config.imgDomain
  static String img(dynamic url) {
    final String path = '$url'.trim();
    if (path.isEmpty || path == 'null') return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${Config.imgDomain}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
