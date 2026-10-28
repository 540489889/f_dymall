/// 手机桌面长按 App 图标的快捷入口(扫一扫 / 每日任务 / 付款码)
/// 基于 quick_actions: 冷启动(通过 initialize 回调下发)与热启动(后台点快捷方式)都会触发同一回调。
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:quick_actions/quick_actions.dart';

class ShortcutHelper {
  static final QuickActions _qa = QuickActions();

  /// 设置快捷方式并注册点击回调。
  /// * iOS 自定义图标需放入 Asset Catalog, 这里不传入避免缺图崩溃(仅显示文字)。
  /// * Android 图标引用 res/drawable 下的矢量图(ic_scan / ic_task / ic_pay)。
  static void init() {
    _qa.initialize((String? type) {
      if (type != null) _navigate(type);
    });

    final bool isIOS = !kIsWeb && Platform.isIOS;
    _qa.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'scan',
        localizedTitle: '扫一扫',
        icon: isIOS ? null : 'ic_scan',
      ),
      ShortcutItem(
        type: 'task',
        localizedTitle: '每日任务',
        icon: isIOS ? null : 'ic_task',
      ),
      ShortcutItem(
        type: 'pay',
        localizedTitle: '付款码',
        icon: isIOS ? null : 'ic_pay',
      ),
    ]);
  }

  /// 快捷方式点击 -> 跳转对应路由。
  /// 未登录访问需登录路由时, RouteMiddleware 会自动跳转到 /login。
  static void _navigate(String type) {
    final String? route = _routeOf(type);
    if (route != null) Get.toNamed(route);
  }

  static String? _routeOf(String type) {
    switch (type) {
      case 'scan':
        return '/scan';
      case 'task':
        return '/earn'; // 赚钱页(任务中心)
      case 'pay':
        return '/my/payment_qrcode'; // 付款码
      default:
        return null;
    }
  }
}
