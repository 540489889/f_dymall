/// 渐隐路由
library;

import 'package:flutter/material.dart';

class FadeRoute extends PopupRoute {
  FadeRoute({
  this.backgroundColor = Colors.black54,
  this.effect = 'fade',
  required this.child
});

// 背景色
final Color backgroundColor;
// 进场动画(渐变fade 左向右left 右向左right 下向上bottom 上向下top)
final String effect;
// 页面组件
final Widget child;

final Duration _duration = const Duration(milliseconds: 300);

@override
Color? get barrierColor => backgroundColor;

@override
bool get barrierDismissible => true;

@override
String? get barrierLabel => null;

@override
Duration get transitionDuration => _duration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
  if(effect == 'fade') {
    // 渐隐效果
    return FadeTransition(
    opacity: animation,
    child: child,
  );
}else if(effect == 'left') {
  // 左向右效果
  return SlideTransition(
    position: Tween(begin: const Offset(-1.0, 0), end: Offset.zero).animate(animation),
    child: child,
  );
}else if(effect == 'right') {
  // 右向左效果
  return SlideTransition(
    position: Tween(begin: const Offset(1.0, 0), end: Offset.zero).animate(animation),
    child: child,
  );
}else if(effect == 'top') {
  // 上向下效果
  return SlideTransition(
    position: animation.drive(Tween(begin: const Offset(0.0, -1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut))),
    child: child,
  );
}else if(effect == 'bottom') {
  // 下向上效果
  return SlideTransition(
    position: animation.drive(Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut))),
    child: child,
    );
  }else {
      return child;
    }
  }
}
