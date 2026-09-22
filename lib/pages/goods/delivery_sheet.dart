/// 配送方式说明弹窗(商品详情"配送"入口)
library;

import 'package:flutter/material.dart';

import '../../behavior/custom_scroll_behavior.dart';
import '../../styles/index.dart';

/// 打开配送说明弹窗
Future<void> showDeliverySheet(BuildContext context, {Map<String, dynamic>? expressType}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => DeliverySheet(expressType: expressType),
  );
}

class DeliverySheet extends StatelessWidget {
  const DeliverySheet({ super.key, this.expressType });

  final Map<String, dynamic>? expressType;

  /// 判断当前是否是某一项(用后端 express_type.title 粗略匹配)
  bool get isExpress => '${expressType?['title'] ?? ''}'.contains('物流') || '${expressType?['title'] ?? ''}'.contains('快递');
  bool get isPickup => '${expressType?['title'] ?? ''}'.contains('自提');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            FStyle.divider,
            Expanded(
              child: ScrollConfiguration(
                behavior: CustomScrollBehavior(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
                  children: <Widget>[
                    _buildItem(
                      title: '快递发货',
                      desc: '支持快递发货的商品在购买后将会通过快递的方式进行配送，可在订单中查看物流信息',
                      active: !isPickup,
                    ),
                    const SizedBox(height: 24.0),
                    _buildItem(
                      title: '门店自提',
                      desc: '支持门店自提的商品在购买后用户可自行到下单时所选择的自提点进行提货',
                      active: isPickup,
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

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 48.0,
      child: Stack(
        children: <Widget>[
          const Center(child: Text('配送', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600))),
          Positioned(
            right: 5.0,
            top: 0.0,
            bottom: 0.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.close, size: 20.0, color: Colors.black45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({required String title, required String desc, required bool active}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: <Widget>[
        Row(
          spacing: 8.0,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700, color: Colors.black87)),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(color: const Color(0xFFFFF2F2), borderRadius: BorderRadius.circular(10.0)),
                child: const Text('当前配送', style: TextStyle(fontSize: 10.0, color: Color(0xFFFF2C55), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        Text(desc, style: const TextStyle(fontSize: 13.0, color: Colors.black54, height: 1.6)),
      ],
    );
  }
}
