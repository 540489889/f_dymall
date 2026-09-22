/// 商品评价接口
/// 对齐 H5: pages_tool/goods/evaluate.vue + components/goods-detail-view
/// * /api/goodsevaluate/config             评价配置(evaluate_show: 1 详情页展示评价)
/// * /api/goodsevaluate/getgoodsevaluate   各类型评价数量
/// * /api/goodsevaluate/page               评价列表(按 explain_type 筛选)
library;

import '../config/index.dart';
import '../utils/request.dart';

class GoodsEvaluateApi {
  /// 评价配置(/api/goodsevaluate/config)
  /// * 返回 { evaluate_status, evaluate_show, evaluate_audit }
  static Future<Map<String, dynamic>> config() async {
    final dynamic res = await Request().post('/api/goodsevaluate/config');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 评价数量(/api/goodsevaluate/getgoodsevaluate)
  /// * 返回 { total, haoping, zhongping, chaping }
  static Future<Map<String, dynamic>> count(int goodsId) async {
    final dynamic res = await Request().post(
      '/api/goodsevaluate/getgoodsevaluate',
      data: <String, dynamic>{'goods_id': goodsId},
      form: true,
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 评价列表(/api/goodsevaluate/page)
  /// * [explainType] 0 全部 / 1 好评 / 2 中评 / 3 差评
  /// * 返回 { list: [...], count, page_count }
  static Future<Map<String, dynamic>> page({
    required int goodsId,
    int page = 1,
    int pageSize = 10,
    int explainType = 0,
  }) async {
    final dynamic res = await Request().post(
      '/api/goodsevaluate/page',
      data: <String, dynamic>{
        'goods_id': goodsId,
        'page': page,
        'page_size': pageSize,
        if (explainType != 0) 'explain_type': explainType,
      },
      form: true,
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 列表项 -> 标准 Map
  static List<Map<String, dynamic>> listOf(dynamic data) {
    final dynamic list = data is Map ? data['list'] : data;
    if (list is! List) return <Map<String, dynamic>>[];
    return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 评价图片(images / again_images: 逗号分隔字符串或数组)
  static List<String> imagesOf(Map<String, dynamic> item, {String field = 'images'}) {
    final dynamic raw = item[field];
    final List<String> paths = <String>[];
    if (raw is List) {
      for (final dynamic e in raw) {
        if ('$e'.trim().isNotEmpty) paths.add('$e'.trim());
      }
    } else if (raw is String && raw.isNotEmpty) {
      paths.addAll(raw.split(',').map((String e) => e.trim()).where((String e) => e.isNotEmpty));
    }
    return paths.map(img).where((String e) => e.isNotEmpty).toList();
  }

  /// 昵称(H5: 匿名时首字+***+尾字)
  static String memberNameOf(Map<String, dynamic> item) {
    final String name = '${item['member_name'] ?? ''}';
    final bool anonymous = '${item['is_anonymous'] ?? ''}' == '1';
    if (anonymous && name.length > 2) return '${name[0]}***${name[name.length - 1]}';
    return name;
  }

  /// 头像(相对路径拼接图片域名)
  static String headimgOf(Map<String, dynamic> item) {
    return img(item['member_headimg']);
  }

  /// 评价时间(create_time 秒级时间戳)
  static String timeOf(Map<String, dynamic> item) {
    final int time = int.tryParse('${item['create_time'] ?? ''}') ?? 0;
    if (time <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(time.toString().length <= 10 ? time * 1000 : time);
    final String mm = '${date.month}'.padLeft(2, '0');
    final String dd = '${date.day}'.padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  /// 图片地址: 相对路径拼接 Config.imgDomain
  static String img(dynamic url) {
    final String path = '$url'.trim();
    if (path.isEmpty || path == 'null') return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${Config.imgDomain}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
