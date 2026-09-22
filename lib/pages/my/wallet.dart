/// 我的余额
/// 对齐 H5: pages_tool/member/balance.vue
/// * 账户余额 = 储值余额(balance) + 现金余额(balance_money),接口 /api/memberaccount/info
/// * 菜单: 余额明细;充值记录(需充值插件开启)
/// * 底部: 充值 / 提现,按插件配置 is_use 显隐(H5 addonIsExist + config.is_use)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/member_account.dart';
import '../../styles/index.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  static const Color primary = Color(0xFFFF2C55);
  /// 顶部渐变(与 _buildHeader 共用)
  static const LinearGradient topGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF1959), Color(0xFFFE7849)],
  );

  Map<String, dynamic> balanceInfo = <String, dynamic>{};
  bool loading = true;
  String errorMsg = '';
  // 充值 / 提现入口是否开放(取插件配置 is_use)
  bool rechargeOpen = false;
  bool withdrawOpen = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 储值余额(H5 balance)
  double get balance => double.tryParse('${balanceInfo['balance'] ?? 0}') ?? 0;

  /// 现金余额(H5 balance_money)
  double get balanceMoney => double.tryParse('${balanceInfo['balance_money'] ?? 0}') ?? 0;

  /// 账户余额(H5 顶部展示口径: 两者相加)
  double get total => balance + balanceMoney;

  /// 余额 + 充值/提现配置(三个接口并发,配置接口失败不影响余额展示)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberAccountApi.info(),
        MemberAccountApi.withdrawConfig(),
        MemberAccountApi.memberrechargeConfig(),
      ]);
      if (!mounted) return;
      final dynamic withdraw = res[1];
      final dynamic recharge = res[2];
      setState(() {
        balanceInfo = res[0] is Map ? (res[0] as Map).cast<String, dynamic>() : <String, dynamic>{};
        withdrawOpen = withdraw is Map && '${withdraw['is_use'] ?? ''}' == '1';
        rechargeOpen = recharge is Map && '${recharge['is_use'] ?? ''}' == '1';
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberAccountApi.errorMsg(e, '余额加载失败');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // 渐变延伸到状态栏 + 标题栏,AppBar 透明浮在上面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        title: const Text('我的余额', style: TextStyle(fontSize: 17.0, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      // 插件都未开启时不显示底部按钮区
      bottomNavigationBar: loading || (!rechargeOpen && !withdrawOpen) ? null : _buildActions(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return _buildPlain(
        const CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (balanceInfo.isEmpty && errorMsg.isNotEmpty) return _buildPlain(_buildError());
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12.0),
          _buildMenus(),
        ],
      ),
    );
  }

  /// 非内容态(加载/失败)顶部补一段渐变,避免透明 AppBar 下露出灰底
  Widget _buildPlain(Widget child) {
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          height: top + 24.0,
          decoration: const BoxDecoration(gradient: topGradient),
        ),
        Expanded(child: Center(child: child)),
      ],
    );
  }

  /// 加载失败(接口报错)
  Widget _buildError() {
    return Column(
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
    );
  }

  /// 顶部余额卡(H5 head-wrap: 红橙渐变 + 账户余额)
  /// * 顶部留白 = 状态栏 + 标题栏高度,渐变向上延伸到屏幕顶部
  Widget _buildHeader() {
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.0, top + 20.0, 16.0, 28.0),
      decoration: const BoxDecoration(
        gradient: topGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.0)),
      ),
      child: Column(
        children: <Widget>[
          const Text('账户余额（元）', style: TextStyle(color: Colors.white70, fontSize: 13.0)),
          const SizedBox(height: 10.0),
          Text(
            total.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 36.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
          ),
          const SizedBox(height: 18.0),
          Row(
            children: <Widget>[
              _buildSubItem('储值余额（元）', balance),
              Container(width: 0.5, height: 24.0, color: Colors.white30),
              _buildSubItem('现金余额（元）', balanceMoney),
            ],
          ),
        ],
      ),
    );
  }

  /// 储值 / 现金分项
  Widget _buildSubItem(String label, double value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
          ),
          const SizedBox(height: 4.0),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.0)),
        ],
      ),
    );
  }

  /// 菜单卡(H5 menu-wrap)
  Widget _buildMenus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          _buildMenu(
            Icons.receipt_long,
            '余额明细',
            () => Get.toNamed('/my/balance_detail'),
            showDivider: rechargeOpen,
          ),
          if (rechargeOpen)
            _buildMenu(Icons.history, '充值记录', () => Get.toNamed('/my/recharge_order')),
        ],
      ),
    );
  }

  /// 菜单项
  Widget _buildMenu(IconData icon, String title, VoidCallback onTap, {bool showDivider = false}) {
    return Column(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20.0, color: primary),
                  const SizedBox(width: 12.0),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500))),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 46.0),
      ],
    );
  }

  /// 底部充值 / 提现(H5 action)
  Widget _buildActions() {
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + bottom),
      child: Row(
        children: <Widget>[
          if (rechargeOpen)
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(primary),
                  minimumSize: WidgetStateProperty.all(const Size(double.infinity, 42.0)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(21.0))),
                ),
                onPressed: () async {
                  // 充值完成后返回刷新余额
                  await Get.toNamed('/my/recharge');
                  load();
                },
                child: const Text('充值', style: TextStyle(fontSize: 15.0)),
              ),
            ),
          if (rechargeOpen && withdrawOpen) const SizedBox(width: 12.0),
          if (withdrawOpen)
            Expanded(
              child: OutlinedButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(const Color(0xFF333333)),
                  side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFDDDDDD))),
                  minimumSize: WidgetStateProperty.all(const Size(double.infinity, 42.0)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(21.0))),
                ),
                onPressed: () async {
                  // 提现完成后返回刷新余额
                  await Get.toNamed('/my/withdraw');
                  load();
                },
                child: const Text('提现', style: TextStyle(fontSize: 15.0)),
              ),
            ),
        ],
      ),
    );
  }
}
