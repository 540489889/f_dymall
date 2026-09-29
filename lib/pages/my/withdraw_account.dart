/// 提现账户管理
/// 对齐 H5: pages_tool/member/account.vue
/// * 账户列表 /api/memberbankaccount/page
/// * 设为默认 /api/memberbankaccount/setdefault(点击项即设为默认并返回)
/// * 删除 /api/memberbankaccount/delete(默认账户不可删除)
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_withdraw.dart';

class WithdrawAccountPage extends StatefulWidget {
  const WithdrawAccountPage({super.key});

  @override
  State<WithdrawAccountPage> createState() => _WithdrawAccountPageState();
}

class _WithdrawAccountPageState extends State<WithdrawAccountPage> {
  static const Color primary = Color(0xFFFF2C55);

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  String errorMsg = '';
  /// 来源: member 会员 / fenxiao 分销(对齐 H5 type)
  String type = 'member';
  /// 从提现页选账户进入时带回的页面(对齐 H5 back + redirect)
  String back = '';
  String redirect = 'redirectTo';
  /// 提现方式是否含「余额」(仅 fenxiao 且后端返回 balance 时为真)
  bool balanceAvailable = false;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      type = '${args['type'] ?? 'member'}';
      back = '${args['back'] ?? ''}';
      redirect = '${args['redirect'] ?? 'redirectTo'}';
    }
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<Map<String, dynamic>> data = await MemberWithdrawApi.accountPage(pageSize: 50);
      if (!mounted) return;
      await getTransferType();
      if (!mounted) return;
      setState(() {
        list = data;
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

  /// 提现方式(区分 member/fenxiao),fenxiao 且后端返回 balance 时显示「提现到余额」
  Future<void> getTransferType() async {
    try {
      final List<Map<String, dynamic>> result = await MemberWithdrawApi.transferType(type: type);
      balanceAvailable = type == 'fenxiao' && result.any((Map<String, dynamic> e) => '${e['value']}' == 'balance');
    } catch (_) {
      balanceAvailable = false;
    }
  }

  /// 新增 / 编辑账户,返回后刷新
  Future<void> toEdit({int id = 0}) async {
    await Get.toNamed('/my/withdraw_account_edit', arguments: <String, dynamic>{'id': id, 'type': type});
    if (!mounted) return;
    await load();
  }

  /// 设为默认(对齐 H5 setDefault: back 非空则带回原页,否则刷新列表)
  Future<void> setDefault(int id) async {
    try {
      await MemberWithdrawApi.accountSetDefault(id);
      if (!mounted) return;
      MyDialog.toast('设置成功');
      if (back.isNotEmpty) {
        Get.back(result: <String, dynamic>{'id': id});
      } else {
        await load();
      }
    } catch (e) {
      MyDialog.toast(MemberWithdrawApi.errorMsg(e, '设置失败'));
    }
  }

  /// 提现到余额(仅 fenxiao): 对齐 H5 setBalanceDefault,带回 back 并标记 is_balance=1
  Future<void> setBalanceDefault() async {
    if (back.isNotEmpty) {
      Get.back(result: <String, dynamic>{'is_balance': 1});
    } else {
      MyDialog.toast('已选择提现到余额');
    }
  }

  /// 删除账户
  Future<void> deleteAccount(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示', style: TextStyle(fontSize: 16.0)),
          content: const Text('确定要删除该账户吗？', style: TextStyle(fontSize: 14.0)),
          actionsPadding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
          actions: <Widget>[
            TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
            TextButton(onPressed: () => Get.back(result: true), child: const Text('确定')),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await MemberWithdrawApi.accountDelete(id);
      if (!mounted) return;
      MyDialog.toast('删除成功');
      await load();
    } catch (e) {
      MyDialog.toast(MemberWithdrawApi.errorMsg(e, '删除失败'));
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
        title: const Text('提现账户', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildAddButton(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (list.isEmpty && !balanceAvailable) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/common-empty.png', width: 120.0),
            const SizedBox(height: 12.0),
            Text(
              errorMsg.isEmpty ? '暂无账户信息，请添加' : errorMsg,
              style: const TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
        itemCount: list.length + (balanceAvailable ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (balanceAvailable && index == 0) return _buildBalanceItem();
          final Map<String, dynamic> item = list[index - (balanceAvailable ? 1 : 0)];
          return _buildItem(item);
        },
      ),
    );
  }

  /// 提现到余额(分销): 对齐 H5 balance-item
  Widget _buildBalanceItem() {
    return GestureDetector(
      onTap: setBalanceDefault,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
        child: const Row(
          children: <Widget>[
            Text('提现到余额', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
          ],
        ),
      ),
    );
  }

  /// 账户项
  Widget _buildItem(Map<String, dynamic> item) {
    final int id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    final bool isDefault = '${item['is_default'] ?? ''}' == '1';
    final String type = '${item['withdraw_type'] ?? ''}';
    final String typeName = '${item['withdraw_type_name'] ?? ''}';
    final String account = type == 'bank'
        ? '银行名称：${item['branch_bank_name'] ?? ''}'
        : (type == 'wechatpay' ? '微信默认钱包' : '提现账号：${item['bank_account'] ?? ''}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
              onTap: back.isNotEmpty ? () => setDefault(id) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(typeName, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                              if (isDefault) ...<Widget>[
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: const Text('默认', style: TextStyle(fontSize: 11.0, color: primary)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          Text('${item['realname'] ?? ''}  ${item['mobile'] ?? ''}',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                          const SizedBox(height: 4.0),
                          Text(account, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => toEdit(id: id),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 12.0),
                        child: Text('修改', style: TextStyle(fontSize: 13.0, color: primary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: Color(0xFFF0F0F0), height: 1.0, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: isDefault ? null : () => setDefault(id),
                    child: Text(
                      isDefault ? '默认账户' : '设为默认账户',
                      style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666)),
                    ),
                  ),
                ),
                if (!isDefault)
                  GestureDetector(
                    onTap: () => deleteAccount(id),
                    child: const Icon(Icons.delete_outline, size: 20.0, color: Color(0xFF999999)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + bottom),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 44.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
        ),
        onPressed: () => toEdit(),
        child: const Text('新增账户', style: TextStyle(fontSize: 15.0)),
      ),
    );
  }
}
