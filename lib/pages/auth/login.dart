/// 登录
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../api/auth.dart';
import '../../utils/index.dart';
import '../../controller/auth_store.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final authStore = AuthStore.to;

  final Map authObj = {
    'tel': '',
    'pwd': '',
    'isVisiblePwd': true,
  };

  final TextEditingController fieldController = TextEditingController();
  final FocusNode telFocus = FocusNode();
  final FocusNode pwdFocus = FocusNode();

  // 登录请求中
  bool submitting = false;
  // 是否已勾选协议
  bool agreed = false;

  @override
  void initState() {
    super.initState();
    telFocus.addListener(() => setState(() {}));
    pwdFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    fieldController.dispose();
    telFocus.dispose();
    pwdFocus.dispose();
    super.dispose();
  }

  // 清空手机号
  void handleClear() {
    fieldController.clear();
    setState(() {
      authObj['tel'] = '';
    });
  }

  void handleSubmit() async {
    if (authObj['tel'] == '') {
      MyDialog.toast('请输入手机号', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
    } else if (!Utils.checkTel(authObj['tel'])) {
      MyDialog.toast('手机号格式不正确', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
    } else if (authObj['pwd'] == '') {
      MyDialog.toast('请输入密码', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
    } else if (!agreed) {
      MyDialog.toast('请先阅读并同意《隐私协议》和《用户协议》', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
    } else {
      if (submitting) return;
      setState(() => submitting = true);
      try {
        // 调用登录接口
        final Map<String, dynamic> res = await AuthApi.login(
          username: '${authObj['tel']}',
          password: '${authObj['pwd']}',
        );
        final String token = '${res['token'] ?? ''}';
        if (token.isEmpty) {
          throw '登录失败,未获取到登录凭证';
        }
        // 存储登录凭证
        authStore.setAuthorization(token);

        // 拉取会员信息(昵称/头像/余额等),失败不阻塞登录
        await authStore.loadMemberInfo();

        // 解析 store_id,0 表示未绑定门店,跳到绑定门店页
        final dynamic rawData = res['data'];
        final int storeId = rawData is Map ? int.tryParse('${rawData['store_id'] ?? ''}') ?? 0 : 0;
        // 登录接口与会员信息接口任一返回已绑定,都视为已绑定
        final bool boundStore = storeId != 0 || authStore.storeId.value != 0;

        if (!mounted) return;
        if (!boundStore) {
          Get.offAllNamed('/bind_store');
        } else {
          Get.offAllNamed('/');
        }
      } catch (e) {
        if (!mounted) return;
        MyDialog.toast(AuthApi.errorMsg(e), icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
      } finally {
        if (mounted) {
          setState(() => submitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 状态栏高度: 红色头部顶到状态栏,不露白边
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 状态栏透明,露出红色头部
        statusBarIconBrightness: Brightness.light, // Android 状态栏图标白色
        statusBarBrightness: Brightness.dark, // iOS 状态栏图标白色
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _buildHeader(statusTop),
                // 白色表单卡上移,压在红色头部上
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
                        _buildTelInput(),
                        const SizedBox(height: 14.0),
                        _buildPwdInput(),
                        const SizedBox(height: 18.0),
                        _buildAgreement(),
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
      ),
    );
  }

  /// 红色渐变头部(顶到状态栏)
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
          Container(
            width: 58.0,
            height: 58.0,
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.0),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10.0, offset: const Offset(0.0, 4.0)),
              ],
            ),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 20.0),
          const Text(
            '欢迎登录',
            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6.0),
          Text(
            '登录后可同步购物车、订单与收货地址',
            style: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  /// 手机号
  Widget _buildTelInput() {
    return _buildInputBox(
      focusNode: telFocus,
      child: TextField(
        controller: fieldController,
        focusNode: telFocus,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 14.0),
        decoration: InputDecoration(
          hintText: '请输入手机号',
          hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
          prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18.0, color: Colors.black26),
          prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
          suffixIcon: authObj['tel'].toString().isEmpty
            ? null
            : IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36.0),
                icon: const Icon(Icons.cancel_rounded, size: 16.0, color: Colors.black26),
                onPressed: handleClear,
              ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String value) => setState(() => authObj['tel'] = value),
      ),
    );
  }

  /// 密码
  Widget _buildPwdInput() {
    return _buildInputBox(
      focusNode: pwdFocus,
      child: TextField(
        focusNode: pwdFocus,
        obscureText: authObj['isVisiblePwd'] == true,
        style: const TextStyle(fontSize: 14.0),
        decoration: InputDecoration(
          hintText: '请输入密码',
          hintStyle: const TextStyle(fontSize: 14.0, color: Colors.black26),
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.black26),
          prefixIconConstraints: const BoxConstraints(minWidth: 40.0),
          suffixIcon: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36.0),
            icon: Icon(
              authObj['isVisiblePwd'] == true ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16.0,
              color: Colors.black26,
            ),
            onPressed: () => setState(() => authObj['isVisiblePwd'] = !(authObj['isVisiblePwd'] == true)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String value) => setState(() => authObj['pwd'] = value),
      ),
    );
  }

  /// 输入框容器: 聚焦时高亮边框
  Widget _buildInputBox({required FocusNode focusNode, required Widget child}) {
    final bool focused = focusNode.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: focused ? const Color(0xFFFF2C55).withValues(alpha: 0.5) : const Color(0xFFF0F0F0),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }

  /// 登录按钮
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
          onTap: submitting
            ? null
            : () {
                FocusScope.of(context).unfocus();
                handleSubmit();
              },
          child: Center(
            child: submitting
              ? const SizedBox(width: 18.0, height: 18.0, child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white))
              : const Text('登 录', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 4.0)),
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
          onTap: () => setState(() => agreed = !agreed),
          child: Padding(
            padding: const EdgeInsets.only(right: 4.0, top: 4.0, bottom: 4.0),
            child: Container(
              width: 15.0,
              height: 15.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: agreed ? const Color(0xFFFF2C55) : Colors.transparent,
                border: Border.all(
                  color: agreed ? const Color(0xFFFF2C55) : Colors.grey.shade400,
                  width: 1.0,
                ),
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
              _buildAgreementLink('《隐私协议》'),
              const Text('和', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
              _buildAgreementLink('《用户协议》'),
            ],
          ),
        ),
      ],
    );
  }

  /// 协议链接(暂无协议页,先给提示)
  Widget _buildAgreementLink(String text) {
    return GestureDetector(
      onTap: () => Get.snackbar('提示', text),
      child: Text(text, style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0)),
    );
  }

  /// 忘记密码 / 注册账号
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: () => Get.snackbar('提示', '忘记密码'),
          child: const Text('忘记密码', style: TextStyle(color: Colors.black38, fontSize: 13.0)),
        ),
        Container(width: 1.0, height: 12.0, margin: const EdgeInsets.symmetric(horizontal: 14.0), color: Colors.black12),
        GestureDetector(
          onTap: () => Get.toNamed('/register'),
          child: const Text('注册账号', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 13.0, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
