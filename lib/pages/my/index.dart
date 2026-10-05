/// 我的模板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controller/auth_store.dart';

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

  Widget _buildAvatar() {
    final Widget placeholder = Image.asset(
      'assets/images/me/mine_avatar_default.png',
      width: 66.0,
      height: 66.0,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(width: 66.0, height: 66.0, child: Icon(Icons.person, color: Colors.grey)),
    );
    final String url = authStore.headimg;
    if (url.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        url,
        width: 66.0,
        height: 66.0,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  /// 顶部图标(消息/收藏/视频/扫码/设置)
  Widget _topIcon(String asset, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Image.asset(asset, width: 24.0, height: 24.0, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: 24.0, height: 24.0)),
      ),
    );
  }

  /// 通用白色卡片
  Widget _whiteCard({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12.0, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  /// 菜单入口(图标 + 文字)
  Widget _menuItem({required String label, required String image, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(image, width: 32.0, height: 32.0, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 32.0, height: 32.0)),
            const SizedBox(height: 8.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  // 会员徽章: 普通会员直接显示完整徽章图; 其他等级用白底胶囊 + 图标 + 文字
  Widget _buildMemberBadge() {
    if (_levelText == '普通会员') {
      return Image.asset(
        'assets/images/me/mine_badge_member.png',
        width: 76.0,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(width: 76.0, height: 26.0),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6.0, 3.0, 10.0, 3.0),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14.0, color: Color(0xFFFF7A33)),
          const SizedBox(width: 3.0),
          Text(_levelText,
              style: const TextStyle(fontSize: 11.0, color: Color(0xFFFF7A33), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 顶部橙色渐变区域
  Widget _buildHeader(double statusTop) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9A70), Color(0xFFFF7A50)],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: statusTop),
          // 右上角图标
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _topIcon('assets/images/me/mine_icon_msg.png', () => _checkLogin(() => Get.toNamed('/chat'))),
                _topIcon('assets/images/me/mine_icon_star.png', () {}),
                _topIcon('assets/images/me/mine_icon_video.png', () => Get.snackbar('提示', '功能开发中')),
                _topIcon('assets/images/me/mine_icon_scan.png', () {}),
                _topIcon('assets/images/me/mine_icon_setting.png', () => authStore.isLogin ? Get.toNamed('/personal_info') : Get.toNamed('/login')),
              ],
            ),
          ),
          // 用户信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Row(
              children: [
                // 头像
                Container(
                  width: 70.0,
                  height: 70.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: authStore.isLogin ? _buildAvatar() : const Icon(Icons.person, color: Colors.white70, size: 40.0),
                ),
                const SizedBox(width: 12.0),
                // 信息
                Expanded(
                  child: authStore.isLogin
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_maskedMobile,
                                style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8.0),
                            _buildMemberBadge(),
                          ],
                        )
                      : GestureDetector(
                          onTap: () => Get.toNamed('/login'),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('登录 / 注册',
                                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(height: 6.0),
                              Text('登录后查看订单 / 余额 / 优惠券', style: TextStyle(fontSize: 12.0, color: Colors.white70)),
                            ],
                          ),
                        ),
                ),
                // 内部门店
                if (authStore.isLogin)
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(authStore.hasStore ? '内部门店' : '绑定门店',
                              style: const TextStyle(fontSize: 12.0, color: Color(0xFFFF7A33), fontWeight: FontWeight.w500)),
                          const Icon(Icons.chevron_right, color: Color(0xFFFF7A33), size: 16.0),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 顶部区域: 渐变头部 + 统计卡(统计卡作为独立卡片置于头部下方)
  Widget _buildTopArea(double statusTop) {
    return Column(
      children: [
        _buildHeader(statusTop),
        _buildStatsCard(),
      ],
    );
  }

  // 统计卡: 余额 / 积分 / 优惠券
  Widget _buildStatsCard() {
    final bool isLogin = authStore.isLogin;
    return _whiteCard(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
      child: Row(
        children: [
            Expanded(
              child: InkWell(
                onTap: () => _onStatTap('余额'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLogin ? authStore.balance : '--',
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    const SizedBox(height: 4.0),
                    const Text('余额', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                  ],
                ),
              ),
            ),
            Container(width: 1.0, height: 32.0, color: const Color(0xFFEEEEEE)),
            Expanded(
              child: InkWell(
                onTap: () => _onStatTap('积分'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLogin ? authStore.point : '--',
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    const SizedBox(height: 4.0),
                    const Text('积分', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                  ],
                ),
              ),
            ),
            Container(width: 1.0, height: 32.0, color: const Color(0xFFEEEEEE)),
            Expanded(
              child: InkWell(
                onTap: () => _onStatTap('优惠券'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLogin ? '${authStore.couponCount}' : '--',
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    const SizedBox(height: 4.0),
                    const Text('优惠券', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  // 我的订单
  Widget _buildOrderCard() {
    return _whiteCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('我的订单', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const Spacer(),
              InkWell(
                onTap: () => _checkLogin(() => Get.toNamed('/order')),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('查看全部', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                    Icon(Icons.chevron_right, color: Color(0xFF999999), size: 16.0),
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
                  image: 'assets/images/me/mine_icon_order_unpaid.png',
                  label: '待付款',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitpay'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_unshipped.png',
                  label: '待发货',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitsend'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_unreceived.png',
                  label: '待收货',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'waitconfirm'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_touse.png',
                  label: '待使用',
                  onTap: () => _checkLogin(() => Get.toNamed('/order', arguments: {'status': 'wait_use'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_aftersale.png',
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
    return _whiteCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的服务', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_livemic.png',
                  label: '直播连麦',
                  onTap: () => _checkLogin(() => Get.toNamed('/live')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_account.png',
                  label: '我的账户',
                  onTap: () => _checkLogin(() => Get.toNamed('/my/withdraw_account')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_address.png',
                  label: '收货地址',
                  onTap: () => _checkLogin(() => Get.toNamed('/address')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_medal.png',
                  label: '看播集章',
                  onTap: () => _checkLogin(() => Get.toNamed('/stamp')),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_support.png',
                  label: '联系客服',
                  onTap: () => _checkLogin(() => Get.toNamed('/chat')),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_invite.png',
                  label: '邀请好友',
                  onTap: () => Get.snackbar('提示', '邀请功能开发中'),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_svc_about.png',
                  label: '关于我们',
                  onTap: () => Get.toNamed('/agreement'),
                ),
              ),
              Expanded(child: const SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }

  // 底部版权
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Expanded(
            child: Divider(indent: 30.0, endIndent: 8.0, color: Color(0xFFDDDDDD), height: 1.0),
          ),
          Text('Copyright © 2023-2026 乐惠新零售 All Rights Reserved.',
              style: TextStyle(fontSize: 11.0, color: Color(0xFFBBBBBB))),
          Expanded(
            child: Divider(indent: 8.0, endIndent: 30.0, color: Color(0xFFDDDDDD), height: 1.0),
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
        backgroundColor: const Color(0xFFFFF8F5),
        body: Obx(() {
          // 显式订阅登录态/会员信息/优惠券数量, 让 GetX 能正确刷新本页
          final _ = <dynamic>[authStore.authorization.value, authStore.memberInfo.length, authStore.couponNum.value];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopArea(statusTop),
              _buildOrderCard(),
              _buildServiceCard(),
              _buildFooter(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20.0),
            ],
          );
        }),
      ),
    );
  }
}
