/// 微信登录未绑定账号 -> 绑定手机号(对齐 H5: pages_tool/login/login.vue)
/// * 微信授权拿到的 openid/unionid/nickname/headimg + 手机号动态码 -> /api/login/appMobileBind
/// * 绑定成功即视为登录: 存 token -> 拉会员信息 -> 未绑门店去 /bind_store,否则回首页
/// * 图形验证码由 /api/config/getCaptchaConfig 的 shop_reception_login 控制开关
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/auth.dart';
import '../../controller/auth_store.dart';
import '../../utils/captcha.dart';
import '../../utils/index.dart';
import '../../widgets/field_error.dart';

/// 表单项统一间距
const double _gap = 12.0;
/// 主色
const Color _primary = Color(0xFFFF2C55);

class BindMobilePage extends StatefulWidget {
  const BindMobilePage({super.key});

  @override
  State<BindMobilePage> createState() => _BindMobilePageState();
}

class _BindMobilePageState extends State<BindMobilePage> {
  final authStore = AuthStore.to;

  /// 微信用户信息: {openid, unionid, nickname, headimg, type}
  Map<String, dynamic> wxInfo = <String, dynamic>{};

  final TextEditingController mobileController = TextEditingController();
  final TextEditingController dynacodeController = TextEditingController();
  final TextEditingController vercodeController = TextEditingController();

  final FocusNode mobileFocus = FocusNode();
  final FocusNode dynacodeFocus = FocusNode();
  final FocusNode vercodeFocus = FocusNode();

  // 协议配置
  bool agreementShow = true;
  bool agreed = false;

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
  // 字段级错误: 展示在对应输入框下方(null 表示无错误)
  String? mobileError;
  String? dynacodeError;
  String? vercodeError;
  // 表单级错误: 协议未勾选 / 微信信息缺失 / 服务端返回且无法归属到具体输入框
  String? formError;

  @override
  void initState() {
    super.initState();
    // 登录页 -10016 跳转时传入微信用户信息
    final dynamic args = Get.arguments;
    if (args is Map) wxInfo = args.cast<String, dynamic>();
    mobileFocus.addListener(() => setState(() {}));
    dynacodeFocus.addListener(() => setState(() {}));
    vercodeFocus.addListener(() => setState(() {}));
    loadConfig();
    loadCaptchaConfig();
  }

  @override
  void dispose() {
    mobileController.dispose();
    dynacodeController.dispose();
    vercodeController.dispose();
    mobileFocus.dispose();
    dynacodeFocus.dispose();
    vercodeFocus.dispose();
    dynacodeTimer?.cancel();
    super.dispose();
  }

  /// 协议是否展示(/api/register/config)
  Future<void> loadConfig() async {
    try {
      final Map<String, dynamic> config = await AuthApi.registerConfig();
      if (!mounted) return;
      setState(() => agreementShow = AuthApi.isOn(config, 'agreement_show'));
    } catch (_) {}
  }

  /// 图形验证码配置
  Future<void> loadCaptchaConfig() async {
    try {
      final Map<String, dynamic> config = await AuthApi.captchaConfig();
      if (!mounted) return;
      setState(() => captchaOn = AuthApi.isOn(config, 'shop_reception_login'));
      if (captchaOn) refreshCaptcha();
    } catch (_) {}
  }

  /// 刷新图形验证码
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
    debugPrint('[bind_mobile] error: $message');
    if (!mounted) return;
    setState(() {
      mobileError = null;
      dynacodeError = null;
      vercodeError = null;
      formError = null;
      switch (field ?? guessErrorField(message)) {
        case 'mobile':
          mobileError = message;
        case 'dynacode':
          dynacodeError = message;
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
      vercodeError = null;
      formError = null;
    });
  }

  /// 发送绑定动态码(/api/login/bindMobileCode)
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
      final String key = await AuthApi.bindMobileCode(
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

  /// 倒计时归零/发送失败: 还原状态
  void resetDynacode() {
    dynacodeTimer?.cancel();
    dynacodeTimer = null;
    setState(() {
      dynacodeSeconds = 120;
      dynacodeSending = false;
    });
    refreshCaptcha();
  }

  /// 表单校验(返回 null 表示通过;否则返回 <字段, 提示>,提示显示在对应位置)
  MapEntry<String, String>? verify() {
    final String mobile = mobileController.text.trim();
    if (mobile.isEmpty) return const MapEntry<String, String>('mobile', '请输入手机号');
    if (!Utils.checkTel(mobile)) return const MapEntry<String, String>('mobile', '手机号格式不正确');
    if (dynacodeController.text.trim().isEmpty) return const MapEntry<String, String>('dynacode', '请输入动态码');
    if (dynacodeKey.isEmpty) return const MapEntry<String, String>('dynacode', '请先获取动态码');
    if (wxInfo['openid'] == null && wxInfo['unionid'] == null) {
      return const MapEntry<String, String>('form', '微信信息缺失,请重新授权登录');
    }
    if (captchaOn && vercodeController.text.trim().isEmpty) {
      return const MapEntry<String, String>('vercode', '请输入验证码');
    }
    // 协议最后校验: 让用户先把表单填对,最后再提示勾选协议
    if (agreementShow && !agreed) {
      return const MapEntry<String, String>('agreement', '请先阅读并同意《用户协议》和《隐私政策》');
    }
    return null;
  }

  /// 绑定并提交
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
      final Map<String, dynamic> res = await AuthApi.appMobileBind(
        mobile: mobileController.text.trim(),
        key: dynacodeKey,
        code: dynacodeController.text.trim(),
        wxInfo: wxInfo,
        captchaId: captchaId,
        captchaCode: vercodeController.text.trim(),
      );
      final String token = '${res['token'] ?? ''}';
      if (token.isEmpty) throw '绑定失败,未获取到登录凭证';
      await _finishLogin(token, res['data']);
    } catch (e) {
      if (!mounted) return;
      showError(AuthApi.errorMsg(e));
      refreshCaptcha();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// 绑定成功收尾: 存凭证 -> 拉会员信息 -> 未绑门店去 /bind_store,否则回首页
  Future<void> _finishLogin(String token, dynamic rawData) async {
    authStore.setAuthorization(token);
    await authStore.loadMemberInfo();

    final int storeId = rawData is Map ? int.tryParse('${rawData['store_id'] ?? ''}') ?? 0 : 0;
    final bool boundStore = storeId != 0 || authStore.storeId.value != 0;

    if (!mounted) return;
    if (!boundStore) {
      Get.offAllNamed('/bind_store');
    } else {
      Get.offAllNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    final double keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardBottom + 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(statusTop),
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420.0),
                      child: _buildCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 红色渐变头部
  Widget _buildHeader(double statusTop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.0, statusTop + 8.0, 20.0, 72.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF8A4F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.back(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20.0, color: Colors.white),
            ),
          ),
          const SizedBox(height: 18.0),
          const Text(
            '绑定手机号',
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 6.0),
          Text(
            '该微信未绑定账号,绑定手机号后即可登录',
            style: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: 0.85), height: 1.2),
          ),
        ],
      ),
    );
  }

  /// 表单卡片
  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
      padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18.0, offset: const Offset(0.0, 6.0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildMobileInput(),
          const SizedBox(height: _gap),
          _buildDynacodeInput(),
          if (captchaOn) ...<Widget>[
            const SizedBox(height: _gap),
            _buildCaptchaInput(),
          ],
          const SizedBox(height: 20.0),
          _buildSubmit(),
          if (agreementShow) ...<Widget>[
            const SizedBox(height: 18.0),
            _buildAgreement(),
          ],
          // 表单级错误: 协议未勾选 / 微信信息缺失 / 服务端返回但无法归属到具体输入框
          FieldError(formError),
        ],
      ),
    );
  }

  /// 手机号
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
            style: const TextStyle(fontSize: 14.5),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '请输入手机号码',
              hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
              // 只保留区号: 不带「中国」和下箭头(没有国家选择功能)
              prefixIcon: const SizedBox(
                width: 40.0,
                child: Center(
                  child: Text('+86', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
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

  /// 动态码
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
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: '请输入验证码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
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
                        onTap: counting ? null : sendDynacode,
                        child: Center(
                          child: Text(
                            dynacodeSending ? '发送中' : (counting ? '${dynacodeSeconds}s' : '获取动态码'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: counting ? Colors.black26 : _primary,
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
            onChanged: (String value) => setState(() => dynacodeError = null),
          ),
        ),
        FieldError(dynacodeError),
      ],
    );
  }

  /// 图形验证码
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
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: '请输入验证码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
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
    final Color borderColor = hasError
        ? _primary
        : (focused ? _primary.withValues(alpha: 0.55) : const Color(0xFFF0F0F0));
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

  /// 协议勾选
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
            padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
            child: Container(
              width: 16.0,
              height: 16.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: agreed ? _primary : Colors.transparent,
                border: Border.all(
                  color: agreed ? _primary : Colors.grey.shade400,
                  width: 1.0,
                ),
                shape: BoxShape.circle,
              ),
              child: agreed ? const Icon(Icons.check, size: 11.0, color: Colors.white) : null,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('我已阅读并同意', style: TextStyle(color: Color(0xFF999999), fontSize: 12.0)),
              _buildAgreementLink('《用户协议》', 'SERVICE'),
              const Text(' | ', style: TextStyle(color: Color(0xFF999999), fontSize: 12.0)),
              _buildAgreementLink('《隐私政策》', 'PRIVACY'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementLink(String text, String type) {
    return GestureDetector(
      onTap: () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': type}),
      child: Text(text, style: const TextStyle(color: _primary, fontSize: 12.5)),
    );
  }

  /// 协议确认弹窗(与登录页一致): 未勾选协议时弹出,点"同意"自动勾选并继续
  /// * 用原生 showDialog 挂在当前 State 的 context 上,避免 shirne_dialog 的
  ///   navigatorKey 在 GetX 路由下取不到 NavigatorState 导致弹窗推不出来的问题
  Future<void> showAgreementDialog({required VoidCallback onAgreed}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 标题
              const Text(
                '温馨提示',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF202020)),
              ),
              const SizedBox(height: 20),
              _buildAgreementDialogContent(),
              const SizedBox(height: 24),
              // 不同意 / 同意
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: const Text('不同意', style: TextStyle(fontSize: 15)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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

  /// 弹窗内容(与登录页一致): 允许使用个人信息并阅读同意《隐私政策》|《用户协议》,协议名可点击跳转
  Widget _buildAgreementDialogContent() {
    return RichText(
      text: TextSpan(
        text: '允许我们在必要场景下，合理使用您的个人信息，且阅读并同意',
        style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6),
        children: <InlineSpan>[
          // 用 TextSpan + recognizer,不用 WidgetSpan: WidgetSpan 默认按 PlaceholderAlignment.bottom
          // 插入子 Widget,和周围文字基线对不齐(会偏低一点),改成同一段文字里的可点击 span 就自然对齐了
          TextSpan(
            text: '《隐私政策》',
            style: const TextStyle(color: _primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'PRIVACY'}),
          ),
          const TextSpan(text: ' | ', style: TextStyle(color: Color(0xFF999999))),
          TextSpan(
            text: '《用户协议》',
            style: const TextStyle(color: _primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'SERVICE'}),
          ),
        ],
      ),
    );
  }

  /// 绑定按钮
  Widget _buildSubmit() {
    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          gradient: LinearGradient(
            colors: submitting
                ? <Color>[Colors.grey.shade300, Colors.grey.shade400]
                : const <Color>[Color(0xFFFF2C55), Color(0xFFFF9C55)],
          ),
          boxShadow: submitting
              ? null
              : <BoxShadow>[
                  BoxShadow(color: _primary.withValues(alpha: 0.28), blurRadius: 12.0, offset: const Offset(0.0, 5.0)),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(24.0),
            onTap: submitting ? null : handleSubmit,
            child: Center(
              child: submitting
                  ? const SizedBox(width: 20.0, height: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white))
                  : const Text(
                      '绑定并登录',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 2.0),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
