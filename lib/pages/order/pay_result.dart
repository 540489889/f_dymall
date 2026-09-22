/// 支付结果页
/// 对齐 H5: pages_tool/pay/result.vue
/// * 入参 code = out_trade_no(支付单号)
/// * /api/pay/info 查询支付结果(pay_status > 0 为支付成功)
/// * 0元订单/支付完成后进入,可跳订单详情(payInfo.order_id)或回首页
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/pay.dart';

class PayResultPage extends StatefulWidget {
  const PayResultPage({super.key});

  @override
  State<PayResultPage> createState() => _PayResultPageState();
}

class _PayResultPageState extends State<PayResultPage> {
  static const Color primary = Color(0xFFFF2C55);

  Map<String, dynamic> payInfo = <String, dynamic>{};
  String outTradeNo = '';
  bool loading = true;
  String errorMsg = '';

  /// 支付成功(pay_status > 0)
  bool get paySuccess => (int.tryParse('${payInfo['pay_status'] ?? 0}') ?? 0) > 0;

  /// 支付金额: pay_money + balance + balance_money(与 H5 一致)
  num get payMoney {
    num money = num.tryParse('${payInfo['pay_money'] ?? ''}') ?? 0;
    money += num.tryParse('${payInfo['balance'] ?? ''}') ?? 0;
    money += num.tryParse('${payInfo['balance_money'] ?? ''}') ?? 0;
    return money;
  }

  int get orderId => int.tryParse('${payInfo['order_id'] ?? ''}') ?? 0;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) outTradeNo = '${args['code'] ?? args['out_trade_no'] ?? ''}';
    load();
  }

  /// 支付结果(/api/pay/info)
  Future<void> load() async {
    if (outTradeNo.isEmpty) {
      setState(() {
        errorMsg = '缺少支付单号';
        loading = false;
      });
      return;
    }
    try {
      final Map<String, dynamic> data = await PayApi.info(outTradeNo);
      if (!mounted) return;
      setState(() {
        payInfo = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = '$e';
        loading = false;
      });
      // 与 H5 一致: 未获取到支付信息时提示后回首页
      MyDialog.toast('未获取到支付信息！');
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) goHome();
      });
    }
  }

  /// 查看订单: 跳订单详情
  void toOrderDetail() {
    final int id = orderId;
    if (id <= 0) {
      Get.offNamed('/order');
      return;
    }
    Get.offNamed('/order/detail', arguments: <String, dynamic>{'order_id': id});
  }

  /// 回首页
  void goHome() {
    Get.until((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('支付结果', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: goHome,
        ),
      ),
      body: loading ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary))) : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
            TextButton(onPressed: load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    final bool success = paySuccess;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16.0, 34.0, 16.0, 26.0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0)),
          child: Column(
            children: <Widget>[
              Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 56.0,
                color: success ? const Color(0xFF09BB07) : const Color(0xFFFF4646),
              ),
              const SizedBox(height: 14.0),
              Text(
                success ? '支付成功' : '支付失败',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: success ? const Color(0xFF09BB07) : const Color(0xFFFF4646)),
              ),
              if (success) ...<Widget>[
                const SizedBox(height: 22.0),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: '¥', style: TextStyle(fontSize: 15.0)),
                      TextSpan(
                        text: payMoney.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700, fontFamily: 'Arial'),
                      ),
                    ],
                    style: const TextStyle(color: Color(0xFF333333)),
                  ),
                ),
              ],
              const SizedBox(height: 26.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _buildButton('查看订单', false, toOrderDetail),
                  const SizedBox(width: 14.0),
                  _buildButton('返回首页', true, goHome),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, bool filled, VoidCallback onTap) {
    return SizedBox(
      width: 120.0,
      height: 36.0,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? primary : Colors.white,
          foregroundColor: filled ? Colors.white : primary,
          side: BorderSide(color: filled ? primary : primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 14.0)),
      ),
    );
  }
}
