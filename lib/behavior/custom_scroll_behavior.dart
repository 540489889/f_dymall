/// 自定义默认滚动行为(支持桌面端鼠标滑动)
library;

import 'dart:ui';
import 'package:flutter/material.dart';

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
   PointerDeviceKind.touch,
    PointerDeviceKind.mouse
 };
}
