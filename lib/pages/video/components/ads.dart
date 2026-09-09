/// 广告红包组件(可拖拽)
library;

import 'package:flutter/material.dart';

class Ads extends StatefulWidget {
  const Ads({super.key});

  @override
State<Ads> createState() => _AdsState();
}

class _AdsState extends State<Ads> with WidgetsBindingObserver {
double winWidth = 0.0;
double winHeight = 0.0;
double dx = 10.0;
double dy = 100.0;
double ballWidth = 50.0;
double ballHeight = 50.0;
bool isAnimate = false;
// 是否显示
bool isVisible = true;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    updateResize();
  });
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}

// 监听窗口尺寸变化
@override
void didChangeMetrics() {
    super.didChangeMetrics();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    updateResize();
  });
}

// 更新设备尺寸
void updateResize() {
  setState(() {
    winWidth = MediaQuery.of(context).size.width;
    winHeight = MediaQuery.of(context).size.height;
  });
}

// 拖拽更新
void onDragUpdate(Offset position) {
  setState(() {
    isAnimate = false;
    dx = (dx + position.dx).clamp(0.0, winWidth - ballWidth);
    dy = (dy + position.dy).clamp(0.0, winHeight - ballHeight);
    });
  }

  // 拖拽结束
  void onDragEnd() {
    setState(() {
    isAnimate = true;
    // 水平吸附
    if (dx + ballWidth / 2 < winWidth / 2) {
      dx = 10.0;
    } else {
      dx = winWidth - ballWidth - 10.0;
    }
    // 垂直边界限制
    dy = dy.clamp(100.0, winHeight / 2 - ballHeight);
  });
}

Widget buildBall() {
  return GestureDetector(
    onTap: () {
    debugPrint('click ads');
  },
  child: Stack(
    children: [
    SizedBox(
    height: ballHeight,
    width: ballWidth,
    child: UnconstrainedBox(
      child: Container(
      height: 40.0,
      width: 40.0,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(50),
        borderRadius: BorderRadius.circular(100.0),
      ),
      child: UnconstrainedBox(
        child: Image.asset('assets/images/hbico.png', width: 18.0, fit: BoxFit.contain,),
      ),
      ),
    )
  ),
    Positioned(
      right: 0,
    top: 0,
    child: GestureDetector(
      child: Icon(Icons.close, color: Colors.white, size: 10.0,),
        onTap: () {
          setState(() {
            isVisible = false;
          });
          },
        ),
        ),
      ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
    visible: isVisible,
    child: AnimatedPositioned(
      duration: Duration(milliseconds: isAnimate ? 200 : 0),
    left: dx,
    top: dy,
    child: Draggable(
      feedback: buildBall(), // 拖拽时显示组件
      childWhenDragging: Container(), // 拖拽时原位置隐藏
      onDragUpdate: (details) {
        onDragUpdate(details.delta);
      },
      onDragEnd: (details) {
        onDragEnd();
      },
      child: buildBall()
    ),
    ),
  );
  }
}
