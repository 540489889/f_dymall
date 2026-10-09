/// 修改 / 设置密码(独立页,替换原弹窗)
/// 从「账户安全」页点击「密码」进入
/// * 已设密码: 原密码 + 新密码 + 确认新密码 -> /api/member/modifypassword(old_password)
/// * 未设密码: 图形验证码 + 短信动态码(当前手机号) + 新密码 -> /api/member/modifypassword(code + key)
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import '../../utils/captcha.dart';
import '../../widgets/field_error.dart';

/// 主色
const Color _primary = Color(0xFFFF2C55);

class PasswordEditPage extends StatefulWidget {
  const PasswordEditPage({super.key});

  @override
  State<PasswordEditPage> createState() => _PasswordEditPageState();
}

class _PasswordEditPageState extends State<PasswordEditPage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  final TextEditingController oldCtl = TextEditingController();
  final TextEditingController newCtl = TextEditingController();
  final TextEditingController confirmCtl = TextEditingController();
  final TextEditingController verCtl = TextEditingController();
  final TextEditingController dynCtl = TextEditingController();

  final FocusNode oldFocus = FocusNode();
  final FocusNode newFocus = FocusNode();
  final FocusNode confirmFocus = FocusNode();
  final FocusNode verFocus = FocusNode();
  final FocusNode dynFocus = FocusNode();

  /// 已设置过密码走「原密码」,未设置走「短信动态码」
  bool get hasPassword => auth.hasPassword;

  // 密码明文开关
  bool oldObscure = true;
  bool newObscure = true;
  bool confirmObscure = true;

  // 图形验证码(未设密码时用于发短信)
  String captchaId = '';
  Uint8List? captchaBytes;

  // 短信动态码(120s 倒计时)
  Timer? timer;
  int seconds = 0;
  bool sending = false;
  String smsKey = '';

  bool submitting = false;

  // 字段级错误: 展示在对应输入框下方
  String? oldError;
  String? newError;
  String? confirmError;
  String? verError;
  String? dynError;
  // 表单级错误: 服务端返回且无法归属到具体输入框
  String? formError;

  @override
  void initState() {
    super.initState();
    oldFocus.addListener(() => setState(() {}));
    newFocus.addListener(() => setState(() {}));
    confirmFocus.addListener(() => setState(() {}));
    verFocus.addListener(() => setState(() {}));
    dynFocus.addListener(() => setState(() {}));
    if (!hasPassword) refreshCaptcha();
  }

  @override
  void dispose() {
    oldCtl.dispose();
    newCtl.dispose();
    confirmCtl.dispose();
    verCtl.dispose();
    dynCtl.dispose();
    oldFocus.dispose();
    newFocus.dispose();
    confirmFocus.dispose();
    verFocus.dispose();
    dynFocus.dispose();
    timer?.cancel();
    super.dispose();
  }

  // ============== 图形验证码 ==============

  Future<void> refreshCaptcha() async {
    try {
      final Map<String, dynamic> res = await MemberApi.captcha();
      if (!mounted) return;
      setState(() {
        captchaId = '${res['id'] ?? ''}';
        captchaBytes = CaptchaImg.decode('${res['img'] ?? ''}');
      });
    } catch (_) {}
  }

  // ============== 短信动态码 ==============

  /// 发往当前账号已绑定的手机号(/api/member/pwdmobliecode)
  Future<void> sendCode() async {
    if (seconds > 0 || sending) return;
    if (verCtl.text.trim().isEmpty) return showError('请输入验证码', field: 'vercode');
    clearErrors();
    setState(() => sending = true);
    try {
      final String key = await MemberApi.pwdMobileCode(
        captchaId: captchaId,
        captchaCode: verCtl.text.trim(),
      );
      if (!mounted) return;
      smsKey = key;
      setState(() {
        sending = false;
        seconds = 120;
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => seconds--);
        if (seconds <= 0) resetCode();
      });
      MyDialog.toast('动态码已发送，请注意查收');
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      showError(MemberApi.errorMsg(e, '动态码发送失败'));
      refreshCaptcha();
    }
  }

  void resetCode() {
    timer?.cancel();
    timer = null;
    setState(() {
      seconds = 0;
      sending = false;
    });
  }

  // ============== 校验 / 提交 ==============

  /// 表单校验: 返回 <字段, 提示>,null 表示通过
  MapEntry<String, String>? verify() {
    final String newPwd = newCtl.text.trim();
    final String confirmPwd = confirmCtl.text.trim();
    if (hasPassword) {
      final String oldPwd = oldCtl.text.trim();
      if (oldPwd.isEmpty) return const MapEntry<String, String>('pwd', '请输入原密码');
      if (newPwd.isEmpty) return const MapEntry<String, String>('newPwd', '请输入新密码');
      if (oldPwd == newPwd) return const MapEntry<String, String>('newPwd', '新密码不能与原密码相同');
    } else {
      if (verCtl.text.trim().isEmpty) return const MapEntry<String, String>('vercode', '请输入验证码');
      if (smsKey.isEmpty) return const MapEntry<String, String>('dynacode', '请先获取动态码');
      if (dynCtl.text.trim().isEmpty) return const MapEntry<String, String>('dynacode', '请输入动态码');
      if (newPwd.isEmpty) return const MapEntry<String, String>('newPwd', '请输入新密码');
    }
    if (newPwd != confirmPwd) return const MapEntry<String, String>('rePwd', '两次密码不一致');
    return null;
  }

  Future<void> submit() async {
    clearErrors();
    final MapEntry<String, String>? error = verify();
    if (error != null) return showError(error.value, field: error.key);
    if (submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await MemberApi.modifyPassword(
        newPassword: newCtl.text.trim(),
        oldPassword: hasPassword ? oldCtl.text.trim() : '',
        code: hasPassword ? '' : dynCtl.text.trim(),
        key: hasPassword ? '' : smsKey,
      );
      await auth.loadMemberInfo();
      if (!mounted) return;
      MyDialog.toast(hasPassword ? '密码修改成功' : '密码设置成功');
      Get.back<bool>(result: true);
    } catch (e) {
      if (!mounted) return;
      showError(MemberApi.errorMsg(e, '修改失败'));
      if (!hasPassword) {
        refreshCaptcha();
        resetCode();
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// 展示错误: 优先显示在对应输入框下方,判断不了时显示在按钮上方
  void showError(String message, {String? field}) {
    if (!mounted) return;
    setState(() {
      oldError = null;
      newError = null;
      confirmError = null;
      verError = null;
      dynError = null;
      formError = null;
      switch (field ?? guessErrorField(message)) {
        case 'pwd':
          oldError = message;
        case 'newPwd':
          newError = message;
        case 'rePwd':
          confirmError = message;
        case 'vercode':
          verError = message;
        case 'dynacode':
          dynError = message;
        default:
          formError = message;
      }
    });
  }

  void clearErrors() {
    if (!mounted) return;
    setState(() {
      oldError = null;
      newError = null;
      confirmError = null;
      verError = null;
      dynError = null;
      formError = null;
    });
  }

  // ============== 页面 ==============

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    final double keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 白底页面:状态栏透出白色
        statusBarIconBrightness: Brightness.dark, // Android 黑色图标
        statusBarBrightness: Brightness.light, // iOS 黑色图标
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: <Widget>[
              SizedBox(height: statusTop),
              _buildAppBar(),
              if (submitting)
                const SizedBox(
                  height: 2.0,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFFFFEEF0),
                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, keyboardBottom + 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (hasPassword) ...<Widget>[
                        _buildPasswordField(
                          label: '原密码',
                          controller: oldCtl,
                          focusNode: oldFocus,
                          obscure: oldObscure,
                          hasError: oldError != null,
                          onToggle: () => setState(() => oldObscure = !oldObscure),
                          onChanged: () => setState(() => oldError = null),
                        ),
                        FieldError(oldError),
                      ] else ...<Widget>[
                        _buildCaptchaInput(),
                        FieldError(verError),
                        const SizedBox(height: 12.0),
                        _buildDynacodeInput(),
                        FieldError(dynError),
                      ],
                      const SizedBox(height: 12.0),
                      _buildPasswordField(
                        label: '新密码',
                        controller: newCtl,
                        focusNode: newFocus,
                        obscure: newObscure,
                        hasError: newError != null,
                        onToggle: () => setState(() => newObscure = !newObscure),
                        onChanged: () => setState(() => newError = null),
                      ),
                      FieldError(newError),
                      const SizedBox(height: 12.0),
                      _buildPasswordField(
                        label: '确认新密码',
                        controller: confirmCtl,
                        focusNode: confirmFocus,
                        obscure: confirmObscure,
                        hasError: confirmError != null,
                        onToggle: () => setState(() => confirmObscure = !confirmObscure),
                        onChanged: () => setState(() => confirmError = null),
                      ),
                      FieldError(confirmError),
                      FieldError(formError, top: 14.0),
                      const SizedBox(height: 32.0),
                      _buildSubmit(),
                      const SizedBox(height: 12.0),
                      _buildTips(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => Get.back<void>(),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.chevron_left, size: 26.0, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hasPassword ? '修改密码' : '设置密码',
                style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 42.0), // 占位平衡左右
        ],
      ),
    );
  }

  /// 密码输入框(带明文切换)
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    required VoidCallback onToggle,
    required VoidCallback onChanged,
    bool hasError = false,
  }) {
    return _inputBox(
      focusNode: focusNode,
      hasError: hasError,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !submitting,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15.0, color: Colors.black87),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFFBDBDBD)),
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.black26),
          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
          suffixIcon: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18.0,
              color: Colors.black26,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40.0),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String value) => onChanged(),
      ),
    );
  }

  /// 图形验证码
  Widget _buildCaptchaInput() {
    return _inputBox(
      focusNode: verFocus,
      hasError: verError != null,
      child: TextField(
        controller: verCtl,
        focusNode: verFocus,
        enabled: !submitting,
        style: const TextStyle(fontSize: 15.0, color: Colors.black87),
        decoration: InputDecoration(
          hintText: '请输入验证码',
          hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFFBDBDBD)),
          prefixIcon: const Icon(Icons.verified_user_outlined, size: 18.0, color: Colors.black26),
          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
          suffixIcon: GestureDetector(
            onTap: refreshCaptcha,
            child: Container(
              width: 84.0,
              height: 32.0,
              margin: const EdgeInsets.only(left: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(6.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: captchaBytes == null
                  ? const Center(child: Text('点击刷新', style: TextStyle(fontSize: 11.0, color: Colors.black38)))
                  : Image.memory(captchaBytes!, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 92.0, minHeight: 32.0),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String value) => setState(() => verError = null),
      ),
    );
  }

  /// 短信动态码
  Widget _buildDynacodeInput() {
    final bool counting = seconds > 0;
    return _inputBox(
      focusNode: dynFocus,
      hasError: dynError != null,
      child: TextField(
        controller: dynCtl,
        focusNode: dynFocus,
        enabled: !submitting,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 15.0, color: Colors.black87),
        decoration: InputDecoration(
          hintText: '请输入动态码',
          hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFFBDBDBD)),
          prefixIcon: const Icon(Icons.sms_outlined, size: 18.0, color: Colors.black26),
          prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
          suffixIcon: SizedBox(
            width: 88.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Container(width: 1.0, height: 18.0, color: const Color(0xFFE6E7EA)),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: counting || sending ? null : sendCode,
                    child: Center(
                      child: Text(
                        sending ? '发送中' : (counting ? '${seconds}s' : '获取动态码'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: counting || sending ? Colors.black26 : _primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 88.0),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String value) => setState(() => dynError = null),
      ),
    );
  }

  /// 输入框容器: 聚焦高亮边框,出错红色边框
  Widget _inputBox({required FocusNode focusNode, required Widget child, bool hasError = false}) {
    final bool focused = focusNode.hasFocus;
    final Color borderColor =
        hasError ? _primary : (focused ? _primary.withValues(alpha: 0.55) : const Color(0xFFF0F0F0));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: hasError ? _primary.withValues(alpha: 0.04) : (focused ? Colors.white : const Color(0xFFF7F8FA)),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: child,
    );
  }

  /// 提交按钮
  Widget _buildSubmit() {
    return SizedBox(
      width: double.infinity,
      height: 46.0,
      child: ElevatedButton(
        onPressed: submitting ? null : submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: FStyle.primaryColor,
          disabledBackgroundColor: const Color(0xFFE4E4E7), // 禁用: 灰底灰字,明确不可点
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF9B9B9B),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23.0)),
        ),
        child: submitting
            ? const SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('提交', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
      ),
    );
  }

  /// 底部提示
  Widget _buildTips() {
    return Text(
      hasPassword ? '修改成功后需要使用新密码重新登录。' : '动态码将发送至当前账号绑定的手机号。',
      style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999), height: 1.5),
    );
  }
}
