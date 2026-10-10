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
import '../../utils/wx.dart';

class WithdrawAccountPage extends StatefulWidget {
  const WithdrawAccountPage({super.key});

  @override
  State<WithdrawAccountPage> createState() => _WithdrawAccountPageState();
}

class _WithdrawAccountPageState extends State<WithdrawAccountPage> {
  static const Color primary = Color(0xFFFF2C55);
  /// 卡片阴影
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 8.0, offset: Offset(0.0, 2.0)),
  ];

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

  /// 微信免确认收款授权(对齐 H5 account.vue toTransferAuth)
  /// * 1) /api/memberbankaccount/authorization 拿 mchid / appid / package_info
  /// * 2) 拉起微信商家转账授权,成功后刷新列表(auth_status 后端置为已授权)
  Future<void> toTransferAuth(Map<String, dynamic> item) async {
    final int id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    if (id <= 0) return;
    try {
      final Map<String, dynamic> auth = await MemberWithdrawApi.accountAuthorization(id);
      final String mchId = '${auth['mchid'] ?? ''}';
      final String appId = '${auth['appid'] ?? ''}';
      final String packageInfo = '${auth['package_info'] ?? ''}';
      if (mchId.isEmpty || appId.isEmpty || packageInfo.isEmpty) {
        MyDialog.toast('授权信息不完整,请稍后重试');
        return;
      }
      await WxAuth.requestMerchantTransfer(mchId: mchId, appId: appId, package: packageInfo);
      if (!mounted) return;
      MyDialog.toast('授权成功');
      await load();
    } catch (e) {
      MyDialog.toast(WxAuth.errorMsg(e, '授权失败'));
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
    if (list.isEmpty && !balanceAvailable) return _buildEmpty();
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

  /// 空态
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset('assets/images/common-empty.png', width: 110.0),
          const SizedBox(height: 14.0),
          Text(
            errorMsg.isEmpty ? '还没有提现账户' : errorMsg,
            style: const TextStyle(fontSize: 15.0, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 6.0),
          const Text('添加账户后，提现一键到账', style: TextStyle(fontSize: 12.0, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 18.0),
          SizedBox(
            width: 140.0,
            height: 38.0,
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(primary),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(19.0))),
              ),
              onPressed: () => toEdit(),
              child: const Text('新增账户', style: TextStyle(fontSize: 14.0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 提现到余额(分销): 对齐 H5 balance-item
  Widget _buildBalanceItem() {
    return GestureDetector(
      onTap: setBalanceDefault,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.0),
          boxShadow: cardShadow,
        ),
        child: Row(
          children: <Widget>[
            _buildTypeIcon('balance'),
            const SizedBox(width: 12.0),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('提现到余额', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4.0),
                  Text('实时到账平台余额', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18.0),
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
    final String bankName = '${item['branch_bank_name'] ?? ''}';
    final String bankAccount = '${item['bank_account'] ?? ''}';
    final String account = type == 'bank'
        ? (bankName.isEmpty ? '' : '$bankName · ') + maskTail(bankAccount)
        : (type == 'wechatpay' ? '微信默认钱包' : '提现账号：${maskTail(bankAccount)}');
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: isDefault ? Border.all(color: primary.withValues(alpha: 0.35), width: 1.0) : null,
        boxShadow: cardShadow,
      ),
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14.0)),
              onTap: back.isNotEmpty ? () => setDefault(id) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 12.0),
                child: Row(
                  children: <Widget>[
                    _buildTypeIcon(type),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(typeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                              ),
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
                          Text('${item['realname'] ?? ''}  ${maskMobile('${item['mobile'] ?? ''}')}',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                          if (account.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4.0),
                            Text(account,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 微信账户才有: 免确认收款授权状态(auth_status 由后台返回)
          if (type == 'wechatpay') _buildAuthRow(item),
          const Divider(color: Color(0xFFF5F5F5), height: 1.0, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
            child: Row(
              children: <Widget>[
                _buildAction(
                  icon: isDefault ? Icons.check_circle : Icons.radio_button_unchecked,
                  label: isDefault ? '默认账户' : '设为默认',
                  color: isDefault ? primary : const Color(0xFF888888),
                  onTap: isDefault ? null : () => setDefault(id),
                ),
                const Spacer(),
                _buildAction(
                  icon: Icons.edit_outlined,
                  label: '修改',
                  onTap: () => toEdit(id: id),
                ),
                if (!isDefault)
                  _buildAction(
                    icon: Icons.delete_outline,
                    label: '删除',
                    onTap: () => deleteAccount(id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 账户类型图标(微信绿 / 支付宝蓝 / 银行卡橙)
  Widget _buildTypeIcon(String type) {
    final Color color = type == 'wechatpay'
        ? const Color(0xFF07C160)
        : (type == 'alipay' ? const Color(0xFF1677FF) : const Color(0xFFFF9F43));
    final Widget child = type == 'wechatpay'
        ? Image.asset('assets/images/wxpay.png', width: 24.0, height: 24.0, fit: BoxFit.contain)
        : (type == 'alipay'
            ? Image.asset('assets/images/alipay.png', width: 24.0, height: 24.0, fit: BoxFit.contain)
            : Icon(type == 'balance' ? Icons.account_balance_wallet_outlined : Icons.credit_card,
                color: color, size: 22.0));
    return Container(
      width: 44.0,
      height: 44.0,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  /// 底部小操作(图标 + 文字)
  Widget _buildAction({
    required IconData icon,
    required String label,
    Color color = const Color(0xFF888888),
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16.0, color: color),
              const SizedBox(width: 4.0),
              Text(label, style: TextStyle(fontSize: 12.0, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  /// 手机号脱敏: 138****8888
  static String maskMobile(String mobile) {
    if (mobile.length == 11) return '${mobile.substring(0, 3)}****${mobile.substring(7)}';
    return mobile;
  }

  /// 账号只留尾号
  static String maskTail(String account) {
    if (account.length > 4) return '**** ${account.substring(account.length - 4)}';
    return account;
  }

  /// 微信免确认收款授权行(对齐 H5 .auth-row)
  /// * auth_status == 0 -> 「未微信免确认收款授权」+「去授权」按钮
  /// * 其它值(后台未返回该字段时也是) -> 绿点 + 「已收款授权」(与 H5 v-else 口径一致)
  Widget _buildAuthRow(Map<String, dynamic> item) {
    final bool authed = '${item['auth_status'] ?? ''}' != '0';
    if (authed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 12.0),
        child: Row(
          children: <Widget>[
            Container(
              width: 6.0,
              height: 6.0,
              decoration: const BoxDecoration(color: Color(0xFF07C160), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6.0),
            const Text('已收款授权，提现免确认', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 12.0),
      padding: const EdgeInsets.fromLTRB(10.0, 8.0, 8.0, 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 15.0, color: Color(0xFFFF9F43)),
          const SizedBox(width: 6.0),
          const Expanded(
            child: Text('未授权免确认收款，提现可能失败',
                style: TextStyle(fontSize: 12.0, color: Color(0xFFB26A00))),
          ),
          GestureDetector(
            onTap: () => toTransferAuth(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F43),
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: const Text('去授权', style: TextStyle(fontSize: 12.0, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(color: Color(0x08000000), blurRadius: 8.0, offset: Offset(0.0, -2.0))],
      ),
      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0 + bottom),
      child: Container(
        height: 46.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23.0),
          gradient: const LinearGradient(colors: <Color>[Color(0xFFFF5A77), Color(0xFFFF2C55)]),
          boxShadow: <BoxShadow>[
            BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 10.0, offset: const Offset(0.0, 4.0)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(23.0),
            onTap: () => toEdit(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, color: Colors.white, size: 18.0),
                SizedBox(width: 4.0),
                Text('新增提现账户', style: TextStyle(fontSize: 15.0, color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
