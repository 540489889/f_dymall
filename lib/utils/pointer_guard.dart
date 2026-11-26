/// 全局指针守卫: 修复广告/系统弹窗关闭时"点击穿透"导致页面卡死的问题。
///
/// 根因: 激励视频等原生全屏页关闭那一下, DOWN 事件穿透进了 Flutter, 但 UP 落在
/// 原生窗口上, Flutter 永远收不到 UP -> Scrollable 的 DragGestureRecognizer 一直停在
/// "拖动中" -> viewport 内容被 IgnorePointer 包住 -> 页面所有按钮点不动, 表现为卡死
/// (滚动组件自己还能滚, 因为走的是它自己的手势)。
///
/// 修复: 在最外层跟踪指针状态, 对三类"幽灵指针"补发 PointerCancelEvent 让 gesture
/// arena 正常收尾, 解除滚动组件的拖动锁定:
///   1. App 不在前台时收到的 DOWN(广告关闭穿透) -> 立即作废
///   2. 切后台时仍按着的指针 -> 标记, 回前台后补 CANCEL
///   3. 回前台时仍被记为"按着"的指针 -> 全部补 CANCEL
///
/// 这是全局守卫, 分享面板/系统弹窗/来电等任何"原生界面盖住 App"的场景一并覆盖。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PointerGuard extends StatefulWidget {
  const PointerGuard({super.key, required this.child});

  final Widget child;

  @override
  State<PointerGuard> createState() => _PointerGuardState();
}

class _PointerGuardState extends State<PointerGuard> with WidgetsBindingObserver {
  /// 已 DOWN 但尚未收到 UP/CANCEL 的指针
  final Set<int> _pressed = <int>{};

  /// 切后台时仍按着的指针(幽灵候选), 回前台后统一补 CANCEL
  final Set<int> _staleOnPause = <int>{};

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      // 回前台: 所有仍被记为"按着"的指针都是切后台前遗留的幽灵指针, 全部作废
      final Set<int> ghosts = <int>{..._pressed, ..._staleOnPause};
      _pressed.clear();
      _staleOnPause.clear();
      for (final int pointer in ghosts) {
        debugPrint('[pointer_guard] 回前台补 CANCEL pointer=$pointer');
        _sendCancel(pointer);
      }
    } else if (_pressed.isNotEmpty) {
      // 切后台/失焦: 记录仍按着的指针, 等回前台收尾
      _staleOnPause.addAll(_pressed);
      debugPrint('[pointer_guard] 失焦 $state 记录幽灵指针 $_staleOnPause');
    }
  }

  /// 伪造一个 CANCEL 事件送进 gesture binding, 让卡在"拖动中"的 recognizer 收尾。
  void _sendCancel(int pointer) {
    try {
      GestureBinding.instance.handlePointerEvent(
        PointerCancelEvent(pointer: pointer),
      );
    } catch (e) {
      // pointer 可能已被系统回收, 补发失败不影响其它逻辑
      debugPrint('[pointer_guard] 补 CANCEL 失败 pointer=$pointer err=$e');
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_lifecycle != AppLifecycleState.resumed) {
      // 非前台收到 DOWN(广告关闭穿透): 用 microtask 等本次 DOWN 分发完再补 CANCEL,
      // 避免 CANCEL 抢在 DOWN 前面导致 hit test 顺序错乱。
      debugPrint('[pointer_guard] 非前台 DOWN pointer=${e.pointer} state=$_lifecycle, 作废');
      unawaited(Future<void>.microtask(() => _sendCancel(e.pointer)));
      return;
    }
    _pressed.add(e.pointer);
  }

  void _onPointerUp(PointerUpEvent e) {
    _pressed.remove(e.pointer);
    _staleOnPause.remove(e.pointer);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pressed.remove(e.pointer);
    _staleOnPause.remove(e.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
