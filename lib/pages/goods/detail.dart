/// 商品详情页
library;

import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../api/cart.dart';
import '../../api/goods.dart';
import '../../api/goods_evaluate.dart';
import '../../api/store.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/backtop.dart';
import '../../components/loading.dart';
import '../../styles/index.dart';
import './coupon_sheet.dart';
import './sku_sheet.dart';
import './delivery_sheet.dart';
import './evaluate.dart';

class Goods extends StatefulWidget {
  const Goods({ super.key });

@override
State<Goods> createState() => _GoodsState();
}

class _GoodsState extends State<Goods> {
late final ScrollController scrollController = ScrollController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);
// 接口返回的商品详情
Map<String, dynamic> detail = const {};
// 加载状态
bool loading = true;
// 错误信息(非空表示加载失败/无数据)
String errorMsg = '';
// 用户已领取的券标识集合(本地记录, 关闭弹窗时回写)
Set<int> fetchedCoupons = <int>{};
// 规格属性是否展开
bool attrExpanded = false;
// 加入购物车请求中
bool addingCart = false;
// 购物车商品总件数(用于底部购物车角标,取 /api/cart/lists)
int cartNum = 0;
// 适用门店(/api/store/page 第一条)
int storeId = 0;
// 适用门店名
String storeName = '';
// 适用门店地址(full_address + address)
String storeAddress = '';
// 商品评价(配置 evaluate_show == 1 时展示)
bool evaluateShow = false;
int evaluateCount = 0;
List<Map<String, dynamic>> evaluateList = <Map<String, dynamic>>[];

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;
  });
  loadDetail();
  loadCartNum();
  // loadStore(); // 适用门店暂时隐藏, 暂不请求
  loadEvaluate();
}

/// 拉取购物车总件数(未登录或接口异常时静默失败,保持原值)
Future<void> loadCartNum() async {
  try {
    final int total = await CartApi.count();
    if (!mounted) return;
    setState(() => cartNum = total);
  } catch (_) {
    // 忽略: 角标非关键信息
  }
}

/// 拉取适用门店(取 /api/store/page 第一条, 接口异常时不展示该行)
Future<void> loadStore() async {
  try {
    final List<Map<String, dynamic>> list = await StoreApi.page(pageSize: 1);
    if (!mounted || list.isEmpty) return;
    final Map<String, dynamic> store = list.first;
    setState(() {
      storeId = int.tryParse('${store['store_id'] ?? 0}') ?? 0;
      storeName = '${store['store_name'] ?? ''}';
      storeAddress = '${store['full_address'] ?? ''}${store['address'] ?? ''}';
    });
  } catch (_) {
    // 忽略: 门店信息非下单关键项
  }
}

/// 加载商品评价(评价配置开启时展示: 总数 + 前 2 条)
Future<void> loadEvaluate() async {
  try {
    final Map<String, dynamic> config = await GoodsEvaluateApi.config();
    if (!mounted || '${config['evaluate_show'] ?? '0'}' != '1') return;
    final Map<String, dynamic> count = await GoodsEvaluateApi.count(goodsId);
    final Map<String, dynamic> data = await GoodsEvaluateApi.page(goodsId: goodsId, pageSize: 2);
    if (!mounted) return;
    setState(() {
      evaluateShow = true;
      evaluateCount = int.tryParse('${count['total'] ?? 0}') ?? 0;
      evaluateList = GoodsEvaluateApi.listOf(data);
    });
  } catch (_) {
    // 忽略: 评价非下单关键项
  }
}

@override
void dispose() {
  scrollController.dispose();
  super.dispose();
}

/// 商品id: 支持路由传 Map({'goodsId' 或 'id'})、数字或字符串
int get goodsId {
  final dynamic args = Get.arguments;
  if (args is Map) return int.tryParse('${args['goodsId'] ?? args['id'] ?? 1}') ?? 1;
  return int.tryParse('$args') ?? 1;
}

/// 直播间房间号 sn: 从直播间点商品进来时由直播间页带过来
/// * 加购 / 下单都要回传给后台(live_roomid),用于统计直播间成交
/// * 普通商品详情没有这个参数,为空表示非直播间下单
String get liveRoomId {
  final dynamic args = Get.arguments;
  if (args is! Map) return '';
  return '${args['live_roomid'] ?? ''}'.trim();
}

/// 加载商品详情
Future<void> loadDetail() async {
  setState(() {
    loading = true;
    errorMsg = '';
  });
  try {
    final Map<String, dynamic> res = await GoodsApi.detail(goodsId);
    if (!mounted) return;
    setState(() {
      detail = res;
      loading = false;
      errorMsg = res.isEmpty ? '未查询到商品信息' : '';
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      loading = false;
      errorMsg = '$e'.replaceAll(RegExp(r'^DioException.*message: '), '');
    });
  }
}

/* 数据快捷读取 */
List<String> get images => (detail['images'] as List? ?? const []).map((e) => '$e').toList();
num get price => detail['price'] as num? ?? 0;
num get marketPrice => detail['marketPrice'] as num? ?? 0;
bool get showMarketPrice => detail['showMarketPrice'] == true && marketPrice > 0;
String get title => '${detail['title'] ?? ''}';
String get introduction => '${detail['introduction'] ?? ''}';
String get labelName => '${detail['labelName'] ?? ''}';
String get content => '${detail['content'] ?? ''}';
num get saleNum => detail['saleNum'] as num? ?? 0;
num get stock => detail['stock'] as num? ?? 0;
bool get showSale => detail['showSale'] == true;
bool get showStock => detail['showStock'] == true;
bool get isFreeShipping => detail['isFreeShipping'] == true;
bool get isCollect => detail['isCollect'] == true;
bool get onSale => detail['onSale'] == true;
List<dynamic> get couponList => (detail['couponList'] as List? ?? const []);
List<dynamic> get specGroups => (detail['specGroups'] as List? ?? const []);
/// 规格属性(商品参数)
List<dynamic> get attrList => (detail['attrList'] as List? ?? const []);
Map<String, dynamic> get expressType => (detail['expressType'] as Map? ?? const {}).cast<String, dynamic>();

/// 金额格式化(保留两位)
String money(num value) => value.toStringAsFixed(2);

/// 券后价: 取第一张可用的满减券
num get couponPrice {
  for (final dynamic item in couponList) {
    if (item is! Map) continue;
    final num money = num.tryParse('${item['money'] ?? 0}') ?? 0;
    final num atLeast = num.tryParse('${item['at_least'] ?? 0}') ?? 0;
    if (money > 0 && price >= atLeast) return (price - money) < 0 ? 0 : price - money;
  }
  return price;
}

@override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: loading
      ? const Center(child: Loading(title: '加载中...'))
      : (errorMsg.isNotEmpty ? _buildError() : _buildContent()),
    // 商品导航栏(加载失败时不显示)
    bottomNavigationBar: (loading || errorMsg.isNotEmpty) ? null : _buildBottomBar(context),
  // 返回顶部
  floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}

/// 加载失败/空态
Widget _buildError() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10.0,
      children: [
        const Icon(Icons.inbox_outlined, color: Colors.grey, size: 40.0),
        Text(errorMsg, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
        TextButton(onPressed: loadDetail, child: const Text('重新加载')),
      ],
    ),
  );
}

Widget _buildContent() {
  return CustomScrollView(
      scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
      controller: scrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        pinned: true,
        expandedHeight: 280.0,
        titleSpacing: 10.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 20.0,),
          style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.black.withAlpha(20)),
        ),
        onPressed: () {
          Get.back();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(isCollect ? Icons.favorite : Icons.favorite_border, color: isCollect ? const Color(0xFFFF2C55) : Colors.white, size: 20.0,),
          onPressed: () => setState(() => detail = {...detail, 'isCollect': !isCollect}),
        ),
        IconButton(icon: Icon(Icons.share, size: 20.0,), onPressed: () {},),
      ],
      // 自定义伸缩区域(轮播图)
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF2C55), Color(0xFFFF9C55)
              ]
            )
          ),
          child: FlexibleSpaceBar(
              background: ScrollConfiguration(
                behavior: CustomScrollBehavior(),
              child: _buildSwiper(),
              ),
            ),
          ),
        ),
          SliverToBoxAdapter(
            child: ScrollConfiguration(
            behavior: CustomScrollBehavior().copyWith(scrollbars: false),
            child: Column(
              children: [
                _buildPriceBlock(),
              Container(
                padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
                ),
                transform: Matrix4.translationValues(0.0, -15.0, 0.0),
                child: Column(
                  children: [
                    _buildTitle(),
                    _buildPromotion(),
                    _buildEvaluate(),
                    _buildAttr(),
                    _buildDetail(),
                  ],
                ),
              ),
              // 底部按钮安全间距
              const SizedBox(height: 20.0),
              ],
            ),
            ),
          ),
        ],
      );
}

/// 顶部轮播(接口 images)
Widget _buildSwiper() {
  final List<String> list = images;
  if (list.isEmpty) {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40.0),
    );
  }
  return Swiper.children(
    pagination: SwiperPagination(
      alignment: .bottomRight,
      builder: DotSwiperPaginationBuilder(
        color: Colors.white70,
        activeColor: Colors.white,
        )
      ),
      indicatorLayout: PageIndicatorLayout.SCALE,
    children: list.map((String url) => CachedNetworkImage(
      imageUrl: url,
      placeholder: (context, url) => Container(color: Colors.grey[50]),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30.0),
      ),
      fit: BoxFit.cover,
    )).toList(),
  );
}

/// 价格区(价格 / 券后价 / 划线价)
Widget _buildPriceBlock() {
  return Container(
    padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 25.0),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF2C55), Color(0xFFFF9C55)
        ]
      )
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5.0,
      children: [
        Row(
        spacing: 5.0,
        children: [
          Text('¥${money(price)}', style: TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w700),),
          // 券后价
          if (couponPrice < price)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: Text('券后价¥${money(couponPrice)}', style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      Row(
        spacing: 8.0,
        children: [
          // 划线价
          if (showMarketPrice)
            Text('¥${money(marketPrice)}', style: TextStyle(color: Colors.white70, fontSize: 13.0, decoration: TextDecoration.lineThrough),),
          // 卖点/副标题
          if (introduction.isNotEmpty)
            Expanded(child: Text(introduction, style: TextStyle(color: Colors.white, fontSize: 12.0), maxLines: 1, overflow: TextOverflow.ellipsis,)),
        ],
      ),
      // 库存 / 销量
      if (showStock || showSale)
        Row(
          spacing: 8.0,
          children: <Widget>[
            if (showStock) _buildPriceMeta('库存${trimNum(stock)}件'),
            if (showStock && showSale)
              Container(width: 1.0, height: 9.0, color: Colors.white.withValues(alpha: 0.5)),
            if (showSale) _buildPriceMeta('销量${trimNum(saleNum)}件'),
          ],
        ),
      ],
    ),
  );
}

/// 价格区半透明小字(库存/销量)
Widget _buildPriceMeta(String text) {
  return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11.0));
}

/// 标题区(标签 + 商品名)
Widget _buildTitle() {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(10.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (labelName.isNotEmpty)
                TextSpan(text: ' $labelName ', style: TextStyle(fontSize: 12.0, backgroundColor: const Color(0xFFFF2C55), color: Colors.white)),
              TextSpan(text: title.isEmpty ? '商品名称' : ' $title', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700),),
            ]
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

/// 已选规格文本(来自 sku_spec_format)
String get selectedSpecText {
  final List<dynamic> specs = (detail['specFormat'] as List? ?? const []);
  if (specs.isEmpty) return '请选择规格';
  final List<String> names = specs
      .map((dynamic e) => '${(e is Map ? e['spec_value_name'] : '') ?? ''}')
      .where((String s) => s.isNotEmpty)
      .toList();
  if (names.isEmpty) return '请选择规格';
  return '商品规格/${names.join('/')}';
}

/// 配送方式文本
String get deliveryText {
  final List<String> names = <String>[];
  for (final String key in const <String>['express', 'store']) {
    final dynamic value = expressType[key];
    if (value is Map && '${value['name'] ?? ''}'.isNotEmpty) {
      names.add('${value['name']}');
    }
  }
  if (names.isEmpty) return '快递发货 · 门店自提';
  return names.join(' · ');
}



/// 单张券 chip(票券样式: 渐变底 + 左右齿孔), 点击打开券弹窗
Widget _buildCouponChip(Map item) {
  const double chipHeight = 24.0;
  const double notchSize = 6.0;
  final String amount = couponAmountText(item);
  final String condition = couponConditionText(item, short: true);
  return GestureDetector(
    onTap: _showCouponSheet,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          height: chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 7.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A45)],
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                amount,
                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w700),
              ),
              if (condition.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4.0),
                Container(width: 1.0, height: 9.0, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 4.0),
                Text(condition, style: const TextStyle(color: Colors.white, fontSize: 10.0)),
              ],
            ],
          ),
        ),
        // 左右齿孔(白卡背景色)
        Positioned(
          left: -notchSize / 2,
          top: (chipHeight - notchSize) / 2,
          child: _buildCouponNotch(notchSize),
        ),
        Positioned(
          right: -notchSize / 2,
          top: (chipHeight - notchSize) / 2,
          child: _buildCouponNotch(notchSize),
        ),
      ],
    ),
  );
}

Widget _buildCouponNotch(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size / 2),
    ),
  );
}

/// 打开优惠券弹窗
Future<void> _showCouponSheet() async {
  final List<Map> coupons = couponList.whereType<Map>().toList();
  if (coupons.isEmpty) return;
  fetchedCoupons = await showCouponSheet(context, coupons: coupons, fetched: fetchedCoupons);
  if (mounted) setState(() {});
}

/// 打开规格选择弹窗
/// * 单规格商品也弹窗(弹窗内可选购买数量), 不再直接下单
Future<void> _showSkuSheet({String? action}) async {
  final SkuSheetResult? result = await showSkuSheet(context, detail: detail);
  if (result == null) return;
  if (result.detail['skuId'] != detail['skuId']) {
    setState(() => detail = result.detail);
  }
  if (result.action == 'buy') {
    _goToOrderSure(num: result.num);
  } else if (result.action == 'cart') {
    await _addToCart(num: result.num);
  }
}

/// 加入购物车(/api/cart/add)
Future<void> _addToCart({int num = 1}) async {
  final int skuId = detail['skuId'] as int? ?? 0;
  if (skuId == 0) {
    Get.snackbar('提示', '商品规格有误,请重新选择');
    return;
  }
  if (addingCart) return;
  setState(() => addingCart = true);
  try {
    // 直播间加购: 带上房间号 sn; 非直播间进来时为空,不传该字段
    await CartApi.add(
      skuId: skuId,
      num: num,
      liveRoomId: liveRoomId.isEmpty ? null : liveRoomId,
    );
    if (!mounted) return;
    // 先乐观 +num 保证即时反馈,再用服务端真实值校正
    setState(() => cartNum += num);
    await loadCartNum();
  } catch (e) {
    Get.snackbar('提示', CartApi.errorMsg(e), snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  } finally {
    if (mounted) setState(() => addingCart = false);
  }
}

/// 跳转到订单确认
void _goToOrderSure({int num = 1}) {
  Get.toNamed('/order/ordersure', arguments: <String, dynamic>{
    'goodsId': detail['goodsId'],
    'skuId': detail['skuId'],
    'num': num,
    'title': title,
    'price': price,
    'image': images.isEmpty ? '' : images.first,
    // 直播间下单: 把房间号 sn 透传给结算页,再由它写进 orderCreateData.live_roomid
    'live_roomid': liveRoomId,
  });
}

/// 打开配送说明弹窗
Future<void> _showDeliverySheet() async {
  await showDeliverySheet(context, expressType: expressType);
}



/// 信息行(领券/规格/配送/适用门店)
Widget _buildInfoRow({required String label, required Widget content, VoidCallback? onTap, bool showArrow = true}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 45.0,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12.0), textAlign: TextAlign.center),
          ),
          Expanded(child: content),
          if (showArrow) const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0),
        ],
      ),
    ),
  );
}

/// 领券 / 选择规格 / 配送
Widget _buildPromotion() {
  final List<Widget> rows = <Widget>[];

  // 领券
  if (couponList.isNotEmpty) {
    rows.add(_buildInfoRow(
      label: '领券',
      onTap: _showCouponSheet,
      // 单行横向滚动: 券多时也不换行占满整行
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 12.0,
          children: couponList.whereType<Map>().map<Widget>((Map item) => _buildCouponChip(item)).toList(),
        ),
      ),
    ));
  }

  // 适用门店暂时隐藏(后续开放时去掉注释即可, 需同时放开 initState 里的 loadStore)
  // if (storeName.isNotEmpty) {
  //   rows.add(_buildInfoRow(
  //     label: '适用\n门店',
  //     onTap: () => Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': storeId}),
  //     content: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisSize: MainAxisSize.min,
  //       children: <Widget>[
  //         Text(storeName, style: const TextStyle(fontSize: 12.0, color: Colors.black87)),
  //         if (storeAddress.isNotEmpty) ...<Widget>[
  //           const SizedBox(height: 2.0),
  //           Text(
  //             storeAddress,
  //             style: const TextStyle(fontSize: 11.0, color: Colors.grey),
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ],
  //       ],
  //     ),
  //   ));
  // }

  // 选择规格(单规格商品没有可选规格, 点了也没用, 直接不展示)
  if (specGroups.isNotEmpty) {
    rows.add(_buildInfoRow(
      label: '选择',
      onTap: _showSkuSheet,
      content: Text(
        selectedSpecText,
        style: const TextStyle(fontSize: 12.0, color: Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ));
  }

  // 配送方式
  rows.add(_buildInfoRow(
    label: '配送',
    onTap: _showDeliverySheet,
    content: Text(
      deliveryText,
      style: const TextStyle(fontSize: 12.0, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  ));

  return Container(
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      spacing: 0.0,
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) FStyle.divider,
          rows[i],
        ],
      ],
    ),
  );
}

/// 规格属性(接口 goods_attr_format): 表格 + 展开收起
/// 商品评价(总数 + 前 2 条 + 查看全部)
Widget _buildEvaluate() {
  if (!evaluateShow) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => Get.toNamed('/goods/evaluate', arguments: <String, dynamic>{'goods_id': goodsId}),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: <Widget>[
              Text(
                '商品评价($evaluateCount)',
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const Spacer(),
              if (evaluateCount > 0) ...<Widget>[
                const Text('查看全部', style: TextStyle(fontSize: 12.0, color: FStyle.c999)),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12.0, color: FStyle.c999),
              ] else
                const Text('暂无评价', style: TextStyle(fontSize: 12.0, color: FStyle.c999)),
            ],
          ),
        ),
        ...evaluateList.map((Map<String, dynamic> item) => _buildEvaluateItem(item)),
      ],
    ),
  );
}

/// 评价条目(简版: 头像 + 昵称 + 星级 + 内容 + 图片)
Widget _buildEvaluateItem(Map<String, dynamic> item) {
  final List<String> images = GoodsEvaluateApi.imagesOf(item);
  final String headimg = GoodsEvaluateApi.headimgOf(item);
  final String content = '${item['content'] ?? ''}';
  return Padding(
    padding: const EdgeInsets.only(top: 10.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            ClipOval(
              child: headimg.isEmpty
                  ? Container(
                      width: 26.0,
                      height: 26.0,
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(Icons.person_outline, size: 16.0, color: Colors.grey),
                    )
                  : CachedNetworkImage(
                      imageUrl: headimg,
                      width: 26.0,
                      height: 26.0,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 26.0,
                        height: 26.0,
                        color: const Color(0xFFF0F0F0),
                        child: const Icon(Icons.person_outline, size: 16.0, color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                GoodsEvaluateApi.memberNameOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.0, color: Colors.black87),
              ),
            ),
            StarRating(score: item['scores'] as num? ?? 0, size: 12.0),
          ],
        ),
        if (content.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6.0),
          Text(content, style: const TextStyle(fontSize: 12.0, color: Colors.black87, height: 1.5)),
        ],
        if (images.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: images
                .map((String url) => ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 56.0,
                        height: 56.0,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 56.0,
                          height: 56.0,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 16.0),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    ),
  );
}

Widget _buildAttr() {
  final List<Map<String, String>> items = <Map<String, String>>[];
  for (final dynamic item in attrList) {
    if (item is! Map) continue;
    final String name = '${item['attr_name'] ?? ''}'.trim();
    // 多值用英文逗号分隔,展示时换成顿号
    final String value = '${item['attr_value_name'] ?? ''}'.trim().replaceAll(',', '、');
    if (name.isEmpty || value.isEmpty) continue;
    items.add(<String, String>{'name': name, 'value': value});
  }
  if (items.isEmpty) return const SizedBox.shrink();

  const int defaultRows = 5;
  final bool hasMore = items.length > defaultRows;
  final List<Map<String, String>> visibleItems =
      (attrExpanded || !hasMore) ? items : items.sublist(0, defaultRows);

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10.0,
      children: <Widget>[
        const Text('规格属性', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
            ),
            child: Table(
              columnWidths: const <int, TableColumnWidth>{
                0: FixedColumnWidth(90.0),
                1: FlexColumnWidth(),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
                verticalInside: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
              ),
              children: visibleItems.map<TableRow>((Map<String, String> item) => TableRow(
                children: <Widget>[
                  _buildAttrCell(item['name'] ?? '', color: Colors.grey),
                  _buildAttrCell(item['value'] ?? '', color: Colors.black87),
                ],
              )).toList(),
            ),
          ),
        ),
        if (hasMore)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => attrExpanded = !attrExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(attrExpanded ? '收起' : '展开', style: const TextStyle(fontSize: 13.0, color: Colors.black54)),
                  Icon(attrExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16.0, color: Colors.black54),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _buildAttrCell(String text, {required Color color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
    child: Text(text, style: TextStyle(fontSize: 13.0, color: color, height: 1.5)),
  );
}

/// 图文详情(接口 goods_content 为 HTML)
Widget _buildDetail() {
  return Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 10.0),
    padding: EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10.0,
      children: [
        const Text('商品详情', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
        content.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: const CommonEmpty(text: '暂无详情')),
            )
          : Html(
              data: content,
              shrinkWrap: true,
              style: {
                'body': Style(margin: Margins.zero, fontSize: FontSize(14.0)),
                'img': Style(width: Width(MediaQuery.of(context).size.width - 40.0)),
              },
            ),
      ],
    ),
  );
}

/// 底部操作栏(下架时按钮置灰)
Widget _buildBottomBar(BuildContext context) {
  final Color primary = const Color(0xFFFF2C55);
  final Color disabled = Colors.grey.shade400;
  final double bottomInset = MediaQuery.of(context).padding.bottom;
  return Container(
    color: Colors.white,
    padding: EdgeInsets.only(bottom: bottomInset),
    child: Container(
      height: 54.0,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
      children: [
      Expanded(
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.offAllNamed('/'),
            child: _buildBarIcon('assets/images/c1.png', '首页'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.toNamed('/chat'),
            child: _buildBarIcon('assets/images/c2.png', '客服'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.toNamed('/cart'),
            child: _buildBarIcon('assets/images/c3.png', '购物车', badge: cartNum),
          ),
        ],
      ),
      ),
      Container(
        alignment: Alignment.center,
      height: 36.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onSale ? const Color(0xFFFFEBEB) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSale ? (addingCart ? null : () => _showSkuSheet(action: 'cart')) : null,
              child: addingCart
                ? const SizedBox(
                    width: 14.0,
                    height: 14.0,
                    child: CircularProgressIndicator(color: Color(0xFFFF2C55), strokeWidth: 2.0),
                  )
                : Text('加入购物车', style: TextStyle(color: onSale ? primary : disabled, fontSize: 14.0),),
            ),
          ),
          GestureDetector(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              color: onSale ? primary : disabled,
              child: Text(onSale ? '领券购买' : '已下架', style: const TextStyle(color: Colors.white, fontSize: 14.0),),
            ),
            onTap: onSale ? () => _showSkuSheet(action: 'buy') : null,
          ),
        ],
      ),
      ),
      ],
    ),
    ),
  );
}

/// 底部操作栏图标(首页 / 客服 / 购物车): 用本地切图 assets/images/c1.png ~ c3.png
/// * [badge] > 0 时右上角显示数量红点(购物车)
Widget _buildBarIcon(String asset, String label, {int badge = 0}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            width: 22.0,
            height: 22.0,
            fit: BoxFit.contain,
            isAntiAlias: true,
            // 切图缺失时退化成同尺寸占位,避免红屏
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                const SizedBox(width: 22.0, height: 22.0),
          ),
          Text(label, style: TextStyle(fontSize: 12.0),)
        ],
      ),
      if (badge > 0)
        Positioned(
          right: -6.0,
          top: -2.0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16.0, minHeight: 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2C55),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.white, width: 1.0),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w600),
            ),
          ),
        ),
    ],
  );
}
}
