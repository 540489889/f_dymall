/// 积分兑换商品详情
/// 对齐 H5: pages_promotion/point/detail.vue
/// * 详情 /pointexchange/api/goods/detail(id)
/// * 价格: point 积分,pay_type > 0 且 exchange_price != 0 时叠加现金
/// * 兑换: 选数量后跳确认订单页(H5 ns-goods-sku -> exchangeOrderCreateData: { id, sku_id, num })
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_point.dart';
import '../../api/point_exchange.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';

class PointGoodsDetailPage extends StatefulWidget {
  const PointGoodsDetailPage({super.key});

  @override
  State<PointGoodsDetailPage> createState() => _PointGoodsDetailPageState();
}

/// 详情里的规格/属性字段可能是 JSON 字符串,统一解析
List<Map<String, dynamic>> jsonList(dynamic raw) {
  if (raw is List) return raw.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
  if (raw is String && raw.isNotEmpty) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    } catch (_) {}
  }
  return <Map<String, dynamic>>[];
}

class _PointGoodsDetailPageState extends State<PointGoodsDetailPage> {
  static const Color primary = Color(0xFFF16914);

  Map<String, dynamic> detail = <String, dynamic>{};
  bool loading = true;
  String errorMsg = '';
  int memberPoint = 0;
  /// 兑换数量
  int buyNum = 1;
  /// 登录态
  final authStore = AuthStore.to;
  /// 全部 SKU(多规格时由 /pointexchange/api/goods/goodsSku 拉取)
  List<Map<String, dynamic>> skuList = <Map<String, dynamic>>[];
  /// 已选规格: { spec_id: spec_value_id }
  Map<int, int> selectedSpec = <int, int>{};

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    int id = 0;
    if (args is Map) id = int.tryParse('${args['id'] ?? 0}') ?? 0;
    id = id > 0 ? id : int.tryParse('${Get.parameters['id'] ?? 0}') ?? 0;
    if (id <= 0) {
      loading = false;
      errorMsg = '兑换商品不存在';
      return;
    }
    detail = <String, dynamic>{'id': id};
    load(id);
  }

  /* 数据快捷读取 */
  int get id => int.tryParse('${detail['id'] ?? 0}') ?? 0;

  /// 兑换活动 id(H5 ns-goods-sku 里的 exchange_id)
  int get exchangeId => int.tryParse('${detail['exchange_id'] ?? detail['id'] ?? 0}') ?? 0;

  int get type => int.tryParse('${detail['type'] ?? 1}') ?? 1;

  int get point => int.tryParse('${detail['point'] ?? 0}') ?? 0;

  int get payType => int.tryParse('${detail['pay_type'] ?? 0}') ?? 0;

  num get exchangePrice => num.tryParse('${detail['exchange_price'] ?? 0}') ?? 0;

  int get stock => int.tryParse('${detail['stock'] ?? 0}') ?? 0;

  /// 库存是否无限(优惠券 stock = -1)
  bool get unlimited => stock < 0;

  /// 最大可兑数量(H5: min(库存, floor(我的积分 / point)))
  int get maxNum {
    if (point <= 0) return 1;
    final int byPoint = (memberPoint / point).floor();
    if (unlimited) return byPoint > 0 ? byPoint : 1;
    final int byStock = stock;
    final int max = byPoint < byStock ? byPoint : byStock;
    return max > 0 ? max : 1;
  }

  /// 积分不足(H5 enough)
  bool get notEnough => point > memberPoint;

  String get name => type == PointExchangeApi.typeGoods
      ? '${detail['goods_name'] ?? detail['name'] ?? ''}'
      : '${detail['name'] ?? ''}';

  /// 图片: 商品取 sku_image,优惠券/红包取 image(无图时用图标占位)
  String get image {
    final String skuImage = '${detail['sku_image'] ?? ''}'.split(',').first.trim();
    final String raw = type == PointExchangeApi.typeGoods && skuImage.isNotEmpty
        ? skuImage
        : '${detail['image'] ?? ''}';
    return PointExchangeApi.img(raw);
  }

  /// 已选规格(H5 sku_spec_format: JSON字符串)
  List<Map<String, dynamic>> get skuSpec => jsonList(detail['sku_spec_format']);

  /// 商品规格组(H5 goods_spec_format: 多规格时用于切换 SKU)
  List<Map<String, dynamic>> get goodsSpec => jsonList(detail['goods_spec_format']);

  /// 商品属性(H5 goods_attr_format: 按 attr_id 去重,同属性多值用「、」合并)
  List<Map<String, dynamic>> get goodsAttr {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> item in jsonList(detail['goods_attr_format'])) {
      final int index = out.indexWhere((Map<String, dynamic> e) => '${e['attr_id']}' == '${item['attr_id']}');
      if (index >= 0) {
        out[index] = <String, dynamic>{
          ...out[index],
          'attr_value_name': '${out[index]['attr_value_name'] ?? ''}、${item['attr_value_name'] ?? ''}',
        };
      } else {
        out.add(<String, dynamic>{...item});
      }
    }
    return out;
  }

  /// 详情加载(商品详情 + 我的积分)
  Future<void> load(int id) async {
    try {
      final Map<String, dynamic> res = await PointExchangeApi.goodsDetail(id);
      if (!mounted) return;
      if (res.isEmpty) {
        setState(() {
          loading = false;
          errorMsg = '兑换商品不存在';
        });
        return;
      }
      setState(() {
        detail = res;
        loading = false;
        selectedSpec = <int, int>{
          for (final Map<String, dynamic> e in skuSpec)
            int.tryParse('${e['spec_id'] ?? 0}') ?? 0: int.tryParse('${e['spec_value_id'] ?? 0}') ?? 0,
        };
      });
      await loadPoint();
      await loadSkuList();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = PointExchangeApi.errorMsg(e, '详情加载失败');
        loading = false;
      });
    }
  }

  /// 我的积分(用于判断积分是否足够与最大可兑数量)
  Future<void> loadPoint() async {
    try {
      final Map<String, dynamic> res = await MemberPointApi.point();
      if (!mounted) return;
      setState(() => memberPoint = int.tryParse('${res['point'] ?? 0}') ?? 0);
    } catch (_) {}
  }

  /// 多规格商品拉取 SKU 列表(H5 ns-goods-sku getPointGoodsSkuList)
  Future<void> loadSkuList() async {
    if (type != PointExchangeApi.typeGoods || goodsSpec.isEmpty) return;
    final int goodsId = int.tryParse('${detail['goods_id'] ?? 0}') ?? 0;
    if (goodsId <= 0) return;
    try {
      final List<Map<String, dynamic>> res = await PointExchangeApi.goodsSku(
        goodsId: goodsId,
        exchangeId: exchangeId,
        type: type,
      );
      if (!mounted || res.isEmpty) return;
      setState(() => skuList = res);
      // 未带出当前规格时,默认取第一个 SKU(H5 同样取 res.data[0])
      if (selectedSpec.isEmpty) {
        for (final Map<String, dynamic> e in jsonList(res.first['sku_spec_format'])) {
          selectedSpec[int.tryParse('${e['spec_id'] ?? 0}') ?? 0] = int.tryParse('${e['spec_value_id'] ?? 0}') ?? 0;
        }
      }
      applySelectedSku();
    } catch (_) {}
  }

  /// 按已选规格值匹配 SKU,命中后整体覆盖详情(H5 Object.assign(pointInfo, sku))
  void applySelectedSku() {
    final Set<int> values = selectedSpec.values.where((int v) => v > 0).toSet();
    if (values.isEmpty || skuList.isEmpty) return;
    for (final Map<String, dynamic> sku in skuList) {
      final Set<int> ids = jsonList(sku['sku_spec_format'])
          .map((Map<String, dynamic> e) => int.tryParse('${e['spec_value_id'] ?? 0}') ?? 0)
          .where((int v) => v > 0)
          .toSet();
      if (ids.length == values.length && values.difference(ids).isEmpty) {
        final Map<String, dynamic> next = <String, dynamic>{...detail, ...sku};
        // 切换 SKU 后纠正数量(H5 keyInput)
        if (buyNum > maxNum) buyNum = maxNum < 1 ? 1 : maxNum;
        if (mounted) {
          setState(() => detail = next);
        } else {
          detail = next;
        }
        return;
      }
    }
  }

  /// 优惠券 / 红包说明(H5 coupon-desc)
  String get couponDesc {
    final List<String> parts = <String>[];
    final num balance = num.tryParse('${detail['balance'] ?? 0}') ?? 0;
    if (balance > 0) parts.add('内含${balance.toStringAsFixed(0)}元');
    final String couponType = '${detail['coupon_type'] ?? ''}';
    final num atLeast = num.tryParse('${detail['at_least'] ?? 0}') ?? 0;
    switch (couponType) {
      case 'random':
        parts.add('无门槛优惠券');
        break;
      case 'reward':
        parts.add('满${atLeast.toStringAsFixed(0)}减${num.tryParse('${detail['money'] ?? 0}') ?? 0}');
        break;
      case 'discount':
        parts.add('满${atLeast.toStringAsFixed(0)}元 ${detail['discount']}折 最多优惠${detail['discount_limit']}元');
        break;
    }
    return parts.join(' · ');
  }

  /// 兑换(未登录先登录 / 库存不足 / 积分不足 均拦截)
  void exchange() {
    if (!authStore.isLogin) {
      Get.toNamed('/login');
      return;
    }
    if (!unlimited && stock <= 0) {
      MyDialog.toast('库存不足');
      return;
    }
    if (notEnough) {
      MyDialog.toast('积分不足');
      return;
    }
    openSkuSheet();
  }

  /// 数量选择弹层
  Future<void> openSkuSheet() async {
    buyNum = 1;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final int max = maxNum;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(15.0, 16.0, 15.0, 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
                                  child: const Icon(Icons.card_giftcard_outlined, color: Colors.grey, size: 26.0),
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
                                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24.0),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '$point 积分${exchangePrice > 0 && payType > 0 ? ' + ¥${exchangePrice.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(color: primary, fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                unlimited ? '库存充足' : '库存 $stock',
                                style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    if (goodsSpec.isNotEmpty) _buildSpecGroups(setSheetState),
                    Row(
                      children: <Widget>[
                        const Text('兑换数量', style: TextStyle(fontSize: 14.0)),
                        const Spacer(),
                        _buildStepper(setSheetState, max),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(primary),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                        ),
                        onPressed: () {
                          Get.back();
                          Get.toNamed('/point/confirm', arguments: <String, dynamic>{
                            'id': exchangeId,
                            'sku_id': int.tryParse('${detail['sku_id'] ?? 0}') ?? 0,
                            'num': buyNum,
                          });
                        },
                        child: const Text('确定', style: TextStyle(fontSize: 15.0)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 规格选择(H5 sku-list-wrap: 按规格组渲染,选中后切换 SKU)
  Widget _buildSpecGroups(StateSetter setSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: goodsSpec.map((Map<String, dynamic> group) {
        final int specId = int.tryParse('${group['spec_id'] ?? 0}') ?? 0;
        final List<Map<String, dynamic>> values = jsonList(group['value']);
        if (values.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${group['spec_name'] ?? ''}', style: const TextStyle(fontSize: 14.0)),
              const SizedBox(height: 10.0),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: values.map((Map<String, dynamic> value) {
                  final int valueId = int.tryParse('${value['spec_value_id'] ?? 0}') ?? 0;
                  final bool selected = selectedSpec[specId] == valueId;
                  return InkWell(
                    onTap: () {
                      selectedSpec[specId] = valueId;
                      applySelectedSku();
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: selected ? primary.withValues(alpha: 0.08) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: selected ? primary : Colors.transparent),
                      ),
                      child: Text(
                        '${value['spec_value_name'] ?? ''}',
                        style: TextStyle(fontSize: 13.0, color: selected ? primary : const Color(0xFF333333)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 数量步进器
  Widget _buildStepper(StateSetter setSheetState, int max) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _stepBtn(Icons.remove, buyNum > 1 ? () => setSheetState(() => buyNum -= 1) : null),
        Container(
          width: 44.0,
          alignment: Alignment.center,
          child: Text('$buyNum', style: const TextStyle(fontSize: 14.0, fontFamily: 'Arial')),
        ),
        _stepBtn(Icons.add, buyNum < max ? () => setSheetState(() => buyNum += 1) : null),
        const SizedBox(width: 8.0),
        Text('最多$max', style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999))),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 26.0,
        height: 26.0,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4.0),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14.0, color: onTap == null ? const Color(0xFFCCCCCC) : const Color(0xFF333333)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('兑换详情', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: loading || detail.isEmpty ? null : _buildBottom(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
            const SizedBox(height: 12.0),
            OutlinedButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(primary),
                side: WidgetStateProperty.all(const BorderSide(color: primary)),
              ),
              onPressed: () => load(id),
              child: const Text('重新加载', style: TextStyle(fontSize: 14.0)),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20.0),
      children: <Widget>[
        _buildImage(),
        _buildInfo(),
        if (type == PointExchangeApi.typeGoods && (skuSpec.isNotEmpty || goodsSpec.isNotEmpty || goodsAttr.isNotEmpty)) ...<Widget>[
          const SizedBox(height: 10.0),
          _buildSpec(),
        ],
        const SizedBox(height: 10.0),
        _buildContent(),
      ],
    );
  }

  /// 顶部图
  Widget _buildImage() {
    return Container(
      width: double.infinity,
      height: 300.0,
      color: Colors.white,
      child: image.isEmpty
          ? Icon(
              type == PointExchangeApi.typeCoupon ? Icons.confirmation_num_outlined : Icons.card_giftcard_outlined,
              color: Colors.grey.shade300,
              size: 80.0,
            )
          : CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.contain,
              placeholder: (BuildContext context, String url) => Container(color: Colors.grey[50]),
              errorWidget: (BuildContext context, String url, Object error) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 50.0),
            ),
    );
  }

  /// 价格 / 名称 / 库存
  Widget _buildInfo() {
    final num marketPrice = num.tryParse('${detail['price'] ?? 0}') ?? 0;
    final int saleNum = int.tryParse('${detail['sale_num'] ?? 0}') ?? 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$point',
                style: const TextStyle(color: primary, fontSize: 24.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
              ),
              const SizedBox(width: 3.0),
              const Text('积分', style: TextStyle(color: primary, fontSize: 13.0)),
              if (exchangePrice > 0 && payType > 0) ...<Widget>[
                const SizedBox(width: 6.0),
                Text(
                  '+ ¥${exchangePrice.toStringAsFixed(2)}',
                  style: const TextStyle(color: primary, fontSize: 15.0, fontWeight: FontWeight.w600),
                ),
              ],
              if (marketPrice > 0) ...<Widget>[
                const SizedBox(width: 8.0),
                Text(
                  '¥${marketPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12.0,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8.0),
          Text(name, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
          if (couponDesc.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6.0),
            Text(couponDesc, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ],
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              Text(unlimited ? '库存:无限' : '库存:$stock', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              const SizedBox(width: 14.0),
              Text('已兑:$saleNum', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              const Spacer(),
              Text('我的积分:$memberPoint', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
            ],
          ),
        ],
      ),
    );
  }

  /// 选择 / 属性(H5 newdetail: selected-sku-spec + goods-attribute,仅 type=1 显示)
  Widget _buildSpec() {
    final String specText = skuSpec
        .map((Map<String, dynamic> e) => '${e['spec_name'] ?? ''}/${e['spec_value_name'] ?? ''}')
        .join('  ');
    final List<Map<String, dynamic>> attrs = goodsAttr;
    final String attrText = attrs
        .take(2)
        .map((Map<String, dynamic> e) => '${e['attr_name'] ?? ''}: ${e['attr_value_name'] ?? ''}')
        .join('  ');
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (skuSpec.isNotEmpty || goodsSpec.isNotEmpty)
            InkWell(
              onTap: exchange,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 13.0, 15.0, 13.0),
                child: Row(
                  children: <Widget>[
                    const Text('选择', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Text(
                        specText.isEmpty ? '请选择规格' : specText,
                        style: const TextStyle(fontSize: 13.0),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                  ],
                ),
              ),
            ),
          if (attrs.isNotEmpty) ...<Widget>[
            const Divider(color: Color(0xFFEEEEEE), height: 1.0, thickness: 0.5, indent: 15.0),
            InkWell(
              onTap: () => openAttrSheet(attrs),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 13.0, 15.0, 13.0),
                child: Row(
                  children: <Widget>[
                    const Text('属性', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Text(
                        attrText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.0),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 商品属性弹层(H5 goods-attribute-popup-layer)
  Future<void> openAttrSheet(List<Map<String, dynamic>> attrs) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    const Text('商品属性', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18.0, color: Color(0xFF999999)),
                        onPressed: () => Get.back(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFEEEEEE), height: 1.0, thickness: 0.5),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
                  itemCount: attrs.length,
                  separatorBuilder: (BuildContext context, int index) => const Divider(color: Color(0xFFF5F5F5), height: 1.0),
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> item = attrs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 90.0,
                            child: Text(
                              '${item['attr_name'] ?? ''}',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item['attr_value_name'] ?? ''}',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(primary),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                    ),
                    onPressed: () => Get.back(),
                    child: const Text('确定', style: TextStyle(fontSize: 15.0)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 兑换详情(富文本)
  Widget _buildContent() {
    final String content = '${detail['content'] ?? ''}';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('兑换详情', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
          const Divider(color: FStyle.dividerColor, height: 20.0, thickness: 0.5),
          content.isEmpty
              ? const CommonEmpty(text: '暂无兑换详情！')
              : Html(data: content, shrinkWrap: true),
        ],
      ),
    );
  }

  /// 底部兑换按钮
  Widget _buildBottom() {
    final String text = !authStore.isLogin
        ? '登录之后方可兑换'
        : (!unlimited && stock <= 0)
            ? '库存不足'
            : notEnough
                ? '积分不足'
                : '兑换';
    final bool disabled = !authStore.isLogin || (!unlimited && stock <= 0) || notEnough;
    return Container(
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(disabled ? const Color(0xFFCCCCCC) : primary),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0))),
          ),
          onPressed: exchange,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(text, style: const TextStyle(fontSize: 16.0)),
          ),
        ),
      ),
    );
  }
}
