/// 主框架底部 tab 切换控制器
/// * Layout 在 initState 把自身的「按 type 切 tab」方法注册进来, dispose 解注册
/// * 推送/深链等外部入口(如任务中心通知)通过 switchTo('earn') 切到指定 tab
library;

import 'package:get/get.dart';

class MainTabController extends GetxController {
  void Function(String type)? _switcher;

  void register(void Function(String) fn) => _switcher = fn;

  void unregister(void Function(String) fn) {
    if (_switcher == fn) _switcher = null;
  }

  void switchTo(String type) {
    try {
      _switcher?.call(type);
    } catch (_) {}
  }
}
