/// 自定义粘性委托类
library;

import 'package:flutter/material.dart';

class CustomStickyHeader extends SliverPersistentHeaderDelegate {
final PreferredSize child;

CustomStickyHeader({required this.child});

@override
double get minExtent => child.preferredSize.height;

@override
double get maxExtent => child.preferredSize.height;

@override
bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
  return true;
}

@override
Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
  return child;
  }
}
