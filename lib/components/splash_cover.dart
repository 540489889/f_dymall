/// 启动图遮罩(Flutter 侧)
/// * 冷启动: 系统原生启动图(android launch_background / iOS LaunchScreen)
/// * Flutter 首帧: 由本遮罩继续展示同一张启动图
/// * 首屏数据就绪: 淡出并移除,直接露出已渲染好的首页
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_splash.dart';

class SplashCover extends StatefulWidget {
  const SplashCover({super.key});

  /// 启动图资源(与原生启动图同一张,保证冷启动过渡不跳)
  static const String image = 'assets/images/satrt_bg.png';

  /// 兜底超时: 首屏请求异常/迟迟不返回时强制放行,不能一直盖着
  static const Duration timeout = Duration(seconds: 6);

  /// 最短展示时长: 数据秒回时也不让启动图一闪而过
  static const Duration minDuration = Duration(milliseconds: 300);

  @override
  State<SplashCover> createState() => _SplashCoverState();
}

class _SplashCoverState extends State<SplashCover> with SingleTickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  Timer? _timeout;
  Timer? _minTimer;
  bool _minElapsed = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    AppSplash.ready.addListener(_onReady);
    // 最短展示时长到了才允许淡出
    _minTimer = Timer(SplashCover.minDuration, () {
      _minElapsed = true;
      if (AppSplash.ready.value) _startFade();
    });
    // 兜底: 超时直接置为就绪(监听回调会自动触发淡出)
    _timeout = Timer(SplashCover.timeout, () => AppSplash.dismiss());
  }

  void _onReady() {
    if (!AppSplash.ready.value || !_minElapsed) return;
    _startFade();
  }

  void _startFade() {
    if (_fade.isAnimating || _fade.isCompleted) return;
    _fade.forward().whenComplete(() {
      if (mounted) setState(() => _removed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _minTimer?.cancel();
    AppSplash.ready.removeListener(_onReady);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fade),
      // 未淡出时吞掉点击,避免误触到下面的页面
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: SizedBox.expand(
          child: Image.asset(SplashCover.image, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ),
    );
  }
}
