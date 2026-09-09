/// 自定义公共样式
library;

import 'package:flutter/material.dart';

class FStyle {
  // 模拟Badge
  static Container badge(int count, {
  Color color = Colors.redAccent,
  bool isdot = false,
  double height = 16.0,
  double width = 16.0
}) {
  final num = count > 99 ? '99+' : count;
  return Container(
    alignment: Alignment.center,
    height: isdot ? height / 2 : height,
    width: isdot ? width / 2 : width,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100.00)),
    child: isdot ? null : Text('$num', style: const TextStyle(color: Colors.white, fontSize: 10.0,)),
  );
}
  // 边框
static const border = Divider(color: Color(0xFFBBBBBB), height: 1.0, thickness: .5,);
// 颜色
static const backgroundColor = Color(0xFFEEEEEE);
static const primaryColor = Color(0xFFFF2C55);
static const white = Colors.white;
static const c999 = Color(0xFF999999);
// 间距
static EdgeInsets mt(double v) => .only(top: v);
static EdgeInsets mb(double v) => .only(bottom: v);
static EdgeInsets ml(double v) => .only(left: v);
static EdgeInsets mr(double v) => .only(right: v);
static EdgeInsets mlr(double v) => .symmetric(horizontal: v);
static EdgeInsets mtb(double v) => .symmetric(vertical: v);
static EdgeInsets margin(double v) => .all(v);
}
