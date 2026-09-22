/// 申请退款/售后
/// 对齐 H5: pages_tool/order/refund.vue
/// * 入参 order_goods_id(Get.arguments: { order_goods_id: 1 })
/// * 批量退款时传 order_goods_ids(逗号拼接)
/// * /api/orderrefund/refundData  退款原因/金额/可退方式
/// * /api/orderrefund/refund      提交申请
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/refund.dart';
import '../../styles/index.dart';

class OrderRefund extends StatefulWidget {
  const OrderRefund({super.key});

  @override
  State<OrderRefund> createState() => _OrderRefundState();
}

class _OrderRefundState extends State<OrderRefund> {
  static const Color primary = Color(0xFFFF2C55);

  /// 订单商品id(多个时逗号拼接)
  String orderGoodsIds = '';
  int firstGoodsId = 0;

  bool loading = true;
  String errorMsg = '';
  bool submitting = false;

  Map<String, dynamic> refundData = <String, dynamic>{};
  Map<String, dynamic> goodsInfo = <String, dynamic>{};

  /// 1仅退款 2退货退款(0 未选择)
  int refundType = 0;
  String refundReason = '';
  final TextEditingController remarkController = TextEditingController();

  /// 可选退款方式(refund_type 数组)
  List<int> get refundTypes {
    final dynamic list = refundData['refund_type'];
    if (list is! List) return <int>[1];
    return list.map((dynamic e) => int.tryParse('$e') ?? 0).where((int e) => e > 0).toList();
  }

  /// 退款原因列表
  List<String> get reasons {
    final dynamic list = refundData['refund_reason_type'];
    if (list is! List) return <String>[];
    return list.map((dynamic e) => '$e').toList();
  }

  num get refundMoney => num.tryParse('${refundData['refund_money'] ?? 0}') ?? 0;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      final String ids = '${args['order_goods_ids'] ?? args['order_goods_id'] ?? ''}';
      orderGoodsIds = ids;
      firstGoodsId = int.tryParse(ids.split(',').first) ?? 0;
    }
    load();
  }

  @override
  void dispose() {
    remarkController.dispose();
    super.dispose();
  }

  /// 退款页数据(/api/orderrefund/refundData)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await RefundApi.refundData(firstGoodsId);
      if (!mounted) return;
      final dynamic goods = data['order_goods_info'];
      setState(() {
        refundData = data;
        goodsInfo = goods is Map ? goods.cast<String, dynamic>() : <String, dynamic>{};
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = '$e';
        loading = false;
      });
      MyDialog.toast('未获取到该订单项退款信息');
      Future<void>.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Get.back();
      });
    }
  }

  Future<void> submit() async {
    if (refundType == 0) {
      MyDialog.toast('请选择退款方式');
      return;
    }
    if (refundReason.isEmpty) {
      MyDialog.toast('请选择退款原因');
      return;
    }
    if (submitting) return;
    setState(() {
      submitting = true;
    });
    try {
      await RefundApi.refund(
        orderGoodsIds: orderGoodsIds,
        refundType: refundType,
        refundReason: refundReason,
        refundRemark: remarkController.text,
      );
      MyDialog.toast('提交成功');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      // 单个退款时直接进退款详情,批量时回订单列表
      if (orderGoodsIds.contains(',')) {
        Get.offNamed('/order');
      } else {
        Get.offNamed('/order/refund_detail', arguments: <String, dynamic>{'order_goods_id': firstGoodsId});
      }
    } catch (e) {
      MyDialog.toast('$e');
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  /// 退款原因选择(底部弹窗)
  Future<void> openReason() async {
    final List<String> list = reasons;
    if (list.isEmpty) return;
    final String? result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('退款原因', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              FStyle.divider,
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 16.0),
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      dense: true,
                      title: Text(list[index], style: const TextStyle(fontSize: 13.0)),
                      trailing: Icon(
                        refundReason == list[index] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 18.0,
                        color: refundReason == list[index] ? primary : const Color(0xFFBBBBBB),
                      ),
                      onTap: () => Get.back(result: list[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    setState(() {
      refundReason = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('申请退款', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)))
          : _buildBody(),
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(10.0),
      children: <Widget>[
        _buildGoods(),
        if (refundType == 0) _buildTypeSelect(),
        if (refundType != 0) ...<Widget>[
          _buildForm(),
          const SizedBox(height: 16.0),
          _buildSubmit(),
        ],
        const SizedBox(height: 10.0),
      ],
    );
  }

  /// 退款商品
  Widget _buildGoods() {
    final String image = '${goodsInfo['sku_image'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: image.isEmpty
                ? Container(width: 60.0, height: 60.0, color: const Color(0xFFF5F5F5))
                : CachedNetworkImage(
                    imageUrl: image,
                    width: 60.0,
                    height: 60.0,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 60.0, height: 60.0, color: const Color(0xFFF5F5F5)),
                  ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              '${goodsInfo['sku_name'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 选择退款方式(H5 refund-option)
  Widget _buildTypeSelect() {
    final List<int> types = refundTypes;
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          _typeItem(1, '退款无需退货', '没收到货，或与卖家协商同意无需退货只退款'),
          if (types.contains(2)) _typeItem(2, '退货退款', '已收到货，需退还收到的货物'),
        ],
      ),
    );
  }

  Widget _typeItem(int type, String title, String desc) {
    return InkWell(
      onTap: () => setState(() => refundType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF2F2F2)))),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontSize: 14.0)),
                  const SizedBox(height: 4.0),
                  Text(desc, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18.0, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 退款原因 + 金额 + 说明
  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: openReason,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
              child: Row(
                children: <Widget>[
                  const Text('退款原因：', style: TextStyle(fontSize: 13.0)),
                  Expanded(
                    child: Text(
                      refundReason.isEmpty ? '请选择' : refundReason,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13.0, color: refundReason.isEmpty ? Colors.grey : Colors.black87),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18.0, color: Colors.grey),
                ],
              ),
            ),
          ),
          FStyle.divider,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            child: Row(
              children: <Widget>[
                const Text('退款金额：', style: TextStyle(fontSize: 13.0)),
                Text('¥${refundMoney.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13.0, color: primary)),
              ],
            ),
          ),
          FStyle.divider,
          const Padding(
            padding: EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 6.0),
            child: Text('退款说明', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
            child: TextField(
              controller: remarkController,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(fontSize: 13.0),
              decoration: InputDecoration(
                hintText: '请输入退款说明(选填)',
                hintStyle: const TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                isCollapsed: true,
                contentPadding: const EdgeInsets.all(10.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide.none),
                counterStyle: const TextStyle(fontSize: 11.0, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmit() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SizedBox(
        height: 42.0,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21.0)),
            padding: EdgeInsets.zero,
          ),
          onPressed: submitting ? null : submit,
          child: Text(submitting ? '提交中' : '提交', style: const TextStyle(fontSize: 15.0)),
        ),
      ),
    );
  }
}
