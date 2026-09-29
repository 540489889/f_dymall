/// 确认订单
/// 接口与字段对齐 H5: pages/order/payment.vue + components/common-payment
/// * /api/ordercreate/payment   结算数据(goods_list / delivery.express_type / member_address)
/// * /api/ordercreate/calculate 金额计算(pay_money / goods_money / delivery_money ...)
/// * /api/ordercreate/create    创建订单(返回 out_trade_no)
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';
import '../../components/popup_pay.dart';
import '../../config/index.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import '../my/address_list.dart';

class OrderSure extends StatefulWidget {
  const OrderSure({ super.key });
  @override
  State<OrderSure> createState() => _OrderSureState();
}

class _OrderSureState extends State<OrderSure> {
  // 主色(图标/按钮/金额统一用这个色, 不再单独用蓝色)
  static const Color primary = Color(0xFFFF2C55);
  final AuthStore authStore = AuthStore.to;

  // 下单参数(与 H5 orderCreateData 一致)
  Map<String, dynamic> orderCreateData = <String, dynamic>{};
  // 下单接口前缀: 普通 OrderApi.api / 秒杀 OrderApi.seckillApi
  String apiPrefix = OrderApi.api;
  // 结算数据(/api/ordercreate/payment)
  Map<String, dynamic> paymentData = <String, dynamic>{};
  // 计算结果(/api/ordercreate/calculate)
  Map<String, dynamic> calcData = <String, dynamic>{};
  // 商品列表(优先取计算结果)
  List<Map<String, dynamic>> goodsList = <Map<String, dynamic>>[];
  // 配送方式列表: delivery.express_type
  List<Map<String, dynamic>> expressTypes = <Map<String, dynamic>>[];
  // 当前配送方式: express / store / local
  String deliveryType = OrderApi.express;
  // 当前配送方式下的门店
  List<Map<String, dynamic>> storeList = <Map<String, dynamic>>[];
  int storeId = 0;
  Map<String, dynamic>? storeInfo;
  // 收货地址(快递发货)
  Map<String, dynamic>? memberAddress;
  // 可用优惠券
  List<Map<String, dynamic>> couponList = <Map<String, dynamic>>[];
  // 购买须知(/api/order/transactionagreement)
  Map<String, dynamic> agreement = <String, dynamic>{};
  // 提货时间文案
  String deliveryTime = '';
  // 状态
  bool loading = true;
  bool submitting = false;
  String errorMsg = '';

  // 自提联系人(门店自提/同城配送时提交)
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController mobileCtrl = TextEditingController();
  TextEditingController messageCtrl = TextEditingController();

  bool get isStore => deliveryType == OrderApi.store;

  /// 可用门店id集合(/api/store/getStorePage 的 store_ids 参数)
  String get availableStoreIds {
    final dynamic ids = paymentData['available_store_ids'];
    if (ids is List) return ids.join(',');
    return '${ids ?? ''}';
  }

  // ===== 金额(取自计算结果) =====
  num get payMoney => OrderApi.moneyOf(calcData['pay_money']);
  num get goodsMoney => OrderApi.moneyOf(calcData['goods_money']);
  num get deliveryMoney => OrderApi.moneyOf(calcData['delivery_money']);
  num get couponMoney => OrderApi.moneyOf(calcData['coupon_money']);
  num get pointMoney => OrderApi.moneyOf(calcData['point_money']);
  num get promotionMoney => OrderApi.moneyOf(calcData['promotion_money']);

  @override
  void initState() {
    super.initState();
    initArgs();
    loadPayment();
    loadAgreement();
  }

  /// 入参: 购物车结算 cart_ids(逗号拼接) / 立即购买 sku_id + num
  void initArgs() {
    final dynamic args = Get.arguments;
    String cartIds = '';
    int? skuId;
    int? num;
    int? seckillId;
    if (args is Map) {
      cartIds = '${args['cart_ids'] ?? ''}';
      if (cartIds.isEmpty && args['cartIds'] is List) cartIds = (args['cartIds'] as List).join(',');
      skuId = int.tryParse('${args['sku_id'] ?? args['skuId'] ?? ''}');
      num = int.tryParse('${args['num'] ?? ''}');
      seckillId = int.tryParse('${args['seckill_id'] ?? args['seckillId'] ?? ''}');
    }
    // 秒杀下单走 /seckill/api/ordercreate/*(H5 pages_promotion/seckill/payment.vue)
    apiPrefix = seckillId == null ? OrderApi.api : OrderApi.seckillApi;
    orderCreateData = OrderApi.createData(
      cartIds: cartIds.isEmpty ? null : cartIds,
      skuId: skuId,
      num: num,
      seckillId: seckillId,
    );
  }

  /// 热重载时 State 实例会保留但新增字段为未初始化状态,这里重建避免读取报错
  @override
  void reassemble() {
    super.reassemble();
    loading = true;
    submitting = false;
    errorMsg = '';
    paymentData = <String, dynamic>{};
    calcData = <String, dynamic>{};
    goodsList = <Map<String, dynamic>>[];
    expressTypes = <Map<String, dynamic>>[];
    storeList = <Map<String, dynamic>>[];
    couponList = <Map<String, dynamic>>[];
    agreement = <String, dynamic>{};
    deliveryType = OrderApi.express;
    storeId = 0;
    storeInfo = null;
    memberAddress = null;
    deliveryTime = '';
    nameCtrl = TextEditingController();
    mobileCtrl = TextEditingController();
    messageCtrl = TextEditingController();
    initArgs();
    loadPayment();
    loadAgreement();
  }

  /// 购买须知(/api/order/transactionagreement)
  Future<void> loadAgreement() async {
    try {
      final Map<String, dynamic> data = await OrderApi.transactionAgreement();
      if (!mounted || data.isEmpty) return;
      setState(() {
        agreement = data;
      });
    } catch (_) {
      // 购买须知加载失败不阻断下单
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  /// 是否有下单来源参数(cart_ids 或 sku_id)
  bool get hasBuyParams =>
      orderCreateData['cart_ids'] != null || orderCreateData['sku_id'] != null;

  /// 结算数据(/api/ordercreate/payment)
  Future<void> loadPayment() async {
    if (!hasBuyParams) {
      setState(() {
        loading = false;
        errorMsg = '缺少下单参数,请从商品详情或购物车下单';
      });
      return;
    }
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await OrderApi.payment(orderCreateData, prefix: apiPrefix);
      if (!mounted) return;
      paymentData = data;
      orderCreateData['order_key'] = '${data['order_key'] ?? ''}';
      final List<Map<String, dynamic>> types = OrderApi.expressTypesOf(data);
      if (types.isNotEmpty) expressTypes = types;
      // 保持已选配送方式(仍可用时),否则取后台第一个
      final Map<String, dynamic> current = expressTypes.firstWhere(
        (Map<String, dynamic> e) => '${e['name']}' == deliveryType,
        orElse: () => expressTypes.isEmpty ? <String, dynamic>{} : expressTypes.first,
      );
      applyDeliveryType(
        '${current['name'] ?? OrderApi.express}',
        title: '${current['title'] ?? ''}',
        memberAccount: data['member_account'],
      );
      await loadCouponList();
      await calc();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = OrderApi.errorMsg(e, '结算信息加载失败');
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /// 金额计算(/api/ordercreate/calculate)
  Future<void> calc() async {
    try {
      final Map<String, dynamic> data = await OrderApi.calculate(orderCreateData, prefix: apiPrefix);
      if (!mounted) return;
      setState(() {
        calcData = data;
        final List<Map<String, dynamic>> list = OrderApi.goodsListOf(data);
        goodsList = list.isNotEmpty ? list : OrderApi.goodsListOf(paymentData);
        final dynamic delivery = data['delivery'];
        if (delivery is Map) {
          final dynamic address = delivery['member_address'];
          if (address is Map) memberAddress = address.cast<String, dynamic>();
          final int id = _intOf(delivery['store_id']);
          if (id > 0) storeId = id;
        }
        // 后台重新匹配的优惠券
        if (data.containsKey('coupon_id')) {
          orderCreateData['coupon'] = <String, dynamic>{'coupon_id': _intOf(data['coupon_id'])};
        }
      });
    } catch (e) {
      MyDialog.toast(OrderApi.errorMsg(e, '金额计算失败'));
    }
  }

  /// 可用优惠券(/api/ordercreate/getcouponlist),并自动匹配第一张
  Future<void> loadCouponList() async {
    try {
      final List<Map<String, dynamic>> list = await OrderApi.couponList(orderCreateData, prefix: apiPrefix);
      if (!mounted) return;
      couponList = list;
      orderCreateData['coupon'] = <String, dynamic>{
        'coupon_id': list.isEmpty ? 0 : _intOf(list.first['coupon_id']),
      };
    } catch (_) {
      // 优惠券加载失败不阻断下单
    }
  }

  /// 应用配送方式(与 H5 selectDeliveryType 一致)
  void applyDeliveryType(String type, { String? title, dynamic memberAccount }) {
    final Map<String, dynamic> cfg = expressTypes.firstWhere(
      (Map<String, dynamic> e) => '${e['name']}' == type,
      orElse: () => <String, dynamic>{},
    );
    deliveryType = type;
    storeList = OrderApi.storeListOf(cfg);
    storeInfo = null;
    deliveryTime = '';
    final Map<String, dynamic> delivery = <String, dynamic>{
      'delivery_type': type,
      'delivery_type_name': title ?? '${cfg['title'] ?? ''}',
      'buyer_ask_delivery_time': <String, String>{'start_date': '', 'end_date': ''},
    };
    if (type == OrderApi.store || type == OrderApi.local) {
      if (storeList.isNotEmpty) {
        storeId = _intOf(storeList.first['store_id']);
        storeInfo = storeList.first;
        delivery['store_id'] = storeId;
      }
      // 自提/同城需预留联系人: 默认取会员资料
      final dynamic account = memberAccount is Map ? memberAccount : <String, dynamic>{};
      final String name = '${account['nickname'] ?? ''}'.trim().isNotEmpty ? '${account['nickname']}' : authStore.nickname;
      final String mobile = '${account['mobile'] ?? ''}'.trim().isNotEmpty ? '${account['mobile']}' : authStore.mobile;
      orderCreateData['member_address'] = <String, dynamic>{'name': name, 'mobile': mobile};
      // 已填写过则不覆盖用户输入
      if (nameCtrl.text.trim().isEmpty) nameCtrl.text = name;
      if (mobileCtrl.text.trim().isEmpty) mobileCtrl.text = mobile;
    }
    orderCreateData['delivery'] = delivery;
  }

  /// 切换配送方式
  Future<void> switchDeliveryType(String type, String title) async {
    if (deliveryType == type) return;
    applyDeliveryType(type, title: title, memberAccount: paymentData['member_account']);
    setState(() {});
    await loadPayment();
  }

  /// 选择自提门店
  Future<void> selectStore(Map<String, dynamic> store) async {
    final int id = _intOf(store['store_id']);
    if (id <= 0 || id == storeId) return;
    storeId = id;
    storeInfo = store;
    final dynamic delivery = orderCreateData['delivery'];
    if (delivery is Map) {
      delivery['store_id'] = id;
      delivery['buyer_ask_delivery_time'] = <String, String>{'start_date': '', 'end_date': ''};
    }
    deliveryTime = '';
    setState(() {});
    await loadPayment();
  }

  /// 选择优惠券
  Future<void> selectCoupon(int couponId) async {
    final int current = _intOf((orderCreateData['coupon'] as Map?)?['coupon_id']);
    final int id = current == couponId ? 0 : couponId;
    orderCreateData['coupon'] = <String, dynamic>{'coupon_id': id};
    setState(() {});
    await calc();
  }

  /// 门店可提货时段(对齐 H5 storetime)
  /// * delivery_time: [{start_time, end_time}],值为当天秒数,可能是 JSON 字符串
  /// * 未配置时退回门店 start_time / end_time
  List<Map<String, int>> _timeRangesOf(Map<String, dynamic> store) {
    dynamic raw = store['delivery_time'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = null;
      }
    }
    final List<Map<String, int>> ranges = <Map<String, int>>[];
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is! Map) continue;
        final int start = int.tryParse('${item['start_time'] ?? ''}') ?? -1;
        final int end = int.tryParse('${item['end_time'] ?? ''}') ?? -1;
        if (start >= 0 && end > start) ranges.add(<String, int>{'start': start, 'end': end});
      }
    }
    if (ranges.isEmpty) {
      final int start = int.tryParse('${store['start_time'] ?? ''}') ?? 32400; // 09:00
      final int end = int.tryParse('${store['end_time'] ?? ''}') ?? 75600; // 21:00
      if (end > start) ranges.add(<String, int>{'start': start, 'end': end});
    }
    return ranges;
  }

  /// 可提货星期(time_type: 0每天 1按周 time_week)
  List<int> _timeWeekOf(Map<String, dynamic> store) {
    final int type = int.tryParse('${store['time_type'] ?? ''}') ?? 0;
    if (type == 0) return <int>[0, 1, 2, 3, 4, 5, 6];
    dynamic raw = store['time_week'];
    if (raw is String && raw.trim().isNotEmpty) raw = raw.split(',');
    final List<int> week = <int>[];
    if (raw is List) {
      for (final dynamic item in raw) {
        final int? day = int.tryParse('$item'.trim());
        if (day != null) week.add(day);
      }
    }
    return week;
  }

  /// 秒数转 HH:mm(与 H5 $util.getTimeStr 一致)
  String _hm(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 某天的可选时段(对齐 H5 ns-select-time toTime)
  /// * 当天从当前时刻开始生成(过滤已过时段)
  List<String> _periodsOf(
    DateTime day,
    List<Map<String, int>> ranges,
    int interval,
    DateTime now,
    int advanceDay,
  ) {
    final bool isToday = advanceDay == 0 && day.year == now.year && day.month == now.month && day.day == now.day;
    final int nowSeconds = now.hour * 3600 + now.minute * 60;
    final List<String> list = <String>[];
    for (final Map<String, int> range in ranges) {
      final int start = range['start']!;
      final int end = range['end']!;
      int time = start;
      if (isToday && nowSeconds > start) time = nowSeconds;
      while (time + interval <= end) {
        list.add('${_hm(time)}-${_hm(time + interval)}');
        time += interval;
      }
    }
    return list;
  }

  /// 选择提货时间(门店自提): 写入 delivery.buyer_ask_delivery_time
  /// 对齐 H5 components/ns-select-time/ns-select-time.vue + payment.js storetime/selectPickupTime
  Future<void> pickDeliveryTime() async {
    final Map<String, dynamic> store = storeInfo ?? <String, dynamic>{};
    if (store.isEmpty) {
      MyDialog.toast('请先选择提货门店');
      return;
    }
    final List<Map<String, int>> ranges = _timeRangesOf(store);
    if (ranges.isEmpty) {
      MyDialog.toast('该门店未配置提货时间');
      return;
    }
    final int interval = (int.tryParse('${store['time_interval'] ?? ''}') ?? 20) * 60; // 默认20分钟
    final int advanceDay = int.tryParse('${store['advance_day'] ?? ''}') ?? 0; // 提前天数
    final int mostDay = int.tryParse('${store['most_day'] ?? ''}') ?? 0; // 最多可预约天数
    final List<int> week = _timeWeekOf(store);
    final DateTime now = DateTime.now();
    final int nowSeconds = now.hour * 3600 + now.minute * 60;
    // 可预约日期(H5 toDay)
    final List<DateTime> days = <DateTime>[];
    final int maxDays = mostDay > 0 ? mostDay : 7;
    for (int i = 0; i < maxDays; i++) {
      final DateTime item = DateTime(now.year, now.month, now.day).add(Duration(days: advanceDay + i));
      if (week.isNotEmpty && !week.contains(item.weekday % 7)) continue;
      // 今天已过最晚可提货时间则跳过
      if (i == 0 && advanceDay == 0 && ranges.last['end']! - interval < nowSeconds) continue;
      days.add(item);
    }
    if (days.isEmpty) {
      MyDialog.toast('该门店暂无可预约时间');
      return;
    }
    int dayIndex = 0;
    int periodIndex = 0;
    List<String> periods = _periodsOf(days.first, ranges, interval, now, advanceDay);
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                // 限制弹窗最大高度为屏幕 70%, 中间时间列表自适应剩余空间, 避免底部溢出
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 12.0),
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        const Text('选择提货时间', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 18.0, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 104.0,
                            color: const Color(0xFFF8F8F8),
                            child: ListView.builder(
                              itemCount: days.length,
                              itemBuilder: (BuildContext context, int index) {
                                final DateTime item = days[index];
                                final bool active = index == dayIndex;
                                final String title = index == 0
                                    ? (advanceDay == 0 ? '今天' : '')
                                    : (index == 1 && advanceDay == 0 ? '明天' : '');
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setSheetState(() {
                                      dayIndex = index;
                                      periodIndex = 0;
                                      periods = _periodsOf(item, ranges, interval, now, advanceDay);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    color: active ? Colors.white : Colors.transparent,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${title.isNotEmpty ? '$title\n' : ''}${item.month}月${item.day}日',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13.0, height: 1.35, color: active ? primary : Colors.black54),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: periods.isEmpty
                                ? const Center(child: const CommonEmpty(text: '当天暂无可预约时段'))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    itemCount: periods.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final bool active = index == periodIndex;
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setSheetState(() => periodIndex = index),
                                        child: Container(
                                          height: 46.0,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          child: Text(
                                            periods[index],
                                            style: TextStyle(fontSize: 13.0, color: active ? primary : Colors.black87),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 16.0),
                      child: FilledButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(primary),
                          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 42.0)),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确定'),
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
    if (ok != true || periods.isEmpty) return;
    final DateTime day = days[dayIndex];
    final String period = periods[periodIndex.clamp(0, periods.length - 1)];
    final List<String> range = period.split('-');
    final dynamic delivery = orderCreateData['delivery'];
    if (delivery is Map) {
      // 与 H5 一致: 提交 "YYYY-M-D HH:mm" 字符串,不是时间戳
      delivery['buyer_ask_delivery_time'] = <String, String>{
        'start_date': '${day.year}-${day.month}-${day.day} ${range.first}',
        'end_date': '${day.year}-${day.month}-${day.day} ${range.last}',
      };
    }
    setState(() {
      deliveryTime = '${day.month}月${day.day}日($period)';
    });
  }

  /// 提交前校验(与 H5 verify 一致)
  bool verify() {
    if (deliveryType == OrderApi.express && memberAddress == null) {
      MyDialog.toast('请先选择您的收货地址');
      return false;
    }
    if (isStore) {
      if (storeId <= 0) {
        MyDialog.toast('没有可提货的门店,请选择其他配送方式');
        return false;
      }
      final String mobile = mobileCtrl.text.trim();
      if (mobile.isEmpty) {
        MyDialog.toast('请输入预留手机');
        return false;
      }
      if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
        MyDialog.toast('请输入正确的手机号');
        return false;
      }
      if (deliveryTime.isEmpty) {
        MyDialog.toast('请选择提货时间');
        return false;
      }
    }
    return true;
  }

  /// 提交订单(/api/ordercreate/create)
  Future<void> submitOrder() async {
    if (!verify() || submitting) return;
    final dynamic delivery = orderCreateData['delivery'];
    if (delivery is Map) {
      final dynamic address = orderCreateData['member_address'];
      if (address is Map) {
        address['name'] = nameCtrl.text.trim();
        address['mobile'] = mobileCtrl.text.trim();
      }
    }
    orderCreateData['buyer_message'] = messageCtrl.text.trim();
    setState(() {
      submitting = true;
    });
    try {
      final String outTradeNo = await OrderApi.create(orderCreateData, prefix: apiPrefix);
      if (!mounted) return;
      if (outTradeNo.isEmpty) {
        MyDialog.toast('下单失败,未获取到支付单号');
        return;
      }
      // 与 H5 payment.js create() 一致: 0元订单直接进支付结果页,否则弹支付框
      if (payMoney <= 0) {
        MyDialog.toast('下单成功');
        Get.offNamed('/order/pay_result', arguments: <String, dynamic>{'code': outTradeNo});
        return;
      }
      submitPayDialog(outTradeNo);
    } catch (e) {
      MyDialog.toast(OrderApi.errorMsg(e, '下单失败'));
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  /// 支付弹窗
  void submitPayDialog([String outTradeNo = '']) {
    showModalBottomSheet(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: payMoney,
          outTradeNo: outTradeNo,
          onChanged: (dynamic value) {
            debugPrint('支付信息::: $value');
            MyDialog.toast('$value');
          },
          // 与 H5 payClose 一致: 支付弹窗关闭后跳订单详情
          onClosed: (int orderId) {
            if (orderId > 0) {
              Get.offNamed('/order/detail', arguments: <String, dynamic>{'order_id': orderId});
            } else {
              Get.offNamed('/order');
            }
          },
        );
      },
    );
  }

  /// 费用明细
  void showMoneyDetail() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12.0),
              const Text('费用明细', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6.0),
              _buildMoneyRow('商品金额', '¥${goodsMoney.toStringAsFixed(2)}', Colors.black87),
              if (deliveryMoney > 0) _buildMoneyRow('运费', '¥${deliveryMoney.toStringAsFixed(2)}', Colors.black87),
              if (promotionMoney > 0) _buildMoneyRow('满减优惠', '-¥${promotionMoney.toStringAsFixed(2)}', primary),
              if (couponMoney > 0) _buildMoneyRow('优惠券', '-¥${couponMoney.toStringAsFixed(2)}', primary),
              if (pointMoney > 0) _buildMoneyRow('积分抵扣', '-¥${pointMoney.toStringAsFixed(2)}', primary),
              FStyle.divider,
              _buildMoneyRow('实付金额', '¥${payMoney.toStringAsFixed(2)}', primary),
              const SizedBox(height: 12.0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoneyRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.0, color: Colors.black87))),
          Text(value, style: TextStyle(fontSize: 13.0, color: color, fontWeight: FontWeight.w600)),
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
        icon: Icon(Icons.arrow_back_ios_rounded, size: 20.0,),
        onPressed: () {
          Get.back();
        },
      ),
      title: Text('确认订单', style: TextStyle(fontSize: 18.0),),
    ),
    body: _buildBody(),
      // 商品导航栏
      bottomNavigationBar: Container(
        height: 50.0,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        children: [
      Expanded(
        child: Row(
      children: [
        Text('在线付 ', style: TextStyle(fontSize: 12.0),),
        Text('¥${payMoney.toStringAsFixed(2)}', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 16.0, fontFamily: 'Arial'),),
        Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: showMoneyDetail,
          child: Row(
            spacing: 2.0,
            children: [
              Text('费用明细', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),),
              Icon(Icons.arrow_drop_up, color: Color(0xFFFF2C55), size: 18.0,),
            ],
          ),
        ),
      ],
      ),
    ),
    SizedBox(width: 10.0,),
    GestureDetector(
      child: Container(
        alignment: Alignment.center,
        height: 36.0,
        width: 120.0,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color(0xFFFF2C55),
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Text(submitting ? '提交中...' : '立即支付', style: TextStyle(color: Colors.white, fontSize: 14.0),),
        ),
        onTap: submitting ? null : submitOrder,
        ),
      ],
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: Loading());
    }
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
            const SizedBox(height: 12.0),
            OutlinedButton(onPressed: loadPayment, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.zero,
      children: [
        // 配送方式切换(后台返回多种时展示)
        if (expressTypes.length > 1) _buildDeliveryTabs(),
        // 快递发货: 收货地址
        if (!isStore) _buildAddressCard(),
        // 门店自提: 门店 + 提货人
        if (isStore) _buildStoreCard(),
        if (isStore) _buildPickupFormCard(),
        // 商品信息
        _buildGoodsCard(),
        // 优惠券
        if (couponList.isNotEmpty) _buildCouponCard(),
        // 买家留言
        _buildMessageCard(),
        // 购买须知
        if ('${agreement['content'] ?? ''}'.isNotEmpty) _buildAgreementCard(),
        const SizedBox(height: 12.0),
      ],
        ),
      );
  }

  /// 卡片容器样式
  BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10.0),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x0A000000),
        offset: Offset(0.0, 1.0),
        blurRadius: 1.0,
        spreadRadius: 0.0,
      ),
    ],
  );

  /// 配送方式切换
  Widget _buildDeliveryTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: Row(
        spacing: 10.0,
        children: expressTypes.map((Map<String, dynamic> item) {
          final String type = '${item['name'] ?? ''}';
          final bool active = type == deliveryType;
          final Color color = active ? primary : Colors.black54;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => switchDeliveryType(type, '${item['title'] ?? ''}'),
              child: Container(
                height: 38.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFFF2F2) : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: active ? primary : Colors.transparent, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 5.0,
                  children: <Widget>[
                    Icon(
                      type == OrderApi.store ? Icons.storefront_outlined : Icons.local_shipping_outlined,
                      size: 16.0,
                      color: color,
                    ),
                    Text(
                      '${item['title'] ?? ''}',
                      style: TextStyle(fontSize: 14.0, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 选择收货地址(快递发货)
  /// 与 H5 一致: 跳地址列表,选中即设为默认地址,回传后重新结算(后台按默认地址算运费)
  Future<void> selectAddress() async {
    // 直接 push 页面实例(不走命名路由/登录中间件),避免被重定向
    final dynamic result = await Get.to<dynamic>(
      const AddressListPage(selectMode: true, type: 1, storeId: 0),
    );
    if (result is! Map) return;
    setState(() {
      memberAddress = result.cast<String, dynamic>();
    });
    await loadPayment();
  }

  /// 收货地址(快递发货)
  Widget _buildAddressCard() {
    final Map<String, dynamic> address = memberAddress ?? <String, dynamic>{};
    final String name = '${address['name'] ?? ''}';
    final String mobile = '${address['mobile'] ?? ''}';
    final String detail = '${address['full_address'] ?? ''}${address['address'] ?? ''}';
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectAddress,
        child: Row(
          spacing: 5.0,
          children: <Widget>[
            Icon(Icons.location_on_outlined, color: primary, size: 20.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (name.isNotEmpty || mobile.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          WidgetSpan(child: Text(name, style: TextStyle(fontSize: 16.0))),
                          WidgetSpan(child: SizedBox(width: 5.0)),
                          WidgetSpan(child: Text(mobile, style: TextStyle(color: Colors.grey, fontSize: 12.0))),
                        ]
                      ),
                    ),
                  Text(
                    detail.isEmpty ? '请设置收货地址' : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12.0),
          ],
        ),
      ),
    );
  }

  /// 自提门店
  Widget _buildStoreCard() {
    final Map<String, dynamic>? store = storeInfo;
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: Column(
        spacing: 8.0,
        children: <Widget>[
          Row(
            spacing: 5.0,
            children: <Widget>[
              Icon(Icons.storefront_outlined, size: 18.0, color: primary),
              Expanded(
                child: Text(
                  store == null ? '当前无自提门店,请选择其它配送方式' : '${store['store_name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700),
                ),
              ),
              // 切换门店功能暂时隐藏(后续开放时去掉注释即可)
              // if (storeList.length > 1)
              //   GestureDetector(
              //     behavior: HitTestBehavior.opaque,
              //     onTap: showStoreSheet,
              //     child: Row(
              //       spacing: 2.0,
              //       children: const <Widget>[
              //         Text('切换门店', style: TextStyle(fontSize: 12.0, color: primary)),
              //         Icon(Icons.arrow_forward_ios_rounded, size: 12.0, color: primary),
              //       ],
              //     ),
              //   ),
            ],
          ),
          if (store != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5.0,
              children: <Widget>[
                Icon(Icons.location_on_outlined, size: 16.0, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3.0,
                    children: <Widget>[
                      Text('${store['full_address'] ?? ''}${store['address'] ?? ''}', style: const TextStyle(fontSize: 13.0)),
                      if ('${store['open_date'] ?? ''}'.isNotEmpty)
                        Text('营业时间：${store['open_date']}', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 切换门店弹窗(门店列表来自 /api/store/getStorePage,分页加载)
  void showStoreSheet() {
    const int pageSize = 20;
    int page = 1;
    bool sheetLoading = false;
    bool hasMore = true;
    bool inited = false;
    List<Map<String, dynamic>> stores = List<Map<String, dynamic>>.from(storeList);

    /// 分页加载门店
    Future<void> loadPage(StateSetter setSheetState, {bool refresh = false}) async {
      if (sheetLoading) return;
      if (!refresh && !hasMore) return;
      sheetLoading = true;
      final int target = refresh ? 1 : page;
      try {
        final List<Map<String, dynamic>> list = await OrderApi.storePage(
          page: target,
          pageSize: pageSize,
          type: deliveryType,
          storeIds: availableStoreIds,
        );
        setSheetState(() {
          if (refresh) {
            stores = list;
          } else {
            stores.addAll(list);
          }
          hasMore = list.length >= pageSize;
          page = target + 1;
        });
      } catch (e) {
        MyDialog.toast(OrderApi.errorMsg(e, '门店列表加载失败'));
      } finally {
        sheetLoading = false;
      }
    }

    showModalBottomSheet<void>(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // 首屏先用结算接口返回的门店占位,再用分页接口刷新
            if (!inited) {
              inited = true;
              Future<void>.microtask(() => loadPage(setSheetState, refresh: true));
            }
            return SafeArea(
              top: false,
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification.metrics.extentAfter < 200) loadPage(setSheetState);
                  return false;
                },
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 20.0),
                  itemCount: stores.isEmpty ? 1 : stores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                  itemBuilder: (BuildContext context, int index) {
                    if (stores.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.0),
                        child: Center(child: const CommonEmpty(text: '暂无可选门店')),
                      );
                    }
                    final Map<String, dynamic> store = stores[index];
              final bool active = _intOf(store['store_id']) == storeId;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  selectStore(store);
                },
                child: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: active ? primary : Colors.transparent, width: 1.0),
                  ),
                  child: Row(
                    spacing: 8.0,
                    children: <Widget>[
                      Icon(
                        active ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18.0,
                        color: active ? primary : Colors.grey,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3.0,
                          children: <Widget>[
                            Text('${store['store_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                            Text('${store['full_address'] ?? ''}${store['address'] ?? ''}', maxLines: 1,
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
                },
              ),
              ),
            );
          },
        );
      },
    );
  }

  /// 提货人信息(门店自提)
  Widget _buildPickupFormCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: Column(
        spacing: 10.0,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(constraints: BoxConstraints(minWidth: 80.0), child: Text('提货人')),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 14.0),
                  decoration: const InputDecoration(
                    hintText: '请输入提货人姓名',
                    hintStyle: TextStyle(color: Colors.grey),
                    isDense: true,
                    hoverColor: Colors.transparent,
                    contentPadding: EdgeInsets.all(0.0),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
              Icon(Icons.person_add_alt, color: primary, size: 18.0),
            ],
          ),
          FStyle.divider,
          Row(
            children: <Widget>[
              Container(constraints: BoxConstraints(minWidth: 80.0), child: Text('预留手机')),
              Expanded(
                child: TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14.0),
                  decoration: const InputDecoration(
                    hintText: '请输入手机号,到店核销使用',
                    hintStyle: TextStyle(color: Colors.grey),
                    isDense: true,
                    hoverColor: Colors.transparent,
                    contentPadding: EdgeInsets.all(0.0),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
              Icon(Icons.phone_android_outlined, color: primary, size: 18.0),
            ],
          ),
          FStyle.divider,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: pickDeliveryTime,
            child: Row(
              children: <Widget>[
                Container(constraints: BoxConstraints(minWidth: 80.0), child: Text('提货时间')),
                Expanded(
                  child: Text(
                    deliveryTime.isEmpty ? '请选择提货时间' : deliveryTime,
                    style: TextStyle(fontSize: 14.0, color: deliveryTime.isEmpty ? Colors.grey : Colors.black87),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 商品信息
  Widget _buildGoodsCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      decoration: cardDecoration,
      child: Column(
        spacing: 10.0,
        children: goodsList.map((Map<String, dynamic> item) {
          final String image = _imageUrl('${item['sku_image'] ?? ''}');
          final String spec = OrderApi.specTextOf(item['sku_spec_format']);
          final String errMsg = item['error'] is Map ? '${(item['error'] as Map)['message'] ?? ''}' : '';
          // 有规格/异常提示时标题只留一行,保证不超出图片高度
          final bool hasSub = spec.isNotEmpty || errMsg.isNotEmpty;
          final num price = OrderApi.moneyOf(item['price']);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10.0,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: image.isEmpty
                    ? Container(width: 80.0, height: 80.0, color: Colors.grey[200])
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 80.0,
                        height: 80.0,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext context, String url) => Container(width: 80.0, height: 80.0, color: Colors.grey[50]),
                        errorWidget: (BuildContext context, String url, Object error) => Container(width: 80.0, height: 80.0, color: Colors.grey[200]),
                      ),
              ),
              Expanded(
                child: SizedBox(
                  height: 80.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 文本区: 超出剩余高度时裁剪,避免整列溢出报错
                      Expanded(
                        child: ClipRect(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 3.0,
                            children: <Widget>[
                              Text('${item['sku_name'] ?? ''}',
                                maxLines: hasSub ? 1 : 2,
                                overflow: TextOverflow.ellipsis),
                              if (spec.isNotEmpty)
                                Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
                              if (errMsg.isNotEmpty)
                                Text(errMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.0, color: primary)),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Text('¥${price.toStringAsFixed(2)}', style: TextStyle(color: primary)),
                          const Spacer(),
                          Text('x${item['num'] ?? 1}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 优惠券
  Widget _buildCouponCard() {
    final int couponId = _intOf((orderCreateData['coupon'] as Map?)?['coupon_id']);
    final Map<String, dynamic> used = couponList.firstWhere(
      (Map<String, dynamic> e) => _intOf(e['coupon_id']) == couponId,
      orElse: () => <String, dynamic>{},
    );
    return Container(
      margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: InkWell(
        onTap: showCouponSheet,
        child: Row(
          children: <Widget>[
            Text('优惠券', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
            Spacer(),
            Text(
              used.isEmpty ? '${couponList.length}张可用' : '${used['coupon_name'] ?? '优惠券'}',
              style: TextStyle(fontSize: 12.0),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0),
          ],
        ),
      ),
    );
  }

  /// 优惠券选择弹窗
  void showCouponSheet() {
    showModalBottomSheet<void>(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 20.0),
            itemCount: couponList.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10.0),
            itemBuilder: (BuildContext context, int index) {
              final int couponId = index == 0 ? 0 : _intOf(couponList[index - 1]['coupon_id']);
              final bool active = couponId == _intOf((orderCreateData['coupon'] as Map?)?['coupon_id']);
              final String title = index == 0 ? '不使用优惠券' : '${couponList[index - 1]['coupon_name'] ?? '优惠券'}';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  selectCoupon(couponId);
                },
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: active ? primary : Colors.transparent, width: 1.0),
                  ),
                  child: Row(
                    spacing: 8.0,
                    children: <Widget>[
                      Icon(
                        active ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18.0,
                        color: active ? primary : Colors.grey,
                      ),
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 14.0))),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 买家留言
  Widget _buildMessageCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: Row(
        children: <Widget>[
          Container(constraints: BoxConstraints(minWidth: 80.0), child: Text('买家留言')),
          Expanded(
            child: TextField(
              controller: messageCtrl,
              style: const TextStyle(fontSize: 14.0),
              decoration: const InputDecoration(
                hintText: '选填: 对本次交易的说明',
                hintStyle: TextStyle(color: Colors.grey),
                isDense: true,
                hoverColor: Colors.transparent,
                contentPadding: EdgeInsets.all(0.0),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 购买须知入口
  Widget _buildAgreementCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: const EdgeInsets.all(10.0),
      width: double.infinity,
      decoration: cardDecoration,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showAgreement,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text('${agreement['title'] ?? '购买须知'}',
                style: const TextStyle(fontSize: 14.0)),
            ),
            const Icon(Icons.chevron_right, size: 18.0, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 购买须知弹窗(富文本)
  void showAgreement() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text('${agreement['title'] ?? '购买须知'}',
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
              ),
              FStyle.divider,
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(15.0),
                  child: Html(data: '${agreement['content'] ?? ''}'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 图片完整地址(相对路径拼接图片域名)
  String _imageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${Config.imgDomain}/$url';
  }

  static int _intOf(dynamic value) => OrderApi.moneyOf(value).toInt();
}
