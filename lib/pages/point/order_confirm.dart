/// 积分兑换 - 确认订单
/// 对齐 H5: pages_promotion/point/payment.vue + public/js/payment.js
/// * 初始化 /pointexchange/api/ordercreate/payment({ id, sku_id, num })
/// * 变更(配送/地址/门店/时间)后 /pointexchange/api/ordercreate/calculate 重算
/// * 提交 /pointexchange/api/ordercreate/create -> 需付现金时拉起 PopupPay,否则直接完成
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/point_exchange.dart';
import '../../components/popup_pay.dart';
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

  bool loading = true;
  bool submitting = false;
  String errorMsg = '';

  /// 下单数据(H5 orderCreateData)
  Map<String, dynamic> createData = <String, dynamic>{};
  /// 结算数据(H5 orderPaymentData)
  Map<String, dynamic> paymentData = <String, dynamic>{};

  /// 配送方式列表(delivery.express_type)
  List<Map<String, dynamic>> expressType = <Map<String, dynamic>>[];
  /// 门店列表 + 当前门店(自提 / 同城配送)
  List<Map<String, dynamic>> storeList = <Map<String, dynamic>>[];
  Map<String, dynamic> currStore = <String, dynamic>{};
  /// 收货地址(快递) / 自提人信息(门店)
  Map<String, dynamic> memberAddress = <String, dynamic>{};
  /// 选中的自提 / 送达时间 { title, start_date, end_date }
  Map<String, dynamic> selectedTime = <String, dynamic>{};

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
      // 默认选中第一个配送方式
      if (expressType.isNotEmpty) {
        selectDeliveryType(expressType.first, calculateAfter: false);
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

  /// 提交给后端的 member_address(H5: 虚拟商品 / 门店自提用表单手机号,快递用选中地址)
  Map<String, dynamic> get addressParams {
    if (isVirtual) return <String, dynamic>{'mobile': mobileCtrl.text.trim()};
    if (deliveryType == 'store') {
      return <String, dynamic>{
        'name': '${memberAddress['name'] ?? ''}',
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

  /// 选择配送方式(H5 selectDeliveryType)
  void selectDeliveryType(Map<String, dynamic> item, {bool calculateAfter = true}) {
    final Map<String, dynamic> delivery = (createData['delivery'] is Map
            ? createData['delivery'] as Map
            : <String, dynamic>{})
        .cast<String, dynamic>();
    delivery['delivery_type'] = '${item['name'] ?? ''}';
    delivery['delivery_type_name'] = '${item['title'] ?? ''}';
    setState(() {
      createData['delivery'] = delivery;
    });
    // 门店自提 / 同城配送: 取门店列表与默认门店
    if ('${item['name']}' == 'store' || '${item['name']}' == 'local') {
      final dynamic stores = item['store_list'];
      final List<Map<String, dynamic>> list = stores is List
          ? stores.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        storeList = list;
      });
      final dynamic account = paymentData['member_account'];
      if ('${memberAddress['name'] ?? ''}'.isEmpty && account is Map) {
        memberAddress = <String, dynamic>{'name': '${account['nickname'] ?? ''}', 'mobile': '${account['mobile'] ?? ''}'};
      }
      if (mobileCtrl.text.trim().isEmpty && account is Map) mobileCtrl.text = '${account['mobile'] ?? ''}';
      if (list.isNotEmpty) selectStore(list.first, calculateAfter: false);
    }
    if (calculateAfter) calculate();
  }

  /// 选择门店(H5 selectPickupPoint)
  void selectStore(Map<String, dynamic> store, {bool calculateAfter = true}) {
    final Map<String, dynamic> delivery = (createData['delivery'] is Map
            ? createData['delivery'] as Map
            : <String, dynamic>{})
        .cast<String, dynamic>();
    delivery['store_id'] = int.tryParse('${store['store_id'] ?? 0}') ?? 0;
    setState(() {
      currStore = store.cast<String, dynamic>();
      createData['delivery'] = delivery;
      selectedTime = <String, dynamic>{};
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

  /// 时段: 门店 delivery_time(JSON字符串或数组),元素 { start_time, end_time }(秒或 HH:mm)
  List<Map<String, dynamic>> get timeSlots {
    final dynamic raw = currStore['delivery_time'];
    List<dynamic> slots = <dynamic>[];
    if (raw is List) {
      slots = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) slots = decoded;
      } catch (_) {}
    }
    if (slots.isEmpty) {
      final dynamic start = currStore['start_time'];
      final dynamic end = currStore['end_time'];
      if (start != null && end != null) {
        slots = <dynamic>[<String, dynamic>{'start_time': start, 'end_time': end}];
      }
    }
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    final DateTime now = DateTime.now();
    for (int dayOffset = 0; dayOffset < 2; dayOffset++) {
      final DateTime day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final String dayTitle = dayOffset == 0 ? '今天' : '明天';
      for (final dynamic slot in slots) {
        if (slot is! Map) continue;
        final int start = _toSeconds(slot['start_time']);
        final int end = _toSeconds(slot['end_time']);
        result.add(<String, dynamic>{
          'title': '$dayTitle(${_hhmm(start)}-${_hhmm(end)})',
          'start_date': day.millisecondsSinceEpoch ~/ 1000 + start,
          'end_date': day.millisecondsSinceEpoch ~/ 1000 + end,
        });
      }
    }
    return result;
  }

  /// 秒数(H5 getTimeStr 的逆向: 支持秒数 int 与 'HH:mm' 字符串)
  int _toSeconds(dynamic value) {
    if (value is int) return value;
    final String text = '$value';
    if (text.contains(':')) {
      final List<String> parts = text.split(':');
      final int h = int.tryParse(parts[0]) ?? 0;
      final int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return h * 3600 + m * 60;
    }
    return int.tryParse(text) ?? 0;
  }

  String _hhmm(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 选择自提 / 送达时间
  Future<void> pickTime() async {
    final List<Map<String, dynamic>> slots = timeSlots;
    if (slots.isEmpty) {
      MyDialog.toast('暂无可选时间');
      return;
    }
    final Map<String, dynamic>? picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('选择时间', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: slots.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      dense: true,
                      title: Text('${slots[index]['title']}', style: const TextStyle(fontSize: 14.0)),
                      trailing: '${selectedTime['title']}' == '${slots[index]['title']}'
                          ? const Icon(Icons.check, color: primary, size: 18.0)
                          : null,
                      onTap: () => Get.back(result: slots[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final Map<String, dynamic> delivery = (createData['delivery'] is Map
            ? createData['delivery'] as Map
            : <String, dynamic>{})
        .cast<String, dynamic>();
    delivery['buyer_ask_delivery_time'] = <String, dynamic>{
      'start_date': picked['start_date'],
      'end_date': picked['end_date'],
    };
    setState(() {
      selectedTime = picked;
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
        MyDialog.toast('没有可提货的门店,请选择其他配送方式');
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
      if (selectedTime.isEmpty) {
        MyDialog.toast('请选择自提时间');
        return false;
      }
      return true;
    }
    if (deliveryType == 'local') {
      if ((int.tryParse('${(createData['delivery'] as Map)['store_id'] ?? 0}') ?? 0) <= 0) {
        MyDialog.toast('没有可配送的门店,请选择其他配送方式');
        return false;
      }
      final bool timeOpen = '${((paymentData['config'] is Map ? paymentData['config'] as Map : <String, dynamic>{})['local'] is Map ? (paymentData['config'] as Map)['local'] as Map : <String, dynamic>{})['is_use'] ?? ''}' == '1';
      if (timeOpen && selectedTime.isEmpty) {
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
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(4.0),
              onTap: () => selectDeliveryType(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFF3E6) : const Color(0xFFF5F5F5),
                  border: Border.all(color: selected ? primary : Colors.transparent, width: 0.5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '${item['title'] ?? ''}',
                  style: TextStyle(fontSize: 13.0, color: selected ? primary : const Color(0xFF666666)),
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

  /// 门店自提 / 同城配送: 门店 + 预留手机 + 时间
  Widget _buildStore() {
    final bool isStore = deliveryType == 'store';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => storeList.length > 1 ? openStoreSheet() : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.store_outlined, color: primary, size: 20.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        currStore.isEmpty ? '暂无可用门店' : '${currStore['store_name'] ?? ''}',
                        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                      ),
                      if (currStore.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4.0),
                        Text(
                          '${currStore['full_address'] ?? ''}${currStore['address'] ?? ''}',
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (storeList.length > 1) const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
              ],
            ),
          ),
          const SizedBox(height: 10.0),
          Row(
            children: <Widget>[
              const SizedBox(width: 30.0, child: Text('手机', style: TextStyle(fontSize: 13.0, color: Color(0xFF666666)))),
              Expanded(
                child: TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    hintText: '请输入预留手机',
                    hintStyle: TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13.0),
                ),
              ),
            ],
          ),
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
          InkWell(
            onTap: pickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: <Widget>[
                  Text(isStore ? '自提时间' : '送达时间', style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                  const Spacer(),
                  Text(
                    selectedTime.isEmpty ? '请选择时间' : '${selectedTime['title']}',
                    style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 门店列表弹层
  Future<void> openStoreSheet() async {
    final Map<String, dynamic>? picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('选择门店', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: storeList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> item = storeList[index];
                    final bool selected = '${item['store_id']}' == '${currStore['store_id']}';
                    return ListTile(
                      dense: true,
                      title: Text('${item['store_name'] ?? ''}',
                          style: TextStyle(fontSize: 14.0, color: selected ? primary : const Color(0xFF333333))),
                      subtitle: Text('${item['full_address'] ?? ''}${item['address'] ?? ''}',
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                      trailing: selected ? const Icon(Icons.check, color: primary, size: 18.0) : null,
                      onTap: () => Get.back(result: item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    selectStore(picked);
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
