/// 忘记密码 / 找回登录密码
/// * 流程: 填手机号 -> 获取验证码(/api/Login/forgotPasswordCode 返回 key)
///   -> 填验证码 + 新密码 -> 提交重置(/api/Login/forgotPassword)
/// * 视觉与登录页保持一致(主色 / 白卡片 / 圆角输入框 / 错误红色边框)

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/auth.dart';
import '../../utils/index.dart';

/// 主色(与登录页一致)
const Color _primary = Color(0xFFFF2C55);
/// 表单项统一间距
const double _gap = 12.0;

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();
  final TextEditingController rePwdController = TextEditingController();

  final FocusNode mobileFocus = FocusNode();
  final FocusNode codeFocus = FocusNode();
  final FocusNode pwdFocus = FocusNode();
  final FocusNode rePwdFocus = FocusNode();

  /// 获取验证码返回的 key(提交重置时一并传给后端)
  String codeKey = '';

  /// 验证码倒计时(60s)
  Timer? _timer;
  int seconds = 60;
  bool counting = false;
  bool sending = false;

  bool submitting = false;
  bool obscurePwd = true;
  bool obscureRePwd = true;

  // 字段级错误(仅用于在对应输入框显示红色边框,提示文字走 Toast)
  String? mobileError;
  String? codeError;
  String? pwdError;
  String? rePwdError;

  @override
  void initState() {
    super.initState();
    mobileFocus.addListener(() => setState(() {}));
    codeFocus.addListener(() => setState(() {}));
    pwdFocus.addListener(() => setState(() {}));
    rePwdFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    mobileController.dispose();
    codeController.dispose();
    pwdController.dispose();
    rePwdController.dispose();
    mobileFocus.dispose();
    codeFocus.dispose();
    pwdFocus.dispose();
    rePwdFocus.dispose();
    super.dispose();
  }

  /// 设置单个字段错误: 仅让对应输入框变红(与登录页一致,字段级错误不弹 Toast 文字)
  /// * 手机号/验证码/密码这类可归属到具体输入框的校验,靠红框表达即可
  /// * 服务端错误(发码失败 / 重置失败)不走这里,在各自 catch 里保留 Toast
  void _setError(String field, String message) {
    setState(() {
      mobileError = null;
      codeError = null;
      pwdError = null;
      rePwdError = null;
      switch (field) {
        case 'mobile':
          mobileError = message;
        case 'code':
          codeError = message;
        case 'pwd':
          pwdError = message;
        case 'rePwd':
          rePwdError = message;
      }
    });
  }

  /// 发送验证码(/api/Login/forgotPasswordCode)
  Future<void> sendCode() async {
    if (counting || sending) return;
    final String mobile = mobileController.text.trim();
    if (mobile.isEmpty) {
      _setError('mobile', '请输入手机号');
      return;
    }
    if (!Utils.checkTel(mobile)) {
      _setError('mobile', '手机号格式不正确');
      return;
    }
    setState(() => sending = true);
    try {
      codeKey = await AuthApi.forgotPasswordCode(mobile: mobile);
      setState(() {
        seconds = 59;
        counting = true;
        sending = false;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => seconds--);
        if (seconds <= 0) {
          timer.cancel();
          setState(() {
            counting = false;
            seconds = 60;
          });
        }
      });
      MyDialog.toast(
        '验证码已发送，请注意查收',
        style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      MyDialog.toast(
        AuthApi.errorMsg(e),
        icon: const Icon(Icons.warning_rounded),
        style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)).center(),
      );
    }
  }

  /// 提交重置密码(/api/Login/forgotPassword)
  Future<void> handleSubmit() async {
    if (submitting) return;
    final String mobile = mobileController.text.trim();
    final String code = codeController.text.trim();
    final String pwd = pwdController.text;
    final String rePwd = rePwdController.text;

    if (mobile.isEmpty) return _setError('mobile', '请输入手机号');
    if (!Utils.checkTel(mobile)) return _setError('mobile', '手机号格式不正确');
    if (codeKey.isEmpty) return _setError('code', '请先获取验证码');
    if (code.isEmpty) return _setError('code', '请输入验证码');
    if (pwd.isEmpty) return _setError('pwd', '请输入新密码');
    if (pwd.length < 6) return _setError('pwd', '密码长度不能小于6位');
    if (rePwd.isEmpty) return _setError('rePwd', '请再次输入新密码');
    if (rePwd != pwd) return _setError('rePwd', '两次输入的密码不一致');

    setState(() => submitting = true);
    try {
      await AuthApi.forgotPassword(
        mobile: mobile,
        key: codeKey,
        code: code,
        password: pwd,
      );
      MyDialog.toast(
        '密码重置成功，请重新登录',
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)).center(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Get.back();
    } catch (e) {
      if (!mounted) return;
      MyDialog.toast(
        AuthApi.errorMsg(e),
        icon: const Icon(Icons.warning_rounded),
        style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)).center(),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F6),
      body: Stack(
        children: <Widget>[
          // 背景: 与绑定门店界面一致(顶部暖色渐变 + 两个装饰圆)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFFFF3EE), Colors.white],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -MediaQuery.of(context).padding.top - 40,
                  right: -60,
                  child: Container(
                    width: 220.0,
                    height: 220.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF7A52).withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: -40,
                  child: Container(
                    width: 100.0,
                    height: 100.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF2C55).withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 原内容(可滚动表单)
          GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            children: <Widget>[
              SizedBox(height: statusTop + 8.0),
              // 返回 + 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Get.back(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20.0,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '找回密码',
                          style: TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32.0),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16.0,
                      offset: const Offset(0.0, 6.0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      '重置登录密码',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    const Text(
                      '请输入手机号获取验证码，重置您的登录密码',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 20.0),
                    // 手机号
                    _buildField(
                      focusNode: mobileFocus,
                      hasError: mobileError != null,
                      child: TextField(
                        controller: mobileController,
                        focusNode: mobileFocus,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '请输入手机号码',
                          hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
                          prefixIcon: Icon(Icons.phone_iphone_outlined, size: 22.0, color: Colors.black26),
                          prefixIconConstraints: BoxConstraints(minWidth: 40.0),
                          contentPadding: EdgeInsets.symmetric(vertical: 14.0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (String value) => setState(() => mobileError = null),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    // 验证码 + 获取按钮
                    _buildField(
                      focusNode: codeFocus,
                      hasError: codeError != null,
                      child: TextField(
                        controller: codeController,
                        focusNode: codeFocus,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '请输入验证码',
                          hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
                          prefixIcon: const Icon(Icons.verified_user_outlined, size: 22.0, color: Colors.black26),
                          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
                          suffixIcon: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: counting || sending ? null : sendCode,
                            child: Container(
                              alignment: Alignment.center,
                              width: 96.0,
                              child: Text(
                                sending ? '发送中' : (counting ? '${seconds}s后重发' : '获取验证码'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: (counting || sending) ? Colors.black26 : _primary,
                                ),
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 100.0),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (String value) => setState(() => codeError = null),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    // 新密码
                    _buildField(
                      focusNode: pwdFocus,
                      hasError: pwdError != null,
                      child: TextField(
                        controller: pwdController,
                        focusNode: pwdFocus,
                        obscureText: obscurePwd,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: '请输入新密码(至少6位)',
                          hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22.0, color: Colors.black26),
                          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
                          suffixIcon: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => obscurePwd = !obscurePwd),
                            child: Icon(
                              obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20.0,
                              color: Colors.black38,
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 40.0),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (String value) => setState(() => pwdError = null),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    // 确认新密码
                    _buildField(
                      focusNode: rePwdFocus,
                      hasError: rePwdError != null,
                      child: TextField(
                        controller: rePwdController,
                        focusNode: rePwdFocus,
                        obscureText: obscureRePwd,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: '请再次输入新密码',
                          hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22.0, color: Colors.black26),
                          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
                          suffixIcon: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => obscureRePwd = !obscureRePwd),
                            child: Icon(
                              obscureRePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20.0,
                              color: Colors.black38,
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 40.0),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (String value) => setState(() => rePwdError = null),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    // 提交按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.0),
                          gradient: submitting
                              ? const LinearGradient(
                                  colors: <Color>[Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
                                )
                              : const LinearGradient(
                                  colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF9C55)],
                                ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24.0),
                            onTap: submitting ? null : handleSubmit,
                            child: Center(
                              child: submitting
                                  ? const SizedBox(
                                      width: 20.0,
                                      height: 20.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '重置密码',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }

  /// 输入框容器: 聚焦高亮边框,有错误时红色边框(与登录页一致)
  Widget _buildField({
    required FocusNode focusNode,
    required Widget child,
    bool hasError = false,
  }) {
    final bool focused = focusNode.hasFocus;
    final Color borderColor = hasError
        ? _primary
        : (focused ? _primary.withValues(alpha: 0.55) : const Color(0xFFF0F0F0));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: hasError
            ? _primary.withValues(alpha: 0.04)
            : (focused ? Colors.white : const Color(0xFFF7F8FA)),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: child,
    );
  }
}
