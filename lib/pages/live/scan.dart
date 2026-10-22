/// 直播扫码/直播码入口页(直播列表页顶部扫码图标进入)
/// * 上半: 输入直播码 -> 查房间信息校验 -> 进直播间
/// * 下半: 扫一扫入口 -> 全屏扫码 -> 解析出房间号 -> 进直播间
library;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/live.dart';

class LiveScanPage extends StatefulWidget {
  const LiveScanPage({super.key});

  @override
  State<LiveScanPage> createState() => _LiveScanPageState();
}

class _LiveScanPageState extends State<LiveScanPage> {
  final TextEditingController codeController = TextEditingController();
  // 进入中: 查房间接口期间锁住两个入口,避免连点重复跳直播间
  bool entering = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  /// 输入直播码后进入(点"进入直播间"/键盘完成)
  Future<void> enterByCode() async {
    // 先收起软键盘: 不收的话跳转后键盘会带到直播间,把底部输入栏顶起来再落下
    FocusManager.instance.primaryFocus?.unfocus();
    final String code = codeController.text.trim();
    if (code.isEmpty) {
      Get.snackbar('提示', '请输入直播码');
      return;
    }
    await _enterRoom(code);
  }

  /// 扫一扫: 打开全屏扫码,扫到结果后按直播码处理
  Future<void> scan() async {
    if (entering) return;
    // 同上: 键盘开着时点扫一扫,先收起来再进扫码界面
    FocusManager.instance.primaryFocus?.unfocus();
    final BarcodeCapture? capture = await showAiBarcodeScanner(
      context,
      // 组件文案默认是英文,未传的字段会保留英文默认值,所以这里逐项覆盖
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
        scanHint: '将直播二维码放入框内,即可自动扫描',
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
      validator: (BarcodeCapture capture) => firstRawValue(capture).isNotEmpty,
    );

    final String code = firstRawValue(capture);
    if (code.isEmpty) return;
    if (!mounted) return;
    await _enterRoom(code);
  }

  /// 进直播间
  /// * [raw] 直播码/扫码原文: 先解析出房间号(支持二维码里带链接的情况),再调 /live/api/shop/getRoomType 校验
  /// * 校验通过才跳直播间,避免拿着错误码进到一个空白的直播页
  Future<void> _enterRoom(String raw) async {
    if (entering) return;
    final String sn = roomNoOf(raw);
    if (sn.isEmpty) {
      Get.snackbar('提示', '未能识别出直播码');
      return;
    }
    setState(() {
      entering = true;
    });
    final Map<String, dynamic>? room = await LiveApi.roomType(sn);
    if (!mounted) return;
    setState(() {
      entering = false;
    });
    if (room == null) {
      Get.snackbar('提示', '未找到该直播间,请检查直播码');
      return;
    }
    // 横竖屏必须带过去: 直播间进房时用它预判布局(接口 getRoomInfo 回来后还会再校正一次),
    // 不传的话横屏房间会先按竖屏渲染一帧再切换, 观感就是"布局跳一下"
    Get.toNamed('/live', arguments: <String, dynamic>{
      'sn': '${room['sn'] ?? sn}',
      'name': '${room['name'] ?? ''}',
      'src': '${room['push_link'] ?? ''}',
      'type': orientationOf(room),
      'cover': LiveApi.imageOf(room['feeds_img']),
    });
  }

  /// 横竖屏(type): 从直播码接口返回里取,取不到按竖屏
  /// * 字段名各端不统一(type / room_type / orientation / screen_type),逐个候选取第一个有效值
  /// * 只有明确是横屏(horizontal / landscape)才返回 horizontal,其余(含空)一律 vertical:
  ///   与直播间 LiveApi.isHorizontalRoom 的判定保持一致,避免出现两边不一致导致布局跳变
  static String orientationOf(Map<String, dynamic> room) {
    for (final String key in const <String>['type', 'room_type', 'roomType', 'screen_type', 'orientation']) {
      final String val = '${room[key] ?? ''}'.trim().toLowerCase();
      if (val == 'horizontal' || val == 'landscape') return 'horizontal';
    }
    return 'vertical';
  }

  /// 取扫码结果里第一个非空原始值
  static String firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return '';
    for (final Barcode barcode in capture.barcodes) {
      final String raw = (barcode.rawValue ?? '').trim();
      if (raw.isNotEmpty) return raw;
    }
    return '';
  }

  /// 从扫码原文/输入的直播码里取房间号(sn)
  /// * 二维码常存的是分享链接(如 https://xxx/live?sn=123),直接当房间号会查不到,所以先解析
  /// * 依次尝试: 链接 query(sn/no/room_id/roomId/room/id) -> 路径最后一段 -> "sn=123" 文本 -> 原文
  static String roomNoOf(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return '';
    final Uri? uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme) {
      for (final String key in const <String>['sn', 'no', 'room_id', 'roomId', 'room', 'id']) {
        final String? val = uri.queryParameters[key];
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
      final List<String> segs = uri.pathSegments.where((String s) => s.trim().isNotEmpty).toList();
      if (segs.isNotEmpty) return segs.last;
      return '';
    }
    // 非链接但带 key=value / key: value 的文本(部分扫码结果是自定义协议串)
    final RegExpMatch? match = RegExp(r'(?:sn|no|room_id|roomId|room)\s*[:=]\s*([A-Za-z0-9_-]+)').firstMatch(text);
    if (match != null) return match.group(1) ?? '';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF7EE),
        // 标题栏透明并延伸到 body 之下(装饰圆可以铺到状态栏后面),内容用 padding 让开导航栏高度
        extendBodyBehindAppBar: true,
        // 导航栏用标准 AppBar: 返回按钮固定在 leading 槽位,标题由系统居中
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: Center(
            child: GestureDetector(
              // 返回前先收键盘: 直接返回时输入框还占着焦点, iOS 上键盘会留在直播间页面上
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Get.back<void>();
              },
              child: Container(
                width: 34.0,
                height: 34.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: <Color>[Color(0xFFFFA63C), Color(0xFFFF4E2A)]),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16.0, color: Colors.white),
              ),
            ),
          ),
          title: const Text(
            '扫码',
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
          ),
        ),
        body: Stack(
          // 撑满整屏: 否则 Stack 高度会被内容(卡片)撑小,背景图只盖住卡片那一段
          fit: StackFit.expand,
          children: <Widget>[
            // 背景图(bg-c.png)铺满整页(extendBodyBehindAppBar 下会延伸到状态栏后)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/bg-c.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                // iOS 上滑动页面时收起软键盘(默认 manual: 只有 Android 的返回键能收, iOS 没返回键)
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                // 顶部让出一个导航栏高度: extendBodyBehindAppBar 后 body 从状态栏下就开始布局
                padding: const EdgeInsets.fromLTRB(16.0, kToolbarHeight - 32.0, 16.0, 24.0),
                child: _buildMainCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 主体白卡: 扫码插画 + 扫一扫 + 输入直播码 + 进直播间(对齐设计稿)
  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20.0, 26.0, 20.0, 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20.0, offset: const Offset(0.0, 6.0)),
        ],
      ),
      child: Column(
        children: <Widget>[
          _buildScanHero(),
          const SizedBox(height: 14.0),
          const Text('扫直播间二维码 / 用户分享码', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
          const SizedBox(height: 20.0),
          _buildGradientButton('扫一扫', scan),
          const SizedBox(height: 22.0),
          _buildOrDivider(),
          const SizedBox(height: 22.0),
          const Text('输入直播码', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
          const SizedBox(height: 16.0),
          _buildCodeField(),
          const SizedBox(height: 16.0),
          _buildGradientButton('进入直播间', enterByCode, loading: entering),
          const SizedBox(height: 18.0),
          const Text('没有二维码？输入直播码也能进直播间', style: TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB))),
        ],
      ),
    );
  }

  /// 扫码插画: 中间取景框 + 周边直播/商城小元素
  Widget _buildScanHero() {
    return SizedBox(
      width: double.infinity,
      height: 160.0,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 0.0,
            left: 22.0,
            child: Transform.rotate(
              angle: -0.12,
              child: const Icon(Icons.video_camera_front_rounded, size: 38.0, color: Color(0xFFFF8A5B)),
            ),
          ),
          Positioned(
            top: 2.0,
            right: 26.0,
            child: Transform.rotate(
              angle: 0.1,
              child: const Icon(Icons.storefront_rounded, size: 36.0, color: Color(0xFFFFB27A)),
            ),
          ),
          Positioned(
            top: 62.0,
            left: 4.0,
            child: Transform.rotate(
              angle: -0.08,
              child: const Icon(Icons.shopping_bag_rounded, size: 32.0, color: Color(0xFFFF6B81)),
            ),
          ),
          Positioned(
            top: 66.0,
            right: 6.0,
            child: Transform.rotate(
              angle: 0.08,
              child: const Icon(Icons.shopping_cart_rounded, size: 32.0, color: Color(0xFFFFA63C)),
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 34.0,
            child: Transform.rotate(
              angle: 0.1,
              child: const Icon(Icons.card_giftcard_rounded, size: 30.0, color: Color(0xFFFFC46B)),
            ),
          ),
          Positioned(
            bottom: 2.0,
            right: 38.0,
            child: Transform.rotate(
              angle: -0.1,
              child: const Icon(Icons.paid_rounded, size: 30.0, color: Color(0xFFFFB27A)),
            ),
          ),
          _buildQrFrame(),
        ],
      ),
    );
  }

  /// 扫码取景框: 四角括号 + 中间扫描线
  Widget _buildQrFrame() {
    const BorderSide bs = BorderSide(color: Color(0xFFFF5A2C), width: 5.0);
    return SizedBox(
      width: 110.0,
      height: 110.0,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0.0,
            left: 0.0,
            child: Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                border: const Border(top: bs, left: bs),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10.0)),
              ),
            ),
          ),
          Positioned(
            top: 0.0,
            right: 0.0,
            child: Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                border: const Border(top: bs, right: bs),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(10.0)),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            child: Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                border: const Border(bottom: bs, left: bs),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10.0)),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            right: 0.0,
            child: Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                border: const Border(bottom: bs, right: bs),
                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10.0)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 54.0,
              height: 6.0,
              decoration: BoxDecoration(color: const Color(0xFFFF5A2C), borderRadius: BorderRadius.circular(3.0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 橙色渐变胶囊按钮
  Widget _buildGradientButton(String text, VoidCallback onTap, {bool loading = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 48.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          gradient: const LinearGradient(colors: <Color>[Color(0xFFFFA63C), Color(0xFFFF4E2A)]),
          boxShadow: <BoxShadow>[
            BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.30), blurRadius: 12.0, offset: const Offset(0.0, 5.0)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                )
              : Text(text, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }

  /// OR 分隔
  Widget _buildOrDivider() {
    return Row(
      children: <Widget>[
        Expanded(child: Container(height: 1.0, color: const Color(0xFFEDEDED))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('OR', style: TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Container(height: 1.0, color: const Color(0xFFEDEDED))),
      ],
    );
  }

  /// 直播码输入框: 左侧小图标 + 灰底圆角
  Widget _buildCodeField() {
    return Container(
      width: double.infinity,
      height: 48.0,
      // 不给 alignment 时 child 贴左上, hint 会浮在输入框上半部分
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.keyboard_rounded, size: 20.0, color: Color(0xFFBBBBBB)),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: codeController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => enterByCode(),
              cursorColor: const Color(0xFFFF4E2A),
              style: const TextStyle(fontSize: 14.0, color: Color(0xFF333333)),
              decoration: const InputDecoration(
                hintText: '请输入直播间6位数字码',
                hintStyle: TextStyle(fontSize: 14.0, color: Color(0xFFBBBBBB)),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
