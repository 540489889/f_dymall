/// 订单状态展示样式(颜色 / 图标 / 背景渐变)
/// 对齐 H5 不同订单状态使用不同视觉的约定
/// status 取值:
///   '0' 待付款  '1' 待发货  '2' 待收货/待使用
///   '3' 已完成  '4' 已关闭  '5' 已取消
library;

import 'package:flutter/material.dart';

class OrderStatusMeta {
  final Color color;
  final IconData icon;
  final List<Color> gradient;

  const OrderStatusMeta(this.color, this.icon, this.gradient);
}

class OrderStatusStyle {
  static const Color defaultColor = Color(0xFFFF2C55);

  static OrderStatusMeta meta(String status) {
    switch (status) {
      case '0': // 待付款
        return const OrderStatusMeta(
          Color(0xFFFF9C00),
          Icons.account_balance_wallet_outlined,
          <Color>[Color(0xFFFFB23E), Color(0xFFFF9C00)],
        );
      case '1': // 待发货
        return const OrderStatusMeta(
          Color(0xFFFF2C55),
          Icons.inventory_2_outlined,
          <Color>[Color(0xFFFF5577), Color(0xFFFF2C55)],
        );
      case '2': // 待收货 / 待使用
        return const OrderStatusMeta(
          Color(0xFF2D8CF0),
          Icons.local_shipping_outlined,
          <Color>[Color(0xFF4FA8FF), Color(0xFF2D8CF0)],
        );
      case '3': // 已完成
        return const OrderStatusMeta(
          Color(0xFF07C160),
          Icons.check_circle_outline,
          <Color>[Color(0xFF38D08A), Color(0xFF07C160)],
        );
      case '4': // 已关闭
      case '5': // 已取消
      case '-1': // 已关闭(H5 部分接口约定)
        return const OrderStatusMeta(
          Color(0xFF999999),
          Icons.do_not_disturb_on_outlined,
          <Color>[Color(0xFFBBBBBB), Color(0xFF999999)],
        );
      default:
        return const OrderStatusMeta(
          defaultColor,
          Icons.receipt_long_outlined,
          <Color>[Color(0xFFFF5577), defaultColor],
        );
    }
  }
}
