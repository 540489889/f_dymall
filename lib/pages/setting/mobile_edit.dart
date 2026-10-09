/// 绑定 / 更换手机号(独立页,替换原弹窗)
/// 从「账户安全」页点击「手机」进入
/// 流程(与 H5 一致): 新手机号 + 图形验证码 + 短信动态码(120s) -> /api/member/modifymobile
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

class MobileEditPage extends StatefulWidget {
  const MobileEditPage({super.key});

  @override
  State<MobileEditPage> createState() => _MobileEditPageState();
}

class _MobileEditPageState extends State<MobileEditPage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  final TextEditingController mobileCtl = TextEditingController();
  final TextEditingController verCtl = TextEditingController();
  final TextEditingController dynCtl = TextEditingController();

  final FocusNode mobileFocus = FocusNode();
  final FocusNode verFocus = FocusNode();
  final FocusNode dynFocus = FocusNode();

  /// 未绑定时为「绑定手机号」,已绑定时为「更换手机号」
  bool get isBind => auth.mobile.isEmpty;

  // 图形验证码
  String captchaId = '';
  Uint8List? captchaBytes;

  // 短信动态码(120s 倒计时)
  Timer? timer;
  int seconds = 0;
  bool sending = false;
  String smsKey = '';

  bool submitting = false;

  // 字段级错误: 展示在对应输入框下方
  String? mobileError;
  String? verError;
  String? dynError;
  // 表单级错误: 服务端返回且无法归属到具体输入框
  String? formError;

  static final RegExp _mobileRegExp = RegExp(r'^1[3-9]\d{9}$');

  @override
  void initState() {
    super.initState();
    mobileFocus.addListener(() => setState(() {}));
    verFocus.addListener(() => setState(() {}));
    dynFocus.addListener(() => setState(() {}));
    refreshCaptcha();
  }

  @override
  void dispose() {
    mobileCtl.dispose();
    verCtl.dispose();
    dynCtl.dispose();
    mobileFocus.dispose();
    verFocus.dispose();
    dynFocus.dispose();
    timer?.cancel();
    super.dispose();
  }

  // ============== 图形验证码 ==============

  /// 刷新图形验证码(发送失败 / 换绑失败时都要刷新,与 H5 一致)
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

  /// 发送短信动态码: 先校验手机号未被占用(/api/member/checkmobile)
  Future<void> sendCode() async {
    if (seconds > 0 || sending) return;
    final String mobile = mobileCtl.text.trim();
    if (mobile.isEmpty) return showError('请输入手机号', field: 'mobile');
    if (!_mobileRegExp.hasMatch(mobile)) return showError('手机号格式不正确', field: 'mobile');
    if (verCtl.text.trim().isEmpty) return showError('请输入验证码', field: 'vercode');
    clearErrors();
    setState(() => sending = true);
    try {
      await MemberApi.checkMobile(mobile);
      final String key = await MemberApi.bindMobileCode(
        mobile: mobile,
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

  /// 倒计时归零 / 发送失败: 还原状态
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
    final String mobile = mobileCtl.text.trim();
    if (mobile.isEmpty) return const MapEntry<String, String>('mobile', '请输入手机号');
    if (!_mobileRegExp.hasMatch(mobile)) return const MapEntry<String, String>('mobile', '手机号格式不正确');
    if (!isBind && mobile == auth.mobile) return const MapEntry<String, String>('mobile', '与原手机号一致');
    if (verCtl.text.trim().isEmpty) return const MapEntry<String, String>('vercode', '请输入验证码');
    if (smsKey.isEmpty) return const MapEntry<String, String>('dynacode', '请先获取动态码');
    if (dynCtl.text.trim().isEmpty) return const MapEntry<String, String>('dynacode', '请输入动态码');
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
      await MemberApi.modifyMobile(
        mobile: mobileCtl.text.trim(),
        code: dynCtl.text.trim(),
        key: smsKey,
        captchaId: captchaId,
        captchaCode: verCtl.text.trim(),
      );
      await auth.loadMemberInfo();
      if (!mounted) return;
      MyDialog.toast(isBind ? '手机号绑定成功' : '手机号更换成功');
      Get.back<bool>(result: true);
    } catch (e) {
      if (!mounted) return;
      showError(MemberApi.errorMsg(e, '修改失败'));
      refreshCaptcha();
      resetCode();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// 展示错误: 优先显示在对应输入框下方,判断不了时显示在按钮上方
  void showError(String message, {String? field}) {
    if (!mounted) return;
    setState(() {
      mobileError = null;
      verError = null;
      dynError = null;
      formError = null;
      switch (field ?? guessErrorField(message)) {
        case 'mobile':
          mobileError = message;
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
      mobileError = null;
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
                      _buildCurrentMobile(),
                      const SizedBox(height: 18.0),
                      _buildMobileInput(),
                      const SizedBox(height: 12.0),
                      _buildCaptchaInput(),
                      const SizedBox(height: 12.0),
                      _buildDynacodeInput(),
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
                isBind ? '绑定手机号' : '更换手机号',
                style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 42.0), // 占位平衡左右
        ],
      ),
    );
  }

  /// 当前手机号(已绑定时展示)
  Widget _buildCurrentMobile() {
    if (isBind) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        children: <Widget>[
          const Text('当前手机号', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _maskMobile(auth.mobile),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// 新手机号
  Widget _buildMobileInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _inputBox(
          focusNode: mobileFocus,
          hasError: mobileError != null,
          child: TextField(
            controller: mobileCtl,
            focusNode: mobileFocus,
            enabled: !submitting,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            style: const TextStyle(fontSize: 15.0, color: Colors.black87),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '请输入新手机号',
              hintStyle: TextStyle(fontSize: 14.0, color: Color(0xFFBDBDBD)),
              prefixIcon: Icon(Icons.phone_iphone_outlined, size: 18.0, color: Colors.black26),
              prefixIconConstraints: BoxConstraints(minWidth: 42.0),
              contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => mobileError = null),
          ),
        ),
        FieldError(mobileError),
      ],
    );
  }

  /// 图形验证码
  Widget _buildCaptchaInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _inputBox(
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
        ),
        FieldError(verError),
      ],
    );
  }

  /// 短信动态码
  Widget _buildDynacodeInput() {
    final bool counting = seconds > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _inputBox(
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
        ),
        FieldError(dynError),
      ],
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
    return const Text(
      '更换手机号后,原手机号将无法用于登录,请使用新手机号登录。',
      style: TextStyle(fontSize: 12.0, color: Color(0xFF999999), height: 1.5),
    );
  }

  /// 手机号脱敏: 138****8888
  String _maskMobile(String mobile) {
    if (mobile.length < 7) return mobile;
    return '${mobile.substring(0, 3)}****${mobile.substring(mobile.length - 4)}';
  }
}
