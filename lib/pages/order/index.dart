/// 订单列表
/// 对齐 H5: pages/order/list.vue + public/js/orderMethod.js
/// * /api/order/lists   列表(order_status: all/waitpay/waitsend/waitconfirm/wait_use)
/// * /api/order/pay     去支付(返回 out_trade_no)
/// * /api/order/close   取消订单
/// * /api/order/takedelivery 确认收货
/// * /api/order/delete  删除订单
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/popup_pay.dart';

class Order extends StatefulWidget {
  const Order({super.key});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> with SingleTickerProviderStateMixin {
  static const Color primary = Color(0xFFFF2C55);

  /// 订单状态: 与 H5 list.vue getOrderStatus 一致
  final List<Map<String, String>> tabList = <Map<String, String>>[
    <String, String>{'name': '全部', 'status': 'all'},
    <String, String>{'name': '待付款', 'status': 'waitpay'},
    <String, String>{'name': '待发货', 'status': 'waitsend'},
    <String, String>{'name': '待收货', 'status': 'waitconfirm'},
    <String, String>{'name': '待使用', 'status': 'wait_use'},
  ];

  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController tabController;
  late List<ScrollController> scrollControllers;

  // 每个状态各自的数据与分页状态
  late List<List<Map<String, dynamic>>> lists;
  late List<bool> loaded;
  late List<bool> loading;
  late List<bool> hasMore;
  late List<int> pages;
  late List<String> errors;

  /// 订单自动关闭时间(秒,取自列表接口 auto_close)
  int autoClose = 0;
  final TextEditingController searchCtrl = TextEditingController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);
    scrollControllers = List<ScrollController>.generate(tabList.length, (int index) {
      final ScrollController controller = ScrollController();
      controller.addListener(() => onScroll(index));
      return controller;
    });
    lists = List<List<Map<String, dynamic>>>.generate(tabList.length, (_) => <Map<String, dynamic>>[]);
    loaded = List<bool>.filled(tabList.length, false);
    loading = List<bool>.filled(tabList.length, false);
    hasMore = List<bool>.filled(tabList.length, true);
    pages = List<int>.filled(tabList.length, 1);
    errors = List<String>.filled(tabList.length, '');
    // 支持外部传入初始状态: Get.toNamed('/order', arguments: {'status': 'waitpay'})
    final dynamic args = Get.arguments;
    if (args is Map) {
      final int index = tabList.indexWhere((Map<String, String> e) => e['status'] == '${args['status'] ?? ''}');
      if (index > 0) tabController.index = index;
    }
    tabController.addListener(onTabChanged);
    load(refresh: true);
    // 待付款倒计时每秒刷新
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      if (tabList[currentIndex]['status'] == 'waitpay') setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    tabController.dispose();
    for (final ScrollController c in scrollControllers) {
      c.dispose();
    }
    searchCtrl.dispose();
    super.dispose();
  }

  int get currentIndex => tabController.index;

  void onTabChanged() {
    // 切到未加载过的状态时才请求,已加载的直接展示缓存
    if (tabController.indexIsChanging) return;
    if (!loaded[currentIndex]) load(refresh: true);
  }

  /// 滚动到底部加载下一页
  void onScroll(int index) {
    final ScrollController c = scrollControllers[index];
    if (c.position.extentAfter < 200 && hasMore[index] && !loading[index]) {
      load(index: index);
    }
  }

  /// 列表数据(/api/order/lists)
  Future<void> load({int? index, bool refresh = false}) async {
    final int i = index ?? currentIndex;
    if (loading[i]) return;
    if (refresh) {
      pages[i] = 1;
      hasMore[i] = true;
      errors[i] = '';
    }
    if (!hasMore[i]) return;
    setState(() => loading[i] = true);
    try {
      final Map<String, dynamic> data = await OrderApi.lists(
        page: pages[i],
        pageSize: 10,
        orderStatus: tabList[i]['status'] ?? 'all',
        searchText: searchCtrl.text.trim(),
      );
      if (!mounted) return;
      final List<Map<String, dynamic>> list = OrderApi.listOf(data);
      autoClose = int.tryParse('${data['auto_close'] ?? autoClose}') ?? autoClose;
      setState(() {
        if (refresh) {
          lists[i] = list;
        } else {
          lists[i] = <Map<String, dynamic>>[...lists[i], ...list];
        }
        pages[i] = pages[i] + 1;
        hasMore[i] = list.length >= 10;
        loading[i] = false;
        loaded[i] = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errors[i] = OrderApi.errorMsg(e, '订单加载失败');
        loading[i] = false;
        loaded[i] = true;
      });
    }
  }

  /// 搜索
  void onSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    for (int i = 0; i < tabList.length; i++) {
      loaded[i] = false;
      lists[i] = <Map<String, dynamic>>[];
    }
    load(refresh: true);
  }

  /// 订单详情
  void toDetail(Map<String, dynamic> item) {
    final int orderId = int.tryParse('${item['order_id'] ?? ''}') ?? 0;
    if (orderId <= 0) return;
    Get.toNamed('/order/detail', arguments: <String, dynamic>{'order_id': orderId})?.then((dynamic value) {
      // 详情内操作(取消/收货/支付)后回列表刷新
      load(refresh: true);
    });
  }

  /// 列表操作(H5 list.vue operation)
  Future<void> onAction(String action, Map<String, dynamic> item) async {
    final int orderId = int.tryParse('${item['order_id'] ?? ''}') ?? 0;
    switch (action) {
      case 'orderPay':
        await openPay(item);
        break;
      case 'orderClose':
        await confirmAction('您确定要关闭该订单吗？', () => OrderApi.close(orderId));
        break;
      case 'memberTakeDelivery':
        await confirmAction('您确定已经收到货物了吗？', () => OrderApi.takeDelivery(orderId));
        break;
      case 'orderDelete':
        await confirmAction('您确定要删除该订单吗？', () => OrderApi.delete(orderId));
        break;
      case 'memberOrderEvaluation':
        Get.toNamed('/order/evaluate', arguments: <String, dynamic>{'order_id': orderId})?.then((dynamic value) {
          load(refresh: true);
        });
        break;
      case 'trace':
        Get.toNamed('/order/logistics', arguments: <String, dynamic>{'order_id': orderId});
        break;
      default:
        toDetail(item);
    }
  }

  Future<void> confirmAction(String text, Future<void> Function() task) async {
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('操作提示', style: TextStyle(fontSize: 16.0)),
        content: Text(text, style: const TextStyle(fontSize: 14.0, color: Colors.black54)),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('确定', style: TextStyle(color: primary))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await task();
      MyDialog.toast('操作成功');
      await load(refresh: true);
    } catch (e) {
      MyDialog.toast(OrderApi.errorMsg(e, '操作失败'));
    }
  }

  /// 去支付: /api/order/pay 取支付单号后弹支付框
  Future<void> openPay(Map<String, dynamic> item) async {
    final int orderId = int.tryParse('${item['order_id'] ?? ''}') ?? 0;
    String outTradeNo = '${item['out_trade_no'] ?? ''}';
    if (outTradeNo.isEmpty) {
      try {
        outTradeNo = await OrderApi.pay(orderId);
      } catch (e) {
        MyDialog.toast(OrderApi.errorMsg(e, '获取支付信息失败'));
        return;
      }
    }
    if (outTradeNo.isEmpty) {
      MyDialog.toast('未获取到支付单号');
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: OrderApi.moneyOf(item['pay_money']),
          outTradeNo: outTradeNo,
          onChanged: (dynamic value) => MyDialog.toast('$value'),
        );
      },
    );
    await load(refresh: true);
  }

  Widget emptyTip() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5.0,
      children: <Widget>[
        SvgPicture.asset(
          'assets/images/svg/empty.svg',
          colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.srcIn),
          width: 40.0,
        ),
        const Text('还没有相关订单~', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        titleSpacing: 1.0,
        title: Container(
          height: 36.0,
          margin: const EdgeInsets.only(right: 5.0),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30.0)),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索订单',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14.0),
              prefixIcon: const Icon(Icons.search, color: Colors.black38, size: 21.0),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0)),
            ),
            cursorColor: Colors.black,
            textInputAction: TextInputAction.search,
            onSubmitted: (String value) => onSearch(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TabBar(
                  controller: tabController,
                  tabs: tabList
                      .map((Map<String, String> item) => SizedBox(
                            height: 45.0,
                            child: Center(child: Text(item['name'] ?? '')),
                          ))
                      .toList(),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  unselectedLabelColor: Colors.black87,
                  labelColor: primary,
                  indicator: const UnderlineTabIndicator(
                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                    borderSide: BorderSide(color: primary, width: 2.0),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  unselectedLabelStyle: const TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei'),
                  labelStyle: const TextStyle(fontSize: 18.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                  dividerHeight: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior().copyWith(scrollbars: false),
        child: Container(
          color: Colors.grey[50],
          child: TabBarView(
            controller: tabController,
            children: List<Widget>.generate(tabList.length, (int index) => _buildList(index)),
          ),
        ),
      ),
    );
  }

  Widget _buildList(int index) {
    final List<Map<String, dynamic>> list = lists[index];
    if (loading[index] && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)));
    }
    if (list.isEmpty) {
      return RefreshIndicator(
        color: primary,
        onRefresh: () => load(index: index, refresh: true),
        child: ListView(children: <Widget>[SizedBox(height: 260.0, child: emptyTip())]),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => load(index: index, refresh: true),
      child: ListView.builder(
        controller: scrollControllers[index],
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(10.0),
        itemCount: list.length + (hasMore[index] ? 1 : 0),
        itemBuilder: (BuildContext context, int i) {
          if (i >= list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: Text('加载中...', style: TextStyle(fontSize: 12.0, color: Colors.grey))),
            );
          }
          return _buildItem(list[i]);
        },
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final List<Map<String, dynamic>> goods = OrderApi.orderGoodsOf(item);
    final List<Map<String, dynamic>> actions = OrderApi.actionsOf(item);
    final String leftText = closeTimeText(item);
    return GestureDetector(
      onTap: () => toDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Colors.black.withAlpha(10), offset: const Offset(0.0, 1.0), blurRadius: 1.0, spreadRadius: 0.0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 订单号 / 订单类型 / 状态
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '订单号：${item['order_no'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888)),
                  ),
                ),
                if ('${item['order_type_name'] ?? ''}'.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                    decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3.0)),
                    child: Text('${item['order_type_name']}', style: const TextStyle(fontSize: 10.0, color: primary)),
                  ),
                ],
                const SizedBox(width: 6.0),
                Text('${item['order_status_name'] ?? ''}', style: const TextStyle(fontSize: 13.0, color: primary)),
              ],
            ),
            const SizedBox(height: 10.0),
            // 商品: 单商品展示名称,多商品横向图片
            if (goods.length == 1) _buildSingleGoods(goods.first) else _buildMultiGoods(goods),
            const SizedBox(height: 8.0),
            // 实付款
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (leftText.isNotEmpty) ...<Widget>[
                  const Icon(Icons.access_time, size: 13.0, color: Color(0xFFFF4644)),
                  const SizedBox(width: 2.0),
                  Flexible(
                    child: Text(
                      '剩余时间：$leftText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFFFF4644)),
                    ),
                  ),
                  const Spacer(),
                ],
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: '实付款：'),
                      TextSpan(
                        text: '¥${OrderApi.moneyOf(item['order_money'], OrderApi.moneyOf(item['pay_money'])).toStringAsFixed(2)}',
                        style: const TextStyle(color: primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.isEmpty
                  ? <Widget>[_buildButton('查看详情', false, () => toDetail(item))]
                  : actions.map((Map<String, dynamic> action) {
                      final String name = '${action['action'] ?? ''}';
                      final bool main = name == 'orderPay' || name == 'memberTakeDelivery';
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: _buildButton('${action['title'] ?? ''}', main, () => onAction(name, item)),
                      );
                    }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleGoods(Map<String, dynamic> goods) {
    final String image = '${goods['sku_image'] ?? ''}';
    final String spec = OrderApi.specTextOf(goods['sku_spec_format']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: image.isEmpty
              ? Container(width: 70.0, height: 70.0, color: const Color(0xFFF5F5F5))
              : CachedNetworkImage(imageUrl: image, width: 70.0, height: 70.0, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${goods['sku_name'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.0),
                ),
                if (spec.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                  ),
                Row(
                  children: <Widget>[
                    Text('¥${OrderApi.moneyOf(goods['price']).toStringAsFixed(2)}',
                        style: const TextStyle(color: primary, fontSize: 13.0, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('x${goods['num'] ?? 1}', style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiGoods(List<Map<String, dynamic>> goods) {
    return SizedBox(
      height: 70.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: goods.length,
        separatorBuilder: (_, int index) => const SizedBox(width: 8.0),
        itemBuilder: (BuildContext context, int i) {
          final String image = '${goods[i]['sku_image'] ?? ''}';
          return ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: image.isEmpty
                ? Container(width: 70.0, height: 70.0, color: const Color(0xFFF5F5F5))
                : CachedNetworkImage(imageUrl: image, width: 70.0, height: 70.0, fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  Widget _buildButton(String text, bool filled, VoidCallback onTap) {
    return SizedBox(
      height: 28.0,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? primary : Colors.white,
          foregroundColor: filled ? Colors.white : const Color(0xFF666666),
          side: BorderSide(color: filled ? primary : const Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 12.0)),
      ),
    );
  }

  /// 待付款剩余时间: create_time + auto_close
  String closeTimeText(Map<String, dynamic> item) {
    if ('${item['order_status'] ?? ''}' != '0' || autoClose <= 0) return '';
    final int createTime = int.tryParse('${item['create_time'] ?? 0}') ?? 0;
    if (createTime <= 0) return '';
    final int left = createTime + autoClose - (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (left <= 0) return '';
    final int h = left ~/ 3600;
    final int m = (left % 3600) ~/ 60;
    final int s = left % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
