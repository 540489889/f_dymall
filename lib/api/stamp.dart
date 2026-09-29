/// 看播集章接口(对应参考项目 stamp 模块, 后端路径 /live/api/shop/*)
library;

import '../config/index.dart';
import '../utils/request.dart';

class StampApi {
  /// 把图片相对路径拼接成完整 url(对齐 H5 config.imgDomain)
  static String fixUrl(dynamic src) {
    final String s = '${src ?? ''}'.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http') || s.startsWith('data:image')) return s;
    return Config.imgDomain + (s.startsWith('/') ? s : '/$s');
  }

  static List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['list'] is List) return data['list'] as List;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return const [];
  }

  /// 集章记录列表
  static Future<Map<String, dynamic>> getStampList({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final dynamic res = await Request().post(
        '/live/api/shop/getStampList',
        data: <String, dynamic>{'page': page, 'page_size': pageSize},
      );
      if (res is Map) {
        return <String, dynamic>{
          'page_count': res['page_count'] ?? 1,
          'count': res['count'] ?? 0,
          'list': _asList(res),
        };
      }
    } catch (_) {}
    return <String, dynamic>{'page_count': 1, 'count': 0, 'list': const []};
  }

  /// 集章详情(日志列表)
  static Future<Map<String, dynamic>> stampLogDetail({
    required int stampId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final dynamic res = await Request().post(
        '/live/api/shop/stampLogDetail',
        data: <String, dynamic>{
          'stamp_id': stampId,
          'page': page,
          'page_size': pageSize,
        },
      );
      if (res is Map) {
        return <String, dynamic>{
          'page_count': res['page_count'] ?? 1,
          'count': res['count'] ?? 0,
          'list': _asList(res),
        };
      }
    } catch (_) {}
    return <String, dynamic>{'page_count': 1, 'count': 0, 'list': const []};
  }
}
