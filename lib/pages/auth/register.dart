/// 注册(对齐 H5: pages_tool/login/register.vue)
/// * 两种注册方式: 手机号+动态码 / 账号+密码, 由 /api/register/config 决定默认与可选项
/// * 图形验证码由 /api/config/getCaptchaConfig 的 shop_reception_register 控制开关
/// * 密码规则(长度 / 复杂度)同样取自 /api/register/config
/// * 注册成功直接登录: 存 token -> 拉会员信息 -> 未绑定门店去 /bind_store, 否则回首页
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../api/auth.dart';
import '../../utils/captcha.dart';
import '../../utils/index.dart';
import '../../controller/auth_store.dart';
import '../../widgets/field_error.dart';

class Register extends StatefulWidget {
  const Register({super.key});
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final authStore = AuthStore.to;

  /// 注册方式: mobile 手机号 / account 账号
  String registerMode = 'mobile';

  final TextEditingController mobileController = TextEditingController();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();
  final TextEditingController rePwdController = TextEditingController();
  final TextEditingController dynacodeController = TextEditingController();
  final TextEditingController vercodeController = TextEditingController();

  final FocusNode mobileFocus = FocusNode();
  final FocusNode accountFocus = FocusNode();
  final FocusNode pwdFocus = FocusNode();
  final FocusNode rePwdFocus = FocusNode();
  final FocusNode dynacodeFocus = FocusNode();
  final FocusNode vercodeFocus = FocusNode();

  // 平台配置
  Map<String, dynamic> registerConfig = <String, dynamic>{};
  bool agreementShow = true;
  bool supportMobile = true;
  bool supportAccount = true;
  bool registerOpen = true;

  // 图形验证码
  bool captchaOn = false;
  String captchaId = '';
  Uint8List? captchaBytes;

  // 动态码倒计时(与H5一致: 120s)
  Timer? dynacodeTimer;
  int dynacodeSeconds = 120;
  bool dynacodeSending = false;
  String dynacodeKey = '';

  bool submitting = false;
  bool agreed = false;
  bool obscurePwd = true;
  // 字段级错误: 展示在对应输入框下方(null 表示无错误)
  String? mobileError;
  String? dynacodeError;
  String? accountError;
  String? pwdError;
  String? rePwdError;
  String? vercodeError;
  // 表单级错误: 平台未开启注册 / 协议未勾选 / 服务端返回且无法归属到具体输入框
  String? formError;

  @override
  void initState() {
    super.initState();
    mobileFocus.addListener(() => setState(() {}));
    accountFocus.addListener(() => setState(() {}));
    pwdFocus.addListener(() => setState(() {}));
    rePwdFocus.addListener(() => setState(() {}));
    dynacodeFocus.addListener(() => setState(() {}));
    vercodeFocus.addListener(() => setState(() {}));
    loadConfig();
    loadCaptchaConfig();
  }

  @override
  void dispose() {
    mobileController.dispose();
    accountController.dispose();
    pwdController.dispose();
    rePwdController.dispose();
    dynacodeController.dispose();
    vercodeController.dispose();
    mobileFocus.dispose();
    accountFocus.dispose();
    pwdFocus.dispose();
    rePwdFocus.dispose();
    dynacodeFocus.dispose();
    vercodeFocus.dispose();
    dynacodeTimer?.cancel();
    super.dispose();
  }

  /// 注册配置: 注册方式 / 协议 / 密码规则
  Future<void> loadConfig() async {
    try {
      final Map<String, dynamic> config = await AuthApi.registerConfig();
      if (!mounted) return;
      final String register = '${config['register'] ?? ''}';
      if (register.isEmpty) {
        // 平台未开启注册(H5 同处理: 提示后回首页)
        registerOpen = false;
        MyDialog.toast('平台未开启注册', icon: const Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)).center());
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Get.offAllNamed('/');
        });
        return;
      }
      setState(() {
        registerConfig = config;
        agreementShow = AuthApi.isOn(config, 'agreement_show');
        supportMobile = register.contains('mobile');
        supportAccount = register.contains('username');
        // H5: 支持用户名注册时默认账号注册,否则手机号
        registerMode = supportAccount ? 'account' : 'mobile';
      });
    } catch (_) {}
  }

  /// 图形验证码配置
  Future<void> loadCaptchaConfig() async {
    try {
      final Map<String, dynamic> config = await AuthApi.captchaConfig();
      if (!mounted) return;
      setState(() => captchaOn = AuthApi.isOn(config, 'shop_reception_register'));
      if (captchaOn) refreshCaptcha();
    } catch (_) {}
  }

  Future<void> refreshCaptcha() async {
    if (!captchaOn) return;
    try {
      final Map<String, dynamic> res = await AuthApi.captcha(id: captchaId);
      if (!mounted) return;
      setState(() {
        captchaId = '${res['id'] ?? ''}';
        captchaBytes = CaptchaImg.decode('${res['img'] ?? ''}');
      });
    } catch (_) {}
  }

  /// 展示错误: 优先显示在对应输入框下方,判断不了时显示在按钮上方
  void showError(String message, {String? field}) {
    if (!mounted) return;
    setState(() {
      mobileError = null;
      dynacodeError = null;
      accountError = null;
      pwdError = null;
      rePwdError = null;
      vercodeError = null;
      formError = null;
      switch (field ?? guessErrorField(message)) {
        case 'mobile':
          mobileError = message;
        case 'dynacode':
          dynacodeError = message;
        case 'account':
          accountError = message;
        case 'pwd':
          pwdError = message;
        case 'rePwd':
          rePwdError = message;
        case 'vercode':
          vercodeError = message;
        default:
          formError = message;
      }
    });
  }

  /// 清空全部错误提示
  void clearErrors() {
    if (!mounted) return;
    setState(() {
      mobileError = null;
      dynacodeError = null;
      accountError = null;
      pwdError = null;
      rePwdError = null;
      vercodeError = null;
      formError = null;
    });
  }

  /// 发送注册动态码
  Future<void> sendDynacode() async {
    if (dynacodeSeconds != 120 || dynacodeSending) return;
    final String mobile = mobileController.text.trim();
    if (mobile.isEmpty) {
      showError('请输入手机号', field: 'mobile');
      return;
    }
    if (!Utils.checkTel(mobile)) {
      showError('手机号格式不正确', field: 'mobile');
      return;
    }
    if (captchaOn && vercodeController.text.trim().isEmpty) {
      showError('请输入验证码', field: 'vercode');
      return;
    }
    setState(() => dynacodeSending = true);
    try {
      final String key = await AuthApi.registerMobileCode(
        mobile: mobile,
        captchaId: captchaId,
        captchaCode: vercodeController.text.trim(),
      );
      if (!mounted) return;
      dynacodeKey = key;
      setState(() {
        dynacodeSeconds = 119;
        dynacodeSending = false;
      });
      dynacodeTimer?.cancel();
      dynacodeTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => dynacodeSeconds--);
        if (dynacodeSeconds <= 0) resetDynacode();
      });
      MyDialog.toast('动态码已发送，请注意查收', style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)));
    } catch (e) {
      if (!mounted) return;
      setState(() => dynacodeSending = false);
      showError(AuthApi.errorMsg(e));
      refreshCaptcha();
    }
  }

  void resetDynacode() {
    dynacodeTimer?.cancel();
    dynacodeTimer = null;
    setState(() {
      dynacodeSeconds = 120;
      dynacodeSending = false;
    });
    refreshCaptcha();
  }

  /// 密码规则校验(取自 /api/register/config: pwd_len / pwd_complexity)
  String? checkPassword(String pwd) {
    if (pwd.isEmpty) return '请输入密码';
    final int pwdLen = int.tryParse('${registerConfig['pwd_len'] ?? ''}') ?? 0;
    if (pwdLen > 0 && pwd.length < pwdLen) return '密码长度不能小于${pwdLen.toString()}位';
    final String complexity = '${registerConfig['pwd_complexity'] ?? ''}';
    if (complexity.isNotEmpty) {
      String reg = '';
      String errorMsg = '密码需包含';
      if (complexity.contains('number')) {
        reg += '(?=.*?[0-9])';
        errorMsg += '数字';
      }
      if (complexity.contains('letter')) {
        reg += '(?=.*?[a-z])';
        errorMsg += '、小写字母';
      }
      if (complexity.contains('upper_case')) {
        reg += '(?=.*?[A-Z])';
        errorMsg += '、大写字母';
      }
      if (complexity.contains('symbol')) {
        reg += '(?=.*?[#?!@\$%^&*-])';
        errorMsg += '、特殊字符';
      }
      if (reg.isNotEmpty && !RegExp('^$reg.*\$').hasMatch(pwd)) return errorMsg;
    }
    return null;
  }

  /// 表单校验(返回 null 表示通过;否则返回 <字段, 提示>,提示显示在对应位置)
  MapEntry<String, String>? verify() {
    if (!registerOpen) return const MapEntry<String, String>('form', '平台未开启注册');
    if (registerMode == 'mobile') {
      final String mobile = mobileController.text.trim();
      if (mobile.isEmpty) return const MapEntry<String, String>('mobile', '请输入手机号');
      if (!Utils.checkTel(mobile)) return const MapEntry<String, String>('mobile', '手机号格式不正确');
      if (dynacodeController.text.trim().isEmpty) return const MapEntry<String, String>('dynacode', '请输入动态码');
      if (dynacodeKey.isEmpty) return const MapEntry<String, String>('dynacode', '请先获取动态码');
    } else {
      final String account = accountController.text.trim();
      if (account.isEmpty) return const MapEntry<String, String>('account', '请输入账号');
      // H5: 用户名只能数字 + 英文
      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(account)) {
        return const MapEntry<String, String>('account', '用户名只能输入数字跟英文');
      }
      final String? pwdErr = checkPassword(pwdController.text);
      if (pwdErr != null) return MapEntry<String, String>('pwd', pwdErr);
      if (rePwdController.text.isEmpty) return const MapEntry<String, String>('rePwd', '请确认密码');
      if (pwdController.text != rePwdController.text) return const MapEntry<String, String>('rePwd', '两次密码不一致');
    }
    if (captchaOn && vercodeController.text.trim().isEmpty) {
      return const MapEntry<String, String>('vercode', '请输入验证码');
    }
    // 协议最后校验: 让用户先把表单填对,最后再提示勾选协议
    if (agreementShow && !agreed) {
      return const MapEntry<String, String>('agreement', '请先阅读并同意《隐私协议》和《用户协议》');
    }
    return null;
  }

  Future<void> handleSubmit() async {
    clearErrors();
    final MapEntry<String, String>? error = verify();
    if (error != null) {
      if (error.key == 'agreement') {
        await showAgreementDialog(onAgreed: handleSubmit);
        return;
      }
      showError(error.value, field: error.key);
      return;
    }
    if (submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      final Map<String, dynamic> res = registerMode == 'mobile'
          ? await AuthApi.registerMobile(
              mobile: mobileController.text.trim(),
              key: dynacodeKey,
              code: dynacodeController.text.trim(),
              captchaId: captchaId,
              captchaCode: vercodeController.text.trim(),
            )
          : await AuthApi.registerUsername(
              username: accountController.text.trim(),
              password: pwdController.text,
              captchaId: captchaId,
              captchaCode: vercodeController.text.trim(),
            );
      if (!mounted) return;
      final String token = '${res['token'] ?? ''}';
      // 注册成功直接登录(H5 同处理)
      if (token.isNotEmpty) {
        authStore.setAuthorization(token);
        await authStore.loadMemberInfo();
      }
      final dynamic rawData = res['data'];
      final int storeId = rawData is Map ? int.tryParse('${rawData['store_id'] ?? ''}') ?? 0 : 0;
      final bool boundStore = storeId != 0 || authStore.storeId.value != 0;
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (token.isEmpty) {
          Get.offAllNamed('/login');
        } else if (!boundStore) {
          Get.offAllNamed('/bind_store');
        } else {
          Get.offAllNamed('/');
        }
      });
    } catch (e) {
      if (!mounted) return;
      showError(AuthApi.errorMsg(e));
      refreshCaptcha();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              _buildHeader(statusTop),
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.0),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16.0, offset: const Offset(0.0, 4.0)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (supportMobile && supportAccount) _buildModeTabs(),
                      const SizedBox(height: 14.0),
                      if (registerMode == 'mobile') ...<Widget>[
                        _buildMobileInput(),
                        const SizedBox(height: 14.0),
                        _buildDynacodeInput(),
                      ] else ...<Widget>[
                        _buildAccountInput(),
                        const SizedBox(height: 14.0),
                        _buildPwdInput(),
                        const SizedBox(height: 14.0),
                        _buildRePwdInput(),
                      ],
                      if (captchaOn) ...<Widget>[
                        const SizedBox(height: 14.0),
                        _buildCaptchaInput(),
                      ],
                      const SizedBox(height: 18.0),
                      _buildAgreement(),
                      // 表单级错误: 平台未开启注册 / 协议未勾选 / 服务端返回但无法归属到具体输入框
                      FieldError(formError),
                      const SizedBox(height: 22.0),
                      _buildSubmit(),
                      const SizedBox(height: 16.0),
                      _buildFooter(),
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

  /// 红色渐变头部
  Widget _buildHeader(double statusTop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.0, statusTop + 36.0, 24.0, 66.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF7A52)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.back(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20.0, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Text(
            '注册账号',
            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6.0),
          Text(
            '注册后即可下单、领券与绑定门店',
            style: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return Row(
      children: <Widget>[
        if (supportAccount) _buildModeTab('账号注册', 'account'),
        if (supportAccount && supportMobile) const SizedBox(width: 22.0),
        if (supportMobile) _buildModeTab('手机号注册', 'mobile'),
      ],
    );
  }

  Widget _buildModeTab(String text, String mode) {
    final bool active = registerMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => registerMode = mode);
        clearErrors();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? const Color(0xFFFF2C55) : Colors.black45,
            ),
          ),
          const SizedBox(height: 6.0),
          Container(width: 24.0, height: 2.0, color: active ? const Color(0xFFFF2C55) : Colors.transparent),
        ],
      ),
    );
  }

  Widget _buildMobileInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: mobileFocus,
          hasError: mobileError != null,
          child: TextField(
            controller: mobileController,
            focusNode: mobileFocus,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            style: const TextStyle(fontSize: 14.0),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '仅限中国大陆手机号',
              hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: SizedBox(
                width: 40.0,
                child: Center(child: Text('+86', style: TextStyle(fontSize: 14.0, color: Colors.black87))),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 40.0),
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

  Widget _buildDynacodeInput() {
    final bool counting = dynacodeSeconds != 120;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: dynacodeFocus,
          hasError: dynacodeError != null,
          child: TextField(
            controller: dynacodeController,
            focusNode: dynacodeFocus,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: '请输入动态码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: const Icon(Icons.sms_outlined, size: 18.0, color: Colors.black26),
              prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
              suffixIcon: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: counting ? null : sendDynacode,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Center(
                    widthFactor: 1.0,
                    child: Text(
                      dynacodeSending ? '发送中' : (counting ? '${dynacodeSeconds}s后重发' : '获取动态码'),
                      style: TextStyle(
                        fontSize: 12.0,
                        color: counting ? Colors.grey : const Color(0xFFFF2C55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 76.0),
              contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => dynacodeError = null),
          ),
        ),
        FieldError(dynacodeError),
      ],
    );
  }

  Widget _buildAccountInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: accountFocus,
          hasError: accountError != null,
          child: TextField(
            controller: accountController,
            focusNode: accountFocus,
            style: const TextStyle(fontSize: 14.0),
            decoration: const InputDecoration(
              hintText: '请输入账号(数字或英文)',
              hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18.0, color: Colors.black26),
              prefixIconConstraints: BoxConstraints(minWidth: 40.0),
              contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => accountError = null),
          ),
        ),
        FieldError(accountError),
      ],
    );
  }

  Widget _buildPwdInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: pwdFocus,
          hasError: pwdError != null,
          child: TextField(
            controller: pwdController,
            focusNode: pwdFocus,
            obscureText: obscurePwd,
            style: const TextStyle(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: '请输入密码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.black26),
              prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36.0),
                icon: Icon(obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16.0, color: Colors.black26),
                onPressed: () => setState(() => obscurePwd = !obscurePwd),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => pwdError = null),
          ),
        ),
        FieldError(pwdError),
      ],
    );
  }

  Widget _buildRePwdInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: rePwdFocus,
          hasError: rePwdError != null,
          child: TextField(
            controller: rePwdController,
            focusNode: rePwdFocus,
            obscureText: obscurePwd,
            style: const TextStyle(fontSize: 14.0),
            decoration: const InputDecoration(
              hintText: '请确认密码',
              hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.black26),
              prefixIconConstraints: BoxConstraints(minWidth: 40.0),
              contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => rePwdError = null),
          ),
        ),
        FieldError(rePwdError),
      ],
    );
  }

  Widget _buildCaptchaInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInputBox(
          focusNode: vercodeFocus,
          hasError: vercodeError != null,
          child: TextField(
            controller: vercodeController,
            focusNode: vercodeFocus,
            style: const TextStyle(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: '请输入验证码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: const Icon(Icons.verified_user_outlined, size: 18.0, color: Colors.black26),
              prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
              suffixIcon: GestureDetector(
                onTap: refreshCaptcha,
                child: Container(
                  width: 78.0,
                  height: 32.0,
                  margin: const EdgeInsets.only(left: 6.0),
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
              suffixIconConstraints: const BoxConstraints(minWidth: 84.0, minHeight: 32.0),
              contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) => setState(() => vercodeError = null),
          ),
        ),
        FieldError(vercodeError),
      ],
    );
  }

  /// 输入框容器: 聚焦时高亮边框,有错误时红色边框
  Widget _buildInputBox({required FocusNode focusNode, required Widget child, bool hasError = false}) {
    final bool focused = focusNode.hasFocus;
    const Color primary = Color(0xFFFF2C55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: hasError ? primary.withValues(alpha: 0.04) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: hasError
              ? primary
              : (focused ? primary.withValues(alpha: 0.5) : const Color(0xFFF0F0F0)),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSubmit() {
    return Container(
      width: double.infinity,
      height: 46.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23.0),
        gradient: LinearGradient(
          colors: submitting
              ? <Color>[Colors.grey.shade300, Colors.grey.shade400]
              : const <Color>[Color(0xFFFF2C55), Color(0xFFFF9C55)],
        ),
        boxShadow: submitting
            ? null
            : <BoxShadow>[
                BoxShadow(color: const Color(0xFFFF2C55).withValues(alpha: 0.28), blurRadius: 12.0, offset: const Offset(0.0, 5.0)),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(23.0),
          onTap: submitting ? null : handleSubmit,
          child: Center(
            child: submitting
                ? const SizedBox(width: 18.0, height: 18.0, child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white))
                : const Text('注 册', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 4.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildAgreement() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            agreed = !agreed;
            formError = null;
          }),
          child: Padding(
            padding: const EdgeInsets.only(right: 4.0, top: 4.0, bottom: 4.0),
            child: Container(
              width: 15.0,
              height: 15.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: agreed ? const Color(0xFFFF2C55) : Colors.transparent,
                border: Border.all(color: agreed ? const Color(0xFFFF2C55) : Colors.grey.shade400, width: 1.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: agreed ? const Icon(Icons.check, size: 11.0, color: Colors.white) : null,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('请阅读并同意', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
              _buildAgreementLink('《隐私协议》', 'PRIVACY'),
              const Text('和', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
              _buildAgreementLink('《用户协议》', 'SERVICE'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementLink(String text, String type) {
    return GestureDetector(
      onTap: () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': type}),
      child: Text(text, style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0)),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text('已有账号，', style: TextStyle(color: Colors.black38, fontSize: 13.0)),
        GestureDetector(
          onTap: () => Get.offNamed('/login'),
          child: const Text('立即登录', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 13.0, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  /// 协议确认弹窗(类似京东): 未勾选协议时弹出,点"同意"自动勾选并继续
  /// * 用原生 showDialog 挂在当前 State 的 context 上,避免 shirne_dialog 的
  ///   navigatorKey 在 GetX 路由下取不到 NavigatorState 导致弹窗推不出来的问题
  Future<void> showAgreementDialog({required VoidCallback onAgreed}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildAgreementDialogContent(),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        foregroundColor: const Color(0xFF202020),
                        minimumSize: const Size.fromHeight(44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('我再想想', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2C55),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('同意', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (ok == true && mounted) {
      setState(() => agreed = true);
      onAgreed();
    }
  }

  /// 弹窗内容: 请阅读并同意《隐私协议》《用户协议》,协议名可点击跳转
  Widget _buildAgreementDialogContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: '请阅读并同意',
          style: const TextStyle(fontSize: 15, color: Color(0xFF202020), height: 1.5),
          children: <InlineSpan>[
            const TextSpan(text: '《', style: TextStyle(color: Color(0xFF202020))),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'PRIVACY'}),
                child: const Text(
                  '隐私协议',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C8DFA)),
                ),
              ),
            ),
            const TextSpan(text: '》《', style: TextStyle(color: Color(0xFF202020))),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'SERVICE'}),
                child: const Text(
                  '用户协议',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C8DFA)),
                ),
              ),
            ),
            const TextSpan(text: '》', style: TextStyle(color: Color(0xFF202020))),
          ],
        ),
      ),
    );
  }
}
