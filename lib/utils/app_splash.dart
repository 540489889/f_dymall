/// 启动图时序控制
/// * 冷启动时由 components/splash_cover.dart 盖一层启动图,
///   首页首屏数据加载完成后调用 AppSplash.dismiss() 关闭,
///   避免用户先看到"暂无数据"再等列表渲染出来
library;

import 'package:flutter/foundation.dart';

class AppSplash {
  AppSplash._();

  /// true 表示首屏数据已就绪,可以关闭启动图
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// 标记首屏就绪(幂等: 多处调用只有第一次生效)
  static void dismiss() {
    if (ready.value) return;
    ready.value = true;
  }
}
