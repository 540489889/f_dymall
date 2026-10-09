/// 公告接口(/api/notice/page)
library;

import '../utils/request.dart';

class NoticeApi {
  /// 公告分页列表(POST /api/notice/page)
  /// * 入参: page / page_size
  /// * 返回 {page_count, count, list}
  /// * list 单项: id / title / content(富文本 HTML) / create_time(秒级时间戳)
  ///   / is_top(1 置顶) / sort / receiving_type / receiving_name
  static Future<Map<String, dynamic>> page({int page = 1, int pageSize = 10}) async {
    final dynamic res = await Request().post(
      '/api/notice/page',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      final dynamic list = res['list'];
      return <String, dynamic>{
        'page_count': int.tryParse('${res['page_count'] ?? 1}') ?? 1,
        'count': int.tryParse('${res['count'] ?? 0}') ?? 0,
        'list': list is List ? list : const <dynamic>[],
      };
    }
    return <String, dynamic>{'page_count': 1, 'count': 0, 'list': const <dynamic>[]};
  }
}
