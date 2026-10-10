/// 新增 / 编辑提现账户
/// 对齐 H5: pages_tool/member/account_edit.vue
/// * 提现方式 /api/memberwithdraw/transferType(bank 银行卡 / alipay 支付宝 / wechatpay 微信零钱)
/// * 账户详情 /api/memberbankaccount/info(编辑时回填)
/// * 保存 /api/memberbankaccount/add | /api/memberbankaccount/edit
/// * 入参 Get.arguments: { id: 0 } id 为 0 时新增
/// * 微信零钱: 保存成功后若未做免确认收款授权, 主动拉起微信商户授权
///   /api/memberbankaccount/authorization -> mchid / appid / package_info
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_withdraw.dart';
import '../../styles/index.dart';
import '../../utils/wx.dart';

class WithdrawAccountEditPage extends StatefulWidget {
  const WithdrawAccountEditPage({super.key});

  @override
  State<WithdrawAccountEditPage> createState() => _WithdrawAccountEditPageState();
}

class _WithdrawAccountEditPageState extends State<WithdrawAccountEditPage> {
  static const Color primary = Color(0xFFFF2C55);

  final TextEditingController realnameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountController = TextEditingController();

  int id = 0;
  bool loading = true;
  bool submitting = false;
  /// 保存已成功, 正在等微信商户授权返回
  bool authing = false;
  String errorMsg = '';
  /// 微信免确认收款授权状态('0' 未授权 / '1' 已授权; 空=后台未下发, 由授权接口兜底判断)
  String authStatus = '';
  /// 来源: member 会员 / fenxiao 分销
  String type = 'member';
  /// 提现方式 [{ label, value }]
  List<Map<String, dynamic>> types = <Map<String, dynamic>>[];
  String withdrawType = '';

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      id = int.tryParse('${args['id'] ?? 0}') ?? 0;
      type = '${args['type'] ?? 'member'}';
    }
    load();
  }

  @override
  void dispose() {
    realnameController.dispose();
    mobileController.dispose();
    bankNameController.dispose();
    accountController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      // 编辑时先回填账户信息
      if (id > 0) {
        final Map<String, dynamic> info = await MemberWithdrawApi.accountInfo(id);
        if (!mounted) return;
        realnameController.text = '${info['realname'] ?? ''}';
        mobileController.text = '${info['mobile'] ?? ''}';
        bankNameController.text = '${info['branch_bank_name'] ?? ''}';
        accountController.text = '${info['bank_account'] ?? ''}';
        withdrawType = '${info['withdraw_type'] ?? ''}';
        authStatus = '${info['auth_status'] ?? ''}';
      }
      final List<Map<String, dynamic>> transferTypes = await MemberWithdrawApi.transferType(type: type);
      if (!mounted) return;
      setState(() {
        types = transferTypes;
        // 未指定类型时默认取第一个可选项
        if (withdrawType.isEmpty && transferTypes.isNotEmpty) {
          withdrawType = '${transferTypes.first['value'] ?? ''}';
        }
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

  /// 当前类型名称
  String get typeName {
    for (final Map<String, dynamic> item in types) {
      if ('${item['value']}' == withdrawType) return '${item['label']}';
    }
    return '';
  }

  bool get isBank => withdrawType == 'bank';
  bool get isWechat => withdrawType == 'wechatpay';

  /// 校验(对齐 H5 vertify)
  bool verify() {
    if (realnameController.text.trim().isEmpty) {
      MyDialog.toast('请输入姓名');
      return false;
    }
    final String mobile = mobileController.text.trim();
    if (mobile.isEmpty) {
      MyDialog.toast('请输入手机号');
      return false;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile)) {
      MyDialog.toast('请输入正确的手机号');
      return false;
    }
    if (withdrawType.isEmpty) {
      MyDialog.toast('请选择账户类型');
      return false;
    }
    if (isBank && bankNameController.text.trim().isEmpty) {
      MyDialog.toast('请输入银行名称');
      return false;
    }
    if (!isWechat && accountController.text.trim().isEmpty) {
      MyDialog.toast('请输入提现账号');
      return false;
    }
    return true;
  }

  Future<void> submit() async {
    if (submitting) return;
    if (!verify()) return;
    setState(() => submitting = true);
    try {
      final dynamic saved = await MemberWithdrawApi.accountSave(
        id: id,
        realname: realnameController.text.trim(),
        mobile: mobileController.text.trim(),
        withdrawType: withdrawType,
        bankAccount: isWechat ? '' : accountController.text.trim(),
        branchBankName: isBank ? bankNameController.text.trim() : '',
      );
      if (!mounted) return;
      MyDialog.toast(id > 0 ? '修改成功' : '添加成功');
      // 微信零钱: 未授权时顺手把免确认收款授权做了, 免得回列表再点一次「去授权」
      await authMerchant(id > 0 ? id : parseAccountId(saved), saved is Map ? saved.cast<String, dynamic>() : null);
      if (!mounted) return;
      setState(() {
        submitting = false;
        authing = false;
      });
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        authing = false;
      });
      MyDialog.toast(MemberWithdrawApi.errorMsg(e, '保存失败'));
    }
  }

  /// 新增接口返回的账户 id(data 可能是 id 本身, 也可能是 { id / account_id })
  static int parseAccountId(dynamic res) {
    if (res is Map) {
      final dynamic value = res['id'] ?? res['account_id'] ?? res['data'];
      return int.tryParse('$value') ?? 0;
    }
    return int.tryParse('${res ?? 0}') ?? 0;
  }

  /// 微信零钱免确认收款授权(对齐 H5 保存成功后的 requestMerchantTransfer)
  /// * 只在「微信零钱 + 未授权」时才拉起;已授权 / 拿不到授权参数直接跳过,不影响保存结果
  /// * [saved] 保存接口返回,部分环境会直接下发 mchid/appid/package_info,省一次请求
  Future<void> authMerchant(int accountId, [Map<String, dynamic>? saved]) async {
    if (!isWechat || accountId <= 0) return;
    if (authStatus == '1') return;
    setState(() => authing = true);
    try {
      String mchId = '${saved?['mchid'] ?? ''}';
      String appId = '${saved?['appid'] ?? ''}';
      String packageInfo = '${saved?['package_info'] ?? ''}';
      if (mchId.isEmpty || appId.isEmpty || packageInfo.isEmpty) {
        // 拿不到/接口报错(code<0, 通常意味着无需授权)就静默跳过
        final Map<String, dynamic> auth;
        try {
          auth = await MemberWithdrawApi.accountAuthorization(accountId);
        } catch (_) {
          return;
        }
        mchId = '${auth['mchid'] ?? ''}';
        appId = '${auth['appid'] ?? ''}';
        packageInfo = '${auth['package_info'] ?? ''}';
      }
      if (mchId.isEmpty || appId.isEmpty || packageInfo.isEmpty) return;
      await WxAuth.requestMerchantTransfer(mchId: mchId, appId: appId, package: packageInfo);
      if (!mounted) return;
      authStatus = '1';
      MyDialog.toast('授权成功');
    } catch (e) {
      // 授权失败(含取消/未安装微信)只提示,账户已经保存好了
      if (mounted) MyDialog.toast(WxAuth.errorMsg(e, '未授权成功'));
    }
  }

  /// 类型选择
  Future<void> pickType() async {
    await showModalBottomSheet<void>(
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
                child: Text('选择账户类型', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: types.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> item = types[index];
                    final bool selected = '${item['value']}' == withdrawType;
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${item['label']}',
                        style: TextStyle(fontSize: 14.0, color: selected ? primary : const Color(0xFF333333)),
                      ),
                      trailing: selected ? const Icon(Icons.check, color: primary, size: 18.0) : null,
                      onTap: () {
                        Get.back();
                        setState(() => withdrawType = '${item['value']}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(id > 0 ? '编辑账户' : '新增账户', style: const TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildSubmit(),
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
        _buildCard(<Widget>[
          _buildInput('姓名', '请输入真实姓名', realnameController, maxLength: 30),
          _buildInput('手机号', '请输入手机号', mobileController, maxLength: 11, keyboardType: TextInputType.number),
          _buildTypeRow(),
          if (isBank) _buildInput('银行名称', '请输入银行名称', bankNameController, maxLength: 50),
          if (!isWechat) _buildInput('提现账号', '请输入提现账号', accountController, maxLength: 30),
        ]),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(children: children),
    );
  }

  /// 输入框行
  Widget _buildInput(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLength = 30,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80.0,
            child: Text(label, style: const TextStyle(fontSize: 14.0, color: Color(0xFF333333))),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              style: const TextStyle(fontSize: 14.0),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFFBBBBBB)),
                border: InputBorder.none,
                counterText: '',
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 账户类型(底部弹窗选择)
  Widget _buildTypeRow() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: pickType,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: 80.0,
                child: Text('账户类型', style: TextStyle(fontSize: 14.0, color: Color(0xFF333333))),
              ),
              Expanded(
                child: Text(
                  typeName.isEmpty ? '请选择账户类型' : typeName,
                  style: TextStyle(fontSize: 14.0, color: typeName.isEmpty ? const Color(0xFFBBBBBB) : const Color(0xFF333333)),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmit() {
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
        onPressed: submitting ? null : submit,
        child: Text(submitting ? (authing ? '授权中...' : '保存中...') : '保存',
            style: const TextStyle(fontSize: 15.0)),
      ),
    );
  }
}
