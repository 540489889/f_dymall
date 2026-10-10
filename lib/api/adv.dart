/// 广告相关接口
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../config/index.dart';
import '../utils/request.dart';

class AdvApi {
  /// 广告位下的广告列表(/api/adv/detail)
  /// * [keyword] 广告位关键字(如 MEMBER_M: 我的页面"我的订单"上方)
  /// * POST + form-data(与 H5 一致), 只传 keyword
  /// * 返回结构: data{adv_position{广告位信息}, adv_list[{adv_id, adv_title, adv_url, adv_image}]}
  /// * 返回已归一化的广告数组(元素见 [advItem]); 失败/无图返回空数组
  static Future<List<Map<String, dynamic>>> list(String keyword) async {
    final String kw = keyword.trim();
    if (kw.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final Map<String, dynamic> res = await Request().postRaw(
        '/api/adv/detail',
        data: <String, dynamic>{'keyword': kw},
        // 后端按表单解析($_POST['keyword']), 走 x-www-form-urlencoded
        form: true,
      );
      if ('${res['code']}' != '0') {
        debugPrint('[adv]广告详情返回异常($kw): ${res['code']} ${res['message']}');
        return const <Map<String, dynamic>>[];
      }
      return advList(res['data']);
    } catch (e) {
      debugPrint('[adv]广告详情加载失败($kw): $e');
      return const <Map<String, dynamic>>[];
    }
  }

  /// 广告位里的第一张广告(只有一个坑位时用); 没广告返回空 map
  static Future<Map<String, dynamic>> detail(String keyword) async {
    final List<Map<String, dynamic>> items = await list(keyword);
    if (items.isEmpty) return const <String, dynamic>{};
    return items.first;
  }

  /// 取广告列表(data.adv_list)
  /// * data 也可能是数组(部分端直接下发列表), 兜一下
  /// * 只保留有图的条目: 没图的广告展示出来是一块空白
  static List<Map<String, dynamic>> advList(dynamic data) {
    final dynamic raw = data is Map ? (data['adv_list'] ?? data['list'] ?? data['data']) : data;
    if (raw is! List) return const <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final dynamic one in raw) {
      if (one is! Map) continue;
      final Map<String, dynamic>? item = advItem(one);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// 单条广告归一化
  /// * 输出 {image, link, title}; 没图返回 null(整条丢弃)
  /// * 字段: image <- adv_image / image / img / src / picture / pic
  ///         link  <- adv_url / link / url / href / jump_url(为空时点击不跳转)
  static Map<String, dynamic>? advItem(Map<dynamic, dynamic> raw) {
    final String image = imageOf(raw['adv_image'] ?? raw['adv_image_path'] ?? raw['image'] ??
        raw['img'] ?? raw['src'] ?? raw['picture'] ?? raw['pic']);
    if (image.isEmpty) return null;
    final String link = '${raw['adv_url'] ?? raw['link'] ?? raw['url'] ?? raw['href'] ?? raw['jump_url'] ?? ''}'
        .trim()
        .replaceAll(r'\/', '/');
    final String title = '${raw['adv_title'] ?? raw['title'] ?? raw['name'] ?? raw['adv_name'] ?? ''}'.trim();
    return <String, dynamic>{'image': image, 'link': link, 'title': title};
  }

  /// 图片地址: 支持字符串 / 数组 / {url:...}; 相对路径按图片域名补全
  static String imageOf(dynamic val) {
    dynamic raw = val;
    if (raw is List) raw = raw.isNotEmpty ? raw.first : null;
    if (raw is Map) raw = raw['url'] ?? raw['src'] ?? raw['image'] ?? raw['path'];
    // 后端下发的是 JSON 里转义过的地址(https:\/\/xxx): 解析后仍会带 \/ , 不还原图片加载不出来
    final String url = '${raw ?? ''}'.trim().replaceAll(r'\/', '/');
    if (url.isEmpty || url == 'null') return '';
    if (url.startsWith('http')) return url;
    return '${Config.imgDomain}/$url';
  }
}
