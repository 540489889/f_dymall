import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/auth_store.dart';
import '../layouts/index.dart';

/* 引入路由页面 */
import '../pages/auth/bind_mobile.dart';
import '../pages/auth/login.dart';
import '../pages/auth/register.dart';
import '../pages/goods/evaluate.dart';
import '../pages/store/bind_store.dart';
import '../pages/store/detail.dart';
// 直播
import '../pages/live/live.dart';
// 商品详细
import '../pages/goods/detail.dart';
import '../pages/goods/search.dart';
import '../pages/goods/list.dart';
// 购物车
import '../pages/cart/index.dart';
// 聊天消息
import '../pages/chat/chat.dart';
// 订单
import '../pages/order/index.dart';
import '../pages/order/detail.dart';
import '../pages/order/order_sure.dart';
import '../pages/order/pay_result.dart';
import '../pages/order/logistics.dart';
import '../pages/order/evaluate.dart';
import '../pages/order/refund.dart';
import '../pages/order/refund_list.dart';
import '../pages/order/refund_detail.dart';
// 钱包
import '../pages/my/wallet.dart';
// 积分 / 签到
import '../pages/my/point.dart';
import '../pages/my/point_detail.dart';
import '../pages/my/signin.dart';
import '../pages/my/coupon.dart';
import '../pages/my/recharge.dart';
import '../pages/my/balance_detail.dart';
import '../pages/my/recharge_order.dart';
import '../pages/my/withdraw.dart';
import '../pages/my/withdraw_list.dart';
import '../pages/my/withdraw_detail.dart';
import '../pages/my/withdraw_account.dart';
import '../pages/my/withdraw_account_edit.dart';
// 收货地址
import '../pages/my/address_list.dart';
import '../pages/my/address_edit.dart';
// 看播记录
import '../pages/my/watching_record.dart';
import '../pages/my/watching_record_detail.dart';
// 设置/个人资料
import '../pages/setting/personal_info.dart';
// 关于我们
import '../pages/setting/about.dart';
import '../pages/setting/license_info.dart';
// 协议详情(隐私协议 / 用户协议)
import '../pages/setting/agreement.dart';
// 首次启动隐私政策概要
import '../pages/setting/privacy_agreement.dart';
// 限时秒杀
import '../pages/seckill/list.dart';
import '../pages/seckill/detail.dart';
// 学习课程 / 素材库
import '../pages/study/index.dart';
import '../pages/study/detail.dart';
import '../pages/study/article.dart';
import '../pages/study/more.dart';
// 看播集章
import '../pages/stamp/index.dart';
import '../pages/stamp/detail.dart';
// 公告
import '../pages/notice/list.dart';
import '../pages/notice/detail.dart';
// 积分商城(积分兑换)
import '../pages/point/shop.dart';
import '../pages/point/goods_detail.dart';
import '../pages/point/order_confirm.dart';
import '../pages/point/result.dart';
import '../pages/point/order_list.dart';

// 路由地址集合
final Map<String, Widget> routes = {
 '/': const Layout(),
  '/live': const Live(),
 '/goods': const Goods(),
  // 商品搜索 / 搜索结果分类列表(游客可见,不进 authRoutes)
  '/search': const SearchPage(),
  '/goods/list': const GoodsListPage(),
 '/cart': const CartPage(),
 '/chat': const Chat(),
'/order': const Order(),
 '/order/detail': const OrderDetail(),
 '/order/ordersure': const OrderSure(),
 '/order/pay_result': const PayResultPage(),
 '/order/logistics': const OrderLogistics(),
 '/order/evaluate': const OrderEvaluate(),
 '/order/refund': const OrderRefund(),
 '/order/refund_detail': const OrderRefundDetail(),
'/order/refund_list': const RefundList(),
 '/my/wallet': const Wallet(),
'/my/recharge': const Recharge(),
'/my/balance_detail': const BalanceDetailPage(),
'/my/recharge_order': const RechargeOrderPage(),
'/my/withdraw': const WithdrawPage(),
'/my/withdraw_list': const WithdrawListPage(),
'/my/withdraw_detail': const WithdrawDetailPage(),
'/my/withdraw_account': const WithdrawAccountPage(),
'/my/withdraw_account_edit': const WithdrawAccountEditPage(),
'/my/point': const PointPage(),
'/my/point_detail': const PointDetailPage(),
'/my/signin': const SigninPage(),
'/my/coupon': const MyCouponPage(),
// 看播记录(我的服务入口,个人看播数据,需登录)
'/my/watching_record': const WatchingRecordPage(),
'/my/watching_record/detail': const WatchingRecordDetailPage(),
  '/address': const AddressListPage(),
  '/address/edit': const AddressEditPage(),
  '/personal_info': const PersonalInfoPage(),
  // 关于我们(游客可见,不进 authRoutes)
  '/about': const AboutPage(),
  '/license_info': const LicenseInfoPage(),
  // 首次启动隐私政策概要(游客可见,不进 authRoutes)
  '/privacy_agreement': const PrivacyAgreementPage(),
  // 协议详情: 游客也可查看,不进 authRoutes
  '/agreement': const AgreementPage(),
  '/seckill': const SeckillListPage(),
  '/seckill/detail': const SeckillDetailPage(),
  // 公告: 游客也可查看,不进 authRoutes
  '/notice': const NoticeListPage(),
  '/notice/detail': const NoticeDetailPage(),
  '/point/shop': const PointShopPage(),
  '/point/detail': const PointGoodsDetailPage(),
  '/point/confirm': const PointOrderConfirmPage(),
  '/point/result': const PointResultPage(),
  '/point/order_list': const PointOrderListPage(),
};

// 需要登录后才能访问的路由(其余路由游客可直接浏览)
const Set<String> authRoutes = {
  // 直播间: 进房要连 WebSocket 发弹幕/点赞,必须登录
  '/live',
  '/my/wallet',
  '/my/recharge',
  '/my/balance_detail',
  '/my/recharge_order',
  '/my/withdraw',
  '/my/withdraw_list',
  '/my/withdraw_detail',
  '/my/withdraw_account',
  '/my/withdraw_account_edit',
  '/my/point',
  '/my/point_detail',
  '/my/signin',
  '/my/coupon',
  '/my/watching_record',
  '/my/watching_record/detail',
  '/address',
  '/address/edit',
  '/personal_info',
  '/point/confirm',
  '/point/result',
  '/point/order_list',
  '/order',
  '/order/detail',
  '/order/pay_result',
  '/order/logistics',
  '/order/evaluate',
  '/order/refund',
  '/order/refund_detail',
  '/order/refund_list',
  '/cart',
  '/order/ordersure',
  '/chat',
};

final List<GetPage> routeList = routes.entries.map((e) => GetPage(
 name: e.key, // 路由名称
  page: () => e.value, // 路由页面
 transition: Transition.cupertino, // 跳转路由动画
middlewares: authRoutes.contains(e.key) ? [RouteMiddleware()] : [], // 仅需登录的页面走拦截(注意:不能用 const [],GetX 会 sort)
)).toList();

final List<GetPage> routePages = [
 GetPage(name: '/login', page: () => const Login()),
GetPage(name: '/register', page: () => const Register()),
  GetPage(name: '/goods/evaluate', page: () => const GoodsEvaluatePage()),
  GetPage(name: '/store/detail', page: () => const StoreDetailPage()),
  GetPage(name: '/bind_store', page: () => const BindStorePage()),
  GetPage(name: '/bind_mobile', page: () => const BindMobilePage()),
  // 学习课程 / 素材库(游客可见,不进 authRoutes)
  GetPage(name: '/study', page: () => const StudyIndexPage()),
  GetPage(name: '/study/detail', page: () => const StudyDetailPage()),
  GetPage(name: '/study/article', page: () => const StudyArticlePage()),
  GetPage(name: '/study/more', page: () => const StudyMorePage()),
  // 看播集章(游客可见,不进 authRoutes)
  GetPage(name: '/stamp', page: () => const StampIndexPage()),
  GetPage(name: '/stamp/detail', page: () => const StampDetailPage()),
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