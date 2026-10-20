/// 启动图时序控制
/// * 冷启动时由 components/splash_cover.dart 盖一层启动图,
///   满足两个条件后关闭:
///   1. 首页首屏数据加载完成(AppSplash.dismiss)
///   2. /api/config/init 全局配置已返回或已放弃(AppSplash.markConfigReady)
/// * 加第 2 条是因为底部导航/主题等来自这份配置: 配置没回来就撤启动图,
///   用户会看到底部 tab 从默认样式跳成 diy 样式
library;

import 'package:flutter/foundation.dart';

class AppSplash {
  AppSplash._();

  /// true 表示首屏数据 + 全局配置都就绪,可以关闭启动图
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// 首屏数据已就绪(首页调用 [dismiss])
  static bool _firstScreenReady = false;

  /// /api/config/init 已返回或已放弃重试(AppConfig 调用 [markConfigReady])
  static bool _configReady = false;

  /// 标记首屏就绪(幂等: 多处调用只有第一次生效)
  static void dismiss() {
    if (_firstScreenReady) return;
    _firstScreenReady = true;
    _sync();
  }

  /// 标记全局配置就绪(幂等)
  /// * 由 AppConfig.fetch 在 finally 里调用: 请求成功、失败到放弃重试都算就绪,
  ///   启动图不会卡在等一个注定不回来的请求上
  static void markConfigReady() {
    if (_configReady) return;
    _configReady = true;
    _sync();
  }

  /// 兜底强制关闭(SplashCover 超时): 不等全局配置,直接放行
  /// * 接口迟迟不返回(弱网/服务异常)时不能一直盖着启动图
  static void forceDismiss() {
    _firstScreenReady = true;
    _configReady = true;
    if (ready.value) return;
    ready.value = true;
  }

  /// 两个条件都满足才置为就绪
  static void _sync() {
    if (ready.value) return;
    if (_firstScreenReady && _configReady) ready.value = true;
  }
}
