/// 积分商城(积分兑换首页)
/// 对齐 H5: pages_promotion/point/list.vue
/// * 头部: 我的积分 + 提醒
/// * 菜单: 活动规则(弹层) / 兑换记录 / 积分明细
/// * 分区: 积分换券(type=2) · 积分换红包(type=3) · 积分换礼品(type=1,双列+加载更多)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

import '../../api/member_point.dart';
import '../../api/point_exchange.dart';
import '../../controller/auth_store.dart';

class PointShopPage extends StatefulWidget {
  const PointShopPage({super.key});

  @override
  State<PointShopPage> createState() => _PointShopPageState();
}

class _PointShopPageState extends State<PointShopPage> {
  static const Color primary = Color(0xFFF16914);
  static const int pageSize = 10;

  final ScrollController controller = ScrollController();
  final authStore = AuthStore.to;

  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 1;

  int point = 0;
  String rule = '';
  List<Map<String, dynamic>> couponList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> hongbaoList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> goodsList = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
    loadAll();
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

  /// 页面数据(H5 onLoad/onShow): 积分 + 券 + 红包 + 礼品
  Future<void> loadAll() async {
    page = 1;
    hasMore = true;
    try {
      await Future.wait(<Future<void>>[
        loadPoint(),
        loadList(type: PointExchangeApi.typeCoupon, size: 0),
        loadList(type: PointExchangeApi.typeHongbao, size: 0),
        loadList(type: PointExchangeApi.typeGoods),
      ]);
    } catch (_) {}
    if (!mounted) return;
    setState(() => loading = false);
  }

  /// 我的积分
  Future<void> loadPoint() async {
    final Map<String, dynamic> res = await MemberPointApi.point();
    if (!mounted) return;
    setState(() => point = int.tryParse('${res['point'] ?? 0}') ?? 0);
  }

  /// 兑换列表(H5 goods/page: 券与红包一次取全,礼品分页)
  Future<void> loadList({required int type, int size = pageSize, bool append = false}) async {
    final int currentPage = append ? page : 1;
    final Map<String, dynamic> res = await PointExchangeApi.goodsPage(
      page: currentPage,
      pageSize: size,
      type: type,
    );
    if (!mounted) return;
    final dynamic rows = res['list'];
    final List<Map<String, dynamic>> data = rows is List
        ? rows.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    final int pageCount = int.tryParse('${res['page_count'] ?? 0}') ?? 0;
    setState(() {
      switch (type) {
        case PointExchangeApi.typeCoupon:
          couponList = data;
          break;
        case PointExchangeApi.typeHongbao:
          hongbaoList = data;
          break;
        default:
          goodsList = append ? <Map<String, dynamic>>[...goodsList, ...data] : data;
          hasMore = pageCount == 0 ? data.length >= pageSize : currentPage < pageCount;
      }
    });
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    page += 1;
    try {
      await loadList(type: PointExchangeApi.typeGoods, size: pageSize, append: true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => loadingMore = false);
  }

  /// 跳需要登录的页面(H5 redirect)
  void redirect(String route) {
    if (!authStore.isLogin) {
      Get.toNamed('/login');
      return;
    }
    Get.toNamed(route);
  }

  /// 活动规则弹层(H5 openPointPopup)
  Future<void> openRule() async {
    if (rule.isEmpty) rule = await MemberPointApi.ruleConfig();
    if (!mounted) return;
    if (rule.isEmpty) rule = '暂无积分说明';
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
                    const Text('积分说明', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 20.0),
                  child: Html(data: rule, shrinkWrap: true),
                ),
              ),
            ],
          ),
        );
      },
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
        title: const Text('积分商城', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined, size: 20.0, color: primary),
            onPressed: () => redirect('/my/signin'),
          ),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary))) : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: primary,
      onRefresh: loadAll,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 16.0),
        children: <Widget>[
          _buildHead(),
          _buildMenu(),
          if (couponList.isNotEmpty) _buildSection('积分换券', _buildCouponRow()),
          if (hongbaoList.isNotEmpty) _buildSection('积分换红包', _buildHongbaoRow()),
          if (goodsList.isNotEmpty) _buildSection('积分换礼品', _buildGoodsGrid()),
          if (couponList.isEmpty && hongbaoList.isEmpty && goodsList.isEmpty) _buildEmpty(),
          _buildFooter(),
        ],
      ),
    );
  }

  /// 头部: 我的积分 + 提醒(H5 head-box)
  Widget _buildHead() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15.0, 20.0, 15.0, 24.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF16914), Color(0xFFFEAA4C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => redirect('/my/point'),
            child: Row(
              children: <Widget>[
                const Icon(Icons.stars_rounded, color: Colors.white, size: 20.0),
                const SizedBox(width: 6.0),
                const Text('我的积分', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                const SizedBox(width: 8.0),
                Text(
                  '$point',
                  style: const TextStyle(color: Colors.white, fontSize: 24.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                ),
                const SizedBox(width: 4.0),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 18.0),
              ],
            ),
          ),
          const SizedBox(height: 14.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4.0)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('提醒', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                SizedBox(width: 6.0),
                Text('积分兑好礼，每日上新换不停！', style: TextStyle(color: Colors.white, fontSize: 11.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 菜单: 活动规则 / 兑换记录 / 积分明细(H5 menu-list)
  Widget _buildMenu() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: <Widget>[
          _buildMenuItem(Icons.help_outline, '活动规则', openRule),
          _buildMenuItem(Icons.receipt_long_outlined, '兑换记录', () => redirect('/point/order_list')),
          _buildMenuItem(Icons.list_alt_outlined, '积分明细', () => redirect('/my/point_detail')),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.0),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: primary, size: 20.0),
            ),
            const SizedBox(height: 6.0),
            Text(title, style: const TextStyle(fontSize: 12.0, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }

  /// 分区标题(H5 card-category-title: 文字两侧横线)
  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          color: const Color(0xFFF5F5F5),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(width: 30.0, height: 1.0, color: const Color(0xFFDDDDDD)),
              const SizedBox(width: 8.0),
              Text(title, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
              const SizedBox(width: 8.0),
              Container(width: 30.0, height: 1.0, color: const Color(0xFFDDDDDD)),
            ],
          ),
        ),
        child,
      ],
    );
  }

  /// 券列表(横向)
  Widget _buildCouponRow() {
    return SizedBox(
      height: 92.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: couponList.length,
        itemBuilder: (BuildContext context, int index) => _buildCouponCard(couponList[index]),
      ),
    );
  }

  /// 券卡(H5 coupon: 金额/折扣 + 门槛 / 所需积分 + 兑换)
  Widget _buildCouponCard(Map<String, dynamic> item) {
    final String couponType = '${item['coupon_type'] ?? ''}';
    final num money = num.tryParse('${item['money'] ?? 0}') ?? 0;
    final num discount = num.tryParse('${item['discount'] ?? 0}') ?? 0;
    final num atLeast = num.tryParse('${item['at_least'] ?? 0}') ?? 0;
    final String amount = couponType == 'discount' && discount > 0
        ? '${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}折'
        : (money > 0 ? money.toStringAsFixed(money % 1 == 0 ? 0 : 2) : '0');
    final bool isMoney = !(couponType == 'discount' && discount > 0);
    final String condition = atLeast > 0 ? '满${atLeast.toStringAsFixed(0)}可用' : '无门槛优惠券';
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () => Get.toNamed('/point/detail', arguments: <String, dynamic>{'id': item['id']}),
        child: Container(
          width: 240.0,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[Color(0xFFF16914), Color(0xFFFFA54C)]),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          if (isMoney) const Text('¥', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                          Text(
                            amount,
                            style: const TextStyle(color: Colors.white, fontSize: 24.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(condition, style: const TextStyle(color: Colors.white70, fontSize: 11.0)),
                    ],
                  ),
                ),
              ),
              Container(width: 1.0, height: 60.0, color: Colors.white54),
              SizedBox(
                width: 78.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${item['point'] ?? 0}积分', style: const TextStyle(color: Colors.white, fontSize: 12.0)),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
                      child: const Text('兑换', style: TextStyle(color: primary, fontSize: 11.0, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 红包列表(横向)
  Widget _buildHongbaoRow() {
    return SizedBox(
      height: 92.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: hongbaoList.length,
        itemBuilder: (BuildContext context, int index) => _buildHongbaoCard(hongbaoList[index]),
      ),
    );
  }

  /// 红包卡(H5 hongbao: 面额 + 所需积分 + 兑换)
  Widget _buildHongbaoCard(Map<String, dynamic> item) {
    final num balance = num.tryParse('${item['balance'] ?? 0}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () => Get.toNamed('/point/detail', arguments: <String, dynamic>{'id': item['id']}),
        child: Container(
          width: 200.0,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[Color(0xFFFF5A5A), Color(0xFFFF8A5A)]),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      const Text('¥', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                      Text(
                        balance.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white, fontSize: 26.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1.0, height: 60.0, color: Colors.white54),
              SizedBox(
                width: 78.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${item['point'] ?? 0}积分', style: const TextStyle(color: Colors.white, fontSize: 12.0)),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
                      child: const Text('兑换', style: TextStyle(color: Color(0xFFFF5A5A), fontSize: 11.0, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 礼品双列网格(H5 goods-list double-column)
  Widget _buildGoodsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        childAspectRatio: 0.72,
      ),
      itemCount: goodsList.length,
      itemBuilder: (BuildContext context, int index) => _buildGoodsCard(goodsList[index]),
    );
  }

  /// 礼品卡(H5 goods-item: 图 / 名称 / 积分(+现金) / 库存·已兑 / 兑换)
  Widget _buildGoodsCard(Map<String, dynamic> item) {
    final int goodsPoint = int.tryParse('${item['point'] ?? 0}') ?? 0;
    final num price = num.tryParse('${item['price'] ?? 0}') ?? 0;
    final int payType = int.tryParse('${item['pay_type'] ?? 0}') ?? 0;
    final int stock = int.tryParse('${item['stock'] ?? 0}') ?? 0;
    final int saleNum = int.tryParse('${item['sale_num'] ?? 0}') ?? 0;
    final String image = PointExchangeApi.img('${item['image'] ?? ''}'.split(',').first);
    return InkWell(
      borderRadius: BorderRadius.circular(10.0),
      onTap: () => Get.toNamed('/point/detail', arguments: <String, dynamic>{'id': item['id']}),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF7F7F7),
                child: image.isEmpty
                    ? Icon(Icons.card_giftcard_outlined, color: Colors.grey.shade300, size: 40.0)
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext context, String url) => Container(color: const Color(0xFFF7F7F7)),
                        errorWidget: (BuildContext context, String url, Object error) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30.0),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${item['name'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333), height: 1.3),
                  ),
                  const SizedBox(height: 6.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '$goodsPoint',
                        style: const TextStyle(color: primary, fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                      ),
                      const SizedBox(width: 2.0),
                      const Text('积分', style: TextStyle(color: primary, fontSize: 11.0)),
                      if (price > 0 && payType > 0) ...<Widget>[
                        const SizedBox(width: 3.0),
                        Text('+¥${price.toStringAsFixed(2)}', style: const TextStyle(color: primary, fontSize: 11.0)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '库存${stock < 0 ? '充足' : stock} · 已兑$saleNum',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10.0)),
                        child: const Text('兑换', style: TextStyle(color: Colors.white, fontSize: 11.0)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80.0),
      child: Center(child: const CommonEmpty(text: '暂无可兑换的商品')),
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
}
