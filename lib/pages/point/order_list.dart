/// 积分兑换订单列表
/// 对齐 H5: pages_promotion/point/order_list.vue
/// * 列表 /pointexchange/api/order/page(order_status: all / 0 待支付 / 1 已完成)
/// * 关闭 /pointexchange/api/order/close;待支付且含现金时可继续支付(PopupPay)
/// * 详情: 兑换的是实物商品且已生成关联订单时跳普通订单详情
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/point_exchange.dart';
import '../../components/popup_pay.dart';
import '../../styles/index.dart';

class PointOrderListPage extends StatefulWidget {
  const PointOrderListPage({super.key});

  @override
  State<PointOrderListPage> createState() => _PointOrderListPageState();
}

class _PointOrderListPageState extends State<PointOrderListPage> {
  static const Color primary = Color(0xFFF16914);
  static const int pageSize = 10;

  final ScrollController controller = ScrollController();

  /// 状态 tab(H5 statusList)
  final List<Map<String, dynamic>> tabs = <Map<String, dynamic>>[
    <String, dynamic>{'status': 'all', 'name': '全部'},
    <String, dynamic>{'status': '0', 'name': '待支付'},
    <String, dynamic>{'status': '1', 'name': '已完成'},
  ];
  String orderStatus = 'all';

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String errorMsg = '';
  int page = 1;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
    loadList(refresh: true);
  }

  @override
  void dispose() {
    controller.removeListener(_onScroll);
    controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!controller.hasClients) return;
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) loadMore();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    page += 1;
    await loadList();
  }

  Future<void> loadList({bool refresh = false}) async {
    if (refresh) {
      page = 1;
      hasMore = true;
      setState(() {
        loading = true;
        errorMsg = '';
      });
    }
    try {
      final List<Map<String, dynamic>> data = await PointExchangeApi.orderPage(
        page: page,
        pageSize: pageSize,
        orderStatus: orderStatus,
      );
      if (!mounted) return;
      setState(() {
        list = refresh ? data : <Map<String, dynamic>>[...list, ...data];
        hasMore = data.length >= pageSize;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = PointExchangeApi.errorMsg(e, '订单加载失败');
        loading = false;
        loadingMore = false;
      });
    }
  }

  /// 切换状态
  void switchTab(String status) {
    if (status == orderStatus) return;
    setState(() => orderStatus = status);
    loadList(refresh: true);
  }

  /// 状态文案(H5: 0 待支付 / 1 已完成 / -1 已关闭)
  String statusName(dynamic status) {
    switch ('$status') {
      case '0':
        return '待支付';
      case '1':
        return '已完成';
      case '-1':
        return '已关闭';
      default:
        return '';
    }
  }

  /// 关闭兑换
  Future<void> closeOrder(int orderId, int index) async {
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
      setState(() => list[index]['order_status'] = -1);
      MyDialog.toast('关闭成功');
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(PointExchangeApi.errorMsg(e, '关闭失败'));
    }
  }

  /// 继续支付(待支付且存在现金部分)
  void openPay(String outTradeNo, num money) {
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
            loadList(refresh: true);
          },
        );
      },
    );
  }

  /// 详情: 实物商品且已生成关联订单 -> 普通订单详情
  void openDetail(Map<String, dynamic> item) {
    final int type = int.tryParse('${item['type'] ?? 0}') ?? 0;
    final int relateOrderId = int.tryParse('${item['relate_order_id'] ?? 0}') ?? 0;
    if (type == PointExchangeApi.typeGoods && relateOrderId > 0) {
      Get.toNamed('/order/detail', arguments: <String, dynamic>{'order_id': relateOrderId});
      return;
    }
    MyDialog.toast('该兑换暂无订单详情');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('兑换订单', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.toNamed('/point/shop'),
            child: const Text('去逛逛', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      height: 44.0,
      child: Row(
        children: tabs.map((Map<String, dynamic> item) {
          final bool selected = '${item['status']}' == orderStatus;
          return Expanded(
            child: InkWell(
              onTap: () => switchTab('${item['status']}'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${item['name']}',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: selected ? primary : const Color(0xFF666666),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Container(
                    width: 18.0,
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.0),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/common-empty.png', width: 120.0),
            const SizedBox(height: 12.0),
            Text(errorMsg.isEmpty ? '暂无积分兑换订单' : errorMsg,
                style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => loadList(refresh: true),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(top: 10.0, bottom: 12.0),
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length) return _buildFooter();
          return _buildOrder(list[index], index);
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: loadingMore
            ? const SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
              )
            : Text(hasMore ? '' : '没有更多了', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
      ),
    );
  }

  /// 订单项(H5 order-item: 订单号 / 状态 / 商品 / 积分(+现金) / 操作)
  Widget _buildOrder(Map<String, dynamic> item, int index) {
    final int status = int.tryParse('${item['order_status'] ?? 0}') ?? 0;
    final int type = int.tryParse('${item['type'] ?? 0}') ?? 0;
    final int point = int.tryParse('${item['point'] ?? 0}') ?? 0;
    final num price = num.tryParse('${item['price'] ?? 0}') ?? 0;
    final String image = PointExchangeApi.img(item['exchange_image']);
    final String outTradeNo = '${item['out_trade_no'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: () => openDetail(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('订单号：${item['order_no'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                    ),
                    Text(
                      statusName('$status'),
                      style: TextStyle(
                        fontSize: 13.0,
                        color: status == 0 ? primary : const Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Divider(color: FStyle.dividerColor, height: 16.0, thickness: 0.5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: image.isEmpty
                          ? Container(
                              width: 64.0,
                              height: 64.0,
                              color: const Color(0xFFF5F5F5),
                              alignment: Alignment.center,
                              child: Icon(
                                type == PointExchangeApi.typeCoupon
                                    ? Icons.confirmation_num_outlined
                                    : Icons.card_giftcard_outlined,
                                color: Colors.grey,
                                size: 24.0,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: image,
                              width: 64.0,
                              height: 64.0,
                              fit: BoxFit.cover,
                              errorWidget: (BuildContext context, String url, Object error) => Container(
                                width: 64.0,
                                height: 64.0,
                                color: const Color(0xFFF5F5F5),
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 22.0),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('${item['exchange_name'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14.0, color: Color(0xFF222222))),
                          const SizedBox(height: 8.0),
                          Row(
                            children: <Widget>[
                              Text('$point',
                                  style: const TextStyle(
                                      color: primary, fontSize: 15.0, fontWeight: FontWeight.bold, fontFamily: 'Arial')),
                              const Text(' 积分', style: TextStyle(color: primary, fontSize: 11.0)),
                              if (price > 0) ...<Widget>[
                                const SizedBox(width: 4.0),
                                Text('+ ¥${price.toStringAsFixed(2)}',
                                    style: const TextStyle(color: primary, fontSize: 12.0)),
                              ],
                              const Spacer(),
                              Text('x${item['num'] ?? 1}', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: FStyle.dividerColor, height: 16.0, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (status == 0 && type == PointExchangeApi.typeGoods) ...<Widget>[
                      _actionBtn('关闭', false, () => closeOrder(int.tryParse('${item['order_id'] ?? 0}') ?? 0, index)),
                      const SizedBox(width: 8.0),
                      if (price > 0 && outTradeNo.isNotEmpty)
                        _actionBtn('支付', true, () => openPay(outTradeNo, price)),
                    ] else
                      _actionBtn('查看详情', false, () => openDetail(item)),
                  ],
                ),
              ],
            ),
          ),
        ),
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
