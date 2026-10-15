/// 付款码页(对齐 H5 /pages_tool/store/payment_qrcode)
/// * 接口 /api/pay/memberpaycode 返回 payInfo:
///   { barcode(条形码图片), qrcode(二维码图片), auth_code(授权码), dynamic_code(动态码) }
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';

class PaymentQrcodePage extends StatefulWidget {
  const PaymentQrcodePage({super.key});

  @override
  State<PaymentQrcodePage> createState() => _PaymentQrcodePageState();
}

class _PaymentQrcodePageState extends State<PaymentQrcodePage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  Map<String, dynamic>? payInfo;
  bool loading = true;
  bool showAuth = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // 每 30s 静默刷新动态码(对齐 H5 refreshPaymentCode)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 首次加载(带 loading)
  Future<void> _load() async {
    setState(() => loading = true);
    await _fetch();
    if (mounted) setState(() => loading = false);
  }

  /// 定时静默刷新(不显示 loading)
  Future<void> _refresh() async {
    await _fetch();
    if (mounted) setState(() {});
  }

  Future<void> _fetch() async {
    try {
      // Request 封装在 code == 0 时直接返回 data, 故 res 即 payInfo 本身(不含 code/data 包装)
      final dynamic res = await MemberApi.payAuthCode();
      if (res is Map && res.isNotEmpty) {
        payInfo = Map<String, dynamic>.from(res);
        showAuth = false; // 刷新后默认隐藏授权码数字(对齐 H5)
      } else if (kDebugMode) {
        debugPrint('[paymentQrcode] 数据异常: $res');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[paymentQrcode] 请求失败: $e');
    }
  }

  String get _barcode => '${payInfo?['barcode'] ?? ''}'.trim();
  String get _qrcode => '${payInfo?['qrcode'] ?? ''}'.trim();
  String get _authCode => '${payInfo?['auth_code'] ?? ''}'.trim();
  String get _dynamicCode => '${payInfo?['dynamic_code'] ?? ''}'.trim();

  /// 授权码: 每 4 位空格分组(对齐 H5 splitFn)
  String _formatAuthCode(String code) {
    final RegExp reg = RegExp('.{1,4}');
    return reg.allMatches(code).map((Match m) => m.group(0)).join(' ');
  }

  /// 授权码脱敏: 前 5 位 + ******(对齐 H5)
  String _maskAuthCode(String code) {
    if (code.length <= 5) return code;
    return '${code.substring(0, 5)}******';
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
        backgroundColor: FStyle.primaryColor,
        body: Column(
          children: <Widget>[
            SizedBox(height: statusTop),
            _appBar(),
            Expanded(
              child: loading && payInfo == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => Get.back<void>(),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.chevron_left, size: 26.0, color: Colors.white),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('付款码',
                  style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 42.0),
        ],
      ),
    );
  }

  Widget _body() {
    final String nickname = auth.nickname.isNotEmpty ? auth.nickname : '微信用户';
    final String avatar = auth.headimg;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            // 会员头部(灰底, 对齐 H5 .member-wrap)
            Container(
              color: const Color(0xFFF6F6F6),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              child: Row(
                children: <Widget>[
                  ClipOval(
                    child: avatar.isEmpty
                        ? Container(
                            width: 44.0,
                            height: 44.0,
                            color: const Color(0xFFE0E0E0),
                            child: const Icon(Icons.person, color: Colors.grey, size: 24.0),
                          )
                        : CachedNetworkImage(
                            imageUrl: avatar,
                            width: 44.0,
                            height: 44.0,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: const Color(0xFFE0E0E0)),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFE0E0E0),
                              child: const Icon(Icons.person, color: Colors.grey, size: 24.0),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(nickname,
                            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                        const SizedBox(height: 6.0),
                        if (auth.memberLevelName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF474758),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Text(auth.memberLevelName,
                                style: const TextStyle(fontSize: 12.0, color: Color(0xFFDDC095))),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed('/my/recharge'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: FStyle.primaryColor),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text('去充值', style: TextStyle(fontSize: 13.0, color: FStyle.primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
            // body 区(白底, 底部虚线分隔, 对齐 H5 .body-wrap)
            Container(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 20.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(
                children: <Widget>[
                  if (_barcode.isNotEmpty) _barcodeImage(_barcode),
                  if (_barcode.isNotEmpty) const SizedBox(height: 16.0),
                  // 授权码(查看/隐藏数字)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        showAuth ? _formatAuthCode(_authCode) : _maskAuthCode(_authCode),
                        style: const TextStyle(fontSize: 15.0, color: Color(0xFF666666), letterSpacing: 1.0),
                      ),
                      if (_authCode.isNotEmpty) const SizedBox(width: 12.0),
                      if (_authCode.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => showAuth = !showAuth),
                          child: Text(showAuth ? '隐藏数字' : '查看数字',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF163D8F))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // 二维码(base64/网络图片优先, 退化为本地生成)
                  _codeImage(_qrcode, width: 200.0, height: 200.0, qrFallback: true),
                  const SizedBox(height: 16.0),
                  // 动态码(点击刷新)
                  if (_dynamicCode.isNotEmpty)
                    GestureDetector(
                      onTap: _refresh,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6F6),
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('动态码', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                            const SizedBox(width: 8.0),
                            Text(_dynamicCode, style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                            const SizedBox(width: 6.0),
                            const Icon(Icons.refresh, size: 14.0, color: Color(0xFF999999)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14.0),
                  const Text('付款码仅用于支付时向收银员出示，请勿发送给他人',
                      style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                ],
              ),
            ),
            // footer 三栏(积分 / 余额 / 优惠券, 对齐 H5 .footer-wrap)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22.0),
              child: Row(
                children: <Widget>[
                  _accountItem(auth.point, '积分', '/my/point'),
                  _vLine(),
                  _accountItem(auth.balance, '余额', '/my/balance_detail'),
                  _vLine(),
                  _accountItem('${auth.couponCount}', '优惠券', '/my/coupon'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountItem(String value, String title, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Get.toNamed(route),
        child: Column(
          children: <Widget>[
            Text(value, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: FStyle.primaryColor)),
            const SizedBox(height: 4.0),
            Text(title, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _vLine() {
    return Container(width: 1.0, height: 28.0, color: const Color(0xFFDDDDDD));
  }

  /// 条形码图片: 按 H5 比例(590x250)渲染, 并裁掉底部约 20% 的数字编号
  /// * H5 .barcode-wrap 固定高 200rpx + overflow:hidden, 图片 250rpx, 即只显示上方 80%
  Widget _barcodeImage(String src) {
    final Uint8List? bytes = _decodeBase64Image(src);
    if (bytes == null) {
      // 非 base64(如网络图片)时退化为普通渲染
      if (src.startsWith('http')) return _codeImage(src, height: 80.0);
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double fullH = w * 250.0 / 590.0; // 图片完整高度
        final double viewH = w * 200.0 / 590.0; // 可见高度(裁掉底部数字)
        return ClipRect(
          child: SizedBox(
            width: w,
            height: viewH,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: fullH,
              maxHeight: fullH,
              child: Image.memory(bytes, width: w, height: fullH, fit: BoxFit.fill),
            ),
          ),
        );
      },
    );
  }

  /// 渲染付款码图片: 支持 base64(data:image/...) / 网络图片 / 纯内容(本地生成二维码)
  Widget _codeImage(String src, {double? width, double? height, bool qrFallback = false}) {
    if (src.isEmpty) {
      if (!qrFallback) return const SizedBox.shrink();
      return const Center(
        child: Text('暂未获取到付款码', style: TextStyle(color: Color(0xFF999999), fontSize: 13.0)),
      );
    }
    if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(width: width, height: height),
        errorWidget: (_, __, ___) =>
            const Center(child: Text('图片加载失败', style: TextStyle(color: Colors.grey, fontSize: 13.0))),
      );
    }
    final Uint8List? bytes = _decodeBase64Image(src);
    if (bytes != null) {
      return Image.memory(bytes, width: width, height: height, fit: BoxFit.contain, gaplessPlayback: true);
    }
    if (qrFallback) {
      return QrImageView(
        data: src,
        size: width ?? 200.0,
        backgroundColor: Colors.white,
        errorStateBuilder: (_, __) =>
            const Center(child: Text('二维码生成失败', style: TextStyle(color: Colors.grey, fontSize: 13.0))),
      );
    }
    return const SizedBox.shrink();
  }

  /// base64 图片解码(data:image/xxx;base64,xxxx 或纯 base64), 非图片返回 null
  Uint8List? _decodeBase64Image(String src) {
    try {
      String content = src;
      if (content.startsWith('data:')) {
        final int idx = content.indexOf(',');
        if (idx == -1) return null;
        content = content.substring(idx + 1);
      }
      return base64Decode(content);
    } catch (_) {
      return null;
    }
  }
}
