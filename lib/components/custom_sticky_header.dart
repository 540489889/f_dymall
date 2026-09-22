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
bool shouldRebuild(covariant CustomStickyHeader oldDelegate) {
  // 只在高度(是否已吸顶)变化时重建,避免滚动中每帧都重建 header 子树(TabBar)
  return oldDelegate.child.preferredSize.height != child.preferredSize.height;
}

@override
Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
  return child;
  }
}
