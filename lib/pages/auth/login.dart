/// 登录(对齐 H5: pages_tool/login/index.vue)
/// * 两种登录方式: 账号密码 / 手机号+动态码, 由 /api/register/config 决定默认与可选项
/// * 图形验证码由 /api/config/getCaptchaConfig 的 shop_reception_login 控制开关
/// * 登录成功: 存 token -> 拉会员信息 -> 未绑定门店去 /bind_store, 否则回首页(或 back 指定页)
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../api/auth.dart';
import '../../utils/ali_one_key.dart';
import '../../utils/ali_one_key_error.dart';
import '../../utils/captcha.dart';
import '../../utils/index.dart';
import '../../utils/wx.dart';
import '../../controller/auth_store.dart';
import '../../widgets/field_error.dart';

/// 表单项统一间距
const double _gap = 12.0;
/// 主色
const Color _primary = Color(0xFFFF2C55);
/// 测试入口开关: 登录页底部"绑定手机号(测试入口)"是否显示
const bool _testEntry = false;

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final authStore = AuthStore.to;

  /// 登录方式: mobile 手机号动态码 / account 账号密码
  /// * 顶部只有这两个分类;一键登录不作为选项,仅进页面时自动尝试唤起
  String loginMode = 'mobile';

  final TextEditingController accountController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController dynacodeController = TextEditingController();
  final TextEditingController vercodeController = TextEditingController();

  final FocusNode accountFocus = FocusNode();
  final FocusNode pwdFocus = FocusNode();
  final FocusNode mobileFocus = FocusNode();
  final FocusNode dynacodeFocus = FocusNode();
  final FocusNode vercodeFocus = FocusNode();

  // 平台配置
  Map<String, dynamic> registerConfig = <String, dynamic>{};
  bool agreementShow = true;
  bool supportMobile = true;
  bool supportAccount = true;
  // 平台是否开启注册(配置 register 为空表示未开启)
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

  // 登录请求中
  bool submitting = false;
  // 微信登录中
  bool wxSubmitting = false;
  // 阿里云一键登录中
  bool aliSubmitting = false;
  // 微信可用: 端上支持(非web) + 已配置AppID + 已安装微信
  bool wxInstalled = false;
  // 仅预览入口(未配置AppID时,debug 下展示,点击提示未配置)
  bool wxPreview = false;
  // 是否已勾选协议
  bool agreed = false;
  // 密码是否隐藏
  bool obscurePwd = true;
  // 字段级错误: 展示在对应输入框下方(null 表示无错误)
  String? mobileError;
  String? dynacodeError;
  String? accountError;
  String? pwdError;
  String? vercodeError;
  // 表单级错误: 协议未勾选 / 服务端返回且无法归属到具体输入框
  String? formError;

  @override
  void initState() {
    super.initState();
    accountFocus.addListener(() => setState(() {}));
    pwdFocus.addListener(() => setState(() {}));
    mobileFocus.addListener(() => setState(() {}));
    dynacodeFocus.addListener(() => setState(() {}));
    vercodeFocus.addListener(() => setState(() {}));
    // 进入页面先判断是否可一键登录(内部会先拉平台配置)
    autoOneKey();
    loadCaptchaConfig();
    checkWx();
  }

  /// 进入页面先判断是否可一键登录
  /// * 可以: 直接拉起阿里云授权页(未勾选协议会先弹协议确认)
  /// * 不可以: 只保留「验证码登录 / 账号密码」两个分类
  Future<void> autoOneKey() async {
    // 等平台配置回来(决定协议是否展示),再决定是否直接拉起
    await loadConfig();
    if (!mounted) return;
    // 不支持一键登录: 保持默认(验证码登录),什么都不做
    if (!AliOneKey.available) return;
    // 等首帧绘制完再拉授权页,避免和路由转场动画抢
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // 直接唤起一键登录授权页;取消/失败后留在当前页用验证码或账号密码登录
    await handleAliLogin();
  }

  /// 微信登录入口是否展示: 端上支持 + 已安装微信
  /// * debug 且未配置 AppID 时也展示(便于对齐 UI),点击提示未配置
  Future<void> checkWx() async {
    debugPrint('[wx] supported=${WxAuth.supported} configured=${WxAuth.configured}');
    if (!WxAuth.supported) return;
    final bool installed = WxAuth.configured ? await WxAuth.isInstalled() : false;
    debugPrint('[wx] installed=$installed');
    if (!mounted) return;
    setState(() {
      wxInstalled = installed;
      wxPreview = !WxAuth.configured;
    });
  }

  @override
  void dispose() {
    accountController.dispose();
    pwdController.dispose();
    mobileController.dispose();
    dynacodeController.dispose();
    vercodeController.dispose();
    accountFocus.dispose();
    pwdFocus.dispose();
    mobileFocus.dispose();
    dynacodeFocus.dispose();
    vercodeFocus.dispose();
    dynacodeTimer?.cancel();
    AliOneKey.dispose();
    super.dispose();
  }

  /// 登录/注册配置: 决定默认登录方式与协议是否展示
  Future<void> loadConfig() async {
    try {
      final Map<String, dynamic> config = await AuthApi.registerConfig();
      if (!mounted) return;
      final String login = '${config['login'] ?? ''}';
      final String register = '${config['register'] ?? ''}';
      setState(() {
        registerConfig = config;
        agreementShow = AuthApi.isOn(config, 'agreement_show');
        supportMobile = login.isEmpty || login.contains('mobile');
        supportAccount = login.isEmpty || login.contains('username');
        // 默认验证码登录,不支持时切账号(H5 同逻辑)
        loginMode = supportMobile ? 'mobile' : 'account';
        // 平台未开启注册时不显示注册入口
        registerOpen = register.isNotEmpty;
      });
    } catch (_) {
      // 配置拉不到时按默认: 手机号登录 + 展示协议
    }
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
    debugPrint('[login] error: $message');
    if (!mounted) return;
    setState(() {
      mobileError = null;
      dynacodeError = null;
      accountError = null;
      pwdError = null;
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
      vercodeError = null;
      formError = null;
    });
  }

  /// 协议确认弹窗(对齐设计图): 未勾选协议时弹出,点"同意"自动勾选并继续登录
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

  /// 弹窗内容: 允许使用个人信息并阅读同意《隐私政策》|《用户协议》,协议名可点击跳转
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

  /// 发送登录动态码
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
      final String key = await AuthApi.loginMobileCode(
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
        if (dynacodeSeconds <= 0) {
          resetDynacode();
        }
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
  /// * 校验顺序: 先表单项(手机号/密码/验证码),协议勾选放最后
  MapEntry<String, String>? verify() {
    if (loginMode == 'mobile') {
      final String mobile = mobileController.text.trim();
      if (mobile.isEmpty) return const MapEntry<String, String>('mobile', '请输入手机号');
      if (!Utils.checkTel(mobile)) return const MapEntry<String, String>('mobile', '手机号格式不正确');
      if (dynacodeController.text.trim().isEmpty) return const MapEntry<String, String>('dynacode', '请输入动态码');
      if (dynacodeKey.isEmpty) return const MapEntry<String, String>('dynacode', '请先获取动态码');
    } else {
      if (accountController.text.trim().isEmpty) return const MapEntry<String, String>('account', '请输入账号');
      if (pwdController.text.isEmpty) return const MapEntry<String, String>('pwd', '请输入密码');
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
      final Map<String, dynamic> res = loginMode == 'mobile'
          ? await AuthApi.loginMobile(
              mobile: mobileController.text.trim(),
              key: dynacodeKey,
              code: dynacodeController.text.trim(),
              captchaId: captchaId,
              captchaCode: vercodeController.text.trim(),
            )
          : await AuthApi.login(
              username: accountController.text.trim(),
              password: pwdController.text,
            );
      final String token = '${res['token'] ?? ''}';
      if (token.isEmpty) throw '登录失败,未获取到登录凭证';
      await _finishLogin(token, res['data']);
    } catch (e) {
      if (!mounted) return;
      showError(AuthApi.errorMsg(e));
      refreshCaptcha();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// 登录收尾: 存凭证 -> 拉会员信息 -> 未绑门店去 /bind_store,否则回跳
  Future<void> _finishLogin(String token, dynamic rawData) async {
    // 存储登录凭证
    authStore.setAuthorization(token);
    // 拉取会员信息(昵称/头像/余额等),失败不阻塞登录
    await authStore.loadMemberInfo();

    // 解析 store_id,0 表示未绑定门店,跳到绑定门店页
    final int storeId = rawData is Map ? int.tryParse('${rawData['store_id'] ?? ''}') ?? 0 : 0;
    // 登录接口与会员信息接口任一返回已绑定,都视为已绑定
    final bool boundStore = storeId != 0 || authStore.storeId.value != 0;

    if (!mounted) return;
    if (!boundStore) {
      Get.offAllNamed('/bind_store');
    } else {
      Get.offAllNamed(backRoute);
    }
  }

  /// 微信一键登录: 拉起微信授权 -> code -> /api/login/appWxLogin
  Future<void> handleWxLogin() async {
    if (agreementShow && !agreed) {
      await showAgreementDialog(onAgreed: handleWxLogin);
      return;
    }
    if (wxSubmitting) return;
    if (!WxAuth.configured) {
      showError('未配置微信AppID,请先在 Config.wxAppId 填写');
      return;
    }
    setState(() => wxSubmitting = true);
    try {
      final String code = await WxAuth.authCode();
      final Map<String, dynamic> res = await AuthApi.appWxLogin(code);
      final String resCode = '${res['code'] ?? ''}';
      final dynamic data = res['data'];
      final String message = '${res['message'] ?? ''}';
      final String token = data is Map ? '${data['token'] ?? ''}'.trim() : '';
      // -10016: 该微信未绑定账号 -> 跳绑定手机号页(带 openid/unionid/昵称/头像)
      if (resCode == '-10016') {
        if (!mounted) return;
        final Map<String, dynamic> wxInfo = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
        wxInfo['type'] = 'wxopen';
        Get.toNamed('/bind_mobile', arguments: wxInfo);
        return;
      }
      // 40029: code 无效 —— 后端用错 appid/secret(移动应用的 code 不能用公众号/小程序 secret 换)
      if (message.contains('40029')) {
        throw '微信code无效(40029):请检查后端所用AppID/Secret';
      }
      if (token.isEmpty) throw message.isEmpty ? '微信登录失败' : message;
      await _finishLogin(token, data);
    } catch (e) {
      if (!mounted) return;
      showError(WxAuth.errorMsg(e));
    } finally {
      if (mounted) setState(() => wxSubmitting = false);
    }
  }

  /// 阿里云一键登录: 授权页 -> accessToken -> /api/login/phoneAuthLogin
  /// * 直接拉起授权页,不弹协议确认弹窗(授权页自带《隐私协议》《用户协议》,默认已勾选)
  /// * 失败 / 用户取消都留在登录页,用验证码或账号密码登录
  Future<void> handleAliLogin() async {
    if (aliSubmitting) return;
    setState(() => aliSubmitting = true);
    try {
      final String accessToken = await AliOneKey.login();
      debugPrint('[ali] STEP3 token 回到页面,长度=${accessToken.length}');
      // 拿到 token 就立刻关授权页: 后面是网络请求,不能让用户一直盯着授权页
      // (SDK 的 autoQuitPage 实测没生效,必须主动 quit)
      unawaited(AliOneKey.quit());
      debugPrint('[ali] STEP4 准备请求 /api/login/phoneAuthLogin');
      final Map<String, dynamic> res = await AuthApi.phoneAuthLogin(accessToken: accessToken);
      // 阿里云 SDK 日志刷屏,这里单独打一行精简结果,便于确认接口是否通
      final dynamic raw = res['data'];
      final String resCode = raw is Map ? '${raw['code'] ?? ''}' : '';
      final String resMsg = raw is Map ? '${raw['message'] ?? ''}' : '';
      debugPrint('[ali] STEP5 phoneAuthLogin 返回 -> code=$resCode message=$resMsg hasToken=${'${res['token'] ?? ''}'.isNotEmpty}');
      final String token = '${res['token'] ?? ''}';
      if (token.isEmpty) throw '一键登录失败,未获取到登录凭证';
      await _finishLogin(token, res['data']);
    } catch (e) {
      debugPrint('[ali] ERROR $e');
      // 环境类错误(无SIM / 没开移动数据 / 连着WiFi / VPN / 密钥签名不对): 静默回退,不提示用户
      // 其他错误(取号失败、接口报错、超时等)照常提示
      final bool silent = e is AliOneKeyFailure && e.isEnvError;
      if (!silent && mounted) showError('$e');
    } finally {
      if (mounted) setState(() => aliSubmitting = false);
      // 兜底: 登录失败/异常时授权页可能还挂着,这里再关一次
      unawaited(AliOneKey.quit());
    }
  }

  /// 登录后回跳页: 路由 arguments 传 { back: '/xxx' } 时优先,否则首页
  String get backRoute {
    final dynamic args = Get.arguments;
    if (args is Map) {
      final String back = '${args['back'] ?? ''}'.trim();
      if (back.isNotEmpty) return back;
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    // 状态栏高度: 红色头部顶到状态栏,不露白边
    final double statusTop = MediaQuery.of(context).padding.top;
    // 键盘弹出时底部留白,避免按钮被遮挡
    final double keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 状态栏透明,露出浅色头部
        statusBarIconBrightness: Brightness.dark, // Android 状态栏图标深色(适配浅色背景图)
        statusBarBrightness: Brightness.light, // iOS 状态栏图标深色
      ),
      child: Scaffold(
        // 与首页(Layout)同一底色: 米黄 0xFFFCF7EE
        backgroundColor: const Color(0xFFFCF7EE),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardBottom + 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 顶部主题图(login_header.png),宽屏仍居中展示
                _buildHeader(statusTop),
                // 白色表单卡与主题图的间距(正=下移留缝,负=上移压住图片)
                Transform.translate(
                  offset: const Offset(0, -10),
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

  /// 表单卡片
  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
      padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 24.0),
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
          // 登录方式切换: 验证码登录 / 账号密码
          _buildModeTabs(),
          const SizedBox(height: 22.0),
          if (loginMode == 'mobile') ...<Widget>[
            _buildMobileInput(),
            const SizedBox(height: _gap),
            _buildDynacodeInput(),
          ] else ...<Widget>[
            _buildAccountInput(),
            const SizedBox(height: _gap),
            _buildPwdInput(),
            const SizedBox(height: 8.0),
            _buildForgotPwd(),
          ],
          // 图形验证码(平台开启时展示)
          if (captchaOn) ...<Widget>[
            const SizedBox(height: _gap),
            _buildCaptchaInput(),
          ],
          const SizedBox(height: 20.0),
          _buildSubmit(),
          if (showSocialLogin) ...<Widget>[
            const SizedBox(height: 14.0),
            _buildSocialLogin(),
          ],
          const SizedBox(height: 18.0),
          _buildAgreement(),
          // 表单级错误: 协议未勾选 / 服务端返回但无法归属到具体输入框
          FieldError(formError),
          // 测试入口: 直接进绑定手机号页,免去先跑通微信授权(改成 true 即可显示)
          if (_testEntry) _buildTestEntry(),
        ],
      ),
    );
  }

  /// 顶部主题图(使用 login_header.png),返回按钮浮在图上
  /// * 顶部留状态栏安全距离,状态栏那一段用页面底色填充,保证与图片无缝衔接
  Widget _buildHeader(double statusTop) {
    return Stack(
      children: <Widget>[
        Container(
          color: const Color(0xFFFCF7EE),
          padding: EdgeInsets.only(top: statusTop),
          child: Padding(
            // 左右各留 10 间距(状态栏那一段仍是满宽底色,不会出现白边)
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.asset(
                'assets/images/login_header.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
        // 返回(游客可直接返回上一页)
        Positioned(
          top: statusTop + 8.0,
          left: 12.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (Get.previousRoute.isNotEmpty) Get.back();
            },
            child: const Padding(
              padding: EdgeInsets.all(6.0),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20.0, color: Color(0xFF333333)),
            ),
          ),
        ),
      ],
    );
  }

  /// 登录方式切换: 只有 验证码登录 / 账号密码 两个分类
  /// * 一键登录不作为选项,进页面时若支持会自动唤起授权页
  Widget _buildModeTabs() {
    return Container(
      height: 42.0,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(21.0),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildModeTab('验证码登录', 'mobile')),
          Expanded(child: _buildModeTab('账号密码', 'account')),
        ],
      ),
    );
  }

  Widget _buildModeTab(String text, String mode) {
    final bool active = loginMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => loginMode = mode);
        clearErrors();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF8A4F)],
                )
              : null,
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  /// 忘记密码
  Widget _buildForgotPwd() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => MyDialog.toast('忘记密码功能开发中'),
        child: const Text(
          '忘记密码',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF2C8DFA)),
        ),
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
              // 右侧: 分隔线 + 获取动态码
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

  /// 账号
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
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14.5),
            decoration: const InputDecoration(
              hintText: '请输入账号',
              hintStyle: TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18.0, color: Colors.black26),
              prefixIconConstraints: BoxConstraints(minWidth: 42.0),
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

  /// 密码
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
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: '请输入密码',
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.black26),
              prefixIconConstraints: const BoxConstraints(minWidth: 42.0),
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36.0),
                icon: Icon(
                  obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 17.0,
                  color: Colors.black26,
                ),
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

  /// 登录按钮
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
                      '登 录',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 6.0),
                    ),
            ),
          ),
        ),
      ),
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

  /// 测试入口(仅 debug): 跳过微信授权,直接进绑定手机号页
  /// * 传一份假的微信信息,绕开绑定页"微信信息缺失"的校验(openid/unionid 至少有一个)
  Widget _buildTestEntry() {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Get.toNamed('/bind_mobile', arguments: <String, dynamic>{
            'openid': 'debug_test_openid',
            'unionid': '',
            'nickname': '测试用户',
            'headimg': '',
            'type': 'wxopen',
          }),
          child: const Text(
            '绑定手机号(测试入口)',
            style: TextStyle(fontSize: 12.0, color: Color(0xFF2C8DFA), decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }

  /// 协议链接 -> /agreement
  Widget _buildAgreementLink(String text, String type) {
    return GestureDetector(
      onTap: () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': type}),
      child: Text(text, style: const TextStyle(color: _primary, fontSize: 12.5)),
    );
  }

  /// 是否装了微信(未安装 / 端上不支持时不展示微信入口)
  bool get showWxLogin => wxInstalled || wxPreview;

  /// 设备是否支持 Apple 登录(仅 iOS / macOS;Android / Web / Windows 不支持)
  bool get showAppleLogin =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  /// 是否展示「其他登录方式」区块
  bool get showSocialLogin => showWxLogin || showAppleLogin;

  /// 其他登录方式: 微信授权登录 / Apple登录
  /// * 没装微信就不显示微信;设备不支持 Apple 登录就不显示 Apple;两个都没有则整块不展示
  Widget _buildSocialLogin() {
    if (!showSocialLogin) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: Divider(color: Color(0xFFEDEEF0), height: 1.0, thickness: 1.0)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Text('其他登录方式', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
            ),
            const Expanded(child: Divider(color: Color(0xFFEDEEF0), height: 1.0, thickness: 1.0)),
          ],
        ),
        const SizedBox(height: 16.0),
        Row(
          children: <Widget>[
            if (showWxLogin)
              Expanded(
                child: _buildSocialButton(
                  text: '微信授权登录',
                  icon: Icons.wechat,
                  bgColor: const Color(0xFF19C650),
                  onTap: wxSubmitting ? null : handleWxLogin,
                  loading: wxSubmitting,
                ),
              ),
            if (showWxLogin && showAppleLogin) const SizedBox(width: 12.0),
            if (showAppleLogin)
              Expanded(
                child: _buildSocialButton(
                  text: 'Apple登录',
                  icon: Icons.apple,
                  bgColor: const Color(0xFF1C1C1E),
                  onTap: () => MyDialog.toast('Apple登录功能开发中'),
                  loading: false,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required Color bgColor,
    VoidCallback? onTap,
    required bool loading,
  }) {
    return SizedBox(
      height: 44.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22.0),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(22.0),
            onTap: onTap,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: Colors.white, size: 20.0),
                        const SizedBox(width: 6.0),
                        Text(
                          text,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
