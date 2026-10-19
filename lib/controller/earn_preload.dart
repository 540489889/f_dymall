/// 赚钱页首屏数据预拉: 签到状态 + 热门任务
/// * 启动时 main 调 EarnPreload.start() 预拉一次, 进赚钱页首帧就有内容 —— 不再「先没有, 过一会才冒出来」
/// * 页面自己进页面时也会再拉一次(见 earn/index.dart 的 loadSignin / loadTasks),
///   结果写回这里的缓存, 内容没变就不重复 setState
/// * 全部失败静默: 拉不到就按「没数据」处理, 页面不展示对应板块
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../api/member.dart';
import '../api/member_signin.dart';
import '../api/member_task.dart';

class EarnPreload {
  /// 签到开关(1 开启)
  static int signState = 0;
  /// 今日是否已签到
  static int hasSign = 0;
  /// 连续签到天数
  static int signDaysSeries = 0;
  /// 周期天数
  static int cycle = 0;
  /// 签到规则 [{ day, point, growth }]
  static List<Map<String, dynamic>> signRule = <Map<String, dynamic>>[];

  /// 热门任务列表(已映射成界面字段)
  static List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];

  /// 是否已拿到过结果(true 表示结果已确定: 空列表就是后台没配, 页面不再等待)
  static bool signinLoaded = false;
  static bool tasksLoaded = false;

  static bool _started = false;

  /// 启动预拉(幂等, 内部 unawaited, 不阻塞首帧)
  static void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  static Future<void> _run() async {
    await Future.wait<dynamic>(<Future<dynamic>>[
      loadSignin(),
      loadTasks(),
    ]);
  }

  /// 拉签到信息并写缓存(失败保留旧缓存)
  /// * 商家未开启签到(state != 1)也标记 signinLoaded=true: 结果已确定, 页面不再等待
  static Future<void> loadSignin() async {
    try {
      final int state = await MemberSigninApi.status();
      if (state != 1) {
        signinLoaded = true;
        return;
      }
      // 逐个兜底,不能用裸的 Future.wait:
      // /api/member/info 需要登录,游客进页面时它一定会失败,一个失败会让整块签到卡都不显示
      // (游客看到的就是"没有签到板块"); 连续天数拿不到就按 0 处理,规则照常展示
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberApi.info().catchError((_) => null),
        MemberSigninApi.isSign().catchError((_) => 0),
        MemberSigninApi.award().catchError((_) => <String, dynamic>{}),
      ]);
      final dynamic info = res[0];
      final Map<String, dynamic> award =
          res[2] is Map ? (res[2] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final dynamic reward = award['reward'];
      signState = state;
      if (info is Map) signDaysSeries = int.tryParse('${info['sign_days_series'] ?? 0}') ?? 0;
      hasSign = int.tryParse('${res[1]}') ?? 0;
      cycle = int.tryParse('${award['cycle'] ?? 0}') ?? 0;
      signRule = reward is List
          ? reward.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      signinLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[earn-preload] 签到拉取失败: $e');
    }
  }

  /// 拉热门任务并写缓存(失败保留旧缓存)
  static Future<void> loadTasks() async {
    try {
      final List<Map<String, dynamic>> list = await MemberTaskApi.lists();
      tasks = list.map((Map<String, dynamic> e) {
        final String numText = '${e['num_text'] ?? ''}';
        final String cycleText = '${e['cycle_text'] ?? ''}';
        final String desc = cycleText.isEmpty ? numText : '$numText·$cycleText';
        return <String, dynamic>{
          'task_id': e['task_id'],
          'type': e['type'],
          'type_name': '${e['type_name'] ?? ''}',
          'icon': '${e['icon'] ?? ''}',
          'title': '${e['name'] ?? ''}',
          'desc': desc,
          'reward': '${e['reward_text'] ?? ''}',
          'btn': '去完成',
          'done': false,
          'adType': '${e['type']}' == '1' ? 'reward' : 'interstitial',
        };
      }).toList();
      tasksLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[earn-preload] 任务列表拉取失败: $e');
    }
  }
}
