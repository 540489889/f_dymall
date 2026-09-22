/// 充值记录
/// 对齐 H5: pages_tool/recharge/order_list.vue
/// * /memberrecharge/api/order/page 充值订单列表
library;

import 'package:flutter/material.dart';

import '../../api/member_recharge.dart';
import '../../utils/index.dart';

class RechargeOrderPage extends StatefulWidget {
  const RechargeOrderPage({super.key});

  @override
  State<RechargeOrderPage> createState() => _RechargeOrderPageState();
}

class _RechargeOrderPageState extends State<RechargeOrderPage> {
  static const Color primary = Color(0xFFFF2C55);
  static const int pageSize = 20;

  final ScrollController controller = ScrollController();

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
      final List<Map<String, dynamic>> data = await MemberRechargeApi.orderPage(page: page, pageSize: pageSize);
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
        errorMsg = MemberRechargeApi.errorMsg(e, '加载失败');
        loading = false;
        loadingMore = false;
      });
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
        title: const Text('充值记录', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
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
            Icon(Icons.receipt_long_outlined, size: 56.0, color: Colors.grey.shade300),
            const SizedBox(height: 12.0),
            Text(
              errorMsg.isEmpty ? '暂无充值记录' : errorMsg,
              style: const TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => loadList(refresh: true),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(top: 10.0),
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length) return _buildFooter();
          return _buildItem(list[index]);
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

  /// 记录项(H5 order-item: 单号 + 时间 / 充值成功 + 金额 + 赠送)
  Widget _buildItem(Map<String, dynamic> item) {
    final num price = num.tryParse('${item['buy_price'] ?? 0}') ?? 0;
    final String orderNo = '${item['order_no'] ?? ''}';
    final String time = Utils.timeStampTurnTime(item['create_time']);
    final String gift = giftText(item);
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1.0),
      padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(orderNo, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              ),
              Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('充值成功', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500)),
                    if (gift.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6.0),
                      Text(gift, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                    ],
                  ],
                ),
              ),
              Text(
                '¥${price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: primary, fontFamily: 'Arial'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 赠送文案
  String giftText(Map<String, dynamic> item) {
    final List<String> gifts = <String>[];
    final num point = num.tryParse('${item['point'] ?? 0}') ?? 0;
    final num growth = num.tryParse('${item['growth'] ?? 0}') ?? 0;
    final String coupon = '${item['coupon_id'] ?? ''}';
    if (point > 0) gifts.add('$point 积分');
    if (growth > 0) gifts.add('$growth 成长值');
    if (coupon.isNotEmpty && coupon != '0') gifts.add('优惠券 X${coupon.split(',').length}');
    if (gifts.isEmpty) return '';
    return '赠送：${gifts.join('、')}';
  }
}
