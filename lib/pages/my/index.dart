/// 我的模板
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:get/get.dart';
import '../../api/member.dart';
import '../../api/order.dart';
import '../../components/adv_banner.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controller/app_config.dart';
import '../../controller/my_preload.dart';

/// 底部导航切到「我的」tab 的刷新信号(由 lib/layouts/index.dart 的 onNavTap 自增)
/// * 我的页被 PageView 保活, 不主动刷新的话 memberPageConfig 会停在首次进 tab 时的数据
final ValueNotifier<int> mineTabRefreshTick = ValueNotifier<int>(0);

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final authStore = AuthStore.to;

  /// 是否已拉到结果(只有「没有预拉缓存」时才用骨架占位, 拿到结果后占位撤掉)
  /// * 数据本身走 MyPreload(启动时预拉 + 页面刷新共用一份缓存)
  bool advLoaded = false;
  bool serviceLoaded = false;
  // 是否显示「门店支付」板块: 由 /api/member/memberPageConfig 的 is_pay_code == '1' 决定
  bool payCodeEnabled = false;

  // 我的服务: /api/Member/serviceNav 的配置项(为空则不展示「我的服务」卡片)
  final List<Map<String, dynamic>> serviceList = <Map<String, dynamic>>[];

  // 广告图(/api/adv/detail keyword=MEMBER_M 的 adv_list): 展示在「我的订单」上方
  // * 多张时自动轮播; 后台没配图则整块不显示
  List<Map<String, dynamic>> advList = const <Map<String, dynamic>>[];

  // 我的订单各状态数量(/api/order/num): 订单入口的角标; 接口失败为空, 不显示角标
  Map<String, dynamic> orderNum = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    // 首帧直接用 MyPreload 的预拉结果: 启动时已拉到就当已有数据(loaded), 没拉到才走骨架占位
    if (MyPreload.advLoaded) {
      advList = MyPreload.adv;
      advLoaded = true;
    }
    if (MyPreload.serviceLoaded) {
      serviceList.addAll(MyPreload.service);
      serviceLoaded = true;
    }
    loadServiceNav();
    loadAdv();
    // 已登录但会员信息为空(如启动时拉取失败),进入页面补拉一次
    if (authStore.isLogin && authStore.memberInfo.isEmpty) {
      authStore.loadMemberInfo();
    }
    // 券数量: 进入页面刷一次(接口轻量, 内部已做异常兜底)
    if (authStore.isLogin) {
      authStore.loadCouponNum();
      // 订单角标数量: 需要登录态, 未登录不请求
      loadOrderNum();
    }
    // 切到「我的」tab 时刷新 memberPageConfig(含重复点当前 tab)
    mineTabRefreshTick.addListener(_onTabRefreshTick);
    loadMemberPageConfig();
  }

  @override
  void dispose() {
    mineTabRefreshTick.removeListener(_onTabRefreshTick);
    super.dispose();
  }

  /// 切 tab 刷新回调
  void _onTabRefreshTick() {
    loadMemberPageConfig();
  }

  /// 我的页配置(/api/member/memberPageConfig)
  /// * is_pay_code == '1' 时显示「门店支付」板块
  Future<void> loadMemberPageConfig() async {
    try {
      final Map<String, dynamic> res = await MemberApi.memberPageConfig();
      if (kDebugMode) {
        debugPrint('[memberPageConfig] code=${res['code']} message=${res['message']}');
        debugPrint('[memberPageConfig] data=${res['data']}');
      }
      final dynamic data = res['data'];
      final bool showPay = data is Map && '${data['is_pay_code'] ?? ''}' == '1';
      if (mounted && showPay != payCodeEnabled) {
        setState(() => payCodeEnabled = showPay);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[memberPageConfig] 请求失败: $e');
    }
  }

  /// 我的服务: 拉 /api/Member/serviceNav 的配置
  /// * 失败 / 后台没配时列表为空, 「我的服务」整块不展示
  /// * 看播记录是内置入口: 后台没配 WATCH_RECORD 时自动补一项,保证入口一定可达
  Future<void> loadServiceNav() async {
    try {
      // 走 MyPreload: 内部已补「看播记录」入口, 并把结果写回共享缓存
      final List<Map<String, dynamic>> list = await MyPreload.loadService();
      if (!mounted) return;
      // 与当前渲染的一致就不 setState: 内容没变还重建, 会把整个网格重新刷一遍(看起来就是闪一下)
      final bool same = jsonEncode(list) == jsonEncode(serviceList);
      if (same && serviceLoaded) return;
      setState(() {
        serviceList
          ..clear()
          ..addAll(list);
        serviceLoaded = true;
      });
    } catch (e) {
      // 拉不到(预拉也失败): 撤掉骨架, 恢复「没数据就不展示」
      if (mounted) setState(() => serviceLoaded = true);
      if (kDebugMode) debugPrint('[serviceNav] 请求失败, 不展示我的服务: $e');
    }
  }

  /// 广告图(/api/adv/detail keyword=MEMBER_M, 取 adv_list)
  /// * 失败 / 后台没配时列表为空, 「我的订单」上方的广告位不占高度
  Future<void> loadAdv() async {
    try {
      final List<Map<String, dynamic>> list = await MyPreload.loadAdv();
      if (!mounted) return;
      final bool same = jsonEncode(list) == jsonEncode(advList);
      if (same && advLoaded) return;
      setState(() {
        advList = list;
        advLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => advLoaded = true);
      if (kDebugMode) debugPrint('[adv] 请求失败, 不展示广告位: $e');
    }
  }

  /// 订单各状态数量(/api/order/num): 失败/未登录时为空, 角标不显示
  Future<void> loadOrderNum() async {
    final Map<String, dynamic> data = await OrderApi.orderNum();
    if (!mounted || data.isEmpty) return;
    setState(() {
      orderNum = data;
    });
  }

  /// 取某个状态的订单数量(取不到按 0: 不显示角标)
  int _orderNum(String key) => int.tryParse('${orderNum[key] ?? 0}') ?? 0;

  /// 跳订单相关页面, 返回时刷一次角标
  /// * 订单页里的付款/取消/收货/删除都会改变各状态数量, 不刷的话角标会停留在旧值
  Future<void> toOrder(String route, {Object? arguments}) async {
    await Get.toNamed<dynamic>(route, arguments: arguments);
    if (!mounted || !authStore.isLogin) return;
    await loadOrderNum();
  }

  /// 广告位: 「我的订单」卡片上方(多张自动轮播)
  /// * 首次且没有缓存时显示等高占位: 数据来了直接替换, 下方内容不会往上顶
  Widget _buildAdvBanner() {
    if (advList.isEmpty) {
      if (advLoaded) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
        height: 95.0,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.0)),
        child: Container(
          margin: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      );
    }
    return AdvBanner(
      list: advList,
      height: 95.0,
      radius: 16.0,
      margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
    );
  }

  /// 门店支付板块(参考 H5 diy-payment-qrcode): 付款码 / 扫码付 入口, 放在广告位上方
  Widget _buildPaymentQrcode() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0D000000), blurRadius: 10.0, offset: Offset(0.0, 2.0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.storefront_rounded, color: FStyle.primaryColor, size: 22.0),
              const SizedBox(width: 8.0),
              const Text('门店支付',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const Spacer(),
              const Text('付款码 / 扫码付',
                  style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
            ],
          ),
          const SizedBox(height: 8.0),
          const Text('门店消费时使用，支付时点击下方展示付款码',
              style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
          const SizedBox(height: 14.0),
          Row(
            children: <Widget>[
              Expanded(
                child: _payActionBtn('付款码', FStyle.primaryColor,
                    const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18.0), _goPaymentQrcode),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _payActionBtn(
                    '扫码付',
                    const Color(0xFF999999),
                    Image.asset('assets/images/icon_sm.png',
                        width: 18.0, height: 18.0, fit: BoxFit.contain,
                        color: Colors.white, colorBlendMode: BlendMode.srcIn),
                    _scanPay),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 付款码 / 扫码付 按钮
  /// * [icon] 直接传 Widget: 付款码用内置图标, 扫码付用与首页搜索框一致的 icon_sm.png
  Widget _payActionBtn(String label, Color color, Widget icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44.0,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            icon,
            const SizedBox(width: 6.0),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.0)),
          ],
        ),
      ),
    );
  }



  /// 付款码: 跳转付款码页(需登录)
  void _goPaymentQrcode() {
    if (!authStore.isLogin) {
      Get.toNamed('/login');
      return;
    }
    Get.toNamed('/my/payment_qrcode');
  }

  /// 扫码付: 调起全屏扫码(复用项目 ai_barcode_scanner 能力)
  Future<void> _scanPay() async {
    if (!authStore.isLogin) {
      Get.toNamed('/login');
      return;
    }
    final BarcodeCapture? capture = await showAiBarcodeScanner(
      context,
      labels: const ScannerLabels(
        galleryButton: '从相册选择',
        galleryTooltip: '从图片中识别二维码',
        torchOnTooltip: '关闭闪光灯',
        torchOffTooltip: '打开闪光灯',
        torchAutoTooltip: '闪光灯为自动模式',
        switchCameraTooltip: '切换摄像头',
        switchLensTooltip: '切换镜头',
        closeTooltip: '关闭',
        zoomTooltip: '缩放',
        resetZoomTooltip: '重置缩放',
        scanHint: '将收款二维码放入框内,即可自动扫描',
        scanHintIdle: '保持稳定,稍微靠近一些',
        doneButton: '完成',
        retryButton: '重试',
        openSettingsButton: '去设置',
        cameraErrorTitle: '相机启动失败',
        cameraErrorMessage: '请检查相机权限或稍后重试',
        permissionDeniedTitle: '未获取相机权限',
        permissionDeniedMessage: '请在系统设置中开启相机权限后重试',
        cameraUnsupportedTitle: '无法使用扫码功能',
        cameraUnsupportedMessage: '当前设备没有可用的摄像头',
        startingCamera: '正在启动相机…',
        noBarcodeFoundInImage: '该图片中未找到二维码',
        galleryUnsupported: '当前平台不支持从相册识别',
        invalidBarcode: '该二维码无法识别',
        copiedConfirmation: '已复制',
      ),
      validator: (BarcodeCapture capture) => _firstRawValue(capture).isNotEmpty,
    );
    final String code = _firstRawValue(capture);
    if (code.isEmpty) return;
    if (!mounted) return;
    // 门店扫码付: 暂仅展示扫码结果, 实际支付对接后端
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('扫码结果'),
        content: SelectableText(code, style: const TextStyle(fontSize: 14.0)),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back<void>(), child: const Text('确定')),
        ],
      ),
    );
  }

  /// 取扫码结果里第一个非空原始值
  static String _firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return '';
    for (final Barcode barcode in capture.barcodes) {
      final String raw = (barcode.rawValue ?? '').trim();
      if (raw.isNotEmpty) return raw;
    }
    return '';
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
    final Widget placeholder = Container(
      width: 58.0,
      height: 58.0,
      color: Colors.white,
      child: const Icon(Icons.person, color: Color(0xFFFF7A50), size: 32.0),
    );
    final String url = authStore.headimg;
    if (url.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        url,
        width: 58.0,
        height: 58.0,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  /// 顶部图标(公告/收藏/视频/设置)
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
  /// * [image] http(s) 开头走网络图标, 否则按本地资源加载
  /// * [badge] > 0 时在图标右上角显示红色数量角标
  Widget _menuItem({required String label, required String image, required VoidCallback onTap, int badge = 0}) {
    final Widget icon = image.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: image,
            width: 32.0,
            height: 32.0,
            fit: BoxFit.contain,
            placeholder: (BuildContext c, String u) => const SizedBox(width: 32.0, height: 32.0),
            errorWidget: (BuildContext c, String u, Object e) => const SizedBox(width: 32.0, height: 32.0),
          )
        : image.endsWith('.svg')
            ? SvgPicture.asset(image, width: 32.0, height: 32.0, fit: BoxFit.contain)
            : Image.asset(image, width: 32.0, height: 32.0, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 32.0, height: 32.0));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标: 角标要溢出到图标外面, 用 Stack + clipBehavior.none(默认会裁掉)
            SizedBox(
              width: 32.0,
              height: 32.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Center(child: icon),
                  if (badge > 0)
                    Positioned(
                      right: -7.0,
                      top: -4.0,
                      child: _badge(badge),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  /// 数量角标(>99 显示 99+)
  Widget _badge(int count) {
    final String text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2C55),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white, width: 1.0),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 10.0, height: 1.25, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// 我的服务跳转: nav_url 为 JSON 字符串(与首页金刚区同一套约定), name 是动作码
  void _handleServiceNav(Map<String, dynamic> item) {
    final dynamic rawUrl = item['nav_url'];
    Map<String, dynamic> info = <String, dynamic>{};
    if (rawUrl is Map) {
      info = rawUrl.cast<String, dynamic>();
    } else {
      final String text = '${rawUrl ?? ''}'.trim();
      if (text.isEmpty) {
        Get.snackbar('提示', '该入口暂未配置', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      try {
        final dynamic decoded = jsonDecode(text);
        if (decoded is Map) info = decoded.cast<String, dynamic>();
      } catch (_) {
        Get.snackbar('提示', '该入口暂未配置', snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }
    // 后台可能存成小写 / 带空格, 统一成大写再匹配
    final String name = '${info['name'] ?? ''}'.trim().toUpperCase();
    if (kDebugMode) {
      debugPrint('[serviceNav] 点击: ${item['nav_name']} -> name=$name nav_url=$rawUrl');
    }
    _checkLogin(() {
      switch (name) {
        case 'LIVE_CONNECT':
          Get.toNamed('/live');
          break;
        // 直播连麦: 进连麦页输主播给的连麦码, 主播同意后进 TRTC 房间同屏
        // * 后台配: {"name":"LINK_MIC"}
        case 'LINK_MIC':
          Get.toNamed('/live/link_mic');
          break;
        case 'WATCH_RECORD':
          Get.toNamed('/my/watching_record');
          break;
        case 'MEMBER_ACCOUNT':
          Get.toNamed('/my/withdraw_account');
          break;
        case 'ADDRESS_LIST':
          Get.toNamed('/address');
          break;
        case 'STAMP':
          Get.toNamed('/stamp');
          break;
        // 领券中心(参考 H5 goods/coupon.vue): 后台配 {"name":"COUPON"}
        case 'COUPON':
          Get.toNamed('/my/coupon_center');
          break;
        case 'CHAT':
          Get.toNamed('/chat');
          break;
        case 'ABOUT':
          Get.toNamed('/about');
          break;
        // 学习课程(游客可见, 页面自带分类选择): 后台配 {"name":"STUDY"}
        case 'STUDY':
          Get.toNamed('/study');
          break;
        // 付款码(门店支付, 需登录): 后台配 {"name":"PAYCODE"}
        case 'PAYCODE':
          Get.toNamed('/my/payment_qrcode');
          break;
        // 内容详情页(关于我们详情 / 各类协议): nav_url 里带 type(后台 aggrement 的类型) 和可选 title
        // * 后台配: {"name":"AGREEMENT","type":"ABOUT","title":"关于我们"}
        case 'AGREEMENT':
          Get.toNamed('/agreement', arguments: <String, dynamic>{
            'type': '${info['type'] ?? 'SERVICE'}',
            'title': '${info['title'] ?? ''}',
          });
          break;
        // 复用首页金刚区已有的动作码
        case 'SIGN_IN':
          Get.toNamed('/my/signin');
          break;
        case 'SECKILL_PREFECTURE':
          Get.toNamed('/seckill');
          break;
        case 'MEMBER_CENTER':
          Get.toNamed('/my/wallet');
          break;
        case 'GOODS_CATEGORY_PAGE':
          Get.toNamed('/goods', arguments: <String, dynamic>{'category_id': '${info['category_id'] ?? ''}'});
          break;
        case 'INVITE':
          Get.snackbar('提示', '邀请功能开发中', snackPosition: SnackPosition.BOTTOM);
          break;
        default:
          Get.snackbar('提示', name.isNotEmpty ? '暂不支持的入口:$name' : '该入口暂未配置',
              snackPosition: SnackPosition.BOTTOM);
      }
    });
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
    // 已登录且能取到手机号/昵称时才按登录态渲染; 仅有 token 但会员信息未拉到(如接口失败)
    // 时, 按未登录展示, 避免出现"无边框/空电话"的异常空状态
    final bool hasUser = authStore.isLogin &&
        (authStore.mobile.isNotEmpty || authStore.nickname.isNotEmpty);
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/me/mine_header_bg.png'),
          fit: BoxFit.cover,
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
                // 公告(/api/notice/page): 游客也可查看
                _topIcon('assets/images/me/mine_icon_msg.png', () => Get.toNamed('/notice')),
                _topIcon('assets/images/me/mine_icon_star.png', () => Get.toNamed('/my/collection')),
                _topIcon('assets/images/me/mine_icon_video.png', () => Get.snackbar('提示', '功能开发中')),
                _topIcon('assets/images/me/mine_icon_setting.png', () => authStore.isLogin ? Get.toNamed('/personal_info') : Get.toNamed('/login')),
              ],
            ),
          ),
          // 用户信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
            child: Row(
              children: [
                // 头像
                Container(
                  width: 60.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasUser ? _buildAvatar() : const Icon(Icons.person, color: Colors.white70, size: 32.0),
                ),
                const SizedBox(width: 12.0),
                // 信息
                Expanded(
                  child: hasUser
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
                onTap: () => _checkLogin(() => toOrder('/order')),
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
                  badge: _orderNum('waitpay'),
                  onTap: () => _checkLogin(() => toOrder('/order', arguments: {'status': 'waitpay'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_unshipped.png',
                  label: '待发货',
                  badge: _orderNum('waitsend'),
                  onTap: () => _checkLogin(() => toOrder('/order', arguments: {'status': 'waitsend'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_unreceived.png',
                  label: '待收货',
                  badge: _orderNum('waitconfirm'),
                  onTap: () => _checkLogin(() => toOrder('/order', arguments: {'status': 'waitconfirm'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_touse.png',
                  label: '待使用',
                  badge: _orderNum('wait_use'),
                  onTap: () => _checkLogin(() => toOrder('/order', arguments: {'status': 'wait_use'})),
                ),
              ),
              Expanded(
                child: _menuItem(
                  image: 'assets/images/me/mine_icon_order_aftersale.png',
                  label: '售后',
                  badge: _orderNum('refunding'),
                  onTap: () => _checkLogin(() => toOrder('/order/refund_list')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 「我的服务」骨架占位: 形状贴近 4 列网格(圆标 + 文字条), 只在首次无缓存时出现
  Widget _buildServiceSkeleton() {
    Widget cell() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 40.0,
            height: 40.0,
            decoration: const BoxDecoration(color: Color(0xFFF2F2F2), shape: BoxShape.circle),
          ),
          const SizedBox(height: 6.0),
          Container(
            width: 34.0,
            height: 10.0,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('我的服务', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        const SizedBox(height: 12.0),
        Row(
          children: List<Widget>.generate(4, (int i) => Expanded(child: cell())),
        ),
      ],
    );
  }

  // 我的服务(4 列网格,从左到右依次排列,自动换行)
  // * 只渲染 /api/Member/serviceNav 的后台配置, 没数据就整块不显示(不再有本地默认项)
  Widget _buildServiceCard() {
    if (serviceList.isEmpty) {
      // 首次且没有缓存: 占位顶住, 避免「我的服务」突然出现把下面的内容顶下去
      if (serviceLoaded) return const SizedBox.shrink();
      return _whiteCard(child: _buildServiceSkeleton());
    }
    final List<Map<String, dynamic>> items = serviceList;
    return _whiteCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的服务', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 12.0),
          LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints constraints) {
              final double itemW = (constraints.maxWidth - 3 * 4.0) / 4;
              return Wrap(
                spacing: 4.0,
                runSpacing: 4.0,
                children: items
                    .map((Map<String, dynamic> e) => SizedBox(
                          width: itemW,
                          child: _menuItem(
                            image: '${e['nav_image'] ?? ''}',
                            label: '${e['nav_name'] ?? ''}',
                            onTap: () => _handleServiceNav(e),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // 底部版权(取 /api/config/init 的 copyright.copyright_desc,缺失用兜底文案)
  Widget _buildFooter() {
    return Obx(() {
      final dynamic copyright = AppConfig.to.get('copyright');
      final String desc = copyright is Map ? '${copyright['copyright_desc'] ?? ''}' : '';
      final String text = desc.isNotEmpty
          ? desc
          : 'Copyright © 2023-2026 乐惠新零售 All Rights Reserved.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Divider(indent: 30.0, endIndent: 8.0, color: Color(0xFFDDDDDD), height: 1.0),
            ),
            Text(text, style: TextStyle(fontSize: 11.0, color: Color(0xFFBBBBBB))),
            Expanded(
              child: Divider(indent: 8.0, endIndent: 30.0, color: Color(0xFFDDDDDD), height: 1.0),
            ),
          ],
        ),
      );
    });
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
        backgroundColor: const Color(0xFFFCF7EE),
        body: Obx(() {
          // 显式订阅登录态/会员信息/优惠券数量, 让 GetX 能正确刷新本页
          final _ = <dynamic>[authStore.authorization.value, authStore.memberInfo.length, authStore.couponNum.value];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopArea(statusTop),
              // 门店支付(付款码 / 扫码付): 由 memberPageConfig.is_pay_code 控制是否显示
              if (payCodeEnabled) _buildPaymentQrcode(),
              // 广告位(MEMBER_M): 在「我的订单」上方
              _buildAdvBanner(),
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
