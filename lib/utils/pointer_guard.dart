/// 指针守卫: 修复 iOS「广告页关闭回到赚钱页后, 页面能滚动但点击全部失效」
///
/// 成因(iOS + 原生全屏广告):
/// * 广告关闭的那一下点击会被系统穿透给 Flutter, 但此时 App 已进入 hidden/paused;
/// * 穿透进来的只有 DOWN, 对应的 UP 落在广告自己的窗口里, Flutter 永远收不到;
/// * Scrollable 的拖动活动因此无法结束(永远处于 DragScrollActivity),
///   Flutter 在拖动期间会把内容层设为 IgnorePointer(true) ——
///   目的是避免拖拽结束时误触子控件;
/// * 结果: 滚动由 Scrollable 自己的手势处理, 仍然可用;
///   但页面里所有按钮都在 IgnorePointer 之下, 点击全部被吃掉。
///   (与赚钱页 `if (adPlaying) return` 无关, 那些 handler 根本没被调用)
///
/// 处理: 补发 PointerCancelEvent, 让框架把这次拖动收尾并恢复正常状态。
/// * App 不在 resumed 时收到的 DOWN: 立即作废并补发 cancel(广告关闭穿透就属于这种);
/// * 切后台/回前台时仍未抬起的手指: 全部补发 cancel。
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class PointerGuard {
  PointerGuard._();

  /// 仍处于按下状态的指针 -> 最后位置
  static final Map<int, Offset> _down = <int, Offset>{};
  /// 需要在下次收尾时补发 cancel 的指针
  static final Set<int> _stale = <int>{};
  static AppLifecycleState _state = AppLifecycleState.resumed;
  static _GuardObserver? _observer;

  /// 诊断用日志钩子(排查完由调用方置空即可, 不依赖任何诊断代码)
  static void Function(String message)? logger;

  /// 补发 cancel 的次数统计(诊断用)
  static int cancelCount = 0;

  static void install() {
    if (_observer != null) return;
    _observer = _GuardObserver();
    WidgetsBinding.instance.addObserver(_observer!);
  }

  static void onLifecycleChanged(AppLifecycleState state) {
    final AppLifecycleState previous = _state;
    _state = state;
    if (state != AppLifecycleState.resumed) {
      // 切后台时手指还按着的: 系统不会补发抬起, 这里先收尾, 避免拖动状态跨到后台
      _stale.addAll(_down.keys);
      _releaseStale('enter-${state.name}');
    } else if (previous != AppLifecycleState.resumed) {
      // 回前台: 此刻仍被记为"按着"的手指, 全部是切后台前遗留的幽灵指针
      // (手指早就在广告页上抬起了, 但抬起事件没有回传到 Flutter), 一律作废
      _stale.addAll(_down.keys);
      _releaseStale('resume');
    }
  }

  static void _releaseStale(String reason) {
    if (_stale.isEmpty) return;
    final List<int> ids = _stale.toList(growable: false);
    _stale.clear();
    for (final int id in ids) {
      final Offset pos = _down.remove(id) ?? Offset.zero;
      _cancel(id, pos);
    }
    cancelCount += ids.length;
    logger?.call('$reason cancel=${ids.length} pointer=$ids');
  }

  static void _cancel(int pointer, Offset position) {
    // 当前可能正在派发这个 DOWN 事件, 放到微任务里再补发 cancel, 避免重入框架分发流程
    scheduleMicrotask(() {
      try {
        GestureBinding.instance.handlePointerEvent(
          PointerCancelEvent(
            pointer: pointer,
            position: position,
            timeStamp: Duration.zero,
          ),
        );
      } catch (_) {
        // 指针已被框架清理等异常情况: 忽略
      }
    });
  }

  /// 包在 MaterialApp.builder 最外层: 旁路记录指针状态, 不拦截任何事件
  static Widget wrap(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        if (_state != AppLifecycleState.resumed) {
          // App 不在前台时收到的按下(原生广告关闭穿透): 直接作废,
          // 否则 Scrollable 会停在这个永不结束的拖动里, 回前台后整页点不动
          _cancel(event.pointer, event.position);
          cancelCount++;
          logger?.call('drop-down-while-${_state.name} pointer=${event.pointer}');
          return;
        }
        _down[event.pointer] = event.position;
      },
      onPointerUp: (PointerUpEvent event) {
        _down.remove(event.pointer);
        _stale.remove(event.pointer);
      },
      onPointerCancel: (PointerCancelEvent event) {
        _down.remove(event.pointer);
        _stale.remove(event.pointer);
      },
      child: child,
    );
  }
}

class _GuardObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PointerGuard.onLifecycleChanged(state);
  }
}
