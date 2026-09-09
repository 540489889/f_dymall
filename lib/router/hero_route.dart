/// hero动效路由
library;

import 'package:flutter/material.dart';

class HeroRoute extends PageRouteBuilder {
  final Widget route;
  HeroRoute({required this.route}) : super(
  pageBuilder: (
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => route, transitionsBuilder: (
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>FadeTransition(
    opacity: animation,
    child: child,
  ),
);
}
