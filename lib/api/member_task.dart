/// 任务中心接口(membertask 插件)
/// 对齐 H5: pages_tool/membertask 任务列表
/// * 任务列表 /membertask/api/task/lists
library;

import '../utils/request.dart';

class MemberTaskApi {
  /// 任务列表(/membertask/api/task/lists)
  /// * [page] 页码, [pageSize] 每页条数
  /// 返回任务数组, 单项字段: task_id/icon/name/type/type_name/num/num_unit/num_text/
  /// cycle_text/limit_num/reward_type/reward_num_type/reward_text ...
  static Future<List<Map<String, dynamic>>> lists({
    int page = 1,
    int pageSize = 15,
  }) async {
    final dynamic res = await Request().post(
      '/membertask/api/task/lists',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      },
    );
    // 实际返回 data 就是数组
    if (res is List) {
      return res.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    // 兼容 { list: [...] } 的包装
    if (res is Map && res['list'] is List) {
      return (res['list'] as List).whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }
}
