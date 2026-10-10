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

  /// 后台配送配置: 商品详情 detail.express_type,结构形如
  /// { express: { name: 快递发货, ... }, store: { name: 门店自提, ... } }
  /// * 注意: 这里没有 title 字段(那是结算页 express_type 列表项的结构),
  ///   之前按 title 判断导致恒为 false,"当前配送"一直标在"快递发货"上,与结算页不一致
  final Map<String, dynamic>? expressType;

  Map<String, dynamic>? cfg(String key) {
    final dynamic value = expressType?[key];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  /// 后台是否支持该项
  bool get supportExpress => cfg('express') != null;
  bool get supportStore => cfg('store') != null;

  /// 展示哪些项: 只展示后台支持的; 后台无数据(或结构异常)时两项都展示,避免弹窗空白
  bool get showExpress => supportExpress || !supportStore;
  bool get showStore => supportStore || !supportExpress;

  /// "当前配送"只在只支持一种时才标: 多种时结算页可切换,标死会和结算页对不上
  bool get expressActive => supportExpress && !supportStore;
  bool get storeActive => supportStore && !supportExpress;

  /// 标题优先用后台返回的 name,和详情页"配送"那一行的文案保持一致
  String get expressTitle => '${cfg('express')?['name'] ?? '快递发货'}';
  String get storeTitle => '${cfg('store')?['name'] ?? '门店自提'}';

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
                    if (showExpress)
                      _buildItem(
                        title: expressTitle,
                        desc: '支持快递发货的商品在购买后将会通过快递的方式进行配送，可在订单中查看物流信息',
                        active: expressActive,
                      ),
                    if (showExpress && showStore) const SizedBox(height: 24.0),
                    if (showStore)
                      _buildItem(
                        title: storeTitle,
                        desc: '支持门店自提的商品在购买后用户可自行到下单时所选择的自提点进行提货',
                        active: storeActive,
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
