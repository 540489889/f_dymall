import 'package:flutter/material.dart';

class Backtop extends StatelessWidget {
  const Backtop({
  super.key,
  required this.controller,
  required this.offset,
  this.distance = 1000.0,
});

final ScrollController controller;
/// 滚动位置
final ValueNotifier<double> offset;
/// 距离顶部多远显示
final double distance;

  @override
  Widget build(BuildContext context){
    return ValueListenableBuilder(
    valueListenable: offset,
    // 按钮作为 child 只构建一次: 滚动中每帧仅切换显示状态,不重复重建按钮
    child: IconButton(
      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        shadowColor: WidgetStateProperty.all(Colors.black54),
        elevation: WidgetStateProperty.all(3.0)
      ),
      onPressed: () {
        controller.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      },
    ),
    builder: (context, value, Widget? child) {
      return Visibility(
      visible: value > distance,
      child: child ?? const SizedBox.shrink(),
      );
    },
    );
  }
}
