/// 购物车
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/cart.dart';
import '../../api/coupon.dart';
import '../../api/goods.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';
import '../../styles/index.dart';

/// 购物车条目
class CartItem {
  CartItem.fromJson(Map<String, dynamic> json)
      : cartId = _toInt(json['cart_id']),
        skuId = _toInt(json['sku_id']),
        goodsId = _toInt(json['goods_id']),
        buyNum = _toInt(json['num']),
        price = _toNum(json['price']),
        discountPrice = _toNum(json['discount_price']),
        memberPrice = _toNum(json['member_price']),
        stock = _toNum(json['stock']).toInt(),
        maxBuy = _toNum(json['max_buy']).toInt(),
        minBuy = _toNum(json['min_buy']).toInt(),
        isLimit = _toInt(json['is_limit']) == 1,
        // 接口不返回 goods_state/store_goods_status 时不参与失效判定
        goodsState = json.containsKey('goods_state') ? _toInt(json['goods_state']) : null,
        storeGoodsStatus =
            json.containsKey('store_goods_status') ? _toInt(json['store_goods_status']) : null,
        goodsName = '${json['goods_name'] ?? ''}',
        skuName = '${json['sku_name'] ?? ''}' {
    image = '${json['sku_image'] ?? ''}';
    specText = _parseSpec(json['sku_spec_format']);
  }

  final int cartId;
  final int skuId;
  final int goodsId;
  final num price;
  final num discountPrice;
  final num memberPrice;
  final int stock;
  final int maxBuy;
  final int minBuy;
  final bool isLimit;
  final int? goodsState;
  final int? storeGoodsStatus;
  final String goodsName;
  final String skuName;
  // 购买数量(可本地变更)
  int buyNum;
  // 商品图/规格: 接口未返回时由 /api/goodssku/detail 补充
  String image = '';
  String specText = '';

  /// 单价: 会员价优先(大于0且低于折扣价),其次折扣价,最后原价(与 H5 一致)
  num get unitPrice {
    if (memberPrice > 0 && memberPrice < discountPrice) return memberPrice;
    return discountPrice > 0 ? discountPrice : price;
  }

  /// 是否失效: 下架/无库存/最小购买数超库存(与 H5 一致)
  bool get invalid =>
      (goodsState != null && goodsState != 1) ||
      (storeGoodsStatus != null && storeGoodsStatus != 1) ||
      stock <= 0 ||
      (minBuy > 0 && minBuy > stock);

  /// 可买下限
  int get minNum => minBuy > 0 ? minBuy : 1;

  /// 可买上限: 库存优先,开启限购时取限购值(与 H5 一致)
  int get maxNum {
    int max = stock > 0 ? stock : 1;
    if (isLimit && maxBuy > 0 && maxBuy < max) max = maxBuy;
    return max < 1 ? 1 : max;
  }

  /// 小计
  num get totalMoney => unitPrice * buyNum;

  static int _toInt(dynamic value) => _toNum(value).toInt();

  static num _toNum(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return 0;
    return num.tryParse('$value') ?? 0;
  }

  /// 规格文本: sku_spec_format 可能是 JSON 字符串或数组
  static String _parseSpec(dynamic value) {
    dynamic data = value;
    if (data is String) {
      if (data.trim().isEmpty) return '';
      try {
        data = jsonDecode(data);
      } catch (_) {
        return '';
      }
    }
    if (data is! List) return '';
    final List<String> names = data
        .whereType<Map>()
        .map((Map e) => '${e['spec_name'] ?? ''}:${e['spec_value_name'] ?? ''}')
        .where((String e) => e.trim().isNotEmpty && e != ':')
        .toList();
    return names.join('; ');
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // 主色
  static const Color primary = Color(0xFFFF2C55);
  // 加载中
  bool loading = true;
  // 错误信息(非空表示加载失败)
  String errorMsg = '';
  // 购物车列表
  List<CartItem> items = <CartItem>[];
  // 失效商品(下架/无库存/低于最小购买数)
  List<CartItem> invalidItems = <CartItem>[];
  // 已选中的购物车id
  final Set<int> selectedIds = <int>{};
  // 编辑模式(管理/删除)
  bool editing = false;
  // 后台金额计算结果(/api/cartcalculate/calculate)
  Map<String, dynamic> calcData = <String, dynamic>{};
  // 商品补充信息缓存: skuId -> {image, specText}
  final Map<int, Map<String, dynamic>> goodsCache = <int, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  /// 加载购物车列表
  Future<void> loadCart() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<Map<String, dynamic>> list = await CartApi.lists();
      if (!mounted) return;
      // 拆分有效/失效商品
      final List<CartItem> valid = list.map(CartItem.fromJson).where((CartItem e) => !e.invalid).toList();
      final List<CartItem> invalid = list.map(CartItem.fromJson).where((CartItem e) => e.invalid).toList();
      setState(() {
        items = valid;
        invalidItems = invalid;
        // 与 H5 一致: 加载后默认全选有效商品
        selectedIds
          ..clear()
          ..addAll(valid.map((CartItem e) => e.cartId));
        loading = false;
        if (valid.isEmpty) editing = false;
      });
      await _fillGoodsInfo(<CartItem>[...valid, ...invalid]);
      await _recalculate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = CartApi.errorMsg(e, '购物车加载失败');
      });
    }
  }

  /// 补充商品图与规格名(并行,失败保留占位)
  Future<void> _fillGoodsInfo(List<CartItem> list) async {
    await Future.wait(list.map((CartItem item) async {
      // 接口已返回图与规格时不额外请求
      if (item.image.isNotEmpty && item.specText.isNotEmpty) return;
      Map<String, dynamic>? cached = goodsCache[item.skuId];
      if (cached == null) {
        try {
          final Map<String, dynamic> detail = await GoodsApi.detail(item.goodsId, skuId: item.skuId);
          final List<dynamic> images = (detail['images'] as List? ?? const []);
          final String image = images.isEmpty ? '' : '${images.first}';
          final String specText = _buildSpecText(detail['specFormat']);
          cached = <String, dynamic>{'image': image, 'specText': specText};
          goodsCache[item.skuId] = cached;
        } catch (_) {
          // 忽略: 图片/规格非关键信息
          return;
        }
      }
      if (item.image.isEmpty) item.image = '${cached['image'] ?? ''}';
      if (item.specText.isEmpty) item.specText = '${cached['specText'] ?? ''}';
    }));
    if (mounted) setState(() {});
  }

  /// 规格文本: 商品规格/红/M
  String _buildSpecText(dynamic specFormat) {
    final List<dynamic> specs = (specFormat as List? ?? const []);
    final List<String> names = specs
        .map((dynamic e) => '${e is Map ? (e['spec_value_name'] ?? '') : ''}')
        .map((dynamic e) => '$e')
        .where((String e) => e.isNotEmpty)
        .toList();
    return names.isEmpty ? '' : '商品规格/${names.join('/')}';
  }

  /// 已选条目
  List<CartItem> get selectedItems =>
      items.where((CartItem e) => selectedIds.contains(e.cartId)).toList();

  /// 已选合计金额
  num get totalMoney => selectedItems.fold<num>(0, (num sum, CartItem e) => sum + e.totalMoney);

  /// 已选总件数
  int get totalNum => selectedItems.fold<int>(0, (int sum, CartItem e) => sum + e.buyNum);

  /// 商品总额(后台计算)
  num get goodsMoney => CartApi.calcMoney(calcData, const <String>['goods_money', 'goodsMoney']);

  /// 优惠券金额
  num get couponMoney => CartApi.calcMoney(calcData, const <String>['coupon_money', 'couponMoney']);

  /// 满减金额
  num get promotionMoney => CartApi.calcMoney(calcData, const <String>['promotion_money', 'promotionMoney']);

  /// 后台计算合计(应付)
  num get orderMoney =>
      CartApi.calcMoney(calcData, const <String>['order_money', 'orderMoney', 'pay_money', 'total_money']);

  /// 是否有优惠
  bool get hasDiscount => couponMoney > 0 || promotionMoney > 0;

  /// 优惠券信息(calcData.coupon_info)
  Map<String, dynamic>? get couponInfo {
    final dynamic info = calcData['coupon_info'];
    if (info is Map) return info.cast<String, dynamic>();
    return null;
  }

  /// 优惠券是否待领取
  bool get couponWaitReceive => '${couponInfo?['receive_type'] ?? ''}' == 'wait';

  /// 领取优惠券(与 H5 receiveCoupon 一致)
  Future<void> _receiveCoupon([Map<String, dynamic>? coupon]) async {
    final Map<String, dynamic>? info = coupon ?? couponInfo;
    final int typeId = int.tryParse('${info?['coupon_type_id'] ?? 0}') ?? 0;
    if (info == null || typeId == 0) return;
    try {
      await CouponApi.receive(couponTypeId: typeId);
      if (!mounted) return;
      // 领取成功后标记为已领取,并重新计算金额
      setState(() {
        calcData = <String, dynamic>{
          ...calcData,
          'coupon_info': <String, dynamic>{...info, 'receive_type': ''},
        };
      });
      await _recalculate();
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(CartApi.errorMsg(e, '领取失败'));
    }
  }

  /// 应付金额: 优先取后台计算结果,取不到用本地小计兜底
  num get payMoney => orderMoney > 0 ? orderMoney : totalMoney;

  /// 重新计算金额(静默失败,失败沿用本地金额)
  Future<void> _recalculate() async {
    final List<CartItem> selected = selectedItems;
    if (selected.isEmpty) {
      if (calcData.isNotEmpty && mounted) setState(() => calcData = <String, dynamic>{});
      return;
    }
    try {
      final Map<String, dynamic> res = await CartApi.calculate(
        selected.map((CartItem e) => <String, dynamic>{'sku_id': e.skuId, 'num': e.buyNum}).toList(),
      );
      if (!mounted) return;
      setState(() => calcData = res);
    } catch (_) {
      // 忽略: 金额非阻断信息
    }
  }

  /// 是否全选
  bool get isAllSelected => items.isNotEmpty && selectedIds.length >= items.length;

  /// 勾选/取消
  void _toggleSelect(CartItem item) {
    setState(() {
      if (selectedIds.contains(item.cartId)) {
        selectedIds.remove(item.cartId);
      } else {
        selectedIds.add(item.cartId);
      }
    });
    _recalculate();
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (isAllSelected) {
        selectedIds.clear();
      } else {
        selectedIds.addAll(items.map((CartItem e) => e.cartId));
      }
    });
    _recalculate();
  }

  /// 修改数量(与 H5 cartNumChange 一致: 超范围自动收敛,失败回滚)
  Future<void> _changeNum(CartItem item, int delta) async {
    final int lower = item.minNum > item.maxNum ? 1 : item.minNum;
    int newNum = item.buyNum + delta;
    if (newNum > item.maxNum) {
      newNum = item.maxNum;
      MyDialog.toast(item.isLimit && item.maxBuy > 0 && item.maxBuy < item.stock
          ? '该商品每人限购${item.maxBuy}件'
          : '库存不足');
    }
    if (newNum < lower) newNum = lower;
    if (newNum == item.buyNum) return;
    final int oldNum = item.buyNum;
    setState(() => item.buyNum = newNum);
    try {
      await CartApi.editNum(cartId: item.cartId, num: newNum);
      await _recalculate();
    } catch (e) {
      if (!mounted) return;
      setState(() => item.buyNum = oldNum);
      MyDialog.toast(CartApi.errorMsg(e, '修改数量失败'));
    }
  }

  /// 删除确认
  Future<bool?> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('提示', style: TextStyle(fontSize: 16.0)),
        content: Text(message, style: const TextStyle(fontSize: 14.0)),
        actionsPadding: const EdgeInsets.only(right: 10.0, bottom: 6.0),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确定', style: TextStyle(color: primary))),
        ],
      ),
    );
  }

  /// 删除单条
  Future<void> _deleteItem(CartItem item) async {
    final bool? ok = await _confirm('确定要删除「${item.goodsName}」吗？');
    if (ok != true) return;
    await _deleteIds(<int>[item.cartId]);
  }

  /// 删除选中
  Future<void> _deleteSelected() async {
    if (selectedIds.isEmpty) {
      MyDialog.toast('请先选择商品');
      return;
    }
    final bool? ok = await _confirm('确定删除选中的${selectedIds.length}件商品吗？');
    if (ok != true) return;
    await _deleteIds(selectedIds.toList());
  }

  Future<void> _deleteIds(List<int> cartIds) async {
    final List<int> ids = cartIds.toList();
    // 先本地移除,失败再还原
    final List<CartItem> backup = items.toList();
    final Set<int> backupSelected = selectedIds.toSet();
    setState(() {
      items = items.where((CartItem e) => !ids.contains(e.cartId)).toList();
      selectedIds.removeWhere(ids.contains);
      if (items.isEmpty) editing = false;
    });
    try {
      await CartApi.delete(cartIds: ids);
      await _recalculate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        items = backup;
        selectedIds
          ..clear()
          ..addAll(backupSelected);
      });
      MyDialog.toast(CartApi.errorMsg(e, '删除失败'));
    }
  }

  /// 去结算(校验逻辑与 H5 settlement 一致)
  Future<void> _goCheckout() async {
    final List<CartItem> selected = selectedItems;
    if (selected.isEmpty) {
      MyDialog.toast('请先选择要结算的商品');
      return;
    }
    // 库存/最小购买数校验
    for (final CartItem item in selected) {
      if (item.buyNum > item.stock) {
        MyDialog.toast('商品${item.goodsName}商品库存不足');
        return;
      }
      if (item.minBuy > 0 && item.buyNum < item.minBuy) {
        MyDialog.toast('商品${item.goodsName}商品最少要购买${item.minBuy}件');
        return;
      }
    }
    // 同一商品合并数量后校验最大购买数
    final Map<int, int> goodsNum = <int, int>{};
    for (final CartItem item in selected) {
      goodsNum[item.goodsId] = (goodsNum[item.goodsId] ?? 0) + item.buyNum;
    }
    for (final CartItem item in selected) {
      final int merged = goodsNum[item.goodsId] ?? item.buyNum;
      if (item.maxBuy > 0 && merged > item.maxBuy) {
        MyDialog.toast('商品${item.goodsName}最多可购买${item.maxBuy}件');
        return;
      }
    }
    // 有可领取的优惠券时先领券(与 H5 一致)
    final Map<String, dynamic>? coupon = couponInfo;
    if (coupon != null && '${coupon['receive_type'] ?? ''}' == 'wait') {
      await _receiveCoupon(coupon);
    }
    if (!mounted) return;
    Get.toNamed('/order/ordersure', arguments: <String, dynamic>{
      'from': 'cart',
      // 与 H5 一致: 逗号拼接的 cart_ids 字符串
      'cart_ids': selected.map((CartItem e) => e.cartId).join(','),
      'cartIds': selected.map((CartItem e) => e.cartId).toList(),
      'skus': selected
          .map((CartItem e) => <String, dynamic>{
                'skuId': e.skuId,
                'goodsId': e.goodsId,
                'num': e.buyNum,
                'price': e.unitPrice,
                'title': e.goodsName,
                'image': e.image,
              })
          .toList(),
      'totalMoney': payMoney,
      'calc': calcData,
    });
  }

  /// 优惠明细弹窗
  void _showDiscountDetail() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12.0),
            const Text('优惠明细', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6.0),
            _buildDiscountRow('商品总额', '¥${goodsMoney.toStringAsFixed(2)}', Colors.black87),
            if (couponInfo != null) _buildCouponRow(),
            if (couponMoney > 0) _buildDiscountRow('优惠券', '-¥${couponMoney.toStringAsFixed(2)}', primary),
            if (promotionMoney > 0) _buildDiscountRow('满减', '-¥${promotionMoney.toStringAsFixed(2)}', primary),
            FStyle.divider,
            _buildDiscountRow('合计', '¥${orderMoney.toStringAsFixed(2)}', primary),
            const SizedBox(height: 12.0),
          ],
        ),
      ),
    );
  }

  /// 优惠券行(可领取时显示领取按钮)
  Widget _buildCouponRow() {
    final Map<String, dynamic> info = couponInfo!;
    final String name = '${info['coupon_name'] ?? ''}';
    final num atLeast = CartApi.calcMoney(info, const <String>['at_least']);
    final num money = CartApi.calcMoney(info, const <String>['money', 'discount_money']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name.isEmpty ? '优惠券' : name, style: const TextStyle(fontSize: 13.0, color: Colors.black87)),
                if (atLeast > 0)
                  Text('满${atLeast.toStringAsFixed(0)}可用', style: const TextStyle(fontSize: 10.0, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '-¥${money.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13.0, color: primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8.0),
          if (couponWaitReceive)
            GestureDetector(
              onTap: _receiveCoupon,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20.0)),
                child: const Text('领取', style: TextStyle(fontSize: 11.0, color: Colors.white)),
              ),
            )
          else
            const Text('已领取', style: TextStyle(fontSize: 11.0, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDiscountRow(String title, String money, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
      child: Row(
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 13.0, color: Colors.black87)),
          const Spacer(),
          Text(money, style: TextStyle(fontSize: 13.0, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        forceMaterialTransparency: true,
        titleSpacing: 1.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20.0),
          onPressed: () => Get.back(),
        ),
        title: Text(
          items.isEmpty ? '购物车' : '购物车(${items.length})',
          style: const TextStyle(fontSize: 18.0),
        ),
        actions: <Widget>[
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => editing = !editing),
              child: Text(editing ? '完成' : '管理', style: const TextStyle(fontSize: 14.0, color: Colors.black87)),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: Loading(title: '加载中...'));
    }
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
            const SizedBox(height: 12.0),
            OutlinedButton(onPressed: loadCart, child: const Text('重新加载', style: TextStyle(color: primary))),
          ],
        ),
      );
    }
    if (items.isEmpty && invalidItems.isEmpty) return _buildEmpty();
    final bool hasInvalid = invalidItems.isNotEmpty;
    return RefreshIndicator(
      color: primary,
      onRefresh: loadCart,
      child: ScrollConfiguration(
        behavior: CustomScrollBehavior(),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 10.0),
          itemCount: items.length + (hasInvalid ? 1 + invalidItems.length : 0),
          separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 0),
          itemBuilder: (BuildContext context, int index) {
            if (index < items.length) return _buildItem(items[index]);
            if (index == items.length) return _buildInvalidHeader();
            return _buildInvalidItem(invalidItems[index - items.length - 1]);
          },
        ),
      ),
    );
  }

  /// 失效商品标题栏
  Widget _buildInvalidHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          Text('失效商品${invalidItems.length}件', style: const TextStyle(fontSize: 13.0, color: Colors.black87)),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _clearInvalid,
            child: const Text('清空', style: TextStyle(fontSize: 13.0, color: primary)),
          ),
        ],
      ),
    );
  }

  /// 失效商品项(不可勾选,灰化)
  Widget _buildInvalidItem(CartItem item) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 80.0,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(Icons.remove_circle_outline, size: 20.0, color: Colors.grey.shade400),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: item.image.isEmpty
                  ? Container(width: 80.0, height: 80.0, color: Colors.grey.shade200)
                  : CachedNetworkImage(
                      imageUrl: item.image,
                      width: 80.0,
                      height: 80.0,
                      fit: BoxFit.cover,
                      errorWidget: (BuildContext context, String url, Object error) =>
                          Container(width: 80.0, height: 80.0, color: Colors.grey.shade200),
                    ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: SizedBox(
                height: 80.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      item.goodsName,
                      style: const TextStyle(fontSize: 13.0, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '¥${item.unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 15.0, fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                          child: const Text('已失效', style: TextStyle(fontSize: 10.0, color: Colors.grey)),
                        ),
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

  /// 清空失效商品
  Future<void> _clearInvalid() async {
    final bool? ok = await _confirm('确定要清空失效商品吗？');
    if (ok != true) return;
    final List<int> ids = invalidItems.map((CartItem e) => e.cartId).toList();
    setState(() => invalidItems = <CartItem>[]);
    try {
      await CartApi.delete(cartIds: ids);
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(CartApi.errorMsg(e, '清空失败'));
      loadCart();
    }
  }

  /// 空购物车
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.shopping_cart_outlined, size: 70.0, color: Colors.grey.shade300),
          const SizedBox(height: 12.0),
          const Text('购物车还是空的', style: TextStyle(color: Colors.grey, fontSize: 14.0)),
          const SizedBox(height: 16.0),
          GestureDetector(
            onTap: () => Get.toNamed('/'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const Text('去逛逛', style: TextStyle(color: Colors.white, fontSize: 14.0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个购物车商品
  Widget _buildItem(CartItem item) {
    final bool selected = selectedIds.contains(item.cartId);
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withAlpha(10), offset: const Offset(0.0, 1.0), blurRadius: 1.0),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 勾选(与商品图垂直居中)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleSelect(item),
            child: Container(
              height: 80.0,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20.0,
                color: selected ? primary : Colors.grey.shade400,
              ),
            ),
          ),
          // 商品图
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: item.image.isEmpty
                ? Container(
                    width: 80.0,
                    height: 80.0,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  )
                : CachedNetworkImage(
                    imageUrl: item.image,
                    width: 80.0,
                    height: 80.0,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) => Container(width: 80.0, height: 80.0, color: Colors.grey.shade100),
                    errorWidget: (BuildContext context, String url, dynamic error) => Container(
                      width: 80.0,
                      height: 80.0,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
          ),
          const SizedBox(width: 8.0),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.goodsName,
                  style: const TextStyle(fontSize: 13.0, color: Colors.black87, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.specText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0, bottom: 6.0),
                    child: Text(
                      item.specText,
                      style: const TextStyle(fontSize: 11.0, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const SizedBox(height: 6.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '¥${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: primary, fontSize: 15.0, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildStepper(item),
                        if (editing) ...<Widget>[
                          const SizedBox(width: 6.0),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _deleteItem(item),
                            child: Icon(Icons.delete_outline, size: 18.0, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
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

  /// 数量步进器
  Widget _buildStepper(CartItem item) {
    final int lower = item.minNum > item.maxNum ? 1 : item.minNum;
    final bool canMinus = item.buyNum > lower;
    final bool canPlus = item.buyNum < item.maxNum;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 减到最小时删除该商品(与 H5 goodsLimit 一致)
        _buildStepButton(Icons.remove, canMinus, canMinus ? () => _changeNum(item, -1) : () => _deleteItem(item)),
        SizedBox(
          width: 30.0,
          child: Center(
            child: Text('${item.buyNum}', style: const TextStyle(fontSize: 13.0, color: Colors.black87)),
          ),
        ),
        _buildStepButton(
          Icons.add,
          canPlus,
          canPlus
              ? () => _changeNum(item, 1)
              : () => MyDialog.toast(
                    item.isLimit && item.maxBuy > 0 && item.maxBuy < item.stock
                        ? '该商品每人限购${item.maxBuy}件'
                        : '库存不足',
                  ),
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 22.0,
        height: 22.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: enabled ? Colors.grey.shade300 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Icon(icon, size: 13.0, color: enabled ? Colors.black87 : Colors.grey.shade400),
      ),
    );
  }

  /// 底部结算/删除栏
  Widget _buildBottomBar() {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 50.0,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleSelectAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isAllSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20.0,
                  color: isAllSelected ? primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 4.0),
                const Text('全选', style: TextStyle(fontSize: 13.0)),
              ],
            ),
          ),
          if (!editing) ...<Widget>[
            const SizedBox(width: 8.0),
            const Text('合计:', style: TextStyle(fontSize: 12.0)),
            const SizedBox(width: 2.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '¥${payMoney.toStringAsFixed(2)}',
                      style: const TextStyle(color: primary, fontSize: 16.0, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (hasDiscount)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showDiscountDetail,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('优惠明细', style: TextStyle(fontSize: 10.0, color: Colors.grey)),
                          Icon(Icons.arrow_drop_up, size: 14.0, color: Colors.grey),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
          ],
          if (editing) const Spacer(),
          GestureDetector(
            onTap: editing ? _deleteSelected : _goCheckout,
            child: Container(
              alignment: Alignment.center,
              height: 36.0,
              constraints: const BoxConstraints(minWidth: 100.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: editing ? Colors.grey.shade800 : primary,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Text(
                editing
                    ? (selectedIds.isEmpty ? '删除' : '删除(${selectedIds.length})')
                    : (totalNum == 0
                        ? '去结算'
                        : (couponWaitReceive ? '领券结算($totalNum)' : '去结算($totalNum)')),
                style: const TextStyle(color: Colors.white, fontSize: 14.0),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
