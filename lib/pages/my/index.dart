/// 我的模板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
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

  // 行列表数据
  final List<Map> rowList = [
    {
      'icon': Icons.receipt_long,
      'iconColor': const Color(0xFFFF9A52),
      'iconBg': const Color(0xFFFEF1E8),
      'title': '我的订单',
      'subtitle': '待自提 / 配送中 / 售后',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.storefront,
      'iconColor': const Color(0xFFFF9A52),
      'iconBg': const Color(0xFFFEF1E8),
      'title': '我的自提门店',
      'subtitle': '未绑定 · 请扫码绑定门店',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.location_on_outlined,
      'iconColor': const Color(0xFFFF5C8A),
      'iconBg': const Color(0xFFFFEBF1),
      'title': '收货地址',
      'subtitle': '管理收货地址',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.account_balance_wallet,
      'iconColor': const Color(0xFFFFC83A),
      'iconBg': const Color(0xFFFFF7E0),
      'title': '我的余额',
      'subtitle': '账户余额 · 明细 · 充值提现',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.people_alt,
      'iconColor': const Color(0xFFFF5C8A),
      'iconBg': const Color(0xFFFFEBF1),
      'title': '邀请好友',
      'subtitle': '已赚 ¥6 · 再邀 3 人得 ¥9',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.flag_circle,
      'iconColor': const Color(0xFFFF5C8A),
      'iconBg': const Color(0xFFFFEBF1),
      'title': '我的任务',
      'subtitle': '日常任务 · 成就中心',
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.local_offer_outlined,
      'iconColor': const Color(0xFFFF9A52),
      'iconBg': const Color(0xFFFEF1E8),
      'title': '优惠券',
      'subtitle': '满减券 / 折扣券',
      'trailing': null,
      'trailingColor': const Color(0xFFFF5C8A),
    },
    {
      'icon': Icons.support_agent,
      'iconColor': const Color(0xFFFF5C8A),
      'iconBg': const Color(0xFFFFEBF1),
      'title': '联系客服',
      'subtitle': null,
      'trailing': null,
      'trailingColor': null,
    },
    {
      'icon': Icons.info_outline,
      'iconColor': const Color(0xFF8C9CB8),
      'iconBg': const Color(0xFFF1F4F9),
      'title': '关于我们',
      'subtitle': null,
      'trailing': null,
      'trailingColor': null,
    },
  ];

  void aboutAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          child: SizedBox(
            width: 345.0,
            child: AlertDialog(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', width: 60.0, height: 60.0, fit: BoxFit.cover),
                    const SizedBox(height: 10.0),
                    const Text('Flutter3-DYMall', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 20.0, fontFamily: 'arial')),
                    const SizedBox(height: 5.0),
                    const Text('基于flutter3.41.5+dart3.11+getx仿抖音短视频+直播+聊天App实例。', style: TextStyle(color: Colors.black54, fontSize: 13.0)),
                    const SizedBox(height: 55.0),
                    Text('Power by Andy ©2026/05', style: TextStyle(color: Colors.grey[400], fontSize: 12.0, fontFamily: 'arial')),
                    Text('Q: 282310962', style: TextStyle(color: Colors.grey[400], fontSize: 12.0, fontFamily: 'arial')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void qrcodeAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          child: SizedBox(
            width: 345.0,
            child: AlertDialog(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/qrimg.png', width: 250.0, fit: BoxFit.contain),
                    const SizedBox(height: 15.0),
                    const Text('扫一扫，加我公众号', style: TextStyle(color: Colors.black38, fontSize: 14.0)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 退出登录弹窗
  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: const Text('确认退出当前账号吗？', style: TextStyle(fontSize: 16.0)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          actionsPadding: const EdgeInsets.all(15.0),
          actions: [
            TextButton(
              onPressed: () { Get.back(); },
              child: const Text('取消', style: TextStyle(color: Colors.black54)),
            ),
            TextButton(
              onPressed: () {
                authStore.logout();
                Get.offAllNamed('/login');
              },
              child: const Text('退出登录', style: TextStyle(color: Color(0xFFFF2C55))),
            ),
          ],
        );
      },
    );
  }

  // 已登录用户信息(昵称 + 会员等级徽标 + ID/积分)
  Widget _userInfo() {
    final String level = authStore.memberLevelName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                authStore.nickname.isEmpty ? '乐惠会员' : authStore.nickname,
                style: const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (level.isNotEmpty) ...[
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(color: const Color(0xFFFFAA3A), borderRadius: BorderRadius.circular(4.0)),
                child: Text(level, style: const TextStyle(color: Colors.white, fontSize: 10.0)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6.0),
        Text(
          'ID ${authStore.memberId} · 积分 ${authStore.point}',
          style: const TextStyle(color: Colors.white70, fontSize: 12.0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // 头像: 用会员头像,未设置或加载失败时显示灰色人像占位(不使用示例图片)
  Widget _buildAvatar() {
    const Widget placeholder = Icon(Icons.person, color: Colors.white70, size: 34.0);
    final String url = authStore.headimg;
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  // 未登录用户信息(点击去登录)
  Widget _guestInfo() {
    return GestureDetector(
      onTap: () => Get.toNamed('/login'),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('登录 / 注册', style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
          SizedBox(height: 6.0),
          Text('登录后查看订单 / 金币 / 优惠券', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
        ],
      ),
    );
  }

  // 统计单元格(数字 + 文字),整格可点
  Widget _statCell(String value, String label, Color valueColor, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(color: valueColor, fontSize: 18.0, fontWeight: FontWeight.bold, fontFamily: 'Arial')),
              const SizedBox(height: 4.0),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
            ],
          ),
        ),
      ),
    );
  }

  // 顶部统计点击(未登录先去登录)
  void _onStatTap(String label) {
    if (authStore.authorization.value.isEmpty) {
      Get.toNamed('/login');
      return;
    }
    switch (label) {
      case '余额':
        Get.toNamed('/my/wallet');
        break;
      case '订单':
        Get.toNamed('/order');
        break;
      case '积分':
        Get.toNamed('/my/point');
        break;
      case '优惠券':
        Get.toNamed('/my/coupon');
        break;
    }
  }

  // 列表项点击
  void _onRowTap(BuildContext context, Map item) {
    final String title = item['title'] as String;
    // 未登录:「关于我们」可直接看,其余功能先去登录
    if (authStore.authorization.value.isEmpty && title != '关于我们') {
      Get.toNamed('/login');
      return;
    }
    switch (title) {
      case '我的订单':
        Get.toNamed('/order');
        break;
      case '我的自提门店':
        if (authStore.hasStore) {
          Get.snackbar('提示', authStore.storeName.isNotEmpty ? '已绑定门店：${authStore.storeName}' : '已绑定门店');
        } else {
          Get.toNamed('/bind_store');
        }
        break;
      case '收货地址':
        Get.to<dynamic>(() => const AddressListPage());
        break;
      case '我的余额':
        Get.toNamed('/my/wallet');
        break;
      case '优惠券':
        Get.toNamed('/my/coupon');
        break;
      case '联系客服':
        Get.toNamed('/chat');
        break;
      case '关于我们':
        aboutAlertDialog(context);
        break;
      default:
        Get.snackbar('提示', '$title 功能待接入', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // 列表数据: 自提门店副标题随绑定状态变化
  List<Map<String, dynamic>> _rows() {
    final String storeSub = authStore.hasStore
        ? (authStore.storeName.isNotEmpty ? '已绑定 · ${authStore.storeName}' : '已绑定门店')
        : '未绑定 · 请扫码绑定门店';
    return rowList.map((Map item) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item);
      if (row['title'] == '我的自提门店') row['subtitle'] = storeSub;
      // 优惠券: 显示可用张数(无券时不显示)
      if (row['title'] == '优惠券') {
        final int num = authStore.couponCount;
        row['trailing'] = num > 0 ? '$num张可用' : null;
      }
      return row;
    }).toList();
  }

  // 通用行(彩色图标 + 标题/副标 + 右侧文本 + 箭头)
  Widget _buildRow(Map item, bool showDivider) {
    return Column(
      children: [
        InkWell(
          onTap: () => _onRowTap(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  width: 32.0,
                  height: 32.0,
                  decoration: BoxDecoration(color: item['iconBg'] as Color, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(item['icon'] as IconData, color: item['iconColor'] as Color, size: 18.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item['title'] as String, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500)),
                      if (item['subtitle'] != null) ...[
                        const SizedBox(height: 2.0),
                        Text(item['subtitle'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11.0)),
                      ],
                    ],
                  ),
                ),
                if (item['trailing'] != null)
                  Text(item['trailing'] as String, style: TextStyle(color: item['trailingColor'] as Color, fontSize: 12.0)),
                const SizedBox(width: 4.0),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 60.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 状态栏透明,露出红色头部
        statusBarIconBrightness: Brightness.light, // Android 状态栏图标白色
        statusBarBrightness: Brightness.dark, // iOS 状态栏图标白色
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Obx(() {
        // 登录状态(监听 authorization,登录后自动刷新页面)
        final bool isLogin = authStore.authorization.value.isNotEmpty;
        // 列表数据(自提门店副标题随绑定状态变化)
        final List<Map<String, dynamic>> rows = _rows();
        return ListView(
        padding: EdgeInsets.zero,
        children: [
          // 顶部红色头部(头像 + 用户名 + ID + 设置)
          Container(
            padding: EdgeInsets.only(top: statusTop + 16, left: 15, right: 15, bottom: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF4D5F), Color(0xFFFF7A52)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像
                Container(
                  width: 60.0,
                  height: 60.0,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: isLogin ? _buildAvatar() : const Icon(Icons.person, color: Colors.white70, size: 34.0),
                ),
                const SizedBox(width: 12.0),
                // 用户信息(未登录显示登录入口)
                Expanded(child: isLogin ? _userInfo() : _guestInfo()),
                // 设置(未登录时隐藏)
                if (isLogin)
                  GestureDetector(
                    onTap: () => Get.toNamed('/personal_info'),
                    child: Column(
                      children: const [
                        Icon(Icons.settings_outlined, color: Colors.white, size: 22.0),
                        SizedBox(height: 2.0),
                        Text('设置', style: TextStyle(color: Colors.white, fontSize: 12.0)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 数字统计白卡(上移 22,压在红色头部上)
          Transform.translate(
            offset: const Offset(0, -22),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8.0, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  _statCell(isLogin ? authStore.balance : '--', '余额', const Color(0xFFFF4D5F),
                      onTap: () => _onStatTap('余额')),
                  _statCell(isLogin ? authStore.point : '--', '积分', const Color(0xFFFF7A2A),
                      onTap: () => _onStatTap('积分')),
                  _statCell(isLogin ? '${authStore.couponCount}' : '--', '优惠券', Colors.black87,
                      onTap: () => _onStatTap('优惠券')),
                  _statCell('--', '订单', Colors.black87, onTap: () => _onStatTap('订单')),
                ],
              ),
            ),
          ),
          // 绑定门店红横幅及以下(整体上移 22,抵消数字卡上移的占位差)
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(
              children: [
                if (isLogin && !authStore.hasStore) Container(
            margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF4D5F), Color(0xFFFF7A52)]),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8.0)),
                  child: const Icon(Icons.link, color: Colors.white, size: 20.0),
                ),
                const SizedBox(width: 10.0),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('请先绑定常驻门店', style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4.0),
                      Text('绑定后可到店自提 / 核券 / 下单返金币', style: TextStyle(color: Colors.white70, fontSize: 11.0)),
                      Text('绑定后不可更换', style: TextStyle(color: Colors.white70, fontSize: 11.0)),
                    ],
                  ),
                ),
                const SizedBox(width: 10.0),
                GestureDetector(
                  onTap: () => Get.toNamed('/bind_store'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.0)),
                    child: const Text('去绑定', style: TextStyle(color: Color(0xFFFF4D5F), fontSize: 13.0, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          // 列表 1(订单 / 自提门店 / 金币 / 邀请 / 任务)
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 3.0, offset: const Offset(0, 1))],
            ),
            child: Column(
              children: [
                for (int i = 0; i < 5; i++) _buildRow(rows[i], i < 4),
              ],
            ),
          ),
          // 列表 2(优惠券 / 客服 / 关于)
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 3.0, offset: const Offset(0, 1))],
            ),
            child: Column(
              children: [
                for (int i = 5; i < 8; i++) _buildRow(rows[i], i < 7),
              ],
            ),
          ),
                const SizedBox(height: 42.0),
              ],
            ),
          ),
        ],
      );
      }),
      ),
    );
  }
}