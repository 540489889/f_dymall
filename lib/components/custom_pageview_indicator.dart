import 'package:flutter/material.dart';

class CustomPageViewIndicator extends StatefulWidget {
  const CustomPageViewIndicator({
    super.key,
    required this.count,
    required this.controller,
    this.color = Colors.black12,
    this.activeColor = Colors.black26,
    this.pageSnapping = true,
  });

  /// 数量
  final int count;
  final PageController controller;
  /// 颜色
  final Color color;
  /// 激活颜色
  final Color activeColor;
  // 是否停止滑动时吸附到最近页面
  final bool pageSnapping;

  @override
  State<CustomPageViewIndicator> createState() => _CustomPageViewIndicatorState();
}

class _CustomPageViewIndicatorState extends State<CustomPageViewIndicator> {
 int pageIndex = 0;
  double page = 0;
  // 圆点指示器
 Widget dotIndicator() {
  return Row(
   mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
     widget.count,
      (index) => Container(
       margin: EdgeInsets.symmetric(horizontal: 3.0),
        width: pageIndex == index ? 15.0 : 4.0,
        height: 4.0,
       decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
         color: pageIndex == index ? widget.activeColor : widget.color,
        ),
      ),
     ),
    );
  }
  // 滚动槽指示器
  Widget scrollIndicator() {
   return Stack(
    children: [
      Container(
       decoration: BoxDecoration(
        color: widget.color,
       borderRadius: BorderRadius.circular(50.0),
      ),
     height: 4.0,
    width: (widget.count - 1) * 15.0 + 15.0,
    ),
   Container(
    margin: EdgeInsets.only(left: page * 15.0),
     decoration: BoxDecoration(
       color: widget.activeColor,
      borderRadius: BorderRadius.circular(50.0),
      ),
     width: 15.0,
      height: 4.0,
     ),
     ],
    );
  }

  @override
  Widget build(BuildContext context) {
  return widget.count > 1 ?
    widget.pageSnapping ? dotIndicator() : scrollIndicator()
    :
    SizedBox.shrink();
}

void _setInitialPage() {
  pageIndex = widget.controller.initialPage;
  page = pageIndex.toDouble();
}

void _onController() {
  if (!widget.controller.hasClients) return;
  page = widget.controller.page ?? 0.0;
  pageIndex = page.round();
  setState(() {});
  }

  @override
  void initState() {
  super.initState();
  widget.controller.addListener(_onController);
  _setInitialPage();
}

@override
void didUpdateWidget(CustomPageViewIndicator oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.controller != oldWidget.controller) {
    oldWidget.controller.removeListener(_onController);
    widget.controller.addListener(_onController);
  }
}

@override
void dispose() {
  widget.controller.removeListener(_onController);
  super.dispose();
}
}
