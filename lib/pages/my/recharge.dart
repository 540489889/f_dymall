/// 充值
/// 对齐 H5: pages_tool/recharge/list.vue
/// * 充值配置 /memberrecharge/api/memberrecharge/config(is_use == 1 才可用)
/// * 充值套餐 /memberrecharge/api/memberrecharge/page(face_value 面值 / buy_price 售价)
/// * 账户余额 /api/memberaccount/info
/// * 下单 /memberrecharge/api/ordercreate/create -> 支付单号 -> PopupPay 支付
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_account.dart';
import '../../api/member_recharge.dart';
import '../../components/popup_pay.dart';

class Recharge extends StatefulWidget {
  const Recharge({super.key});

  @override
  State<Recharge> createState() => _RechargeState();
}

class _RechargeState extends State<Recharge> {
  static const Color primary = Color(0xFFFF2C55);

  final TextEditingController priceController = TextEditingController();

  bool loading = true;
  bool submitting = false;
  String errorMsg = '';
  /// 充值套餐
  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  Map<String, dynamic> balanceInfo = <String, dynamic>{};
  /// 选中的套餐下标(-1 为自定义金额)
  int isIndex = -1;
  int rechargeId = 0;
  /// 自定义充值金额(空表示未使用)
  String amount = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  /// 账户余额(储值 + 现金)
  num get balance {
    final num b = num.tryParse('${balanceInfo['balance'] ?? 0}') ?? 0;
    final num m = num.tryParse('${balanceInfo['balance_money'] ?? 0}') ?? 0;
    return b + m;
  }

  /// 应付金额(自定义金额优先,否则取选中套餐售价)
  num get payMoney {
    if (amount.isNotEmpty) return num.tryParse(amount) ?? 0;
    if (isIndex >= 0 && isIndex < list.length) {
      return num.tryParse('${list[isIndex]['buy_price'] ?? 0}') ?? 0;
    }
    return 0;
  }

  bool get canSubmit => rechargeId > 0 || amount.isNotEmpty;

  /// 充值配置 + 账户余额 + 套餐列表
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberRechargeApi.config(),
        MemberAccountApi.info(),
        MemberRechargeApi.page(),
      ]);
      if (!mounted) return;
      final dynamic config = res[0];
      if (!(config is Map && '${config['is_use'] ?? ''}' == '1')) {
        MyDialog.toast('充值服务未开启');
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Get.back();
        });
        return;
      }
      final List<Map<String, dynamic>> items = res[2] is List
          ? (res[2] as List).whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        balanceInfo = res[1] is Map ? (res[1] as Map).cast<String, dynamic>() : <String, dynamic>{};
        list = items;
        // 与 H5 一致: 默认选中第一个套餐
        isIndex = items.isNotEmpty ? 0 : -1;
        rechargeId = items.isNotEmpty ? (int.tryParse('${items.first['recharge_id'] ?? 0}') ?? 0) : 0;
        amount = '';
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberRechargeApi.errorMsg(e, '加载失败');
        loading = false;
      });
    }
  }

  /// 选中套餐
  void onItemClick(int index) {
    setState(() {
      isIndex = index;
      rechargeId = int.tryParse('${list[index]['recharge_id'] ?? 0}') ?? 0;
      amount = '';
    });
  }

  /// 自定义金额弹窗(H5 为数字键盘,Flutter 端用输入框)
  void openCustomAmount() {
    priceController.text = amount == '0' ? '' : amount;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('请输入充值金额', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEEEEE))),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(primary),
                    minimumSize: WidgetStateProperty.all(const Size(double.infinity, 44.0)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                  ),
                  onPressed: () {
                    final String value = priceController.text.trim();
                    final num? price = num.tryParse(value);
                    if (price == null || price <= 0) {
                      MyDialog.toast('请输入充值金额');
                      return;
                    }
                    Get.back();
                    setState(() {
                      isIndex = -1;
                      rechargeId = 0;
                      amount = price.toString();
                    });
                  },
                  child: const Text('确定', style: TextStyle(fontSize: 15.0)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 下单 -> 拉起支付弹窗
  Future<void> submit() async {
    if (submitting) return;
    if (!canSubmit) {
      MyDialog.toast('请选择充值金额');
      return;
    }
    setState(() => submitting = true);
    try {
      final String outTradeNo = await MemberRechargeApi.create(rechargeId: rechargeId, faceValue: amount);
      if (!mounted) return;
      setState(() => submitting = false);
      openPay(outTradeNo);
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      MyDialog.toast(MemberRechargeApi.errorMsg(e, '下单失败'));
    }
  }

  /// 支付弹窗(充值单支付完成后不跳订单结果页,刷新余额即可)
  void openPay(String outTradeNo) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (BuildContext context) {
        return PopupPay(
          payMoney: payMoney,
          outTradeNo: outTradeNo,
          toPayResult: false,
          onChanged: (dynamic value) {
            MyDialog.toast('$value');
            load();
          },
        );
      },
    );
  }

  /// 赠品文案(H5 box-text)
  String giftText(Map<String, dynamic> item) {
    final StringBuffer buffer = StringBuffer('注：实际到账 ${item['face_value']} 元');
    final List<String> gifts = <String>[];
    final num point = num.tryParse('${item['point'] ?? 0}') ?? 0;
    final num growth = num.tryParse('${item['growth'] ?? 0}') ?? 0;
    final String coupon = '${item['coupon_id'] ?? ''}';
    if (point > 0) gifts.add('$point 积分');
    if (growth > 0) gifts.add('$growth 成长值');
    if (coupon.isNotEmpty && coupon != '0') gifts.add('优惠券 X${coupon.split(',').length}');
    if (gifts.isNotEmpty) buffer.write('，赠送：${gifts.join('，')}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('充值', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildAction(),
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
              onPressed: load,
              child: const Text('重新加载', style: TextStyle(fontSize: 14.0)),
            ),
          ],
        ),
      );
    }
    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = (width - 32.0 - 24.0) / 3;
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
        children: <Widget>[
          const Text('充值', style: TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16.0),
          // 账户余额
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              const Text('账户余额', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: balance.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                    ),
                    const TextSpan(text: '元', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Divider(color: Color(0xFFF0F0F0), height: 1.0, thickness: 1.0),
          // 套餐
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('选择充值金额', style: TextStyle(fontSize: 14.0, color: Color(0xFF888888))),
                GestureDetector(
                  onTap: () => Get.toNamed('/my/recharge_order'),
                  child: const Text('充值记录', style: TextStyle(fontSize: 13.0, color: primary)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: <Widget>[
              for (int i = 0; i < list.length; i++)
                SizedBox(
                  width: itemWidth,
                  height: 76.0,
                  child: _buildItem(i),
                ),
              SizedBox(
                width: itemWidth,
                height: 76.0,
                child: _buildCustomItem(),
              ),
            ],
          ),
          if (isIndex >= 0 && isIndex < list.length) ...<Widget>[
            const SizedBox(height: 16.0),
            Text(giftText(list[isIndex]), style: const TextStyle(fontSize: 12.0, color: primary)),
          ],
          // 充值说明
          const SizedBox(height: 30.0),
          const Text('充值说明', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10.0),
          for (final Map<String, dynamic> item in list)
            if (_hasGift(item))
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(_explainText(item), style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              ),
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text('充值任意金额后，会存到您的账户资金中', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ),
        ],
      ),
    );
  }

  bool _hasGift(Map<String, dynamic> item) {
    final num point = num.tryParse('${item['point'] ?? 0}') ?? 0;
    final num growth = num.tryParse('${item['growth'] ?? 0}') ?? 0;
    final String coupon = '${item['coupon_id'] ?? ''}';
    return point > 0 || growth > 0 || (coupon.isNotEmpty && coupon != '0');
  }

  String _explainText(Map<String, dynamic> item) {
    final StringBuffer buffer = StringBuffer('充值 ${item['face_value']} 元赠送：');
    final List<String> gifts = <String>[];
    final num point = num.tryParse('${item['point'] ?? 0}') ?? 0;
    final num growth = num.tryParse('${item['growth'] ?? 0}') ?? 0;
    final String coupon = '${item['coupon_id'] ?? ''}';
    if (point > 0) gifts.add('$point 积分');
    if (growth > 0) gifts.add('$growth 成长值');
    if (coupon.isNotEmpty && coupon != '0') gifts.add('优惠券 X${coupon.split(',').length}');
    buffer.write(gifts.join('，'));
    return buffer.toString();
  }

  /// 套餐项
  Widget _buildItem(int index) {
    final Map<String, dynamic> item = list[index];
    final bool active = isIndex == index;
    final String faceValue = '${item['face_value'] ?? '0'}';
    final num face = num.tryParse(faceValue) ?? 0;
    return GestureDetector(
      onTap: () => onItemClick(index),
      child: Container(
        decoration: BoxDecoration(
          color: active ? null : const Color(0xFFF7F7FB),
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFE7849), Color(0xFFFF1959)],
                )
              : null,
          borderRadius: BorderRadius.circular(8.0),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: face.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Arial',
                      color: active ? Colors.white : const Color(0xFF333333),
                    ),
                  ),
                  TextSpan(
                    text: '元',
                    style: TextStyle(fontSize: 13.0, color: active ? Colors.white : const Color(0xFF333333)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              '售价 ${item['buy_price']} 元',
              style: TextStyle(fontSize: 11.0, color: active ? Colors.white : const Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  /// 其他金额
  Widget _buildCustomItem() {
    return GestureDetector(
      onTap: openCustomAmount,
      child: Container(
        decoration: BoxDecoration(
          color: amount.isNotEmpty ? null : const Color(0xFFF7F7FB),
          gradient: amount.isNotEmpty
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFE7849), Color(0xFFFF1959)],
                )
              : null,
          borderRadius: BorderRadius.circular(8.0),
        ),
        alignment: Alignment.center,
        child: Text(
          amount.isNotEmpty ? '自定义 $amount 元' : '其他金额',
          style: TextStyle(fontSize: 15.0, color: amount.isNotEmpty ? Colors.white : const Color(0xFF666666)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 底部充值按钮
  Widget _buildAction() {
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + bottom),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(canSubmit ? primary : const Color(0xFFCCCCCC)),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 44.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
        ),
        onPressed: submitting || !canSubmit ? null : submit,
        child: Text(
          submitting ? '提交中...' : (payMoney > 0 ? '充值 ¥${payMoney.toStringAsFixed(2)}' : '充值'),
          style: const TextStyle(fontSize: 15.0),
        ),
      ),
    );
  }
}
