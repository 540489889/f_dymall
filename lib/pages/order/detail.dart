/// 订单详情
/// 对齐 H5: pages/order/detail.vue
/// * 入参 order_id(Get.arguments: { order_id: 1 })
/// * /api/order/detail           订单详情
/// * /api/order/close            取消(关闭)订单
/// * /api/order/takedelivery     确认收货
/// * /api/order/delete           删除订单
/// * 底部按钮取 order_status_action,与 H5 orderMethod 一致
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';
import '../../utils/order_status.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/popup_pay.dart';
import '../../config/index.dart';
import '../../styles/index.dart';

class OrderDetail extends StatefulWidget {
  const OrderDetail({super.key});

  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> with WidgetsBindingObserver {
  static const Color primary = Color(0xFFFF2C55);
  /// 信息行左侧 label 固定宽度(保证左列对齐)
  static const double labelWidth = 80.0;

  int orderId = 0;
  String merchantTradeNo = '';
  Map<String, dynamic> orderData = <String, dynamic>{};
  bool loading = true;
  String errorMsg = '';
  Timer? timer;
  /// 评价配置(H5 /api/goodsevaluate/config,默认开启)
  Map<String, dynamic> evaluateConfig = <String, dynamic>{'evaluate_status': 1};
  /// 首次 resumed 不重复加载(initState 已加载)
  bool firstResume = true;

  // 待付款倒计时(剩余秒数)
  int closeSeconds = 0;

  /// 订单商品(order_goods)
  List<Map<String, dynamic>> get goodsList => OrderApi.orderGoodsOf(orderData);

  /// 可执行操作: [{ action, title }]
  List<Map<String, dynamic>> get actions => OrderApi.actionsOf(orderData);

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      orderId = int.tryParse('${args['order_id'] ?? args['orderId'] ?? ''}') ?? 0;
      merchantTradeNo = '${args['merchant_trade_no'] ?? ''}';
    }
    WidgetsBinding.instance.addObserver(this);
    loadEvaluateConfig();
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  /// 回到前台刷新(与 H5 onShow 重新拉取详情一致)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (firstResume) {
      firstResume = false;
      return;
    }
    load();
  }

  /// 评价配置(/api/goodsevaluate/config)
  Future<void> loadEvaluateConfig() async {
    try {
      final Map<String, dynamic> data = await OrderApi.evaluateConfig();
      if (!mounted || data.isEmpty) return;
      setState(() {
        evaluateConfig = data;
      });
    } catch (_) {
      // 配置获取失败按默认开启处理
    }
  }

  /// 门店信息(delivery_store_info)
  /// * 接口可能返回 JSON 字符串,与 H5 detail.vue `JSON.parse(orderData.delivery_store_info)` 对齐
  /// * 解析失败/为空时返回空 Map(页面显示"当前无自提门店",与 H5 v-else 分支一致)
  Map<String, dynamic> get storeInfo {
    final dynamic raw = orderData['delivery_store_info'];
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // 解析失败按无门店处理
      }
    }
    return <String, dynamic>{};
  }

  /// 订单详情(/api/order/detail)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await OrderApi.detail(orderId: orderId, merchantTradeNo: merchantTradeNo);
      if (!mounted) return;
      setState(() {
        orderData = _decodeStoreInfo(data);
        orderId = int.tryParse('${data['order_id'] ?? orderId}') ?? orderId;
        loading = false;
      });
      startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = OrderApi.errorMsg(e, '订单加载失败');
        loading = false;
      });
      // 与 H5 一致: 未获取到订单信息提示后返回
      MyDialog.toast('未获取到订单信息！');
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Get.back();
      });
    }
  }

  /// 门店信息归一(与 H5 detail.vue JSON.parse 对齐: 接口返回 JSON 字符串时转成 Map)
  Map<String, dynamic> _decodeStoreInfo(Map<String, dynamic> data) {
    final dynamic raw = data['delivery_store_info'];
    if (raw is! String || raw.trim().isEmpty) return data;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return <String, dynamic>{...data, 'delivery_store_info': decoded.cast<String, dynamic>()};
      }
    } catch (_) {
      // 保持原值: 页面按无门店处理
    }
    return data;
  }

  /// 待付款倒计时: create_time + auto_close
  void startTimer() {
    timer?.cancel();
    final int createTime = int.tryParse('${orderData['create_time'] ?? 0}') ?? 0;
    final int autoClose = int.tryParse('${orderData['auto_close'] ?? 0}') ?? 0;
    if (createTime <= 0 || autoClose <= 0) return;
    final int end = createTime + autoClose;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final int left = end - now;
      setState(() {
        closeSeconds = left > 0 ? left : 0;
      });
      if (left <= 0) t.cancel();
    });
  }

  String get closeTimeText {
    final int h = closeSeconds ~/ 3600;
    final int m = (closeSeconds % 3600) ~/ 60;
    final int s = closeSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 时间戳(秒)转 yyyy-MM-dd HH:mm:ss
  static String timeText(dynamic value) {
    final int ts = int.tryParse('$value') ?? 0;
    if (ts <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  /// 时间戳(秒)转 yyyy-MM-dd
  static String dateText(dynamic value) {
    final int ts = int.tryParse('$value') ?? 0;
    if (ts <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static String money(num value) => value.toStringAsFixed(2);

  num moneyOf(dynamic key) => OrderApi.moneyOf(orderData[key]);

  /// 订单类型: 1快递 2门店自提 3同城配送 4虚拟(与 H5 order_type 一致)
  String get orderType => '${orderData['order_type'] ?? ''}';

  /// 是否已支付
  bool get payed => OrderApi.moneyOf(orderData['pay_status']) > 0;

  /// 是否展示评价/追评按钮(H5: evaluate_status == 1 && is_evaluate == 1)
  bool get showEvaluate =>
      '${evaluateConfig['evaluate_status'] ?? 1}' == '1' && '${orderData['is_evaluate'] ?? ''}' == '1';

  /// 评价状态: 0未评价(评价) 1已评价(追评)
  int get evaluateStatus => int.tryParse('${orderData['evaluate_status'] ?? 0}') ?? 0;

  /// 底部操作(H5 orderMethod.js operation)
  Future<void> onAction(String action) async {
    switch (action) {
      case 'orderPay':
        openPay();
        break;
      case 'orderClose':
        await confirmAction('您确定要关闭该订单吗？', () => OrderApi.close(orderId));
        break;
      case 'memberTakeDelivery':
        await confirmAction('您确定已经收到货物了吗？', () => OrderApi.takeDelivery(orderId));
        break;
      case 'memberVirtualTakeDelivery':
        await confirmAction('您确定要进行收货吗？', () => OrderApi.virtualTakeDelivery(orderId));
        break;
      case 'orderDelete':
        await confirmAction('您确定要删除该订单吗？', () async {
          await OrderApi.delete(orderId);
          if (mounted) Get.back();
        });
        break;
      case 'trace':
        Get.toNamed('/order/logistics', arguments: <String, dynamic>{'order_id': orderId});
        break;
      case 'memberOrderEvaluation':
        Get.toNamed('/order/evaluate', arguments: <String, dynamic>{'order_id': orderId});
        break;
      case 'memberBatchRefund':
        // 与 H5 一致: 可退商品(refund_status 0/-1)一次性批量申请
        final List<String> ids = goodsList
            .where((Map<String, dynamic> e) => '${e['refund_status'] ?? ''}' == '0' || '${e['refund_status'] ?? ''}' == '-1')
            .map((Map<String, dynamic> e) => '${e['order_goods_id'] ?? ''}')
            .where((String e) => e.isNotEmpty)
            .toList();
        Get.toNamed('/order/refund', arguments: <String, dynamic>{'order_goods_ids': ids.join(',')});
        break;
      case 'orderOfflinePay':
        MyDialog.toast('该功能待开发');
        break;
      default:
        MyDialog.toast('暂未支持的操作');
    }
  }

  Future<void> confirmAction(String text, Future<void> Function() task) async {
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('操作提示', style: TextStyle(fontSize: 16.0)),
        content: Text(text, style: const TextStyle(fontSize: 14.0, color: Colors.black54)),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('确定', style: TextStyle(color: primary))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await task();
      MyDialog.toast('操作成功');
      await load();
    } catch (e) {
      MyDialog.toast(OrderApi.errorMsg(e, '操作失败'));
    }
  }

  /// 去支付: 取支付单号后弹支付框(与 H5 orderMethod.pay 一致)
  Future<void> openPay() async {
    String outTradeNo = '${orderData['out_trade_no'] ?? ''}';
    if (outTradeNo.isEmpty) {
      try {
        outTradeNo = await OrderApi.pay(orderId);
      } catch (e) {
        MyDialog.toast(OrderApi.errorMsg(e, '获取支付信息失败'));
        return;
      }
    }
    if (outTradeNo.isEmpty) {
      MyDialog.toast('未获取到支付单号');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: moneyOf('pay_money'),
          outTradeNo: outTradeNo,
          onChanged: (dynamic value) => MyDialog.toast('$value'),
          onClosed: (int id) => load(),
        );
      },
    );
  }

  Future<void> copyText(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    MyDialog.toast('已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('订单详情', style: TextStyle(fontSize: 18.0)),
        titleSpacing: 1.0,
      ),
      body: loading ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary))) : _buildBody(),
      bottomNavigationBar: _buildActions(),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildBody() {
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
            TextButton(onPressed: load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: RefreshIndicator(
        color: primary,
        onRefresh: load,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(10.0),
          children: <Widget>[
            _buildStatus(),
            _buildAddress(),
            _buildGoods(),
            _buildOrderInfo(),
            _buildVirtual(),
            _buildMoney(),
            const SizedBox(height: 10.0),
          ],
        ),
      ),
    );
  }

  /// 订单状态(待付款时展示倒计时) —— 对齐 H5 status-wrap
  Widget _buildStatus() {
    final bool waitPay = '${orderData['order_status'] ?? ''}' == '0' && '${orderData['pay_type'] ?? ''}' != 'offlinepay';
    final String promotionName = '${orderData['promotion_status_name'] ?? ''}';
    final bool presaleWaitSend = '${orderData['promotion_type'] ?? ''}' == 'presale' && '${orderData['order_status'] ?? ''}' == '1';
    final OrderStatusMeta meta = OrderStatusStyle.meta('${orderData['order_status'] ?? ''}');
    return Stack(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: meta.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: <BoxShadow>[BoxShadow(color: meta.color.withAlpha(40), blurRadius: 12.0, offset: const Offset(0.0, 6.0))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(meta.icon, color: Colors.white, size: 22.0),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      '${orderData['order_status_name'] ?? ''}${promotionName.isNotEmpty ? '（$promotionName）' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 19.0, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (presaleWaitSend && dateText(orderData['predict_delivery_time']).isNotEmpty) ...<Widget>[
                const SizedBox(height: 8.0),
                Text('预计${dateText(orderData['predict_delivery_time'])}发货',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.0)),
              ],
              if (waitPay && closeSeconds > 0) ...<Widget>[
                const SizedBox(height: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20.0)),
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(text: '剩余 '),
                        TextSpan(text: closeTimeText, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: ' 自动关闭'),
                      ],
                      style: const TextStyle(color: Colors.white, fontSize: 12.0),
                    ),
                  ),
                ),
              ],
              if ('${orderData['close_cause'] ?? ''}'.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8.0),
                Text('关闭原因：${orderData['close_cause']}', style: const TextStyle(color: Colors.white70, fontSize: 12.0)),
              ],
            ],
          ),
        ),
        Positioned(right: -12.0, bottom: -12.0, child: Icon(Icons.local_shipping_outlined, size: 90.0, color: Colors.white.withValues(alpha: 0.08))),
      ],
    );
  }

  /// 收货信息 —— 对齐 H5: 按 order_type 区分 快递/自提/同城
  Widget _buildAddress() {
    if (orderType == '2') return _buildStoreAddress();
    return _buildExpressAddress();
  }

  /// 快递(1)/同城(3)收货信息
  Widget _buildExpressAddress() {
    final bool isLocal = orderType == '3';
    final dynamic pkg = orderData['package_list'];
    final Map<String, dynamic> package = pkg is Map ? pkg.cast<String, dynamic>() : <String, dynamic>{};
    final String deliverer = '${package['deliverer'] ?? ''}';
    return _addressCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32.0,
            height: 32.0,
            margin: const EdgeInsets.only(right: 10.0, top: 2.0),
            decoration: const BoxDecoration(color: Color(0xFFFFEEF1), shape: BoxShape.circle),
            child: const Icon(Icons.location_on_outlined, size: 16.0, color: primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${orderData['name'] ?? ''} ${orderData['mobile'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6.0),
                Text('${orderData['full_address'] ?? ''} ${orderData['address'] ?? ''}',
                  style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888), height: 1.5)),
                if (isLocal && '${orderData['buyer_ask_delivery_time'] ?? ''}'.isNotEmpty)
                  _pickBlock('送达时间：', '${orderData['buyer_ask_delivery_time']}'),
                if (isLocal && deliverer.isNotEmpty) ...<Widget>[
                  _pickBlock('配送员：', deliverer),
                  _pickBlock('外卖电话：', '${package['deliverer_mobile'] ?? ''}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 门店自提(2): 门店信息 + 联系人 + 提货码
  Widget _buildStoreAddress() {
    final Map<String, dynamic> store = storeInfo;
    final String code = '${orderData['delivery_code'] ?? ''}';
    final int deliveryStoreId = int.tryParse('${orderData['delivery_store_id'] ?? ''}') ?? 0;
    final String storeName = '${orderData['delivery_store_name'] ?? ''}';
    final String fullAddress = '${store['full_address'] ?? ''}';
    final String address = fullAddress.isNotEmpty ? fullAddress : '${store['address'] ?? ''}';
    final String barcode = '${orderData['pickup_barcode'] ?? ''}';
    final String qrcode = '${orderData['pickup'] ?? ''}';
    return Column(
      children: <Widget>[
        _addressCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (store.isNotEmpty) ...<Widget>[
                // 门店名(与 H5 一致: 点击跳门店详情)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: deliveryStoreId <= 0
                      ? null
                      : () => Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': deliveryStoreId}),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.storefront_outlined, size: 16.0, color: primary),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(storeName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12.0, color: Colors.grey),
                    ],
                  ),
                ),
                if ('${store['open_date'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('营业时间：${store['open_date']}',
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
                  ),
                if (address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('地址：$address',
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888), height: 1.4)),
                  ),
              ] else
                const Text('当前无自提门店', style: TextStyle(fontSize: 13.0, color: primary)),
              _pickBlock('姓名', '${orderData['name'] ?? ''}'),
              _pickBlock('预留手机', '${orderData['mobile'] ?? ''}'),
              _pickBlock('提货时间', '${orderData['buyer_ask_delivery_time'] ?? ''}'),
            ],
          ),
        ),
        // 提货码(已支付后展示,与 H5 pickup-info 一致)
        if (payed && code.isNotEmpty)
          _addressCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('提货码：', style: TextStyle(fontSize: 13.0, color: Color(0xFF888888))),
                    Text(code, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8.0),
                    _copyTag(code),
                  ],
                ),
                if (barcode.isNotEmpty || qrcode.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10.0),
                  Row(
                    children: <Widget>[
                      if (barcode.isNotEmpty)
                        Expanded(child: _buildCodeImage(barcode, height: 46.0)),
                      if (barcode.isNotEmpty && qrcode.isNotEmpty) const SizedBox(width: 20.0),
                      if (qrcode.isNotEmpty)
                        _buildCodeImage(qrcode, width: 92.0, height: 92.0),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _addressCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0A000000), blurRadius: 10.0, offset: Offset(0.0, 4.0))],
      ),
      child: child,
    );
  }

  /// 自提/同城信息行(H5 pick-block)
  Widget _pickBlock(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13.0, color: Color(0xFF888888))),
          const SizedBox(width: 6.0),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 13.0))),
        ],
      ),
    );
  }

  /// 复制小按钮(固定 44px 宽)
  Widget _copyTag(String text) {
    return InkWell(
      onTap: () => copyText(text),
      child: Container(
        width: 44.0,
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10.0),
        ),
        alignment: Alignment.center,
        child: const Text('复制', style: TextStyle(fontSize: 10.0, color: Color(0xFF888888))),
      ),
    );
  }

  /// 提货码/条形码图片(兼容 base64 data URL / 网络 URL / 相对路径)
  Widget _buildCodeImage(String src, {double? width, double? height}) {
    final String url = _resolveImageUrl(src);
    if (url.isEmpty) return _codePlaceholder(width: width, height: height);

    // data URL: 直接解码成 bytes 显示
    if (url.startsWith('data:')) {
      final int comma = url.indexOf(',');
      final String data = comma > 0 ? url.substring(comma + 1) : url;
      try {
        final Uint8List bytes = base64Decode(data);
        if (bytes.isEmpty) return _codePlaceholder(width: width, height: height);
        return Image.memory(bytes, width: width, height: height, fit: BoxFit.contain);
      } catch (_) {
        return _codePlaceholder(width: width, height: height);
      }
    }

    // 网络图片: 使用浏览器原生加载(与 H5 image 标签一致),失败显示占位
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _codePlaceholder(width: width, height: height),
      loadingBuilder: (_, Widget child, ImageChunkEvent? loading) {
        if (loading == null) return child;
        return _codePlaceholder(width: width, height: height);
      },
    );
  }

  /// 占位/失败图
  Widget _codePlaceholder({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: const Text('加载失败', style: TextStyle(fontSize: 11.0, color: Colors.grey)),
    );
  }

  /// 补齐图片域名(与 H5 $util.img 对齐)
  String _resolveImageUrl(String src) {
    if (src.trim().isEmpty) return '';
    if (src.startsWith('data:')) return src;
    String url = src;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '${Config.imgDomain}/$url';
    }
    if (Config.baseUrl.startsWith('https://') && url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    if (Config.imageProxy.isNotEmpty) {
      url = '${Config.imageProxy}${Uri.encodeComponent(url)}';
    }
    return url;
  }

  /// 商品列表
  Widget _buildGoods() {
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0A000000), blurRadius: 10.0, offset: Offset(0.0, 4.0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.storefront_outlined, size: 15.0, color: Color(0xFF666666)),
              const SizedBox(width: 5.0),
              Flexible(
                child: Text('${orderData['site_name'] ?? '商品信息'}', style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          ...goodsList.map((Map<String, dynamic> item) => _buildGoodsItem(item)),
        ],
      ),
    );
  }

  Widget _buildGoodsItem(Map<String, dynamic> item) {
    final String image = '${item['sku_image'] ?? ''}';
    final String spec = OrderApi.specTextOf(item['sku_spec_format']);
    final int goodsId = int.tryParse('${item['goods_id'] ?? ''}') ?? 0;
    final bool showDelivery = orderType == '1' && '${orderData['order_status'] ?? ''}' == '1' && '${item['delivery_status'] ?? ''}' == '1';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: goodsId > 0 ? () => Get.toNamed('/goods', arguments: <String, dynamic>{'goodsId': goodsId}) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: image.isEmpty
                      ? Container(width: 86.0, height: 86.0, color: const Color(0xFFF5F5F5))
                      : CachedNetworkImage(
                          imageUrl: image,
                          width: 86.0,
                          height: 86.0,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(width: 86.0, height: 86.0, color: const Color(0xFFF5F5F5)),
                        ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 86.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${item['sku_name'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.0, height: 1.3),
                        ),
                        if (spec.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4.0),
                            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4.0)),
                            child: Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                          ),
                        Row(
                          children: <Widget>[
                            Text('¥${money(OrderApi.moneyOf(item['price']))}', style: const TextStyle(color: primary, fontSize: 14.0, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text('x${item['num'] ?? 1}', style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDelivery && '${item['delivery_status_name'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(color: const Color(0xFFFFF2F4), borderRadius: BorderRadius.circular(6.0)),
                child: Text('${item['delivery_status_name']}', style: const TextStyle(fontSize: 11.0, color: primary)),
              ),
            ),
          _buildGoodsAction(item),
        ],
      ),
    );
  }

  /// 商品级操作: 申请退款/售后 与 退款详情(H5 goods-action)
  /// * 退款页/退款详情页尚未移植,按钮暂提示
  Widget _buildGoodsAction(Map<String, dynamic> item) {
    final bool enableRefund = '${orderData['is_enable_refund'] ?? ''}' == '1' || '${orderData['is_enable_refund'] ?? ''}' == 'true';
    final bool online = '${orderData['order_scene'] ?? ''}' == 'online';
    final int refundStatus = int.tryParse('${item['refund_status'] ?? 0}') ?? 0;
    final bool notBlindbox = '${orderData['promotion_type'] ?? ''}' != 'blindbox';
    if (refundStatus != 0) {
      final String name = '${item['refund_status_name'] ?? ''}';
      if (name.isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerRight,
        child: _goodsButton(name, () => Get.toNamed('/order/refund_detail', arguments: <String, dynamic>{
              'order_goods_id': int.tryParse('${item['order_goods_id'] ?? ''}') ?? 0,
            })),
      );
    }
    if (!(enableRefund && online && notBlindbox)) return const SizedBox.shrink();
    final String text = '${orderData['order_status'] ?? ''}' == '10' ? '申请售后' : '申请退款';
    return Align(
      alignment: Alignment.centerRight,
      child: _goodsButton(text, () => Get.toNamed('/order/refund', arguments: <String, dynamic>{
            'order_goods_id': int.tryParse('${item['order_goods_id'] ?? ''}') ?? 0,
          })),
    );
  }

  Widget _goodsButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        height: 28.0,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF666666),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontSize: 12.0)),
        ),
      ),
    );
  }

  /// 虚拟商品: 核销码 / 核销信息 / 卡密(H5 goods_class 2/3/4)
  Widget _buildVirtual() {
    final String goodsClass = '${orderData['goods_class'] ?? ''}';
    final dynamic raw = orderData['virtual_goods'];
    if (raw == null || (goodsClass != '2' && goodsClass != '3' && goodsClass != '4')) return const SizedBox.shrink();
    // 卡密(goods_class == 3): virtual_goods 为数组
    if (goodsClass == '3') {
      final List<Map<String, dynamic>> list = raw is List
          ? raw.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      if (list.isEmpty) return const SizedBox.shrink();
      return _card(
        title: '卡密信息',
        child: Column(
          children: list.map((Map<String, dynamic> item) {
            final dynamic card = item['card_info'];
            final Map<String, dynamic> info = card is Map ? card.cast<String, dynamic>() : <String, dynamic>{};
            return Column(
              children: <Widget>[
                _buildRowCopy('卡号', '${info['cardno'] ?? ''}'),
                _buildRowCopy('密码', '${info['password'] ?? ''}'),
              ],
            );
          }).toList(),
        ),
      );
    }
    if (raw is! Map) return const SizedBox.shrink();
    final Map<String, dynamic> virtual = raw.cast<String, dynamic>();
    final int isVerify = int.tryParse('${virtual['is_veirfy'] ?? 0}') ?? 0;
    final int total = int.tryParse('${virtual['verify_total_count'] ?? 0}') ?? 0;
    final int used = int.tryParse('${virtual['verify_use_num'] ?? 0}') ?? 0;
    final List<Map<String, dynamic>> records = (virtual['verify_record'] is List)
        ? (virtual['verify_record'] as List).whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    final String code = '${orderData['virtual_code'] ?? ''}';
    final String barcode = '${orderData['virtualgoods_barcode'] ?? ''}';
    final String qrcode = '${orderData['virtualgoods'] ?? ''}';
    return Column(
      children: <Widget>[
        if (isVerify == 0)
          _card(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (barcode.isNotEmpty)
                      Expanded(child: CachedNetworkImage(imageUrl: barcode, height: 46.0, fit: BoxFit.contain)),
                    if (barcode.isNotEmpty && qrcode.isNotEmpty) const SizedBox(width: 16.0),
                    if (qrcode.isNotEmpty)
                      CachedNetworkImage(imageUrl: qrcode, width: 92.0, height: 92.0, fit: BoxFit.contain),
                  ],
                ),
                const SizedBox(height: 6.0),
                const Text('请将条形码或二维码出示给核销员', style: TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: FStyle.divider,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(code, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8.0),
                    _copyTag(code),
                  ],
                ),
              ],
            ),
          ),
        _card(
          title: '核销信息',
          child: Column(
            children: <Widget>[
              _buildRow('核销次数', '剩余${total - used}次/共${total}次', size: 12.0, align: TextAlign.right),
              _buildRow('有效期', int.tryParse('${virtual['expire_time'] ?? 0}') != null && (int.tryParse('${virtual['expire_time'] ?? 0}') ?? 0) > 0
                  ? timeText(virtual['expire_time']) : '永久有效', size: 12.0, align: TextAlign.right),
            ],
          ),
        ),
        _card(
          title: '核销记录',
          child: records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.0),
                  child: const CommonEmpty(text: '暂无核销记录', imageWidth: 80.0),
                )
              : Column(
                  children: records.map((Map<String, dynamic> item) => Column(
                        children: <Widget>[
                          _buildRow('核销人', '${item['verifier_name'] ?? ''}', size: 12.0, align: TextAlign.right),
                          _buildRow('核销时间', timeText(item['verify_time']), size: 12.0, align: TextAlign.right),
                        ],
                      )).toList(),
                ),
        ),
      ],
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0A000000), blurRadius: 10.0, offset: Offset(0.0, 4.0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(title, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10.0),
          ],
          child,
        ],
      ),
    );
  }

  /// 金额明细
  Widget _buildMoney() {
    // 金额统一右对齐,与上方列表同一列
    Widget moneyRow(String label, String value, {Color? color}) =>
        _buildRow(label, value, color: color, align: TextAlign.right);
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0A000000), blurRadius: 10.0, offset: Offset(0.0, 4.0))],
      ),
      child: Column(
        children: <Widget>[
          moneyRow('商品金额', '¥${money(moneyOf('goods_money'))}', color: const Color(0xFF888888)),
          if (orderType != '4') moneyRow('运费', '+¥${money(moneyOf('delivery_money'))}', color: const Color(0xFF888888)),
          if (moneyOf('member_card_money') > 0) moneyRow('会员卡', '-¥${money(moneyOf('member_card_money'))}', color: primary),
          if (moneyOf('invoice_money') > 0)
            moneyRow('税费(${moneyOf('invoice_rate')}%)', '+¥${money(moneyOf('invoice_money'))}', color: primary),
          if (moneyOf('invoice_delivery_money') > 0)
            moneyRow('发票邮寄费', '+¥${money(moneyOf('invoice_delivery_money'))}', color: primary),
          if (moneyOf('adjust_money') != 0)
            moneyRow('订单调整', '${moneyOf('adjust_money') < 0 ? '-' : '+'}¥${money(moneyOf('adjust_money').abs())}', color: primary),
          if (moneyOf('promotion_money') > 0) moneyRow('优惠', '-¥${money(moneyOf('promotion_money'))}', color: primary),
          if (moneyOf('coupon_money') > 0) moneyRow('优惠券', '-¥${money(moneyOf('coupon_money'))}', color: primary),
          if (moneyOf('balance_money') > 0) moneyRow('使用余额', '-¥${money(moneyOf('balance_money'))}', color: primary),
          if (moneyOf('point_money') > 0) moneyRow('积分抵扣', '-¥${money(moneyOf('point_money'))}', color: primary),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: FStyle.divider,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                width: labelWidth,
                child: Text('实付金额', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Text('¥', style: TextStyle(fontSize: 12.0, color: primary, fontWeight: FontWeight.w600)),
                    Text(
                      money(moneyOf('order_money')),
                      style: const TextStyle(fontSize: 20.0, color: primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 订单信息
  Widget _buildOrderInfo() {
    final String orderNo = '${orderData['order_no'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0A000000), blurRadius: 10.0, offset: Offset(0.0, 4.0))],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.receipt_long_outlined, size: 16.0, color: Color(0xFF666666)),
              const SizedBox(width: 5.0),
              const Text('订单信息', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () => copyText(orderNo),
                child: const Icon(Icons.copy_outlined, color: Color(0xFFAAAAAA), size: 15.0),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          if ('${orderData['order_type_name'] ?? ''}'.isNotEmpty) _buildRow('订单类型', '${orderData['order_type_name']}', size: 12.0),
          _buildRow('订单编号', orderNo, size: 12.0),
          if ('${orderData['out_trade_no'] ?? ''}'.isNotEmpty) _buildRow('订单交易号', '${orderData['out_trade_no']}', size: 12.0),
          _buildRow('创建时间', timeText(orderData['create_time']), size: 12.0),
          if (int.tryParse('${orderData['close_time'] ?? 0}') != null && (int.tryParse('${orderData['close_time'] ?? 0}') ?? 0) > 0)
            _buildRow('关闭时间', timeText(orderData['close_time']), size: 12.0),
          if (payed) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: FStyle.divider,
            ),
            if ('${orderData['pay_type_name'] ?? ''}'.isNotEmpty) _buildRow('支付方式', '${orderData['pay_type_name']}', size: 12.0),
            _buildRow('支付时间', timeText(orderData['pay_time']), size: 12.0),
          ],
          if ('${orderData['delivery_type_name'] ?? ''}'.isNotEmpty) _buildRow('配送方式', '${orderData['delivery_type_name']}', size: 12.0),
          if ('${orderData['buyer_message'] ?? ''}'.isNotEmpty) _buildRow('买家留言', '${orderData['buyer_message']}', size: 12.0),
          if ('${orderData['promotion_type_name'] ?? ''}'.isNotEmpty) _buildRow('活动优惠', '${orderData['promotion_type_name']}', size: 12.0),
          ..._buildInvoice(),
          ..._buildOrderForm(),
          ..._buildOfflinePay(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: FStyle.divider,
          ),
          _buildCustomerService(),
        ],
      ),
    );
  }

  /// 订单编号 + 复制
  Widget _buildRowCopy(String label, String value) {
    return _buildRow(label, value, size: 12.0, suffix: _copyTag(value));
  }

  /// 发票信息(H5: is_invoice > 0)
  List<Widget> _buildInvoice() {
    final int isInvoice = int.tryParse('${orderData['is_invoice'] ?? 0}') ?? 0;
    if (isInvoice <= 0) return <Widget>[];
    final bool paper = '${orderData['invoice_type'] ?? ''}' == '1';
    return <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: FStyle.divider,
      ),
      _buildRow('发票类型', paper ? '纸质发票' : '电子发票', size: 12.0),
      _buildRow('发票抬头类型', '${orderData['invoice_title_type'] ?? ''}' == '1' ? '个人' : '企业', size: 12.0),
      _buildRow('发票抬头', '${orderData['invoice_title'] ?? ''}', size: 12.0),
      _buildRow('发票内容', '${orderData['invoice_content'] ?? ''}', size: 12.0),
      _buildRow('发票邮寄地址', '${orderData['invoice_full_address'] ?? ''}', size: 12.0),
      _buildRow('发票接收邮件', '${orderData['invoice_email'] ?? ''}', size: 12.0),
    ];
  }

  /// 订单表单(H5: orderData.form)
  List<Widget> _buildOrderForm() {
    final List<Map<String, dynamic>> forms = _formListOf(orderData['form']);
    if (forms.isEmpty) return <Widget>[];
    return <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: FStyle.divider,
      ),
      ...forms.map((Map<String, dynamic> item) {
        final String title = '${(item['value'] is Map ? item['value']['title'] : '') ?? ''}';
        final String value = '${item['val'] ?? ''}';
        return _buildRowCopy(title.isEmpty ? '自定义信息' : title, value);
      }),
    ];
  }

  /// 线下支付信息(H5: pay_type == offlinepay && offline_pay_info)
  List<Widget> _buildOfflinePay() {
    if ('${orderData['pay_type'] ?? ''}' != 'offlinepay') return <Widget>[];
    final dynamic raw = orderData['offline_pay_info'];
    if (raw is! Map) return <Widget>[];
    final Map<String, dynamic> info = raw.cast<String, dynamic>();
    final dynamic status = info['status_info'];
    final Map<String, dynamic> statusInfo = status is Map ? status.cast<String, dynamic>() : <String, dynamic>{};
    final bool refused = '${statusInfo['const'] ?? ''}' == 'AUDIT_REFUSE';
    return <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: FStyle.divider,
      ),
      _buildRow('支付方式', '线下支付', size: 12.0),
      _buildRow('支付状态', '${statusInfo['name'] ?? ''}', size: 12.0),
      if (refused) _buildRow('审核备注', '${info['audit_remark'] ?? ''}', size: 12.0),
    ];
  }

  /// 联系客服(H5: ns-contact)
  Widget _buildCustomerService() {
    return InkWell(
      onTap: () => Get.toNamed('/chat'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 26.0,
            height: 26.0,
            decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
            child: const Icon(Icons.headset_mic_outlined, size: 14.0, color: Color(0xFF888888)),
          ),
          const SizedBox(width: 6.0),
          const Text('联系客服', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
        ],
      ),
    );
  }

  /// 表单数据: JSON字符串或数组
  static List<Map<String, dynamic>> _formListOf(dynamic value) {
    dynamic data = value;
    if (data is String) {
      if (data.trim().isEmpty) return <Map<String, dynamic>>[];
      try {
        data = jsonDecode(data);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    if (data is! List) return <Map<String, dynamic>>[];
    return data.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  }

  /// 列表行: 左侧 label 固定宽度(对齐成一列) + 右侧 value + 固定宽度尾部(复制按钮/占位)
  Widget _buildRow(
    String label,
    String value, {
    Color? color,
    bool bold = false,
    double size = 13.0,
    TextAlign align = TextAlign.left,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888)),
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              value,
              textAlign: align,
              style: TextStyle(
                fontSize: size,
                color: color ?? const Color(0xFF333333),
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                height: 1.4,
              ),
            ),
          ),
          // 只有存在右侧内容(复制按钮等)时才占位,否则右列贴着卡片右边缘
          if (suffix != null) ...<Widget>[
            const SizedBox(width: 6.0),
            suffix,
          ],
        ],
      ),
    );
  }

  /// 底部操作按钮(order_status_action + 评价/追评)
  Widget? _buildActions() {
    final List<Map<String, dynamic>> list = actions;
    if (loading || (list.isEmpty && !showEvaluate)) return null;
    final List<Widget> children = <Widget>[
      if (showEvaluate)
        _actionButton(
          evaluateStatus == 1 ? '追评' : '评价',
          false,
          () => Get.toNamed('/order/evaluate', arguments: <String, dynamic>{'order_id': orderId}),
        ),
      ...list.map((Map<String, dynamic> item) {
        final String action = '${item['action'] ?? ''}';
        final bool main = action == 'orderPay';
        return _actionButton('${item['title'] ?? ''}', main, () => onAction(action));
      }),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 10.0, offset: Offset(0.0, -2.0))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
      ),
    );
  }

  Widget _actionButton(String text, bool main, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: SizedBox(
        height: 34.0,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: main ? primary : Colors.white,
            foregroundColor: main ? Colors.white : const Color(0xFF666666),
            side: BorderSide(color: main ? primary : const Color(0xFFE5E5E5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
