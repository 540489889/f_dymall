/// 底部支付弹框
/// 对齐 H5: components/payment/payment.vue
/// * /api/pay/info             支付单信息(pay_money / out_trade_no)
/// * /api/pay/type             可用支付方式
/// * /api/pay/getBalanceConfig 余额支付配置
/// * /api/memberaccount/usablebalance 会员余额(余额抵扣金额)
/// * /api/pay/pay              发起支付
/// * /api/pay/status           轮询支付结果(pay_status == 2 为已支付)
/// * /api/pay/resetpay         取消支付后重置支付单据
/// * 支付成功: 关闭弹窗并跳 /order/pay_result(与 H5 payment.vue paySuccess 一致)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/pay.dart';
import '../config/index.dart';

class PopupPay extends StatefulWidget {
  const PopupPay({
    super.key,
    this.onChanged,
    this.onClosed,
    this.payMoney = 0,
    this.outTradeNo = '',
    this.balanceUsable = true,
    this.toPayResult = true,
  });

  /// 支付结果回调(成功/失败都会回调,参数为提示信息)
  final ValueChanged? onChanged;
  /// 支付弹窗关闭回调(与 H5 payment.js payClose 一致: 仅在未支付成功时触发)
  /// * 参数为支付单对应的订单id(payInfo.order_id),未取到时为0
  final ValueChanged<int>? onClosed;
  /// 支付成功后是否跳转支付结果页(与 H5 payment.vue paySuccess 一致,默认跳转)
  final bool toPayResult;
  /// 待支付金额(由下单页传入,未获取到支付单信息时兜底展示)
  final num payMoney;
  /// 支付单号 out_trade_no(下单接口返回)
  final String outTradeNo;
  /// 是否允许使用余额支付
  final bool balanceUsable;

  @override
  State<PopupPay> createState() => _PopupPayState();
}

class _PopupPayState extends State<PopupPay> {
  /// 支付方式列表(按后台可用项过滤后)
  List<PayType> payTypes = <PayType>[];
  int payIndex = 0;
  /// 支付单信息
  Map<String, dynamic> payInfo = <String, dynamic>{};
  String outTradeNo = '';
  /// 余额配置(1开启)与可用余额
  int balanceConfig = 0;
  num balance = 0;
  int isBalance = 0;
  bool loading = true;
  bool paying = false;
  /// 是否已支付成功(区分"支付成功跳结果页"与"取消关闭跳订单详情")
  bool paid = false;
  String errorMsg = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    outTradeNo = widget.outTradeNo;
    load();
  }

  @override
  void dispose() {
    timer?.cancel();
    // 弹窗关闭(用户取消 / 支付失败)通知外部,与 H5 payment.js payClose 一致
    // * 支付成功已跳支付结果页,不再触发(H5 paySuccess 用 redirectTo 覆盖当前页)
    final ValueChanged<int>? onClosed = widget.onClosed;
    if (!paid && onClosed != null) {
      final int id = orderId;
      WidgetsBinding.instance.addPostFrameCallback((_) => onClosed(id));
    }
    super.dispose();
  }

  /// 支付单号(支付单信息优先)
  String get tradeNo => outTradeNo.isNotEmpty ? outTradeNo : '${payInfo['out_trade_no'] ?? ''}';

  /// 支付单对应的订单id(/api/pay/info 返回,支付完成后跳订单详情用)
  int get orderId => int.tryParse('${payInfo['order_id'] ?? ''}') ?? 0;

  /// 订单应付金额(未取到支付单信息时用下单页传入的金额兜底)
  num get orderMoney => num.tryParse('${payInfo['pay_money'] ?? ''}') ?? widget.payMoney;

  /// 余额可抵扣金额(不超过应付金额)
  num get balanceDeduct {
    if (payInfo.isEmpty || balance <= 0) return 0;
    return balance > orderMoney ? orderMoney : balance;
  }

  /// 是否展示余额抵扣
  bool get showBalance => balanceDeduct > 0 && widget.balanceUsable && balanceConfig == 1;

  /// 实际需支付金额(使用余额时扣除抵扣)
  num get payMoney {
    if (showBalance && isBalance == 1) return orderMoney - balanceDeduct;
    return orderMoney;
  }

  /// 加载支付相关信息: 支付方式 + 余额配置 + 支付单 + 会员余额
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    if (tradeNo.isEmpty) {
      errorMsg = '缺少支付单号';
    }
    // 支付方式(与H5一致: 组件初始化即请求,不依赖支付单号)
    try {
      payTypes = await PayApi.payType();
    } catch (_) {
      payTypes = <PayType>[];
    }
    // 余额配置
    if (widget.balanceUsable) {
      try {
        balanceConfig = await PayApi.balanceConfig();
      } catch (_) {
        balanceConfig = 0;
      }
    }
    // 支付单信息(需要支付单号)
    if (tradeNo.isNotEmpty) {
      try {
        payInfo = await PayApi.info(tradeNo);
        final String no = '${payInfo['out_trade_no'] ?? ''}';
        if (no.isNotEmpty) outTradeNo = no;
        // 余额配置开启时取会员余额
        if (balanceConfig == 1 && widget.balanceUsable) {
          try {
            balance = await PayApi.usableBalance();
          } catch (_) {
            balance = 0;
          }
        }
      } catch (e) {
        errorMsg = '$e';
      }
    }
    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  /// 确认支付
  Future<void> confirm() async {
    if (payTypes.isEmpty && payMoney > 0) {
      MyDialog.toast('平台尚未配置支付方式');
      return;
    }
    if (paying) return;
    setState(() {
      paying = true;
    });
    try {
      final PayType type = payTypes.isEmpty
          ? const PayType(type: '', name: '')
          : payTypes[payIndex];
      final PayResult res = await PayApi.pay(
        outTradeNo: tradeNo,
        payType: type.type,
        isBalance: isBalance,
        // 支付完成回跳地址(与H5一致: encodeURIComponent)
        returnUrl: Uri.encodeComponent('${Config.baseUrl}/#/order/detail?code=$tradeNo'),
      );
      if (!mounted) return;
      if (res.paySuccess) {
        paySuccess();
        return;
      }
      if (type.isOffline) {
        // 线下支付: 直接跳订单详情
        paySuccess();
        return;
      }
      if (res.url.isNotEmpty) {
        // 支付宝/微信H5: 跳支付页并轮询支付状态
        final Uri uri = Uri.parse(res.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        startPolling();
        return;
      }
      // APP端: 此处需接原生支付SDK(fluwx/tobias),SDK支付成功后再调 paySuccess()
      MyDialog.toast('请在APP中完成支付');
      startPolling();
    } catch (e) {
      MyDialog.toast('$e');
      // 支付异常: 重置支付单据,避免重复下单
      resetPay();
    } finally {
      if (mounted) {
        setState(() {
          paying = false;
        });
      }
    }
  }

  /// 轮询支付状态(pay_status == 2 为已支付)
  void startPolling() {
    timer?.cancel();
    int times = 0;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      times++;
      if (!mounted || times > 300) {
        t.cancel();
        return;
      }
      try {
        final int payStatus = await PayApi.status(tradeNo);
        if (payStatus == 2) {
          t.cancel();
          paySuccess();
        } else if (payStatus < 0) {
          t.cancel();
        }
      } catch (_) {
        // 网络异常继续轮询
      }
    });
  }

  /// 取消/失败后重置支付单据(换取新的支付单号)
  Future<void> resetPay() async {
    final String no = await PayApi.resetPay(tradeNo);
    if (!mounted || no.isEmpty) return;
    setState(() {
      outTradeNo = no;
    });
    await load();
  }

  /// 支付成功: 关闭弹窗并跳支付结果页(与 H5 payment.vue paySuccess 一致)
  void paySuccess() {
    timer?.cancel();
    if (!mounted) return;
    paid = true;
    final String no = tradeNo;
    Get.back();
    widget.onChanged?.call('支付成功');
    if (widget.toPayResult) {
      Get.offNamed('/order/pay_result', arguments: <String, dynamic>{'code': no});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: '支付 '),
                  TextSpan(
                    text: '¥${payMoney.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 24.0, fontFamily: 'Arial', fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30.0),
              child: CircularProgressIndicator(),
            )
          else if (errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Column(
                children: <Widget>[
                  Text(errorMsg, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                  TextButton(onPressed: load, child: const Text('重新加载')),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                clipBehavior: Clip.antiAlias,
                elevation: 2.0,
                shadowColor: Colors.black26,
                child: Column(
                  children: <Widget>[
                    // 余额抵扣(自定义行,左侧图标与支付方式统一)
                    if (showBalance) _buildBalanceItem(),
                    if (showBalance && payMoney > 0 && payTypes.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.0),
                        child: Divider(height: 1.0, color: Color(0xFFF0F0F0)),
                      ),
                    // 支付方式列表(统一左侧图标,右侧选中指示器)
                    if (payMoney > 0 && payTypes.isNotEmpty)
                      Column(
                        children: <Widget>[
                          for (int i = 0; i < payTypes.length; i++) ...<Widget>[
                            _buildPayItem(payTypes[i]),
                            if (i < payTypes.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14.0),
                                child: Divider(height: 1.0, color: Color(0xFFF0F0F0)),
                              ),
                          ],
                        ],
                      ),
                    if (payMoney > 0 && payTypes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text('平台尚未配置支付方式！', style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(20.0),
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(const Color(0xFFFF2C55)),
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(const Size(double.infinity, 45.0)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                ),
              ),
              onPressed: loading || paying || errorMsg.isNotEmpty ? null : confirm,
              child: Text(paying ? '支付中...' : '确认支付', style: const TextStyle(fontSize: 15.0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 余额抵扣行(左侧统一图标)
  Widget _buildBalanceItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: <Widget>[
          _payIconBox(
            backgroundColor: const Color(0x1AFAA218),
            child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFAA218), size: 22.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('余额抵扣', style: TextStyle(fontSize: 14.0, color: Color(0xFF333333))),
                Text('可用¥${balanceDeduct.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: isBalance == 1,
            activeColor: const Color(0xFFFF2C55),
            onChanged: (bool value) {
              setState(() {
                isBalance = value ? 1 : 0;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 支付方式行
  Widget _buildPayItem(PayType item) {
    final bool selected = payTypes.isNotEmpty && payTypes[payIndex] == item;
    return InkWell(
      onTap: () {
        final int index = payTypes.indexOf(item);
        if (index >= 0) {
          setState(() {
            payIndex = index;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: <Widget>[
            _payIconBoxOf(item),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(item.name, style: const TextStyle(fontSize: 14.0, color: Color(0xFF333333))),
            ),
            _checkIcon(selected),
          ],
        ),
      ),
    );
  }

  /// 选中/未选中指示器
  Widget _checkIcon(bool selected) {
    return Container(
      width: 20.0,
      height: 20.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected ? null : Border.all(color: const Color(0xFFCCCCCC)),
        color: selected ? const Color(0xFFFF2C55) : Colors.transparent,
      ),
      child: selected
        ? const Icon(Icons.check, size: 13.0, color: Colors.white)
        : null,
    );
  }

  /// 支付方式图标(统一 40x40 圆角底)
  Widget _payIconBoxOf(PayType type) {
    if (type.isWechat) {
      return _payIconBox(
        backgroundColor: const Color(0x1A07C160),
        child: Image.asset('assets/images/wxpay.png', height: 22.0),
      );
    }
    if (type.isAlipay) {
      return _payIconBox(
        backgroundColor: const Color(0x1A1677FF),
        child: Image.asset('assets/images/alipay.png', height: 22.0),
      );
    }
    if (type.isOffline) {
      return _payIconBox(
        backgroundColor: const Color(0x1AF9A647),
        child: const Icon(Icons.storefront_outlined, color: Color(0xFFF9A647), size: 22.0),
      );
    }
    return _payIconBox(
      backgroundColor: const Color(0x1AF9A647),
      child: const Icon(Icons.payments_outlined, color: Color(0xFFF9A647), size: 22.0),
    );
  }

  /// 统一图标底(40x40,圆角 10)
  Widget _payIconBox({required Widget child, required Color backgroundColor}) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
