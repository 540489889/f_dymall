import 'package:flutter/material.dart';

// 直播中"正在播放"动效: 3 根上下跳动的竖条(经典 now-playing 指示),自带动画控制器
// * 抽成共享组件, 首页直播卡片与直播列表 badge 复用同一套动画
class LivePlayingBars extends StatefulWidget {
  final Color color;
  final double height;
  const LivePlayingBars({super.key, this.color = Colors.white, this.height = 12.0});

  @override
  State<LivePlayingBars> createState() => _LivePlayingBarsState();
}

class _LivePlayingBarsState extends State<LivePlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.height * 0.9,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _bar(0.0, 0.45),
          _bar(0.2, 1.0),
          _bar(0.4, 0.65),
        ],
      ),
    );
  }

  Widget _bar(double delay, double ratio) {
    final double maxH = widget.height;
    final Animation<double> a = Tween<double>(begin: maxH * 0.25, end: maxH * ratio).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(delay, delay + 0.6, curve: Curves.easeInOut),
      ),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (BuildContext context, Widget? child) => Container(
        width: 2.0,
        height: a.value,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1.0),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
