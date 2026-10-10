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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.black87),
            onPressed: () => Get.back<void>(),
          ),
          title: const Text(
            '扫一扫',
            style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        body: Stack(
          children: <Widget>[
            // 背景装饰圆(与绑定门店页同一套暖色装饰,避免整页空白)
            Positioned(
              top: -70.0,
              right: -60.0,
              child: Container(
                width: 190.0,
                height: 190.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF2C55).withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              top: 150.0,
              left: -50.0,
              child: Container(
                width: 120.0,
                height: 120.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF7A52).withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                // 顶部让出一个导航栏高度: extendBodyBehindAppBar 后 body 从状态栏下就开始布局
                padding: const EdgeInsets.fromLTRB(20.0, kToolbarHeight + 8.0, 20.0, 24.0),
                child: Column(
                  children: <Widget>[
                    _buildCodeCard(),
                    const SizedBox(height: 18.0),
                    _buildDivider(),
                    const SizedBox(height: 18.0),
                    _buildScanEntry(),
                    const SizedBox(height: 22.0),
                    const Text(
                      '扫码或输入直播码,即可进入直播间',
                      style: TextStyle(fontSize: 12.0, color: Colors.black26),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 输入直播码板块: 标题 + 输入框 + 进入直播间
  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16.0, offset: const Offset(0.0, 4.0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.qr_code_2_rounded, size: 18.0, color: Color(0xFFFF2C55)),
              const SizedBox(width: 6.0),
              const Text(
                '输入直播码',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          const Text(
            '看精彩直播,输入主播给你的直播码即可直达直播间',
            style: TextStyle(fontSize: 12.0, color: Colors.black45),
          ),
          const SizedBox(height: 16.0),
          Container(
            width: double.infinity,
            height: 46.0,
            // 不给 alignment 时 child 贴左上, hint 会浮在输入框上半部分
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(23.0),
            ),
            child: TextField(
              controller: codeController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => enterByCode(),
              cursorColor: const Color(0xFFFF2C55),
              style: const TextStyle(fontSize: 14.0, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: '请输入直播码 / 房间号',
                hintStyle: TextStyle(fontSize: 13.0, color: Colors.black26),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 14.0),
          _buildPrimaryButton(),
        ],
      ),
    );
  }

  /// 主按钮: 进入直播间(查询中显示小圈,避免连点)
  Widget _buildPrimaryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: entering ? null : enterByCode,
      child: Container(
        width: double.infinity,
        height: 46.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23.0),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A52)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: const Color(0xFFFF2C55).withValues(alpha: 0.25), blurRadius: 10.0, offset: const Offset(0.0, 4.0)),
          ],
        ),
        child: Center(
          child: entering
              ? const SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                )
              : const Text(
                  '进入直播间',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
                ),
        ),
      ),
    );
  }

  /// 中间"或"分隔
  Widget _buildDivider() {
    return Row(
      children: <Widget>[
        Expanded(child: Container(height: 1.0, color: const Color(0xFFE8E0D4))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('或', style: TextStyle(fontSize: 12.0, color: Colors.black38)),
        ),
        Expanded(child: Container(height: 1.0, color: const Color(0xFFE8E0D4))),
      ],
    );
  }

  /// 扫一扫入口: 整个卡片可点,点开全屏扫码
  Widget _buildScanEntry() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: scan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16.0, offset: const Offset(0.0, 4.0)),
          ],
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 76.0,
              height: 76.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF1F4)],
                ),
                border: Border.all(color: const Color(0xFFFF2C55).withValues(alpha: 0.28), width: 1.0),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 34.0, color: Color(0xFFFF2C55)),
            ),
            const SizedBox(height: 12.0),
            const Text(
              '扫一扫',
              style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 4.0),
            const Text(
              '对准直播二维码,即可自动识别',
              style: TextStyle(fontSize: 12.0, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
