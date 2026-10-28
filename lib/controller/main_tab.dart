/// 主框架底部 tab 切换控制器
/// * 用静态成员持有「按 type 切 tab」的回调, 不依赖 GetX 查找:
///   通知点击 / 深链等外部入口通过 switchTo('earn') 切到指定 tab,
///   但 GetX 在某些时机(如后台被通知拉起)注册状态不稳定, 改用静态更可靠
library;

import 'package:flutter/foundation.dart';

class MainTabController {
  // 静态持有「按 type 切 tab」回调(由 Layout 在 initState 注册, dispose 解注册)
  static void Function(String type)? _switcher;

  static void register(void Function(String) fn) => _switcher = fn;

  static void unregister(void Function(String) fn) {
    if (_switcher == fn) _switcher = null;
  }

  static void switchTo(String type) {
    debugPrint('[tab] switchTo: type=$type hasSwitcher=${_switcher != null}');
    try {
      _switcher?.call(type);
    } catch (e) {
      debugPrint('[tab] switchTo 异常: $e');
    }
  }
}
