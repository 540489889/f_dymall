/// 售后/退款列表
/// 对齐 H5: pages_tool/order/activist.vue
/// * /api/orderrefund/lists  列表
/// * 每条: order_no / refund_status(3成功,1退款中,-1失败) / sku_image / sku_name /
///         refund_status_name / price / num / order_goods_id / refund_action[]
/// * 列表总退款 = (退款成功?refund_real_money:refund_apply_money) + shop_active_refund_money
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/refund.dart';
import '../../behavior/custom_scroll_behavior.dart';

class RefundList extends StatefulWidget {
  const RefundList({super.key});

  @override
  State<RefundList> createState() => _RefundListState();
}

class _RefundListState extends State<RefundList> {
  static const Color primary = Color(0xFFFF2C55);

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = false;
  bool loaded = false;
  bool hasMore = true;
  int page = 1;
  final int pageSize = 10;
  final ScrollController scrollController = ScrollController();
  String error = '';

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScroll);
    load(refresh: true);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void onScroll() {
    if (scrollController.position.extentAfter < 200 && hasMore && !loading) {
      load();
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (loading) return;
    if (refresh) {
      page = 1;
      hasMore = true;
      error = '';
    }
    if (!hasMore) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> data = await RefundApi.lists(page: page, pageSize: pageSize);
      if (!mounted) return;
      final List<Map<String, dynamic>> newList = RefundApi.listOf(data);
      setState(() {
        if (refresh) {
          list = newList;
        } else {
          list = <Map<String, dynamic>>[...list, ...newList];
        }
        page = page + 1;
        hasMore = newList.length >= pageSize;
        loading = false;
        loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = RefundApi.errorMsg(e, '售后列表加载失败');
        loading = false;
        loaded = true;
      });
    }
  }

  /// 列表总退款金额(对齐 H5 activist.vue 第31行)
  /// (退款成功?refund_real_money:refund_apply_money) + shop_active_refund_money
  String refundMoneyText(Map<String, dynamic> item) {
    final int status = int.tryParse('${item['refund_status'] ?? ''}') ?? 0;
    final num base = num.tryParse(status == 3 ? '${item['refund_real_money']}' : '${item['refund_apply_money']}') ?? 0;
    final num active = num.tryParse('${item['shop_active_refund_money'] ?? 0}') ?? 0;
    return (base + active).toStringAsFixed(2);
  }

  void toDetail(int orderGoodsId, {String action = ''}) {
    Get.toNamed(
      '/order/refund_detail',
      arguments: <String, dynamic>{
        'order_goods_id': orderGoodsId,
        if (action.isNotEmpty) 'action': action,
      },
    )?.then((dynamic value) => load(refresh: true));
  }

  /// 列表操作(对齐 H5 activist.vue refundAction)
  Future<void> onAction(Map<String, dynamic> actionItem, Map<String, dynamic> item) async {
    final String event = '${actionItem['event'] ?? ''}';
    final int orderGoodsId = int.tryParse('${item['order_goods_id'] ?? ''}') ?? 0;
    switch (event) {
      case 'orderRefundCancel': // 撤销维权
        try {
          await RefundApi.cancel(orderGoodsId);
          MyDialog.toast('撤销成功');
          await load(refresh: true);
        } catch (e) {
          MyDialog.toast(RefundApi.errorMsg(e, '撤销失败'));
        }
      case 'orderRefundDelivery': // 退货发货
        toDetail(orderGoodsId, action: 'returngoods');
      case 'orderRefundAsk':
      case 'orderRefundApply': // 去申请退款
        Get.toNamed('/order/refund', arguments: <String, dynamic>{'order_goods_id': orderGoodsId});
    }
  }

  Widget emptyTip() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset('assets/images/common-empty.png', width: 120.0),
          const SizedBox(height: 8.0),
          const Text('还没有售后记录~', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: const Text('售后', style: TextStyle(fontSize: 17.0, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior().copyWith(scrollbars: false),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading && list.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (list.isEmpty) {
      return RefreshIndicator(
        color: primary,
        onRefresh: () => load(refresh: true),
        child: ListView(children: <Widget>[SizedBox(height: 260.0, child: emptyTip())]),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => load(refresh: true),
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(10.0),
        itemCount: list.length + (hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int i) {
          if (i >= list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: Text('加载中...', style: TextStyle(fontSize: 12.0, color: Colors.grey))),
            );
          }
          return _buildItem(list[i]);
        },
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final int orderGoodsId = int.tryParse('${item['order_goods_id'] ?? ''}') ?? 0;
    final String image = '${item['sku_image'] ?? ''}';
    final int status = int.tryParse('${item['refund_status'] ?? ''}') ?? 0;
    final String statusName = '${item['refund_status_name'] ?? ''}';
    final Color statusColor = status == 3 ? const Color(0xFF333333) : primary;
    final List<Map<String, dynamic>> actions = RefundApi.actionsOf(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withAlpha(10), offset: const Offset(0.0, 1.0), blurRadius: 1.0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '订单号：${item['order_no'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888)),
                ),
              ),
              Text(statusName, style: TextStyle(fontSize: 13.0, color: statusColor)),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: image.isEmpty
                    ? Container(width: 70.0, height: 70.0, color: const Color(0xFFF5F5F5))
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 70.0,
                        height: 70.0,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(width: 70.0, height: 70.0, color: const Color(0xFFF5F5F5)),
                      ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${item['sku_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.0)),
                    const SizedBox(height: 6.0),
                    Text(statusName, style: TextStyle(fontSize: 12.0, color: statusColor)),
                    const SizedBox(height: 6.0),
                    Row(
                      children: <Widget>[
                        Text('¥${num.tryParse('${item['price'] ?? 0}') ?? 0}', style: const TextStyle(color: primary, fontSize: 13.0, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('x${item['num'] ?? 1}', style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('共${item['num'] ?? 1}件商品', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
              Text('退款：¥${refundMoneyText(item)}', style: const TextStyle(fontSize: 12.0, color: primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _buildButton('查看详情', false, () => toDetail(orderGoodsId)),
              ...actions.map((Map<String, dynamic> a) => Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _buildButton('${a['title'] ?? ''}', true, () => onAction(a, item)),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, bool filled, VoidCallback onTap) {
    return SizedBox(
      height: 28.0,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? primary : Colors.white,
          foregroundColor: filled ? Colors.white : const Color(0xFF666666),
          side: BorderSide(color: filled ? primary : const Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 12.0)),
      ),
    );
  }
}
