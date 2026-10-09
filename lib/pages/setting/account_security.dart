/// 账户安全(独立页)
/// 承载 手机号绑定/换绑 / 修改密码 / 注销账号
/// 入口在「个人资料」页,跳转: Get.to(const AccountSecurityPage())
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import 'cancel_account.dart';
import 'mobile_edit.dart';
import 'password_edit.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  // 提交中(顶部细进度条)
  bool loading = false;
  // 注销功能是否开启(/membercancel/api/membercancel/config)
  bool cancelEnable = false;

  @override
  void initState() {
    super.initState();
    if (auth.memberInfo.isEmpty) auth.loadMemberInfo();
    _loadCancelConfig();
  }

  /// 注销插件开关: 未开启则不展示「注销账号」
  Future<void> _loadCancelConfig() async {
    try {
      final Map<String, dynamic> res = await MemberApi.cancelConfig();
      if (!mounted) return;
      setState(() => cancelEnable = '${res['is_enable'] ?? ''}' == '1');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 白底页面:状态栏透出白色
        statusBarIconBrightness: Brightness.dark, // Android 黑色图标
        statusBarBrightness: Brightness.light, // iOS 黑色图标
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 顶部状态栏占位
            SizedBox(height: statusTop),
            // 标题栏
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_left, size: 26.0, color: Colors.black87),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('账户安全',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 42.0), // 占位平衡左右
                ],
              ),
            ),
            // 提交中进度条
            if (loading)
              const SizedBox(
                height: 2.0,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFFFEEF0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D5F)),
                ),
              ),
            // 列表
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _actionItem('手机', auth.mobile.isEmpty ? '去绑定' : _maskMobile(auth.mobile), _editMobile),
                  _divider(),
                  _actionItem('密码', auth.hasPassword ? '修改' : '未设置', _editPassword),
                  _divider(),
                  if (cancelEnable) _navItem('注销账号', _cancelAccount),
                  if (cancelEnable) _divider(),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== 组件 ==============

  Widget _divider() => Container(
        color: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(left: 16.0),
          height: 0.5,
          color: FStyle.dividerColor,
        ),
      );

  Widget _actionItem(String label, String value, VoidCallback onTap,
      {Color actionColor = const Color(0xFF666666)}) {
    // 提交中(loading)时整项置灰,提示当前不可点
    return Opacity(
      opacity: loading ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              SizedBox(
                  width: 80.0,
                  child: Text(label, style: const TextStyle(fontSize: 15.0, color: Colors.black87))),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 15.0, color: actionColor)),
              ),
              const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String label, VoidCallback onTap, {Color textColor = Colors.black87}) {
    return Opacity(
      opacity: loading ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 15.0, color: textColor))),
              const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  // ============== 资料修改 ==============

  String _maskMobile(String mobile) {
    if (mobile.length < 7) return mobile;
    return '${mobile.substring(0, 3)}****${mobile.substring(mobile.length - 4)}';
  }

  /// 绑定/换绑手机号: 跳独立页(手机号 + 图形验证码 + 短信动态码)
  /// * 页面返回 true 表示修改成功,重新拉会员信息刷新展示
  Future<void> _editMobile() async {
    final bool? ok = await Get.to<bool>(() => const MobileEditPage());
    if (ok != true) return;
    await auth.loadMemberInfo();
    if (!mounted) return;
    setState(() {});
  }

  /// 修改密码: 跳独立页(已设密码走「原密码」,未设密码走「短信动态码」)
  /// * 页面返回 true 表示修改成功,重新拉会员信息刷新展示
  Future<void> _editPassword() async {
    final bool? ok = await Get.to<bool>(() => const PasswordEditPage());
    if (ok != true) return;
    await auth.loadMemberInfo();
    if (!mounted) return;
    setState(() {});
  }

  // ============== 注销 / 退出 ==============

  /// 注销账号: 跳独立页(展示申请状态 / 注销协议 + 勾选提交)
  /// * 页面返回 true 表示申请已提交,重新拉会员信息刷新展示
  Future<void> _cancelAccount() async {
    final bool? ok = await Get.to<bool>(() => const CancelAccountPage());
    if (ok != true) return;
    await auth.loadMemberInfo();
    if (!mounted) return;
    setState(() {});
  }
}
