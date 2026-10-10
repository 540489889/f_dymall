/// 秒杀商品详情
/// 对齐 H5: pages_promotion/seckill/detail.vue(复用通用商品详情, 接口换成秒杀详情)
/// * 秒杀价 + 原价 + 倒计时 + 限购 + 规格选择 + 图文详情
/// * 底部「立即抢购」-> 选规格/数量 -> 跳结算页(走 /seckill/api/ordercreate/*)
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

import '../../api/seckill.dart';
import '../../controller/auth_store.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

/// 活动主色(H5 style_color: seckill_promotion_color / seckill_promotion_aux_color)
const Color _primary = Color(0xFFF83530);
const Color _aux = Color(0xFFFD9A01);

/// 接口字段多为字符串, 统一转 num
num _toNum(dynamic value, [num def = 0]) => value is num ? value : (num.tryParse('${value ?? ''}') ?? def);

class SeckillDetailPage extends StatefulWidget {
  const SeckillDetailPage({super.key});

  @override
  State<SeckillDetailPage> createState() => _SeckillDetailPageState();
}

class _SeckillDetailPageState extends State<SeckillDetailPage> {
  final ScrollController controller = ScrollController();
  final ValueNotifier<double> scrollOffset = ValueNotifier<double>(0);
  Timer? timer;

  bool loading = true;
  String errorMsg = '';
  Map<String, dynamic> detail = const {};

  /// 规格(sku)列表(仅参与本次秒杀的 sku)
  List<Map<String, dynamic>> skuList = <Map<String, dynamic>>[];
  /// 规格树([{spec_name, value: [{sku_id, spec_value_name, disabled, ...}]}])
  List<Map<String, dynamic>> specTree = <Map<String, dynamic>>[];
  Map<String, dynamic>? currentSku;
  int buyNum = 1;

  /// 服务器时间戳(秒)与同步时的本机秒数
  int serverTimestamp = 0;
  int syncedAt = 0;

  int get seckillId {
    final dynamic args = Get.arguments;
    if (args is Map) return int.tryParse('${args['seckillId'] ?? args['id'] ?? 0}') ?? 0;
    return int.tryParse('$args') ?? 0;
  }

  /// 当前服务器时间戳(秒)
  int get nowTimestamp {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return serverTimestamp + (now - syncedAt);
  }

  /// 当日秒数
  int get nowSeconds {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(nowTimestamp * 1000);
    return t.hour * 3600 + t.minute * 60 + t.second;
  }

  List<SeckillTime> get times => (detail['times'] as List? ?? const []).cast<SeckillTime>();
  num get seckillPrice => detail['seckillPrice'] as num? ?? 0;
  num get price => detail['price'] as num? ?? 0;
  num get stock => detail['stock'] as num? ?? 0;
  int get maxBuy => (detail['maxBuy'] as num? ?? 0).toInt();
  int get endTime => (detail['endTime'] as num? ?? 0).toInt();
  String get title => '${detail['title'] ?? ''}';
  List<String> get images => (detail['images'] as List? ?? const []).map((dynamic e) => '$e').toList();

  /// 状态: 0 已结束 / 1 抢购中 / 2 即将开始
  int get status {
    if (endTime > 0 && nowTimestamp >= endTime) return 0;
    for (final SeckillTime t in times) {
      if (t.isNow(nowSeconds)) return 1;
    }
    return 2;
  }

  /// 剩余秒数(抢购中=距本场结束, 未开始=距下场开始)
  int get remainSeconds {
    if (status == 0) return 0;
    if (status == 1) {
      for (final SeckillTime t in times) {
        if (t.isNow(nowSeconds)) return t.endTime - nowSeconds;
      }
      return 0;
    }
    int min = 0;
    for (final SeckillTime t in times) {
      if (t.startTime <= nowSeconds) continue;
      final int v = t.startTime - nowSeconds;
      if (min == 0 || v < min) min = v;
    }
    if (min == 0) min = 86400 - nowSeconds;
    return min;
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(() => scrollOffset.value = controller.offset);
    loadDetail();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    timer?.cancel();
    super.dispose();
  }

  /// 热重载会保留旧 State(新增字段缺失), 这里重建并重新拉取
  @override
  void reassemble() {
    super.reassemble();
    loading = true;
    errorMsg = '';
    detail = const <String, dynamic>{};
    skuList = <Map<String, dynamic>>[];
    specTree = <Map<String, dynamic>>[];
    currentSku = null;
    buyNum = 1;
    loadDetail();
  }

  Future<void> loadDetail() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> res = await SeckillApi.detail(seckillId);
      if (!mounted) return;
      setState(() {
        detail = res;
        serverTimestamp = int.tryParse('${res['timestamp'] ?? 0}') ?? 0;
        syncedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        loading = false;
        errorMsg = res.isEmpty ? '未查询到秒杀商品' : '';
      });
      if (res.isNotEmpty) await loadSku();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = '$e'.replaceAll(RegExp(r'^DioException.*message: '), '');
      });
    }
  }

  /// 规格(sku)列表
  Future<void> loadSku() async {
    try {
      final List<Map<String, dynamic>> list = await SeckillApi.goodsSku(
        goodsId: (detail['goodsId'] as num? ?? 0).toInt(),
        seckillId: (detail['seckillId'] as num? ?? seckillId).toInt(),
      );
      if (!mounted || list.isEmpty) return;
      setState(() {
        skuList = list;
        specTree = SeckillApi.specTreeOf(list);
        currentSku = _defaultSku(list);
        buyNum = 1;
      });
    } catch (_) {
      // 单规格商品可不返回, 忽略
    }
  }

  /// 默认选中: 优先详情返回的 sku_id, 否则第一个
  Map<String, dynamic> _defaultSku(List<Map<String, dynamic>> list) {
    final int skuId = (detail['skuId'] as num? ?? 0).toInt();
    for (final Map<String, dynamic> item in list) {
      if (int.tryParse('${item['sku_id'] ?? 0}') == skuId && skuId > 0) return item;
    }
    return list.first;
  }

  /// 规格文案(基础款【经典包装】21套投影+无音乐)
  String specTextOf(Map<String, dynamic> sku) => SeckillApi.specTextOf(sku);

  /// 当前规格的秒杀价(各 sku 的秒杀价可能不同)
  num get currentPrice {
    final num v = _toNum(currentSku?['seckill_price']);
    return v > 0 ? v : seckillPrice;
  }

  /// 当前规格剩余库存
  /// * sku 行的 goods_stock 就是"剩余库存"(与 H5 列表口径一致, 不再减 sale_num)
  /// * sku 行的 stock 是脏值(可能为 0/负数), 只在 goods_stock 缺失时兜底
  int get currentStock {
    final Map<String, dynamic>? sku = currentSku;
    if (sku != null) {
      final int goodsStock = _toNum(sku['goods_stock']).toInt();
      if (goodsStock != 0) return goodsStock < 0 ? 0 : goodsStock;
      final int s = _toNum(sku['stock']).toInt();
      return s < 0 ? 0 : s;
    }
    final int s = stock.toInt();
    return s < 0 ? 0 : s;
  }

  /// 打开规格选择
  Future<void> openSkuSheet() async {
    if (!AuthStore.to.isLogin) {
      Get.toNamed('/login');
      return;
    }
    if (status == 0) {
      MyDialog.toast('限时秒杀活动已结束');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) => _SkuSheet(
        skuList: skuList,
        specTree: specTree,
        current: currentSku,
        count: buyNum,
        maxBuy: maxBuy,
        stock: currentStock,
        specText: specTextOf,
        onConfirm: (Map<String, dynamic> sku, int count) {
          setState(() {
            currentSku = sku;
            buyNum = count;
          });
          Get.back();
          submit();
        },
      ),
    );
  }

  /// 去结算(秒杀下单: /seckill/api/ordercreate/*)
  void submit() {
    final int skuId = currentSku == null
        ? (detail['skuId'] as num? ?? 0).toInt()
        : (currentSku!['sku_id'] as num? ?? 0).toInt();
    if (skuId == 0) {
      MyDialog.toast('未获取到商品规格');
      return;
    }
    if (currentStock <= 0) {
      MyDialog.toast('该规格已抢完');
      return;
    }
    Get.toNamed(
      '/order/ordersure',
      arguments: <String, dynamic>{
        'seckillId': (detail['seckillId'] as num? ?? seckillId).toInt(),
        'skuId': skuId,
        'num': buyNum,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 底部安全区(iOS 全面屏的 home indicator):
    // * 底部栏要避开它,否则「立即抢购」贴着屏幕最底边,既不好点也容易被系统手势误触
    // * 列表底部要留出同样的高度,否则最后一块内容会被加高后的底部栏盖住
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primary,
        surfaceTintColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('限时秒杀', style: TextStyle(fontSize: 17.0, color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(_primary)))
          : errorMsg.isNotEmpty
              ? _buildError()
              : Stack(
                  children: <Widget>[
                    Positioned.fill(child: _buildBody(bottomSafe)),
                    Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar(bottomSafe)),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(errorMsg, style: const TextStyle(color: Color(0xFF999999), fontSize: 14.0)),
          const SizedBox(height: 12.0),
          OutlinedButton(onPressed: loadDetail, child: const Text('重新加载')),
        ],
      ),
    );
  }

  /// [bottomSafe] 底部安全区: 让最后一块内容不被加高后的底部栏盖住
  Widget _buildBody(double bottomSafe) {
    return ListView(
      controller: controller,
      padding: EdgeInsets.only(bottom: 70.0 + bottomSafe),
      children: <Widget>[
        _buildSwiper(),
        _buildPriceCard(),
        _buildGoodsInfo(),
        if ('${detail['content'] ?? ''}'.isNotEmpty) _buildContent(),
      ],
    );
  }

  /// 轮播图
  Widget _buildSwiper() {
    if (images.isEmpty) {
      return Container(
        height: 320.0,
        color: Colors.white,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 48.0),
      );
    }
    return SizedBox(
      height: 320.0,
      child: Swiper(
        itemCount: images.length,
        autoplay: images.length > 1,
        loop: images.length > 1,
        pagination: const SwiperPagination(
          builder: DotSwiperPaginationBuilder(size: 6.0, activeSize: 6.0, color: Color(0x66FFFFFF), activeColor: _primary),
        ),
        itemBuilder: (BuildContext context, int index) => CachedNetworkImage(
          imageUrl: images[index],
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFFF5F5F5)),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFFF5F5F5),
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 48.0),
          ),
        ),
      ),
    );
  }

  /// 秒杀价 + 倒计时(红渐变头)
  Widget _buildPriceCard() {
    final int remain = remainSeconds;
    final int st = status;
    final bool showOrigin = price > currentPrice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15.0, 16.0, 15.0, 16.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: <Color>[_primary, _aux], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // 左侧：价格区
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    const Text('¥', style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.w600)),
                    Text(
                      currentPrice.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                if (showOrigin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '¥${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13.0,
                        decoration: TextDecoration.lineThrough,
                        height: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧：活动标签 + 倒计时
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Text(
                  '限时秒杀',
                  style: TextStyle(color: _primary, fontSize: 11.0, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    st == 0
                        ? '活动已结束'
                        : (st == 1 ? '距本场结束' : '距开场'),
                    style: const TextStyle(color: Colors.white, fontSize: 11.0),
                  ),
                  if (st != 0) ...<Widget>[
                    const SizedBox(width: 4.0),
                    _buildBlock(remain ~/ 3600),
                    const Text(':', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                    _buildBlock((remain % 3600) ~/ 60),
                    const Text(':', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                    _buildBlock(remain % 60),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(int v) {
    final String text = v < 10 ? '0$v' : '$v';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
      ),
    );
  }

  /// 标题 / 限购 / 规格
  Widget _buildGoodsInfo() {
    final int remain = currentStock;
    final int saleNum = currentSku == null
        ? (detail['saleNum'] as num? ?? 0).toInt()
        : _toNum(currentSku!['sale_num']).toInt();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 15.0, color: Color(0xFF333333), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              if (maxBuy > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  child: Text('每人限购$maxBuy件', style: const TextStyle(color: _primary, fontSize: 11.0)),
                ),
              Text('已售$saleNum件', style: const TextStyle(color: Color(0xFF999999), fontSize: 11.0)),
              const SizedBox(width: 8.0),
              Text(remain > 0 ? '剩余$remain件' : '已抢完',
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11.0)),
            ],
          ),
          if (skuList.isNotEmpty) ...<Widget>[
            const Divider(color: Color(0xFFF2F2F2), height: 20.0, thickness: 0.5),
            GestureDetector(
              onTap: openSkuSheet,
              child: Row(
                children: <Widget>[
                  const Text('已选', style: TextStyle(color: Color(0xFF999999), fontSize: 12.0)),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      '${specTextOf(currentSku ?? const <String, dynamic>{})}  $buyNum件',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF333333)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18.0, color: Color(0xFFBBBBBB)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 图文详情
  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10.0, 12.0, 10.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(left: 5.0, bottom: 8.0),
            child: Text('商品详情', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
          ),
          Html(data: '${detail['content'] ?? ''}', shrinkWrap: true),
        ],
      ),
    );
  }

  /// 底部按钮
  /// * [bottomSafe] 底部安全区(iOS home indicator): 白底延伸到屏幕最底,按钮整体上移避开它
  Widget _buildBottomBar(double bottomSafe) {
    final bool disabled = status == 0 || currentStock <= 0;
    return Container(
      // 60 为按钮区高度,底部再补安全区
      padding: EdgeInsets.fromLTRB(15.0, 0, 15.0, bottomSafe),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 6.0, offset: Offset(0, -1))],
      ),
      child: SizedBox(
        height: 60.0,
        child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: disabled ? null : openSkuSheet,
              child: Container(
                height: 42.0,
                decoration: BoxDecoration(
                  color: disabled ? const Color(0xFFDDDDDD) : _primary,
                  borderRadius: BorderRadius.circular(21.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  status == 0 ? '活动已结束' : (currentStock <= 0 ? '已抢完' : '立即抢购'),
                  style: const TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// 规格/数量选择弹层
class _SkuSheet extends StatefulWidget {
  const _SkuSheet({
    required this.skuList,
    required this.specTree,
    required this.current,
    required this.count,
    required this.maxBuy,
    required this.stock,
    required this.specText,
    required this.onConfirm,
  });

  final List<Map<String, dynamic>> skuList;
  /// 规格树(按 spec_name 分组, 值为 [{sku_id, spec_value_name, disabled}])
  final List<Map<String, dynamic>> specTree;
  final Map<String, dynamic>? current;
  /// 初始购买数量
  final int count;
  final int maxBuy;
  final int stock;
  final String Function(Map<String, dynamic>) specText;
  final void Function(Map<String, dynamic> sku, int count) onConfirm;

  @override
  State<_SkuSheet> createState() => _SkuSheetState();
}

class _SkuSheetState extends State<_SkuSheet> {
  late Map<String, dynamic> current;
  late int count;
  late List<Map<String, dynamic>> tree;

  @override
  void initState() {
    super.initState();
    current = widget.current ?? widget.skuList.first;
    count = widget.count < 1 ? 1 : widget.count;
    tree = widget.specTree.isNotEmpty ? widget.specTree : _buildFallbackTree();
    // 初始选中项可能不在规格树里(单规格), 做一次兜底
    if (_skuOf(widget.specTree) == null && widget.specTree.isNotEmpty) {
      tree = _buildFallbackTree();
    }
  }

  /// 接口没给 goods_spec_format 时, 用参与秒杀的 sku 列表兜底成一组
  List<Map<String, dynamic>> _buildFallbackTree() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'spec_name': '',
        'value': widget.skuList
            .map((Map<String, dynamic> e) => <String, dynamic>{
                  'sku_id': e['sku_id'],
                  'spec_value_name': widget.specText(e),
                })
            .toList(),
      },
    ];
  }

  /// 当前选中项是否在规格树中
  Map<String, dynamic>? _skuOf(List<Map<String, dynamic>> source) {
    final int skuId = int.tryParse('${current['sku_id'] ?? 0}') ?? 0;
    for (final Map<String, dynamic> group in source) {
      for (final dynamic v in (group['value'] as List? ?? const [])) {
        if (v is Map && int.tryParse('${v['sku_id'] ?? 0}') == skuId) return group;
      }
    }
    return null;
  }

  /// 按 sku_id 找秒杀 sku 数据
  Map<String, dynamic>? skuById(dynamic id) {
    final int skuId = int.tryParse('$id') ?? 0;
    for (final Map<String, dynamic> item in widget.skuList) {
      if (int.tryParse('${item['sku_id'] ?? 0}') == skuId && skuId > 0) return item;
    }
    return null;
  }

  /// 是否有得选: 所有规格值加起来只有一个时(单规格)没有选择余地,不展示规格区
  /// * 否则弹窗会为一行规格撑出大片空白
  bool get hasSpec {
    int count = 0;
    for (final Map<String, dynamic> group in tree) {
      count += (group['value'] as List? ?? const <dynamic>[]).length;
    }
    return count > 1;
  }

  /// 可买上限: 库存与限购取小
  int get limit {
    int max = widget.stock <= 0 ? 1 : widget.stock;
    if (widget.maxBuy > 0 && widget.maxBuy < max) max = widget.maxBuy;
    if (max < 1) max = 1;
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final String image = '${current['sku_image'] ?? ''}';
    final num price = _toNum(current['seckill_price']);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // 显式 stretch: Column 默认 crossAxisAlignment 是 center,
          // 子元素会按自身宽度居中(规格区看起来就左边空一截),这里让它们都撑满弹层宽度
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: image,
                      width: 80.0,
                      height: 80.0,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 80.0,
                        height: 80.0,
                        color: const Color(0xFFF5F5F5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD)),
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
                          '¥${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Arial',
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          widget.specText(current),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18.0, color: Color(0xFF999999)),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFEEEEEE), height: 1.0, thickness: 0.5),
            // 单规格(只有一个可选值)时不展示规格区,弹窗按内容收短
            // * shrinkWrap: 规格少时按内容高度;多时才占满可滚动区
            if (hasSpec) ...<Widget>[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
                  children: tree.map(_buildSpecGroup).toList(),
                ),
              ),
              const Divider(color: Color(0xFFEEEEEE), height: 1.0, thickness: 0.5),
            ],
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 12.0),
            child: Row(
              children: <Widget>[
                const Text('购买数量', style: TextStyle(fontSize: 13.0, color: Color(0xFF333333))),
                const Spacer(),
                _buildStepper(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 0, 15.0, 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 44.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0)),
                ),
                onPressed: () => widget.onConfirm(current, count),
                child: const Text('确定', style: TextStyle(fontSize: 15.0)),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 一组规格(如"颜色分类")
  Widget _buildSpecGroup(Map<String, dynamic> group) {
    final String name = '${group['spec_name'] ?? ''}';
    final List<dynamic> values = (group['value'] as List? ?? const <dynamic>[]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(name, style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333))),
            ),
          // 撑满宽度 + 显式左对齐: Wrap 默认会收缩到"最宽一行的宽度",
          // 被上层居中后看起来就是左边空一截,这里固定铺满弹层宽度,规格值从最左边开始排
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: values.whereType<Map>().map(_buildSpecValue).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个规格值
  Widget _buildSpecValue(Map<dynamic, dynamic> value) {
    final int skuId = int.tryParse('${value['sku_id'] ?? 0}') ?? 0;
    final Map<String, dynamic>? sku = skuById(skuId);
    // 未参与本次秒杀 / 接口没返回该 sku 的都置灰
    final bool disabled = value['disabled'] == true || sku == null;
    final bool active = !disabled && int.tryParse('${current['sku_id'] ?? 0}') == skuId;
    final String text = '${value['spec_value_name'] ?? ''}';
    return GestureDetector(
      onTap: disabled
          ? () => MyDialog.toast('该规格未参与本次秒杀')
          : () => setState(() {
                current = sku;
                if (count > limit) count = limit;
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFDECEC)
              : (disabled ? const Color(0xFFFAFAFA) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: active ? _primary : Colors.transparent),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active
                ? _primary
                : (disabled ? const Color(0xFFCCCCCC) : const Color(0xFF666666)),
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _stepBtn(Icons.remove, count > 1 ? () => setState(() => count -= 1) : null),
        Container(
          width: 44.0,
          alignment: Alignment.center,
          child: Text('$count', style: const TextStyle(fontSize: 14.0, fontFamily: 'Arial')),
        ),
        _stepBtn(Icons.add, count < limit ? () => setState(() => count += 1) : null),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
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
}
