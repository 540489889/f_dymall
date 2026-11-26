/// 任务中心接口(membertask 插件)
/// 对齐 H5: pages_tool/membertask 任务列表
/// * 任务列表 /membertask/api/task/lists
/// * 完成上报 /membertask/api/task/complete(task_id)
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

  /// 任务完成上报(/membertask/api/task/complete)
  /// * 浏览类任务倒计时归零后调用,服务端据此累加 complete_num 并发奖
  /// * 参数名固定 task_id
  static Future<Map<String, dynamic>> complete({required int taskId}) async {
    final dynamic res = await Request().post(
      '/membertask/api/task/complete',
      data: <String, dynamic>{'task_id': taskId},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 浏览类任务的倒计时秒数(num 字段即秒数,不受 num_text 文案影响)
  static int browseSeconds(Map<String, dynamic> e) =>
      int.tryParse('${e['num'] ?? 0}') ?? 0;

  /// 列表项 -> 界面字段(赚钱页与启动预拉共用,避免两处映射不一致)
  /// * limit_num: 一共能做多少次, progress_num: 当前已完成次数(界面进度以此为准)
  /// * complete_num 是服务端累计完成数,不用于界面进度展示
  /// * 达到上限后 done=true, 按钮置为「已完成」且不可再做
  static Map<String, dynamic> toUiTask(Map<String, dynamic> e) {
    final int limit = int.tryParse('${e['limit_num'] ?? 0}') ?? 0;
    final int complete = int.tryParse('${e['complete_num'] ?? 0}') ?? 0;
    final int progress = int.tryParse('${e['progress_num'] ?? 0}') ?? 0;
    final String progressText = limit > 0 ? '已完成 $progress/$limit' : '';
    final List<String> descParts = <String>[
      if ('${e['num_text'] ?? ''}'.isNotEmpty) '${e['num_text']}',
      if ('${e['cycle_text'] ?? ''}'.isNotEmpty) '${e['cycle_text']}',
    ];
    return <String, dynamic>{
      'task_id': e['task_id'],
      'type': e['type'],
      'type_name': '${e['type_name'] ?? ''}',
      'icon': '${e['icon'] ?? ''}',
      'title': '${e['name'] ?? ''}',
      'desc': descParts.join('·'),
      'progress_text': progressText,
      'reward': '${e['reward_text'] ?? ''}',
      'btn': '去完成',
      'done': limit > 0 && progress >= limit,
      'limit_num': limit,
      'complete_num': complete,
      'remain_num': int.tryParse('${e['remain_num'] ?? 0}') ?? 0,
      'progress_num': progress,
      'is_limit': int.tryParse('${e['is_limit'] ?? 0}') ?? 0,
      'num': int.tryParse('${e['num'] ?? 0}') ?? 0,
      'num_text': '${e['num_text'] ?? ''}',
      'seconds': browseSeconds(e),
      'adType': '${e['type']}' == '1' ? 'reward' : 'interstitial',
    };
  }
}
