/// 骨架屏占位: 首屏数据未回来时撑住布局,避免先闪"暂无数据"
library;

import 'package:flutter/material.dart';

/// 从左到右循环扫过的高光,包裹占位布局
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double p = (_controller.value * 1.4 - 0.2).clamp(-0.2, 1.2);
        final List<double> stops = <double>[
          (p - 0.25).clamp(0.0, 1.0),
          p.clamp(0.0, 1.0),
          (p + 0.25).clamp(0.0, 1.0),
        ];
        if (stops[1] <= stops[0]) stops[1] = (stops[0] + 0.001).clamp(0.0, 1.0);
        if (stops[2] <= stops[1]) stops[2] = (stops[1] + 0.001).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const <Color>[Color(0xFFE9EAEE), Color(0xFFF7F8FA), Color(0xFFE9EAEE)],
            stops: stops,
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 占位灰块
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height = 14.0, this.radius = 6.0});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAEE),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 商品卡片骨架: horizontal = 横向单列, 否则瀑布流卡片
class SkeletonGoodsCard extends StatelessWidget {
  const SkeletonGoodsCard({super.key, this.horizontal = false});

  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final Widget image = SkeletonBlock(
      width: horizontal ? 110.0 : double.infinity,
      height: horizontal ? 110.0 : 150.0,
      radius: 8.0,
    );
    final Widget lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        SkeletonBlock(height: 14.0, width: double.infinity),
        SizedBox(height: 10.0),
        FractionallySizedBox(
          widthFactor: 0.6,
          alignment: Alignment.centerLeft,
          child: SkeletonBlock(height: 12.0),
        ),
        SizedBox(height: 10.0),
        FractionallySizedBox(
          widthFactor: 0.4,
          alignment: Alignment.centerLeft,
          child: SkeletonBlock(height: 16.0),
        ),
      ],
    );
    return Skeleton(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[image, const SizedBox(width: 10.0), Expanded(child: lines)],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[image, const SizedBox(height: 10.0), lines],
              ),
      ),
    );
  }
}
