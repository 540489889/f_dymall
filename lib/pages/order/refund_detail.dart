/// 退款详情
/// 对齐 H5: pages_tool/order/refund_detail.vue
/// * 入参 order_goods_id(Get.arguments: { order_goods_id: 1 })
/// * /api/orderrefund/detail    退款详情
/// * /api/orderrefund/cancel    撤销退款
/// * /api/orderrefund/delivery  退货发货(买家回填物流)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/refund.dart';

class OrderRefundDetail extends StatefulWidget {
  const OrderRefundDetail({super.key});

  @override
  State<OrderRefundDetail> createState() => _OrderRefundDetailState();
}

class _OrderRefundDetailState extends State<OrderRefundDetail> {
  static const Color primary = Color(0xFFFF2C55);

  int orderGoodsId = 0;
  Map<String, dynamic> detail = <String, dynamic>{};
  bool loading = true;
  String errorMsg = '';

  /// 当前视图: '' 详情 / 'returngoods' 退货发货 / 'consultrecord' 协商记录
  String action = '';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController noController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();

  String get refundStatus => '${detail['refund_status'] ?? ''}';

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) orderGoodsId = int.tryParse('${args['order_goods_id'] ?? ''}') ?? 0;
    load();
  }

  @override
  void dispose() {
    nameController.dispose();
    noController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  /// 退款详情(/api/orderrefund/detail)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await RefundApi.detail(orderGoodsId);
      if (!mounted) return;
      setState(() {
        detail = data;
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

  static String timeText(dynamic value) {
    final int ts = int.tryParse('$value') ?? 0;
    if (ts <= 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  Future<void> copyText(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    MyDialog.toast('已复制');
  }

  /// 底部操作(refund_action.event)
  Future<void> onAction(String event) async {
    switch (event) {
      case 'orderRefundCancel':
        await cancelRefund();
        break;
      case 'orderRefundDelivery':
        setState(() => action = 'returngoods');
        break;
      case 'orderRefundAsk':
      case 'orderRefundApply':
        Get.toNamed('/order/refund', arguments: <String, dynamic>{'order_goods_id': orderGoodsId});
        break;
      default:
        MyDialog.toast('暂未支持的操作');
    }
  }

  /// 撤销退款(/api/orderrefund/cancel)
  Future<void> cancelRefund() async {
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('操作提示', style: TextStyle(fontSize: 16.0)),
        content: const Text('撤销之后本次申请将会关闭,如后续仍有问题可再次发起申请。', style: TextStyle(fontSize: 14.0, color: Colors.black54)),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back(result: false), child: const Text('暂不撤销', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('确定', style: TextStyle(color: primary))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await RefundApi.cancel(orderGoodsId);
      MyDialog.toast('撤销成功');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (mounted) Get.back();
    } catch (e) {
      MyDialog.toast('$e');
    }
  }

  /// 提交退货物流(/api/orderrefund/delivery)
  Future<void> submitDelivery() async {
    if (nameController.text.trim().isEmpty) {
      MyDialog.toast('请输入物流公司');
      return;
    }
    if (noController.text.trim().isEmpty) {
      MyDialog.toast('请输入物流单号');
      return;
    }
    try {
      await RefundApi.delivery(
        orderGoodsId: orderGoodsId,
        name: nameController.text.trim(),
        no: noController.text.trim(),
        remark: remarkController.text.trim(),
      );
      setState(() => action = '');
      await load();
    } catch (e) {
      MyDialog.toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('退款详情', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)))
          : _buildBody(),
      bottomNavigationBar: action == '' ? _buildActions() : null,
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
    if (action == 'returngoods') return _buildReturnGoods();
    if (action == 'consultrecord') return _buildRecord();
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(10.0),
        children: <Widget>[
          _buildStatus(),
          _buildHistoryEntry(),
          if (refundStatus == '4') _buildShopAddress(),
          _buildInfo(),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }

  /// 退款状态
  Widget _buildStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15.0, 16.0, 15.0, 16.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFFFF6B81), primary], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${detail['refund_status_name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 17.0, fontWeight: FontWeight.w600)),
          if (refundStatus == '1') ...<Widget>[
            const SizedBox(height: 6.0),
            const Text('如果商家拒绝，你可重新发起申请', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
            const Text('如果商家同意，将通过申请并退款给你', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
          ],
          if (refundStatus == '5') ...<Widget>[
            const SizedBox(height: 6.0),
            const Text('如果商家确认收货将会退款给你', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
            const Text('如果商家拒绝收货，该次退款将会关闭，你可以重新发起退款', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
          ],
        ],
      ),
    );
  }

  /// 协商记录入口
  Widget _buildHistoryEntry() {
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () => setState(() => action = 'consultrecord'),
        child: const Row(
          children: <Widget>[
            Expanded(child: Text('协商记录', style: TextStyle(fontSize: 14.0))),
            Icon(Icons.chevron_right_rounded, size: 18.0, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 退货地址(refund_status == 4)
  Widget _buildShopAddress() {
    final String address = '${detail['shop_address'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('退货地址', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6.0),
          Text('收货人：${detail['shop_contacts'] ?? ''}', style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
          Text('联系方式：${detail['shop_mobile'] ?? ''}', style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text('退货地址：$address', style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888), height: 1.4)),
              ),
              InkWell(
                onTap: () => copyText(address),
                child: const Text('复制', style: TextStyle(fontSize: 11.0, color: primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 退款信息
  Widget _buildInfo() {
    final String image = '${detail['sku_image'] ?? ''}';
    final num applyMoney = num.tryParse('${detail['refund_apply_money'] ?? 0}') ?? 0;
    final String images = '${detail['refund_images'] ?? ''}';
    final List<String> imageList = images.isEmpty ? <String>[] : images.split(',').where((String e) => e.isNotEmpty).toList();
    final int goodsId = int.tryParse('${detail['goods_id'] ?? ''}') ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('退款信息', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10.0),
          InkWell(
            onTap: goodsId > 0 ? () => Get.toNamed('/goods', arguments: <String, dynamic>{'goodsId': goodsId}) : null,
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
                  child: Text('${detail['sku_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.0)),
                ),
              ],
            ),
          ),
          if (applyMoney > 0) ...<Widget>[
            const SizedBox(height: 10.0),
            _buildCell('退款方式', '${detail['refund_type'] ?? ''}' == '1' ? '仅退款' : '退款退货'),
            _buildCell('申请原因', '${detail['refund_reason'] ?? ''}'),
            if ('${detail['refund_remark'] ?? ''}'.isNotEmpty) _buildCell('申请说明', '${detail['refund_remark']}'),
            _buildCell('申请金额', '¥${applyMoney.toStringAsFixed(2)}'),
          ],
          if (imageList.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            const Text('退款图片：', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
            const SizedBox(height: 6.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: imageList.map((String url) => ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: CachedNetworkImage(imageUrl: url, width: 60.0, height: 60.0, fit: BoxFit.cover),
                  )).toList(),
            ),
          ],
          if (applyMoney > 0 && refundStatus == '3') ...<Widget>[
            const SizedBox(height: 10.0),
            _buildCell('退款金额', '¥${num.tryParse('${detail['refund_real_money'] ?? 0}') ?? 0} (${detail['refund_money_type_name'] ?? ''})'),
            _buildCell('退款说明', '${detail['shop_refund_remark'] ?? '--'}'),
            _buildCell('退款编号', '${detail['refund_no'] ?? ''}'),
            _buildCell('退款时间', timeText(detail['refund_time'])),
            if ((num.tryParse('${detail['use_point'] ?? 0}') ?? 0) > 0) _buildCell('退款积分', '${detail['use_point']}'),
          ],
          if ('${detail['shop_active_refund'] ?? ''}' == '1') ...<Widget>[
            const SizedBox(height: 10.0),
            _buildCell('主动退款编号', '${detail['shop_active_refund_no'] ?? ''}'),
            _buildCell('主动退款金额', '¥${detail['shop_active_refund_money'] ?? 0} (${detail['shop_active_refund_money_type_name'] ?? ''})'),
            _buildCell('主动退款说明', '${detail['shop_active_refund_remark'] ?? ''}'),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text('$label：$value', style: const TextStyle(fontSize: 12.0, color: Color(0xFF666666), height: 1.5)),
    );
  }

  /// 退货发货表单
  Widget _buildReturnGoods() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(10.0),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildInput('物流公司', '请输入物流公司', nameController),
              _buildInput('物流单号', '请输入物流单号', noController),
              _buildInput('物流说明', '选填', remarkController),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        Padding(
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
              onPressed: submitDelivery,
              child: const Text('提交', style: TextStyle(fontSize: 15.0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13.0)),
          const SizedBox(height: 6.0),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13.0),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  /// 协商记录(refund_log_list)
  Widget _buildRecord() {
    final List<Map<String, dynamic>> logs = RefundApi.logsOf(detail);
    return Column(
      children: <Widget>[
        Expanded(
          child: logs.isEmpty
              ? const Center(child: const CommonEmpty(text: '暂无协商记录'))
              : ListView.separated(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> item = logs[index];
                    final bool buyer = '${item['action_way'] ?? ''}' == '1';
                    return Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(buyer ? '买家' : '卖家', style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(timeText(item['action_time']), style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          Text('${item['action'] ?? ''}', style: const TextStyle(fontSize: 13.0)),
                          if ('${item['desc'] ?? ''}'.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('${item['desc']}', style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888))),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0 + MediaQuery.of(context).padding.bottom),
          color: Colors.white,
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: () => Get.toNamed('/chat'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.headset_mic_outlined, size: 16.0, color: Color(0xFF888888)),
                    SizedBox(width: 4.0),
                    Text('联系客服', style: TextStyle(fontSize: 13.0, color: Color(0xFF888888))),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => action = ''),
                child: const Text('返回详情', style: TextStyle(fontSize: 13.0, color: primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 底部操作(refund_action)
  Widget? _buildActions() {
    final List<Map<String, dynamic>> list = RefundApi.actionsOf(detail);
    if (list.isEmpty) return null;
    return Container(
      padding: EdgeInsets.fromLTRB(10.0, 6.0, 10.0, 6.0 + MediaQuery.of(context).padding.bottom),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: list.map((Map<String, dynamic> item) {
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              height: 32.0,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF666666),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                ),
                onPressed: () => onAction('${item['event'] ?? ''}'),
                child: Text('${item['title'] ?? ''}', style: const TextStyle(fontSize: 13.0)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
