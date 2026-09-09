import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/auth_store.dart';
import '../layouts/index.dart';

/* 引入路由页面 */
import '../pages/auth/login.dart';
import '../pages/auth/register.dart';
// 直播
import '../pages/live/live.dart';
// 商品详细
import '../pages/goods/detail.dart';
// 聊天消息
import '../pages/chat/chat.dart';
// 订单
import '../pages/order/index.dart';
import '../pages/order/detail.dart';
import '../pages/order/order_sure.dart';
// 钱包
import '../pages/my/wallet.dart';
import '../pages/my/recharge.dart';

// 路由地址集合
final Map<String, Widget> routes = {
 '/': const Layout(),
  '/live': const Live(),
 '/goods': const Goods(),
 '/chat': const Chat(),
'/order': const Order(),
 '/order/detail': const OrderDetail(),
  '/order/ordersure': const OrderSure(),
 '/my/wallet': const Wallet(),
'/my/recharge': const Recharge(),
};

final List<GetPage> routeList = routes.entries.map((e) => GetPage(
 name: e.key, // 路由名称
  page: () => e.value, // 路由页面
 transition: Transition.cupertino, // 跳转路由动画
middlewares: [RouteMiddleware()], // 路由中间件
)).toList();

final List<GetPage> routePages = [
 GetPage(name: '/login', page: () => const Login()),
GetPage(name: '/register', page: () => const Register()),
  ...routeList,
];

// 路由中间件拦截验证
class RouteMiddleware extends GetMiddleware {
 final authStore = AuthStore.to;
  @override
  RouteSettings? redirect(String? route) {
   return authStore.isLogin ? null : const RouteSettings(name: '/login');
 }
}