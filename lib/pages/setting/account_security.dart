/// 账户安全(独立页)
/// 承载 手机号绑定/换绑 / 修改密码 / 注销账号
/// 入口在「个人资料」页,跳转: Get.to(const AccountSecurityPage())
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';

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
    return GestureDetector(
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
    );
  }

  Widget _navItem(String label, VoidCallback onTap, {Color textColor = Colors.black87}) {
    return GestureDetector(
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
    );
  }

  // ============== 资料修改 ==============

  /// 统一提交: 成功后刷新会员信息(全局同步), 失败提示接口原因
  Future<void> _run(Future<dynamic> Function() task, {String ok = '修改成功'}) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await task();
      await auth.loadMemberInfo();
      if (!mounted) return;
      setState(() {});
      MyDialog.toast(ok);
    } catch (e) {
      MyDialog.toast(MemberApi.errorMsg(e, '修改失败'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _maskMobile(String mobile) {
    if (mobile.length < 7) return mobile;
    return '${mobile.substring(0, 3)}****${mobile.substring(mobile.length - 4)}';
  }

  /// 绑定/换绑手机号: 手机号 + 图形验证码 + 短信动态码(120s 倒计时)
  Future<void> _editMobile() async {
    Map<String, dynamic> captcha = <String, dynamic>{};
    try {
      captcha = await MemberApi.captcha();
    } catch (_) {}
    String captchaId = '${captcha['id'] ?? ''}';
    String captchaImg = '${captcha['img'] ?? ''}';
    final TextEditingController mobileCtl = TextEditingController();
    final TextEditingController verCtl = TextEditingController();
    final TextEditingController dynCtl = TextEditingController();
    String smsKey = '';
    int seconds = 0;
    Timer? timer;

    /// 刷新图形验证码(发送失败/换绑失败时都要刷新,与 H5 一致)
    Future<void> refreshCaptcha(void Function(void Function()) setDialog) async {
      try {
        final Map<String, dynamic> res = await MemberApi.captcha();
        captchaId = '${res['id'] ?? ''}';
        captchaImg = '${res['img'] ?? ''}';
        setDialog(() {});
      } catch (_) {}
    }

    /// 发送短信动态码
    Future<void> sendCode(void Function(void Function()) setDialog) async {
      final String mobile = mobileCtl.text.trim();
      if (seconds > 0) return;
      if (!_isMobile(mobile)) {
        MyDialog.toast('请输入正确的手机号');
        return;
      }
      if (verCtl.text.trim().isEmpty) {
        MyDialog.toast('请输入验证码');
        return;
      }
      try {
        await MemberApi.checkMobile(mobile);
        smsKey = await MemberApi.bindMobileCode(
          mobile: mobile,
          captchaId: captchaId,
          captchaCode: verCtl.text.trim(),
        );
        seconds = 120;
        setDialog(() {});
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          seconds--;
          setDialog(() {});
          if (seconds <= 0) t.cancel();
        });
        MyDialog.toast('动态码已发送');
      } catch (e) {
        MyDialog.toast(MemberApi.errorMsg(e, '动态码发送失败'));
        await refreshCaptcha(setDialog);
      }
    }

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialog) {
          return AlertDialog(
            title: Text(auth.mobile.isEmpty ? '绑定手机号' : '更换手机号'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: mobileCtl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: '请输入手机号'),
                  ),
                  const SizedBox(height: 8.0),
                  // 图形验证码
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: verCtl,
                          decoration: const InputDecoration(hintText: '请输入验证码'),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      GestureDetector(
                        onTap: () => refreshCaptcha(setDialog),
                        child: _captchaImage(captchaImg),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  // 短信动态码
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dynCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '请输入动态码'),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      TextButton(
                        onPressed: () => sendCode(setDialog),
                        child: Text(seconds > 0 ? '已发送(${seconds}s)' : '获取动态码'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back<void>(), child: const Text('取消')),
              TextButton(
                onPressed: () async {
                  final String mobile = mobileCtl.text.trim();
                  if (!_isMobile(mobile)) {
                    MyDialog.toast('请输入正确的手机号');
                    return;
                  }
                  if (mobile == auth.mobile) {
                    MyDialog.toast('与原手机号一致');
                    return;
                  }
                  if (dynCtl.text.trim().isEmpty) {
                    MyDialog.toast('请输入动态码');
                    return;
                  }
                  Get.back<void>();
                  await _run(
                    () => MemberApi.modifyMobile(
                      mobile: mobile,
                      code: dynCtl.text.trim(),
                      key: smsKey,
                      captchaId: captchaId,
                      captchaCode: verCtl.text.trim(),
                    ),
                    ok: '手机号绑定成功',
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    timer?.cancel();
  }

  /// 修改密码: 已设密码走「原密码」,未设密码走「短信动态码」
  Future<void> _editPassword() async {
    if (auth.hasPassword) return _editPasswordWithOld();
    return _editPasswordWithCode();
  }

  /// 已设置过密码: 原密码 + 新密码 + 确认新密码
  Future<void> _editPasswordWithOld() async {
    final TextEditingController oldCtl = TextEditingController();
    final TextEditingController newCtl = TextEditingController();
    final TextEditingController confirmCtl = TextEditingController();
    final bool? ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('修改密码'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: oldCtl, obscureText: true, decoration: const InputDecoration(hintText: '原密码')),
              TextField(controller: newCtl, obscureText: true, decoration: const InputDecoration(hintText: '新密码')),
              TextField(
                  controller: confirmCtl, obscureText: true, decoration: const InputDecoration(hintText: '确认新密码')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back<bool>(result: false), child: const Text('取消')),
          TextButton(onPressed: () => Get.back<bool>(result: true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final String oldPwd = oldCtl.text.trim();
    final String newPwd = newCtl.text.trim();
    if (oldPwd.isEmpty) return MyDialog.toast('请输入原密码');
    if (newPwd.isEmpty) return MyDialog.toast('请输入新密码');
    if (oldPwd == newPwd) return MyDialog.toast('新密码不能与原密码相同');
    if (newPwd != confirmCtl.text.trim()) return MyDialog.toast('两次密码不一致');
    await _run(() => MemberApi.modifyPassword(newPassword: newPwd, oldPassword: oldPwd), ok: '密码修改成功');
  }

  /// 未设置过密码: 图形验证码 + 短信动态码 + 新密码
  Future<void> _editPasswordWithCode() async {
    Map<String, dynamic> captcha = <String, dynamic>{};
    try {
      captcha = await MemberApi.captcha();
    } catch (_) {}
    String captchaId = '${captcha['id'] ?? ''}';
    String captchaImg = '${captcha['img'] ?? ''}';
    final TextEditingController verCtl = TextEditingController();
    final TextEditingController dynCtl = TextEditingController();
    final TextEditingController newCtl = TextEditingController();
    final TextEditingController confirmCtl = TextEditingController();
    String smsKey = '';
    int seconds = 0;
    Timer? timer;

    Future<void> refreshCaptcha(void Function(void Function()) setDialog) async {
      try {
        final Map<String, dynamic> res = await MemberApi.captcha();
        captchaId = '${res['id'] ?? ''}';
        captchaImg = '${res['img'] ?? ''}';
        setDialog(() {});
      } catch (_) {}
    }

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialog) {
          return AlertDialog(
            title: const Text('设置密码'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: verCtl, decoration: const InputDecoration(hintText: '请输入验证码')),
                      ),
                      const SizedBox(width: 8.0),
                      GestureDetector(onTap: () => refreshCaptcha(setDialog), child: _captchaImage(captchaImg)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                            controller: dynCtl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '请输入动态码')),
                      ),
                      const SizedBox(width: 8.0),
                      TextButton(
                        onPressed: seconds > 0
                            ? null
                            : () async {
                                if (verCtl.text.trim().isEmpty) return MyDialog.toast('请输入验证码');
                                try {
                                  smsKey = await MemberApi.pwdMobileCode(
                                    captchaId: captchaId,
                                    captchaCode: verCtl.text.trim(),
                                  );
                                  seconds = 120;
                                  setDialog(() {});
                                  timer?.cancel();
                                  timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
                                    seconds--;
                                    setDialog(() {});
                                    if (seconds <= 0) t.cancel();
                                  });
                                  MyDialog.toast('动态码已发送');
                                } catch (e) {
                                  MyDialog.toast(MemberApi.errorMsg(e, '动态码发送失败'));
                                  await refreshCaptcha(setDialog);
                                }
                              },
                        child: Text(seconds > 0 ? '已发送(${seconds}s)' : '获取动态码'),
                      ),
                    ],
                  ),
                  TextField(controller: newCtl, obscureText: true, decoration: const InputDecoration(hintText: '新密码')),
                  TextField(
                      controller: confirmCtl,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '确认新密码')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back<void>(), child: const Text('取消')),
              TextButton(
                onPressed: () async {
                  final String newPwd = newCtl.text.trim();
                  if (newPwd.isEmpty) return MyDialog.toast('请输入新密码');
                  if (newPwd != confirmCtl.text.trim()) return MyDialog.toast('两次密码不一致');
                  if (dynCtl.text.trim().isEmpty) return MyDialog.toast('请输入动态码');
                  Get.back<void>();
                  await _run(
                    () => MemberApi.modifyPassword(
                      newPassword: newPwd,
                      code: dynCtl.text.trim(),
                      key: smsKey,
                    ),
                    ok: '密码设置成功',
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    timer?.cancel();
  }

  // ============== 注销 / 退出 ==============

  /// 注销账号: 审核中/已注销/已拒绝直接提示,未申请则先签协议再提交
  Future<void> _cancelAccount() async {
    try {
      final Map<String, dynamic> info = await MemberApi.cancelInfo();
      if (info.isNotEmpty) {
        final int status = int.tryParse('${info['status'] ?? ''}') ?? 0;
        MyDialog.toast(status == 0 ? '注销申请审核中' : (status == 1 ? '账号已注销' : '注销申请已被拒绝'));
        return;
      }
      final Map<String, dynamic> agreement = await MemberApi.cancelAgreement();
      final bool agreed = await _showCancelAgreement(agreement);
      if (!agreed) return;
      await _run(() => MemberApi.cancelApply(), ok: '注销申请已提交');
    } catch (e) {
      MyDialog.toast(MemberApi.errorMsg(e, '注销失败'));
    }
  }

  /// 注销协议弹窗(需勾选同意,与 H5 cancellation.vue 一致)
  Future<bool> _showCancelAgreement(Map<String, dynamic> agreement) async {
    bool selected = false;
    final bool? ok = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialog) {
          return AlertDialog(
            title: Text('${agreement['title'] ?? '注销协议'}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 260.0,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Html(data: '${agreement['content'] ?? ''}'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  selected = !selected;
                  setDialog(() {});
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16.0, color: selected ? const Color(0xFFFF4D5F) : Colors.grey),
                    const SizedBox(width: 4.0),
                    const Text('已阅读并同意', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (!selected) return MyDialog.toast('请先勾选同意协议');
                  Get.back<bool>(result: true);
                },
                child: const Text('下一步', style: TextStyle(color: Color(0xFFFF4D5F))),
              ),
            ],
          );
        },
      ),
    );
    return ok == true;
  }

  // ============== 工具 ==============

  /// 图形验证码图片(接口返回 base64,可能带 data:image 前缀)
  Widget _captchaImage(String base64) {
    if (base64.isEmpty) return const SizedBox(width: 90.0, height: 34.0);
    try {
      final String raw = base64.contains(',') ? base64.split(',').last : base64;
      final Uint8List? bytes = _decodeBase64(raw);
      if (bytes == null) return const SizedBox(width: 90.0, height: 34.0);
      return GestureDetector(
        child: Image.memory(bytes, width: 90.0, height: 34.0, fit: BoxFit.fill),
      );
    } catch (_) {
      return const SizedBox(width: 90.0, height: 34.0);
    }
  }

  Uint8List? _decodeBase64(String raw) {
    try {
      return base64Decode(raw.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  /// 手机号格式校验
  bool _isMobile(String mobile) => RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile);
}
