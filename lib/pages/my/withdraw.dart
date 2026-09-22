/// 申请提现
/// 对齐 H5: pages_tool/member/apply_withdrawal.vue
/// * 提现信息 /api/memberwithdraw/info(配置 min/rate + 可提现余额 balance_money)
/// * 默认提现账户 /api/memberbankaccount/defaultinfo
/// * 提交 /api/memberwithdraw/apply
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_withdraw.dart';
import '../../styles/index.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  static const Color primary = Color(0xFFFF2C55);

  final TextEditingController moneyController = TextEditingController();

  bool loading = true;
  bool submitting = false;
  String errorMsg = '';
  Map<String, dynamic> withdrawInfo = <String, dynamic>{};
  Map<String, dynamic> bankAccountInfo = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    moneyController.dispose();
    super.dispose();
  }

  /// 提现配置 { is_use, min, rate }
  Map<String, dynamic> get config {
    final dynamic value = withdrawInfo['config'];
    return value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// 会员余额信息 { balance_money, balance_withdraw, ... }
  Map<String, dynamic> get memberInfo {
    final dynamic value = withdrawInfo['member_info'];
    return value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// 可提现余额
  double get balanceMoney => double.tryParse('${memberInfo['balance_money'] ?? 0}') ?? 0;

  /// 最小提现金额
  double get minMoney => double.tryParse('${config['min'] ?? 0}') ?? 0;

  /// 手续费比例(%)
  double get rate => double.tryParse('${config['rate'] ?? 0}') ?? 0;

  /// 提现方式(bank / alipay / wechatpay)
  String get withdrawType => '${bankAccountInfo['withdraw_type'] ?? ''}';

  /// 提现信息 + 默认账户
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> info = await MemberWithdrawApi.info();
      if (!mounted) return;
      if ('${(info['config'] is Map ? info['config'] : const <String, dynamic>{})['is_use'] ?? ''}' == '0') {
        MyDialog.toast('未开启提现');
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Get.back();
        });
        return;
      }
      final Map<String, dynamic> account = await MemberWithdrawApi.accountDefaultInfo();
      if (!mounted) return;
      setState(() {
        withdrawInfo = info;
        bankAccountInfo = account;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberWithdrawApi.errorMsg(e, '加载失败');
        loading = false;
      });
    }
  }

  /// 全部提现
  void allWithdraw() {
    setState(() {
      moneyController.text = balanceMoney.toStringAsFixed(2);
    });
  }

  /// 选择提现账户(账户页返回后刷新)
  Future<void> toAccount() async {
    await Get.toNamed('/my/withdraw_account');
    if (!mounted) return;
    final Map<String, dynamic> account = await MemberWithdrawApi.accountDefaultInfo();
    if (!mounted) return;
    setState(() {
      bankAccountInfo = account;
    });
  }

  /// 校验(对齐 H5 verify)
  bool verify() {
    if (withdrawType.isEmpty) {
      MyDialog.toast('请先添加提现方式');
      return false;
    }
    final double money = double.tryParse(moneyController.text.trim()) ?? 0;
    if (money <= 0) {
      MyDialog.toast('请输入提现金额');
      return false;
    }
    if (money > balanceMoney) {
      MyDialog.toast('提现金额超出可提现金额');
      return false;
    }
    if (money < minMoney) {
      MyDialog.toast('提现金额小于最低提现金额');
      return false;
    }
    return true;
  }

  /// 提交提现申请
  Future<void> submit() async {
    if (submitting) return;
    if (!verify()) return;
    setState(() => submitting = true);
    try {
      await MemberWithdrawApi.apply(
        applyMoney: moneyController.text.trim(),
        transferType: withdrawType,
        realname: '${bankAccountInfo['realname'] ?? ''}',
        mobile: '${bankAccountInfo['mobile'] ?? ''}',
        bankName: '${bankAccountInfo['branch_bank_name'] ?? ''}',
        accountNumber: '${bankAccountInfo['bank_account'] ?? ''}',
      );
      if (!mounted) return;
      setState(() => submitting = false);
      MyDialog.toast('提现申请成功');
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Get.offNamed('/my/withdraw_list');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      MyDialog.toast(MemberWithdrawApi.errorMsg(e, '提现申请失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('申请提现', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 24.0),
      children: <Widget>[
        // 提现账户
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: toAccount,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
              child: Row(
                children: <Widget>[
                  _buildAccountIcon(),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: withdrawType.isEmpty
                        ? const Text('请添加提现方式', style: TextStyle(fontSize: 15.0, color: Color(0xFF999999)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('提现到${_accountTypeName()}',
                                  style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
                              const SizedBox(height: 4.0),
                              Text(_accountText(), style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        // 提现金额
        Container(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('提现金额', style: TextStyle(fontSize: 14.0, color: Color(0xFF888888))),
              const SizedBox(height: 8.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  const Text('¥', style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: TextField(
                      controller: moneyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (String value) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              const SizedBox(height: 12.0),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('可提现余额：¥${balanceMoney.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
                  ),
                  GestureDetector(
                    onTap: allWithdraw,
                    child: const Text('全部提现', style: TextStyle(fontSize: 13.0, color: primary)),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Text(
                '最小提现金额为¥${minMoney.toStringAsFixed(2)}，手续费为$rate%',
                style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24.0),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(primary),
            minimumSize: WidgetStateProperty.all(const Size(double.infinity, 44.0)),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
          ),
          onPressed: submitting ? null : submit,
          child: Text(submitting ? '提交中...' : '提现', style: const TextStyle(fontSize: 15.0)),
        ),
        const SizedBox(height: 20.0),
        Center(
          child: GestureDetector(
            onTap: () => Get.toNamed('/my/withdraw_list'),
            child: const Text('提现记录', style: TextStyle(fontSize: 13.0, color: primary)),
          ),
        ),
      ],
    );
  }

  String _accountTypeName() {
    switch (withdrawType) {
      case 'alipay':
        return '支付宝';
      case 'wechatpay':
        return '微信';
      case 'bank':
        return '银行卡';
      default:
        return '';
    }
  }

  String _accountText() {
    if (withdrawType == 'wechatpay') return '微信默认钱包';
    return '${bankAccountInfo['bank_account'] ?? ''}';
  }

  Widget _buildAccountIcon() {
    if (withdrawType == 'alipay') {
      return Image.asset('assets/images/alipay.png', height: 24.0, fit: BoxFit.contain);
    }
    if (withdrawType == 'wechatpay') {
      return Image.asset('assets/images/wxpay.png', height: 24.0, fit: BoxFit.contain);
    }
    return const Icon(Icons.account_balance_outlined, color: Color(0xFF999999), size: 24.0);
  }
}
