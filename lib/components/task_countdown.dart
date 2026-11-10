/// 浏览类任务倒计时(赚钱页 type=2「浏览商品」/ type=3「观看短剧」/ type=4「观看直播」)
/// * 全局单例: 商品列表页 <-> 商品详情页 / 短剧 / 直播列表来回切换时倒计时连续,不会重置
/// * 只有从任务入口启动计时器后才显示,普通逛商城/刷短剧/看直播不显示
/// * 倒计时归零后调用 /membertask/api/task/complete 上报 task_id
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../api/member_task.dart';

class TaskBrowseTimer {
  TaskBrowseTimer._();

  static final TaskBrowseTimer instance = TaskBrowseTimer._();

  /// 刷新信号(每次状态变化都自增,避免值相同导致 ValueNotifier 不通知)
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  /// 剩余秒数(0 = 计时结束)
  int remaining = 0;

  Timer? timer;
  int totalSeconds = 0;
  int taskId = 0;
  String taskName = '';

  /// 完成上报状态: '' 未开始 / reporting 提交中 / done 成功 / failed 失败
  String reportState = '';

  /// 是否处于「计时中 / 已完成展示」状态
  bool get active => totalSeconds > 0;

  void _notify() => tick.value++;

  void start({required int seconds, int taskId = 0, String taskName = ''}) {
    timer?.cancel();
    this.taskId = taskId;
    this.taskName = taskName;
    totalSeconds = seconds < 0 ? 0 : seconds;
    remaining = totalSeconds;
    reportState = '';
    _notify();
    if (totalSeconds <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      final int next = remaining - 1;
      remaining = next > 0 ? next : 0;
      if (next <= 0) {
        t.cancel();
        timer = null;
        // 归零即上报一次完成(Timer 已取消,不会重复触发)
        unawaited(reportComplete());
      }
      _notify();
    });
  }

  /// 倒计时结束后上报任务完成(task_id),服务端据此累加 complete_num 并发奖
  /// * 失败时 banner 可点击重试
  Future<void> reportComplete() async {
    final int id = taskId;
    if (id <= 0 || reportState == 'reporting') return;
    reportState = 'reporting';
    _notify();
    try {
      await MemberTaskApi.complete(taskId: id);
      reportState = 'done';
    } catch (_) {
      reportState = 'failed';
    }
    _notify();
  }

  void stop() {
    timer?.cancel();
    timer = null;
    totalSeconds = 0;
    taskId = 0;
    taskName = '';
    remaining = 0;
    reportState = '';
    _notify();
  }
}

/// 倒计时胶囊(商品列表 / 商品详情 / 短剧 / 直播列表页共用)
class TaskCountdownBanner extends StatelessWidget {
  const TaskCountdownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final TaskBrowseTimer timer = TaskBrowseTimer.instance;
    return ValueListenableBuilder<int>(
      valueListenable: timer.tick,
      builder: (BuildContext context, int revision, Widget? child) {
        if (!timer.active) return const SizedBox.shrink();
        final int seconds = timer.remaining;
        final bool finished = seconds <= 0;
        final String name = timer.taskName.isEmpty ? '浏览任务' : timer.taskName;
        final String state = timer.reportState;
        final String text;
        final IconData icon;
        if (!finished) {
          text = '$name 倒计时 $seconds 秒';
          icon = Icons.access_time;
        } else if (state == 'done') {
          text = '$name已完成，奖励稍后到账';
          icon = Icons.check_circle_outline;
        } else if (state == 'failed') {
          text = '任务上报失败，点击重试';
          icon = Icons.error_outline;
        } else {
          text = '正在提交任务…';
          icon = Icons.hourglass_top;
        }
        final Widget card = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5C33),
            borderRadius: BorderRadius.circular(22.0),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x33FF5C33), blurRadius: 10.0, offset: Offset(0.0, 3.0)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 16.0),
              const SizedBox(width: 6.0),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w700),
                ),
              ),
              if (finished && state == 'done') ...<Widget>[
                const SizedBox(width: 8.0),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: timer.stop,
                  child: const Icon(Icons.close, color: Colors.white70, size: 14.0),
                ),
              ],
              if (finished && state == 'failed') ...<Widget>[
                const SizedBox(width: 8.0),
                const Icon(Icons.refresh, color: Colors.white70, size: 14.0),
              ],
            ],
          ),
        );
        if (finished && state == 'failed') {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => timer.reportComplete(),
            child: card,
          );
        }
        return card;
      },
    );
  }
}

/// 圆形倒计时(短剧页专用): 右上角小圆,只显示剩余秒数,不带文字提示、不遮挡视频内容
/// * 与 TaskCountdownBanner 共用同一个全局 TaskBrowseTimer,计时与完成上报逻辑完全一致
/// * 归零后圆圈直接隐藏(不再显示完成/提交中/重试图标),上报由全局 Timer 在后台执行
class TaskCountdownCircle extends StatelessWidget {
  const TaskCountdownCircle({super.key});

  static const double size = 48.0;

  @override
  Widget build(BuildContext context) {
    final TaskBrowseTimer timer = TaskBrowseTimer.instance;
    return ValueListenableBuilder<int>(
      valueListenable: timer.tick,
      builder: (BuildContext context, int revision, Widget? child) {
        // 归零即隐藏: 完成上报在后台继续,不需要在短剧页给出完成图标
        if (!timer.active || timer.remaining <= 0) return const SizedBox.shrink();
        final int seconds = timer.remaining;
        final double progress = timer.totalSeconds > 0 ? seconds / timer.totalSeconds : 0.0;
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.0,
                  color: const Color(0xFFFF5C33),
                  backgroundColor: Colors.white24,
                ),
              ),
              Text(
                '$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17.0,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Arial',
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
