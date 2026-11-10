/// 积分兑换 - 确认订单
/// 对齐 H5: pages_promotion/point/payment.vue + public/js/payment.js
/// * 初始化 /pointexchange/api/ordercreate/payment({ id, sku_id, num })
/// * 变更(配送/地址/门店/时间)后 /pointexchange/api/ordercreate/calculate 重算
/// * 默认配送方式快递优先;自提/同城无门店时用 /api/store/getStorePage 补齐门店
/// * 门店自提展示对齐普通商品下单页(门店卡 + 提货人/预留手机/提货时间)
/// * 提交 /pointexchange/api/ordercreate/create -> 需付现金时拉起 PopupPay,否则直接完成
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';
import '../../api/point_exchange.dart';
import '../../components/popup_pay.dart';
import '../../controller/auth_store.dart';
import '../../pages/my/address_list.dart';
import '../../styles/index.dart';

class PointOrderConfirmPage extends StatefulWidget {
  const PointOrderConfirmPage({super.key});

  @override
  State<PointOrderConfirmPage> createState() => _PointOrderConfirmPageState();
}

class _PointOrderConfirmPageState extends State<PointOrderConfirmPage> {
  static const Color primary = Color(0xFFF16914);

  final TextEditingController messageCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();
  /// 提货人(门店自提,对齐普通商品下单页)
  final TextEditingController nameCtrl = TextEditingController();

  bool loading = true;
  bool submitting = false;
  String errorMsg = '';

  /// 下单数据(H5 orderCreateData)
  Map<String, dynamic> createData = <String, dynamic>{};
  /// 结算数据(H5 orderPaymentData)
  Map<String, dynamic> paymentData = <String, dynamic>{};

  /// 配送方式列表(delivery.express_type)
  List<Map<String, dynamic>> expressType = <Map<String, dynamic>>[];
  /// 当前提货门店(自提 / 同城配送,由结算数据指定,不允许切换)
  Map<String, dynamic> currStore = <String, dynamic>{};
  /// 收货地址(快递) / 自提人信息(门店)
  Map<String, dynamic> memberAddress = <String, dynamic>{};
  /// 选中的自提 / 送达时间文案(与普通商品下单页一致)
  String deliveryTime = '';

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      createData = <String, dynamic>{
        'id': int.tryParse('${args['id'] ?? 0}') ?? 0,
        'sku_id': int.tryParse('${args['sku_id'] ?? 0}') ?? 0,
        'num': int.tryParse('${args['num'] ?? 1}') ?? 1,
      };
    }
    if ((createData['id'] ?? 0) == 0) {
      loading = false;
      errorMsg = '未获取到创建订单所需数据';
      return;
    }
    loadPayment();
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    mobileCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  /* 结算数据快捷读取 */
  Map<String, dynamic> get exchangeInfo {
    final dynamic info = paymentData['exchange_info'];
    return info is Map ? info.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// 兑换类型(1 商品 / 2 优惠券 / 3 红包)
  int get type => int.tryParse('${exchangeInfo['type'] ?? 0}') ?? 0;

  /// 是否虚拟商品
  bool get isVirtual => '${paymentData['is_virtual'] ?? 0}' == '1';

  String get deliveryType => '${(createData['delivery'] is Map ? createData['delivery'] as Map : <String, dynamic>{})['delivery_type'] ?? ''}';

  /// 是否门店自提
  bool get isStore => deliveryType == 'store';

  int get goodsNum => int.tryParse('${paymentData['goods_num'] ?? createData['num'] ?? 1}') ?? 1;

  int get point => int.tryParse('${paymentData['point'] ?? 0}') ?? 0;

  num get orderMoney => num.tryParse('${paymentData['order_money'] ?? 0}') ?? 0;

  num get deliveryMoney => num.tryParse('${paymentData['delivery_money'] ?? 0}') ?? 0;

  /// 是否需要支付现金(H5: type == 1 && order_money != '0.00')
  bool get needPay => type == PointExchangeApi.typeGoods && orderMoney > 0;

  /* ---------------- 接口 ---------------- */

  /// 订单初始化(H5 getOrderPaymentData + handlePaymentData)
  Future<void> loadPayment() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await PointExchangeApi.orderPayment(createData);
      if (!mounted) return;
      setState(() {
        paymentData = data;
        createData['order_key'] = '${data['order_key'] ?? ''}';
        createData['delivery'] = <String, dynamic>{
          'store_id': 0,
          'delivery_type': '',
          'delivery_type_name': '',
          'buyer_ask_delivery_time': <String, dynamic>{'start_date': '', 'end_date': ''},
        };
        createData['buyer_message'] = '';
        final dynamic delivery = data['delivery'];
        if (delivery is Map) {
          final Map<String, dynamic> d = delivery.cast<String, dynamic>();
          final dynamic address = d['member_address'];
          if (address is Map) memberAddress = address.cast<String, dynamic>();
          final dynamic types = d['express_type'];
          expressType = types is List
              ? types.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
              : <Map<String, dynamic>>[];
        }
        if (isVirtual) {
          final dynamic account = data['member_account'];
          final String mobile = account is Map ? '${account['mobile'] ?? ''}' : '';
          memberAddress = <String, dynamic>{'mobile': mobile};
          mobileCtrl.text = mobile;
        }
      });
      // 兑换结算接口可能不带 store_list,先补齐门店再判断自提是否可用
      await loadStoreListIfEmpty();
      if (!mounted) return;
      // 默认配送方式: 快递优先,无门店的自提/同城不作为默认
      // H5 默认取 express_type[0],若第一项是无门店的自提,提交时必然提示「没有可提货的门店」
      if (expressType.isNotEmpty) {
        final List<Map<String, dynamic>> usable = expressType.where(deliveryTypeAvailable).toList();
        Map<String, dynamic>? chosen;
        for (final Map<String, dynamic> e in usable) {
          if ('${e['name'] ?? ''}' == 'express') {
            chosen = e;
            break;
          }
        }
        chosen ??= usable.isNotEmpty ? usable.first : expressType.first;
        selectDeliveryType(chosen, calculateAfter: false);
      }
      await calculate();
      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = PointExchangeApi.errorMsg(e, '未获取到创建订单所需数据');
        loading = false;
      });
    }
  }

  /// 补齐自提/同城门店列表
  /// * 兑换 payment 常不返回 express_type[i].store_list(未传经纬度),
  ///   用普通商品下单页同一接口 /api/store/getStorePage 拉一次,保证门店信息能展示
  Future<void> loadStoreListIfEmpty() async {
    for (int i = 0; i < expressType.length; i++) {
      final Map<String, dynamic> item = expressType[i];
      final String name = '${item['name'] ?? ''}';
      if (name != 'store' && name != 'local') continue;
      final dynamic stores = item['store_list'];
      if (stores is List && stores.isNotEmpty) continue;
      try {
        final List<Map<String, dynamic>> list = await OrderApi.storePage(type: name);
        if (!mounted || list.isEmpty) continue;
        // 已绑定门店优先展示(与普通商品下单页显示的门店一致)
        final List<Map<String, dynamic>> sorted = <Map<String, dynamic>>[...list];
        final int boundStoreId = AuthStore.to.storeId.value;
        if (boundStoreId > 0) {
          final int index = sorted.indexWhere((Map<String, dynamic> e) => '${e['store_id']}' == '$boundStoreId');
          if (index > 0) {
            final Map<String, dynamic> bound = sorted.removeAt(index);
            sorted.insert(0, bound);
          }
        }
        setState(() {
          expressType[i] = <String, dynamic>{...item, 'store_list': sorted};
        });
      } catch (_) {}
    }
  }

  /// 提交给后端的 member_address(H5: 虚拟商品 / 门店自提用表单手机号,快递用选中地址)
  Map<String, dynamic> get addressParams {
    if (isVirtual) return <String, dynamic>{'mobile': mobileCtrl.text.trim()};
    if (isStore) {
      return <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'mobile': mobileCtrl.text.trim(),
      };
    }
    return memberAddress;
  }

  /// 手机号校验(11 位 1 开头,兼容 19x 等新号段)
  bool validMobile() {
    final String mobile = mobileCtrl.text.trim();
    return RegExp(r'^1\d{10}$').hasMatch(mobile);
  }

  /// 订单计算(H5 orderCalculate)
  Future<void> calculate() async {
    try {
      final Map<String, dynamic> data = <String, dynamic>{...createData};
      data['delivery'] = jsonEncode(createData['delivery'] ?? <String, dynamic>{});
      data['member_address'] = jsonEncode(addressParams);
      final Map<String, dynamic> res = await PointExchangeApi.orderCalculate(data);
      if (!mounted) return;
      setState(() {
        final dynamic address = res['member_address'];
        if (address is Map) paymentData['member_address'] = address;
        paymentData['delivery_money'] = res['delivery_money'];
        paymentData['order_money'] = res['order_money'];
        final dynamic delivery = res['delivery'];
        if (delivery is Map) {
          final Map<String, dynamic> merged = <String, dynamic>{
            ...(paymentData['delivery'] is Map ? paymentData['delivery'] as Map : <String, dynamic>{}).cast<String, dynamic>(),
            ...delivery.cast<String, dynamic>(),
          };
          paymentData['delivery'] = merged;
        }
      });
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(PointExchangeApi.errorMsg(e, '订单计算失败'));
    }
  }

  /// 配送方式是否可用:门店自提/同城配送必须有门店列表
  bool deliveryTypeAvailable(Map<String, dynamic> item) {
    final String name = '${item['name'] ?? ''}';
    if (name != 'store' && name != 'local') return true;
    final dynamic stores = item['store_list'];
    return stores is List && stores.isNotEmpty;
  }

  /// 是否还有其它可用配送方式(无门店时引导用户切换)
  bool get hasOtherDelivery => expressType.any(
        (Map<String, dynamic> e) => '${e['name'] ?? ''}' != deliveryType && deliveryTypeAvailable(e),
      );

  /// 选择配送方式(H5 selectDeliveryType)
  /// * 重建 delivery,避免从自提切到快递时残留 store_id / 自提时间
  void selectDeliveryType(Map<String, dynamic> item, {bool calculateAfter = true}) {
    final String name = '${item['name'] ?? ''}';
    final bool needStore = name == 'store' || name == 'local';
    final dynamic stores = item['store_list'];
    final List<Map<String, dynamic>> list = needStore && stores is List
        ? stores.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    final Map<String, dynamic> delivery = <String, dynamic>{
      'store_id': 0,
      'delivery_type': name,
      'delivery_type_name': '${item['title'] ?? ''}',
      'buyer_ask_delivery_time': <String, dynamic>{'start_date': '', 'end_date': ''},
    };
    if (needStore) {
      final dynamic account = paymentData['member_account'];
      if ('${memberAddress['name'] ?? ''}'.isEmpty && account is Map) {
        memberAddress = <String, dynamic>{'name': '${account['nickname'] ?? ''}', 'mobile': '${account['mobile'] ?? ''}'};
      }
      if (mobileCtrl.text.trim().isEmpty && account is Map) mobileCtrl.text = '${account['mobile'] ?? ''}';
      if (nameCtrl.text.trim().isEmpty) nameCtrl.text = '${memberAddress['name'] ?? ''}'.trim();
      if (list.isNotEmpty) delivery['store_id'] = int.tryParse('${list.first['store_id'] ?? 0}') ?? 0;
    }
    setState(() {
      createData['delivery'] = delivery;
      currStore = list.isNotEmpty ? list.first : <String, dynamic>{};
      deliveryTime = '';
    });
    if (calculateAfter) calculate();
  }

  /// 选择收货地址(快递发货)
  Future<void> selectAddress() async {
    final dynamic result = await Get.to<dynamic>(const AddressListPage(selectMode: true, type: 1));
    if (result is! Map || !mounted) return;
    setState(() => memberAddress = result.cast<String, dynamic>());
    await calculate();
  }

  /* ---------------- 自提 / 送达时间 ---------------- */

  /// 门店可提货时段(与普通商品下单页一致)
  /// * delivery_time: [{start_time, end_time}],值为当天秒数,可能是 JSON 字符串
  /// * 未配置时退回门店 start_time / end_time,再兜底 09:00-21:00
  List<Map<String, int>> timeRangesOf(Map<String, dynamic> store) {
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
  List<int> timeWeekOf(Map<String, dynamic> store) {
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

  /// 秒数转 HH:mm
  String hm(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 某天的可选时段(按门店 time_interval 切分,过滤今天已过时段)
  List<String> periodsOf(DateTime day, List<Map<String, int>> ranges, int interval, DateTime now, int advanceDay) {
    final bool isToday = advanceDay == 0 && day.year == now.year && day.month == now.month && day.day == now.day;
    final int nowSeconds = now.hour * 3600 + now.minute * 60;
    final List<String> list = <String>[];
    for (final Map<String, int> range in ranges) {
      final int start = range['start']!;
      final int end = range['end']!;
      int time = start;
      if (isToday && nowSeconds > start) time = nowSeconds;
      while (time + interval <= end) {
        list.add('${hm(time)}-${hm(time + interval)}');
        time += interval;
      }
    }
    return list;
  }

  /// 选择提货时间(与普通商品下单页一致): 左日期 + 右时段双栏
  /// * 按门店 time_interval / advance_day / most_day / time_week 生成可预约日期与时段
  /// * 提交 "YYYY-M-D HH:mm" 字符串,不是时间戳
  Future<void> pickTime() async {
    final Map<String, dynamic> store = currStore;
    if (store.isEmpty) {
      MyDialog.toast('暂无可用门店');
      return;
    }
    final List<Map<String, int>> ranges = timeRangesOf(store);
    if (ranges.isEmpty) {
      MyDialog.toast('该门店未配置提货时间');
      return;
    }
    final int interval = (int.tryParse('${store['time_interval'] ?? ''}') ?? 20) * 60; // 默认20分钟
    final int advanceDay = int.tryParse('${store['advance_day'] ?? ''}') ?? 0;
    final int mostDay = int.tryParse('${store['most_day'] ?? ''}') ?? 0;
    final List<int> week = timeWeekOf(store);
    final DateTime now = DateTime.now();
    final int nowSeconds = now.hour * 3600 + now.minute * 60;
    final List<DateTime> days = <DateTime>[];
    final int maxDays = mostDay > 0 ? mostDay : 7;
    for (int i = 0; i < maxDays; i++) {
      final DateTime item = DateTime(now.year, now.month, now.day).add(Duration(days: advanceDay + i));
      if (week.isNotEmpty && !week.contains(item.weekday % 7)) continue;
      if (i == 0 && advanceDay == 0 && ranges.last['end']! - interval < nowSeconds) continue;
      days.add(item);
    }
    if (days.isEmpty) {
      MyDialog.toast('该门店暂无可预约时间');
      return;
    }
    int dayIndex = 0;
    int periodIndex = 0;
    List<String> periods = periodsOf(days.first, ranges, interval, now, advanceDay);
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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                                  onTap: () => setSheetState(() {
                                    dayIndex = index;
                                    periodIndex = 0;
                                    periods = periodsOf(item, ranges, interval, now, advanceDay);
                                  }),
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
                                ? const Center(child: Text('当天暂无可预约时段', style: TextStyle(fontSize: 13.0, color: Colors.grey)))
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
    if (ok != true || periods.isEmpty || !mounted) return;
    final DateTime day = days[dayIndex];
    final String period = periods[periodIndex.clamp(0, periods.length - 1)];
    final List<String> range = period.split('-');
    final Map<String, dynamic> delivery = (createData['delivery'] is Map
            ? createData['delivery'] as Map
            : <String, dynamic>{})
        .cast<String, dynamic>();
    delivery['buyer_ask_delivery_time'] = <String, String>{
      'start_date': '${day.year}-${day.month}-${day.day} ${range.first}',
      'end_date': '${day.year}-${day.month}-${day.day} ${range.last}',
    };
    setState(() {
      deliveryTime = '${day.month}月${day.day}日($period)';
      createData['delivery'] = delivery;
    });
    await calculate();
  }

  /* ---------------- 提交 ---------------- */

  /// 提交校验(H5 verify)
  bool verify() {
    if (type != PointExchangeApi.typeGoods) return true;
    if (isVirtual) {
      final String mobile = mobileCtrl.text.trim();
      if (mobile.isEmpty) {
        MyDialog.toast('请输入您的手机号码');
        return false;
      }
      if (!validMobile()) {
        MyDialog.toast('请输入正确的手机号码');
        return false;
      }
      return true;
    }
    if (deliveryType.isEmpty) {
      MyDialog.toast('商家未设置配送方式');
      return false;
    }
    if (deliveryType == 'store') {
      if ((int.tryParse('${(createData['delivery'] as Map)['store_id'] ?? 0}') ?? 0) <= 0) {
        MyDialog.toast(hasOtherDelivery ? '附近暂无可提货门店,请选择快递配送' : '暂无可用配送方式,请联系商家');
        return false;
      }
      if (mobileCtrl.text.trim().isEmpty) {
        MyDialog.toast('请输入预留手机');
        return false;
      }
      if (!validMobile()) {
        MyDialog.toast('请输入正确的预留手机');
        return false;
      }
      if (deliveryTime.isEmpty) {
        MyDialog.toast('请选择提货时间');
        return false;
      }
      return true;
    }
    if (deliveryType == 'local') {
      if ((int.tryParse('${(createData['delivery'] as Map)['store_id'] ?? 0}') ?? 0) <= 0) {
        MyDialog.toast(hasOtherDelivery ? '附近暂无可配送门店,请选择其他配送方式' : '暂无可用配送方式,请联系商家');
        return false;
      }
      final bool timeOpen = '${((paymentData['config'] is Map ? paymentData['config'] as Map : <String, dynamic>{})['local'] is Map ? (paymentData['config'] as Map)['local'] as Map : <String, dynamic>{})['is_use'] ?? ''}' == '1';
      if (timeOpen && deliveryTime.isEmpty) {
        MyDialog.toast('请选择配送时间');
        return false;
      }
      return true;
    }
    // 快递发货
    if (memberAddress.isEmpty) {
      MyDialog.toast('请先选择您的收货地址');
      return false;
    }
    return true;
  }

  /// 提交订单(H5 orderCreate)
  Future<void> submit() async {
    if (submitting) return;
    if (!verify()) return;
    setState(() => submitting = true);
    try {
      final Map<String, dynamic> data = <String, dynamic>{
        ...createData,
        'buyer_message': messageCtrl.text.trim(),
      };
      data['delivery'] = jsonEncode(createData['delivery'] ?? <String, dynamic>{});
      data['member_address'] = jsonEncode(addressParams);
      final String outTradeNo = await PointExchangeApi.orderCreate(data);
      if (!mounted) return;
      setState(() => submitting = false);
      if (needPay && outTradeNo.isNotEmpty) {
        openPay(outTradeNo);
      } else {
        Get.offNamed('/point/result');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      MyDialog.toast(PointExchangeApi.errorMsg(e, '订单创建失败'));
    }
  }

  /// 支付(需付现金时,H5 choosePaymentPopup + paySource=pointexchange)
  void openPay(String outTradeNo) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: orderMoney.toDouble(),
          outTradeNo: outTradeNo,
          toPayResult: false,
          onChanged: (dynamic value) {
            MyDialog.toast('$value');
            Get.offNamed('/point/result');
          },
        );
      },
    );
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('确认订单', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: loading || paymentData.isEmpty ? _buildStatus() : _buildBody(),
      bottomNavigationBar: loading || paymentData.isEmpty ? null : _buildBottom(),
    );
  }

  Widget _buildStatus() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(errorMsg.isEmpty ? '未获取到创建订单所需数据' : errorMsg,
              style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
          const SizedBox(height: 12.0),
          OutlinedButton(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(primary),
              side: WidgetStateProperty.all(const BorderSide(color: primary)),
            ),
            onPressed: () => Get.back(),
            child: const Text('返回', style: TextStyle(fontSize: 14.0)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final bool showDelivery = type == PointExchangeApi.typeGoods && !isVirtual;
    return ListView(
      padding: const EdgeInsets.only(bottom: 12.0),
      children: <Widget>[
        if (showDelivery) ...<Widget>[
          // 只有一种配送方式时不展示切换栏(与普通商品下单页一致)
          if (expressType.length > 1) _buildDeliveryTypes(),
          if (deliveryType == 'store' || deliveryType == 'local') _buildStore(),
          if (deliveryType != 'store') _buildAddress(),
        ],
        if (isVirtual) _buildVirtualMobile(),
        const SizedBox(height: 10.0),
        _buildGoods(),
        const SizedBox(height: 10.0),
        _buildMoney(),
      ],
    );
  }

  /// 配送方式
  Widget _buildDeliveryTypes() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 6.0),
      child: Row(
        children: expressType.map((Map<String, dynamic> item) {
          final bool selected = '${item['name']}' == deliveryType;
          final bool unavailable = !deliveryTypeAvailable(item);
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(4.0),
              onTap: () {
                if (unavailable) {
                  MyDialog.toast('${item['name']}' == 'store' ? '附近暂无可提货门店' : '附近暂无可配送门店');
                  return;
                }
                selectDeliveryType(item);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: unavailable
                      ? const Color(0xFFF7F7F7)
                      : selected ? const Color(0xFFFFF3E6) : const Color(0xFFF5F5F5),
                  border: Border.all(color: unavailable ? const Color(0xFFE5E5E5) : selected ? primary : Colors.transparent, width: 0.5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '${item['title'] ?? ''}',
                  style: TextStyle(
                    fontSize: 13.0,
                    color: unavailable ? const Color(0xFFBBBBBB) : selected ? primary : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 收货地址(快递发货 / 同城配送)
  Widget _buildAddress() {
    final String name = '${memberAddress['name'] ?? ''}';
    final String mobile = '${memberAddress['mobile'] ?? ''}';
    final String detail = '${memberAddress['full_address'] ?? ''}${memberAddress['address'] ?? ''}';
    final bool empty = name.isEmpty && detail.isEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
      child: InkWell(
        onTap: selectAddress,
        child: Row(
          children: <Widget>[
            const Icon(Icons.location_on_outlined, color: primary, size: 20.0),
            const SizedBox(width: 10.0),
            Expanded(
              child: empty
                  ? const Text('请设置收货地址', style: TextStyle(fontSize: 14.0, color: Color(0xFF999999)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('$name  $mobile', style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4.0),
                        Text(detail, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
          ],
        ),
      ),
    );
  }

  /// 门店自提 / 同城配送: 门店卡 + 提货人卡(对齐普通商品下单页)
  Widget _buildStore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildStoreCard(),
        const SizedBox(height: 10.0),
        _buildPickupFormCard(),
        // 同城配送下面还会接收货地址卡
        if (!isStore) const SizedBox(height: 10.0),
      ],
    );
  }

  /// 门店卡: 门店名 / 地址 / 营业时间(纯展示,不允许点击切换门店)
  Widget _buildStoreCard() {
    final Map<String, dynamic> store = currStore;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.storefront_outlined, size: 18.0, color: primary),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  store.isEmpty ? '暂无可用门店' : '${store['store_name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: store.isEmpty ? const Color(0xFF999999) : const Color(0xFF222222),
                  ),
                ),
              ),
            ],
          ),
          if (store.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.location_on_outlined, size: 16.0, color: Colors.grey),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${store['full_address'] ?? ''}${store['address'] ?? ''}',
                        style: const TextStyle(fontSize: 13.0),
                      ),
                      if ('${store['open_date'] ?? ''}'.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3.0),
                        Text(
                          '营业时间：${store['open_date']}',
                          style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 提货人卡: 提货人 / 预留手机 / 提货时间(对齐普通商品下单页)
  Widget _buildPickupFormCard() {
    final String timeText = deliveryTime.isEmpty ? '请选择提货时间' : deliveryTime;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _pickupRow(
            label: isStore ? '提货人' : '收货人',
            icon: Icons.person_add_alt,
            child: TextField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: 14.0),
              decoration: const InputDecoration(
                hintText: '请输入提货人姓名',
                hintStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.all(0.0),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
          _pickupRow(
            label: '预留手机',
            icon: Icons.phone_android_outlined,
            child: TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              style: const TextStyle(fontSize: 14.0),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '请输入手机号,到店核销使用',
                hintStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.all(0.0),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => pickTime(),
            child: _pickupRow(
              label: isStore ? '提货时间' : '送达时间',
              icon: Icons.arrow_forward_ios_rounded,
              iconColor: Colors.grey,
              iconSize: 12.0,
              child: Text(
                timeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.0, color: deliveryTime.isEmpty ? Colors.grey : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 提货人卡里的单行
  Widget _pickupRow({
    required String label,
    required IconData icon,
    required Widget child,
    Color? iconColor,
    double iconSize = 16.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: <Widget>[
          SizedBox(width: 80.0, child: Text(label, style: const TextStyle(fontSize: 14.0))),
          Expanded(child: child),
          Icon(icon, color: iconColor ?? primary, size: iconSize),
        ],
      ),
    );
  }

  /// 虚拟商品手机号
  Widget _buildVirtualMobile() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('购买虚拟类商品需填写手机号,方便商家与您联系',
              style: TextStyle(fontSize: 12.0, color: primary)),
          const SizedBox(height: 6.0),
          Row(
            children: <Widget>[
              const Text('手机号码', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
              const SizedBox(width: 12.0),
              Expanded(
                child: TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    hintText: '请输入您的手机号码',
                    hintStyle: TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 兑换商品行 + 买家留言
  Widget _buildGoods() {
    final String image = PointExchangeApi.img(exchangeInfo['image']);
    final num price = num.tryParse('${exchangeInfo['price'] ?? 0}') ?? 0;
    final int goodsPoint = int.tryParse('${exchangeInfo['point'] ?? 0}') ?? 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: image.isEmpty
                    ? Container(
                        width: 70.0,
                        height: 70.0,
                        color: const Color(0xFFF5F5F5),
                        alignment: Alignment.center,
                        child: Icon(
                          type == PointExchangeApi.typeCoupon
                              ? Icons.confirmation_num_outlined
                              : Icons.card_giftcard_outlined,
                          color: Colors.grey,
                          size: 26.0,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 70.0,
                        height: 70.0,
                        fit: BoxFit.cover,
                        errorWidget: (BuildContext context, String url, Object error) => Container(
                          width: 70.0,
                          height: 70.0,
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
                    Text('${exchangeInfo['name'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.0, color: Color(0xFF222222))),
                    const SizedBox(height: 8.0),
                    Row(
                      children: <Widget>[
                        Text('$goodsPoint 积分',
                            style: const TextStyle(fontSize: 13.0, color: primary, fontWeight: FontWeight.w600)),
                        if ('${exchangeInfo['price'] ?? '0.00'}' != '0.00' && price > 0) ...<Widget>[
                          const SizedBox(width: 6.0),
                          Text('+ ¥${price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13.0, color: primary)),
                        ],
                        const Spacer(),
                        Text('x$goodsNum', style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: FStyle.dividerColor, height: 24.0, thickness: 0.5),
          Row(
            children: <Widget>[
              const Text('买家留言', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
              const SizedBox(width: 12.0),
              Expanded(
                child: TextField(
                  controller: messageCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '留言前建议先与商家协调一致',
                    hintStyle: TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 所需积分 / 运费
  Widget _buildMoney() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildMoneyRow('所需积分', '$point 积分'),
          if (type == PointExchangeApi.typeGoods && deliveryMoney > 0)
            _buildMoneyRow('运费', '¥${deliveryMoney.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333))),
        ],
      ),
    );
  }

  /// 底部合计 + 提交
  Widget _buildBottom() {
    return Container(
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: <Widget>[
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
                children: <TextSpan>[
                  TextSpan(text: '共$goodsNum件  合计：', style: const TextStyle(color: Color(0xFF666666))),
                  TextSpan(
                    text: '$point',
                    style: const TextStyle(color: primary, fontSize: 17.0, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' 积分', style: TextStyle(color: primary)),
                  if (needPay)
                    TextSpan(
                      text: ' + ¥${orderMoney.toStringAsFixed(2)}',
                      style: const TextStyle(color: primary, fontSize: 15.0, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(primary),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0))),
            ),
            onPressed: submitting ? null : submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(submitting ? '提交中…' : '提交订单', style: const TextStyle(fontSize: 15.0)),
            ),
          ),
        ],
      ),
    );
  }
}
