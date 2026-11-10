/// 兑换订单详情
/// 对齐 H5: pages/order/detail_point.vue
/// * 详情 /pointexchange/api/order/info(order_id)
/// * 状态头 + 兑换商品卡 + 订单概况(复制/客服) + 金额区 + 操作(关闭/支付/查看关联订单)
/// * 保留「实物商品且已生成关联订单 -> 普通订单详情」入口, 以「查看关联订单」按钮呈现
/// * 不做 H5 底部的商品推荐
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/point_exchange.dart';
import '../../components/popup_pay.dart';
import '../../styles/index.dart';
import '../../utils/index.dart';

class PointOrderDetailPage extends StatefulWidget {
  const PointOrderDetailPage({super.key});

  @override
  State<PointOrderDetailPage> createState() => _PointOrderDetailPageState();
}

class _PointOrderDetailPageState extends State<PointOrderDetailPage> {
  static const Color primary = Color(0xFFF16914);

  int orderId = 0;
  /// 关联普通订单 id(列表传入兜底, 详情接口若返回则覆盖)
  int relateOrderId = 0;
  Map<String, dynamic> order = <String, dynamic>{};
  bool loading = true;
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      orderId = int.tryParse('${args['order_id'] ?? 0}') ?? 0;
      relateOrderId = int.tryParse('${args['relate_order_id'] ?? 0}') ?? 0;
    }
    load();
  }

  int get status => int.tryParse('${order['order_status'] ?? 0}') ?? 0;
  int get type => int.tryParse('${order['type'] ?? 0}') ?? 0;
  int get point => int.tryParse('${order['point'] ?? 0}') ?? 0;
  num get price => num.tryParse('${order['price'] ?? 0}') ?? 0;
  num get deliveryPrice => num.tryParse('${order['delivery_price'] ?? 0}') ?? 0;
  num get orderMoney => num.tryParse('${order['order_money'] ?? 0}') ?? 0;
  int get closeTime => int.tryParse('${order['close_time'] ?? 0}') ?? 0;
  int get exchangeGoodsId => int.tryParse('${order['exchange_goods_id'] ?? 0}') ?? 0;

  String get statusName {
    switch (status) {
      case 0:
        return '待支付';
      case 1:
        return '已完成';
      case -1:
        return '已关闭';
      default:
        return '';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 0:
        return Icons.schedule_rounded;
      case 1:
        return Icons.check_circle_outline_rounded;
      case -1:
        return Icons.block_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  /// 商品图: H5 exchangeImage 对优惠券/红包有默认图, 失败再回退图标占位
  String get image {
    final String raw = '${order['exchange_image'] ?? ''}'.trim();
    if (raw.isNotEmpty && raw != 'null') return PointExchangeApi.img(raw);
    if (type == PointExchangeApi.typeCoupon) {
      return PointExchangeApi.img('public/uniapp/point/coupon.png');
    }
    if (type == PointExchangeApi.typeHongbao) {
      return PointExchangeApi.img('public/uniapp/point/hongbao.png');
    }
    return '';
  }

  Future<void> load() async {
    if (orderId <= 0) {
      setState(() {
        loading = false;
        errorMsg = '订单参数有误';
      });
      return;
    }
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await PointExchangeApi.orderInfo(orderId);
      if (!mounted) return;
      final int fromApi = int.tryParse('${data['relate_order_id'] ?? 0}') ?? 0;
      setState(() {
        order = data;
        if (fromApi > 0) relateOrderId = fromApi;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = PointExchangeApi.errorMsg(e, '未获取到订单信息');
      });
    }
  }

  Future<void> copyText(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    MyDialog.toast('已复制');
  }

  /// 关闭兑换(H5 orderClose: 二次确认 -> /order/close -> 重新拉详情)
  Future<void> closeOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', style: TextStyle(fontSize: 16.0)),
          content: const Text('确定关闭此次兑换？', style: TextStyle(fontSize: 14.0)),
          actions: <Widget>[
            TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
            TextButton(onPressed: () => Get.back(result: true), child: const Text('确定')),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await PointExchangeApi.orderClose(orderId);
      if (!mounted) return;
      MyDialog.toast('关闭成功');
      await load();
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(PointExchangeApi.errorMsg(e, '关闭失败'));
    }
  }

  /// 继续支付(复用列表页 openPay 的 PopupPay 底部弹窗)
  void openPay() {
    final String outTradeNo = '${order['out_trade_no'] ?? ''}';
    if (outTradeNo.isEmpty || outTradeNo == 'null') {
      MyDialog.toast('支付单号缺失,暂无法支付');
      return;
    }
    final num money = orderMoney > 0 ? orderMoney : price;
    showModalBottomSheet<void>(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: money.toDouble(),
          outTradeNo: outTradeNo,
          toPayResult: false,
          onChanged: (dynamic value) {
            MyDialog.toast('$value');
            load();
          },
        );
      },
    );
  }

  /// 查看关联订单(保留原有能力: 实物商品且已生成普通订单)
  void openRelateOrder() {
    if (relateOrderId <= 0) return;
    Get.toNamed('/order/detail', arguments: <String, dynamic>{'order_id': relateOrderId});
  }

  /// 兑换商品详情(H5 goDetail)
  void openGoods() {
    if (exchangeGoodsId <= 0) return;
    Get.toNamed('/point/detail', arguments: <String, dynamic>{'id': exchangeGoodsId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text('兑换详情', style: TextStyle(fontSize: 17.0)),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            )
          : (errorMsg.isNotEmpty ? _buildError() : _buildBody()),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.receipt_long_outlined, size: 48.0, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 12.0),
          Text(errorMsg, style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
          const SizedBox(height: 16.0),
          OutlinedButton(
            onPressed: load,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(color: primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
            ),
            child: const Text('重新加载', style: TextStyle(fontSize: 13.0)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: <Widget>[
            // 状态头背景(高度大于状态行, 让白色商品卡自然叠压在底部)
            Container(
              height: 116.0,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF7A13B), Color(0xFFF16914)],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildStatusHeader(),
                _buildGoodsCard(),
                _buildOrderInfo(),
                _buildOrderMoney(),
                const SizedBox(height: 24.0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 状态头(H5 status-wrap)
  Widget _buildStatusHeader() {
    return SizedBox(
      height: 92.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 26.0),
        child: Row(
          children: <Widget>[
            Icon(statusIcon, size: 28.0, color: Colors.white),
            const SizedBox(width: 10.0),
            Text(
              statusName,
              style: const TextStyle(fontSize: 19.0, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  /// 兑换商品卡(H5 site-wrap -> goods-item)
  Widget _buildGoodsCard() {
    final String url = image;
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openGoods,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: url.isEmpty
                  ? _imagePlaceholder()
                  : CachedNetworkImage(
                      imageUrl: url,
                      width: 72.0,
                      height: 72.0,
                      fit: BoxFit.cover,
                      errorWidget: (BuildContext context, String u, Object e) => _imagePlaceholder(),
                    ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: SizedBox(
                height: 72.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${order['exchange_name'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.0, color: Color(0xFF222222)),
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          '$point',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontFamily: 'Arial',
                          ),
                        ),
                        const Text(' 积分', style: TextStyle(fontSize: 11.0, color: primary)),
                        if (price > 0) ...<Widget>[
                          const SizedBox(width: 4.0),
                          Text('+ ¥${price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12.0, color: primary)),
                        ],
                        const Spacer(),
                        Text('x${order['num'] ?? 1}',
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                      ],
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

  Widget _imagePlaceholder() {
    return Container(
      width: 72.0,
      height: 72.0,
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: Icon(
        type == PointExchangeApi.typeCoupon
            ? Icons.confirmation_num_outlined
            : (type == PointExchangeApi.typeHongbao ? Icons.redeem_outlined : Icons.card_giftcard_outlined),
        size: 26.0,
        color: Colors.grey,
      ),
    );
  }

  /// 订单概况(H5 order-summary)
  Widget _buildOrderInfo() {
    final String orderNo = '${order['order_no'] ?? ''}';
    final String tradeNo = '${order['out_trade_no'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 10.0),
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        children: <Widget>[
          _buildRow('订单编号', orderNo, suffix: _copyTag(orderNo)),
          if (tradeNo.isNotEmpty && tradeNo != 'null') _buildRow('订单交易号', tradeNo),
          _buildRow('创建时间', Utils.timeStampTurnTime(order['create_time'])),
          if (closeTime > 0) _buildRow('关闭时间', Utils.timeStampTurnTime(closeTime)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: FStyle.divider),
          _buildCustomerService(),
        ],
      ),
    );
  }

  /// 金额区(H5 order-money) + 操作按钮
  Widget _buildOrderMoney() {
    final bool canOperate = status == 0 && type == PointExchangeApi.typeGoods;
    final bool canPay = canOperate && price > 0 && '${order['out_trade_no'] ?? ''}'.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        children: <Widget>[
          if (point > 0) _buildMoneyRow('使用积分', '$point', color: primary),
          if (deliveryPrice > 0) _buildMoneyRow('运费', '¥${deliveryPrice.toStringAsFixed(2)}', color: primary),
          if (orderMoney > 0)
            _buildMoneyRow('实付金额', '¥${orderMoney.toStringAsFixed(2)}', color: primary, bold: true),
          if (canOperate || relateOrderId > 0) ...<Widget>[
            const Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: FStyle.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (type == PointExchangeApi.typeGoods && relateOrderId > 0) ...<Widget>[
                  _actionBtn('查看关联订单', false, openRelateOrder),
                  const SizedBox(width: 8.0),
                ],
                if (canOperate) _actionBtn('关闭', false, closeOrder),
                if (canOperate && canPay) ...<Widget>[
                  const SizedBox(width: 8.0),
                  _actionBtn('支付', true, openPay),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16.0 : 14.0,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88.0,
            child: Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.0, color: Color(0xFF333333))),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _copyTag(String text) {
    return InkWell(
      onTap: () => copyText(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDDDDD), width: 0.8),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: const Text('复制', style: TextStyle(fontSize: 11.0, color: Color(0xFF666666))),
      ),
    );
  }

  /// 联系客服(H5 ns-contact)
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

  Widget _actionBtn(String text, bool filled, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: filled ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: filled ? primary : const Color(0xFFDDDDDD), width: 0.8),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.0, color: filled ? Colors.white : const Color(0xFF666666)),
        ),
      ),
    );
  }
}
