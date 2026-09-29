/// 物流详情
/// 对齐 H5: pages_tool/order/logistics.vue
/// * 入参 order_id(Get.arguments: { order_id: 1 })
/// * /api/order/package 包裹列表 + 物流轨迹(trace)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';

class OrderLogistics extends StatefulWidget {
  const OrderLogistics({super.key});

  @override
  State<OrderLogistics> createState() => _OrderLogisticsState();
}

class _OrderLogisticsState extends State<OrderLogistics> {
  static const Color primary = Color(0xFFFF2C55);

  int orderId = 0;
  List<Map<String, dynamic>> packageList = <Map<String, dynamic>>[];
  int currIndex = 0;
  bool loading = true;
  String errorMsg = '';

  Map<String, dynamic> get current =>
      packageList.isEmpty ? <String, dynamic>{} : packageList[currIndex];

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) orderId = int.tryParse('${args['order_id'] ?? args['orderId'] ?? ''}') ?? 0;
    load();
  }

  /// 包裹信息(/api/order/package)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<Map<String, dynamic>> data = await OrderApi.packageList(orderId);
      if (!mounted) return;
      setState(() {
        packageList = data;
        if (currIndex >= data.length) currIndex = 0;
        loading = false;
      });
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

  Future<void> copyText(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    MyDialog.toast('已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('物流详情', style: TextStyle(fontSize: 17.0)),
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
    return Column(
      children: <Widget>[
        if (packageList.length > 1) _buildTabs(),
        Expanded(
          child: RefreshIndicator(
            color: primary,
            onRefresh: load,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10.0),
              children: <Widget>[
                _buildGoods(),
                _buildExpress(),
                _buildTrack(),
                const SizedBox(height: 10.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 多包裹切换(H5 order-nav)
  Widget _buildTabs() {
    return Container(
      height: 44.0,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: packageList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20.0),
        itemBuilder: (BuildContext context, int index) {
          final bool active = index == currIndex;
          return Center(
            child: InkWell(
              onTap: () => setState(() => currIndex = index),
              child: Container(
                padding: const EdgeInsets.only(bottom: 6.0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: active ? primary : Colors.transparent, width: 2.0)),
                ),
                child: Text(
                  '${packageList[index]['package_name'] ?? ''}',
                  style: TextStyle(fontSize: 14.0, color: active ? primary : Colors.black87, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 包裹商品
  Widget _buildGoods() {
    final List<Map<String, dynamic>> goods = OrderApi.goodsListOf(current);
    return _card(
      child: Column(
        children: goods.map((Map<String, dynamic> item) {
          final String image = '${item['sku_image'] ?? ''}';
          final int goodsId = int.tryParse('${item['goods_id'] ?? item['sku_id'] ?? ''}') ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${item['sku_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.0)),
                        const SizedBox(height: 4.0),
                        Text('x${item['num'] ?? 1}', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                      ],
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

  /// 快递公司 + 运单号(H5: delivery_type == 1 展示)
  Widget _buildExpress() {
    if ('${current['delivery_type'] ?? ''}' != '1') return const SizedBox.shrink();
    final String logo = '${current['express_company_image'] ?? ''}';
    return _card(
      child: Row(
        children: <Widget>[
          if (logo.isNotEmpty) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: CachedNetworkImage(imageUrl: logo, width: 40.0, height: 40.0, fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox(width: 40.0, height: 40.0)),
            ),
            const SizedBox(width: 10.0),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('承运公司：${current['express_company_name'] ?? ''}', style: const TextStyle(fontSize: 13.0)),
                const SizedBox(height: 4.0),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text('运单号：${current['delivery_no'] ?? ''}', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                    ),
                    const SizedBox(width: 6.0),
                    InkWell(
                      onTap: () => copyText('${current['delivery_no'] ?? ''}'),
                      child: const Text('复制', style: TextStyle(fontSize: 11.0, color: primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 物流轨迹(H5 track-wrap)
  Widget _buildTrack() {
    if ('${current['delivery_type'] ?? ''}' != '1') return const SizedBox.shrink();
    final dynamic raw = current['trace'];
    final Map<String, dynamic> trace = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    final bool success = trace['success'] == true || '${trace['success'] ?? ''}' == 'true' || '${trace['success'] ?? ''}' == '1';
    final List<Map<String, dynamic>> list = trace['list'] is List
        ? (trace['list'] as List).whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    if (!success || list.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Center(
            child: CommonEmpty(text: '${trace['reason'] ?? '暂无物流信息'}'),
          ),
        ),
      );
    }
    return _card(
      child: Column(
        children: list.asMap().entries.map((MapEntry<int, Map<String, dynamic>> entry) {
          final bool active = entry.key == 0;
          final Map<String, dynamic> item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const SizedBox(height: 4.0),
                    Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: active ? primary : const Color(0xFFDDDDDD),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${item['remark'] ?? ''}',
                        style: TextStyle(fontSize: 13.0, color: active ? primary : Colors.black87, height: 1.4)),
                      const SizedBox(height: 4.0),
                      Text('${item['datetime'] ?? ''}',
                        style: TextStyle(fontSize: 11.0, color: active ? primary : Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: child,
    );
  }
}
