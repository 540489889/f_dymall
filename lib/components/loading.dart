import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
const Loading({
  super.key,
  this.size = 16.0,
  this.spacing = 8.0,
  this.strokeWidth = 2.0,
  this.backgroundColor,
  this.color = const Color(0xFFFF2C55),
  this.title,
});

// 加载图标大小
final double size;
// 图标和文字间距
final double spacing;
// 加载图标线宽度
final double strokeWidth;
// 加载图标背景色
final Color? backgroundColor;
// 加载图标颜色
final Color color;
// 加载提示文字
  final String? title;

  @override
  Widget build(BuildContext context) {
   return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: spacing,
    children: [
   SizedBox(
    height: size,
    width: size,
    child: CircularProgressIndicator(
     backgroundColor: backgroundColor,
      color: color,
     strokeWidth: strokeWidth,
    ),
   ),
    Text(title ?? 'loading...', style: TextStyle(color: Colors.grey, fontSize: 14.0,),)
  ],
 );
 }
}
