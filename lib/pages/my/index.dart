/// 我的模板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controller/auth_store.dart';
import 'address_list.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final authStore = AuthStore.to;

  @override
  void initState() {
    super.initState();
    // 已登录但会员信息为空(如启动时拉取失败),进入页面补拉一次
    if (authStore.isLogin && authStore.memberInfo.isEmpty) {
      authStore.loadMemberInfo();
    }
    // 券数量: 进入页面刷一次(接口轻量, 内部已做异常兜底)
    if (authStore.isLogin) {
      authStore.loadCouponNum();
    }
  }

  String get _maskedMobile {
    final String m = authStore.mobile;
    if (m.length == 11) return '${m.substring(0, 3)}****${m.substring(7)}';
    return m.isNotEmpty ? m : authStore.nickname;
  }

  String get _levelText {
    final String level = authStore.memberLevelName;
    return level.isNotEmpty ? level : '普通会员';
  }

  void _checkLogin(VoidCallback onLogin) {
    if (!authStore.isLogin) {
      Get.toNamed('/login');
      return;
    }
    onLogin();
  }

  Widget _buildAvatar() {
    const Widget placeholder = Icon(Icons.person, color: Colors.white70, size: 34.0);
    final String url = authStore.headimg;
    if (url.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        url,
        width: 60.0,
        height: 60.0,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  // 顶部：个人中心 + 设置
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          const Text('个人中心', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: () => authStore.isLogin ? Get.toNamed('/personal_info') : Get.toNamed('/login'),
            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24.0),
          ),
        ],
      ),
    );
  }

  // 用户信息卡：头像 + 手机/会员 + 内部门店
  Widget _buildUserCard() {
    final bool isLogin = authStore.isLogin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // 头像
          Container(
            width: 60.0,
            height: 60.0,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: isLogin ? _buildAvatar() : const Icon(Icons.person, color: Colors.white70, size: 34.0),
          ),
          const SizedBox(width: 12.0),
          // 信息
          Expanded(
            child: isLogin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_maskedMobile,
                          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8D0),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium_outlined, size: 12.0, color: Color(0xFFFF8A00)),
                            const SizedBox(width: 2.0),
                            Text(_levelText, style: const TextStyle(fontSize: 11.0, color: Color(0xFFFF8A00))),
                          ],
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () => Get.toNamed('/login'),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('登录 / 注册', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 6.0),
                        Text('登录后查看订单 / 余额 / 优惠券', style: TextStyle(fontSize: 12.0, color: Colors.white70)),
                      ],
                    ),
                  ),
          ),
          // 内部门店
          if (isLogin)
            GestureDetector(
              onTap: () {
                if (authStore.hasStore) {
                  final int sid = authStore.storeId.value;
                  if (sid == 0) {
                    Get.snackbar('提示', authStore.storeName.isNotEmpty ? '已绑定门店：${authStore.storeName}' : '已绑定门店');
                  } else {
                    Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': sid});
                  }
                } else {
                  Get.toNamed('/bind_store');
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(authStore.hasStore ? '内部门店' : '绑定门店',
                      style: const TextStyle(fontSize: 13.0, color: Colors.white)),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 18.0),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 统计单元格
  Widget _statCell(String value, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Arial')),
            const SizedBox(height: 4.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _onStatTap(String label) {
    _checkLogin(() {
      switch (label) {
        case '余额':
          Get.toNamed('/my/wallet');
          break;
        case '积分':
          Get.toNamed('/my/point');
          break;
        case '优惠券':
          Get.toNamed('/my/coupon');
          break;
      }
    });
  }

  // 余额/积分/优惠券 统计白卡
  Widget _buildStatsCard() {
    final bool isLogin = authStore.isLogin;
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 0),
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12.0, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _statCell(isLogin ? authStore.balance : '--', '余额', onTap: () => _onStatTap('余额')),
          _statCell(isLogin ? authStore.point : '--', '积分', onTap: () => _onStatTap('积分')),
          _statCell(isLogin ? '${authStore.couponCount}' : '--', '优惠券', onTap: () => _onStatTap('优惠券')),
        ],
      ),
    );
  }

  // 网格入口项(支持图片图标或矢量图标)
  Widget _menuItem({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
    String? image,
  }) {
    final Widget iconWidget = image != null
        ? Image.asset(image, width: 30.0, height: 30.0, fit: BoxFit.contain)
        : Icon(icon, color: iconColor, size: 24.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42.0,
              height: 42.0,
              alignment: Alignment.center,
              child: iconWidget,
            ),
            const SizedBox(height: 8.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 我的订单
  Widget _buildOrderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12.0, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('我的订单', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              InkWell(
                onTap: () => _checkLogin(() => Get.toNamed('/order')),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('查看全部', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
                    Icon(Icons.chevron_right, color: Colors.grey, size: 16.0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            children: [
              Expanded(
                child: _menuItem(
                  image: 'assets/images/wait_pay.png',
                  label: '待付款',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitpay'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/wait_send.png',
                  label: '待发货',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitsend'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/wait_confirm.png',
                  label: '待收货',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitconfirm'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/wait_use.png',
                  label: '待使用',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'wait_use'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/after_sale.png',
                  label: '售后',
                  onTap: () => _checkLogin(() => Get.toNamed('/order/refund_list')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 我的服务
  Widget _buildServiceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12.0, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的服务', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: _menuItem(
                  image: 'assets/images/live_mic.png',
                  label: '直播连麦',
                  onTap: () => _checkLogin(() => Get.toNamed('/live')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/my_account.png',
                  label: '我的账户',
                  onTap: () => _checkLogin(() => Get.toNamed('/my/withdraw_account')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/my_address.png',
                  label: '收货地址',
                  onTap: () => _checkLogin(() => Get.to<dynamic>(() => const AddressListPage())),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/stamp.png',
                  label: '看播集章',
                  onTap: () => _checkLogin(() => Get.toNamed('/stamp')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Obx(() {
          // 显式订阅登录态/会员信息/优惠券数量, 让 GetX 能正确刷新本页
          final _ = <dynamic>[authStore.authorization.value, authStore.memberInfo.length, authStore.couponNum.value];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // 顶部浅粉色背景区域
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF2C55), Color(0xFFFF9C55)],
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: statusTop),
                    _buildHeader(),
                    _buildUserCard(),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
              // 统计白卡（压住顶部区域下沿）
              _buildStatsCard(),
              // 我的订单
              _buildOrderCard(),
              // 我的服务
              _buildServiceCard(),
              const SizedBox(height: 30.0),
            ],
          );
        }),
      ),
    );
  }
}
