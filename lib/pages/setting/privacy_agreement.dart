/// 首次启动隐私政策概要
/// * 用户安装 App 首次进入时弹出, 必须点「同意」才能继续使用
/// * 不同意则退出 App
/// * 协议名可点击跳转 /agreement
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../utils/privacy_agreement.dart';

/// 主色
const Color _primary = Color(0xFFFF2C55);

class PrivacyAgreementPage extends StatelessWidget {
  const PrivacyAgreementPage({super.key});

  /// 不同意: Android 返回桌面, 其它平台无法强制退出, 保持当前页面阻塞使用
  static void _exitApp() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemNavigator.pop();
    }
  }

  /// 同意: 持久化标志后, 用首页替换掉整个路由栈
  /// * 注意: MyApp 的 initialRoute 只在 Navigator 首次构建时生效, 仅改 agreedNotifier
  ///   不会把已经存在的 /privacy_agreement 换掉, 必须在这里显式跳转, 否则点了同意页面不动
  /// * 先置 agreed: MyApp 会插入启动图遮罩, 首页首屏数据到位后自动淡出, 避免先看到"暂无数据"
  static Future<void> _agree() async {
    await PrivacyAgreement.setAgreed(true);
    Get.offAllNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    // 正文固定高度(超出内部滚动): 弹窗高度不随文案长短变化,同时小屏也不会顶到边
    final double bodyHeight = (MediaQuery.of(context).size.height * 0.42).clamp(180.0, 360.0);

    return PopScope(
      // 拦截物理返回键, 未同意前不允许退回首页
      canPop: false,
      child: Scaffold(
        // 透明, 露出底层启动图
        backgroundColor: Colors.transparent,
        body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/satrt_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        // 暗色遮罩, 让白卡更突出(与截图深红半透明一致)
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withAlpha(120),
          // 只有中间的协议卡(高度固定,不再随文案长短变化)
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360.0),
                child: _buildDialogCard(bodyHeight),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  /// 协议概要卡片
  /// * [bodyHeight] 正文区固定高度,超出的部分在区内滚动
  Widget _buildDialogCard(double bodyHeight) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22.0, 28.0, 22.0, 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 标题
          const Text(
            '用户隐私政策概要',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: Color(0xFF202020), height: 1.3),
          ),
          const SizedBox(height: 20.0),
          // 正文: 固定高度,内容超出时在区内滚动
          SizedBox(
            height: bodyHeight,
            child: SingleChildScrollView(
              child: _buildBodyText(),
            ),
          ),
          const SizedBox(height: 22.0),
          // 同意按钮
          SizedBox(
            width: double.infinity,
            height: 46.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23.0),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF9C55)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(23.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(23.0),
                  onTap: _agree,
                  child: const Center(
                    child: Text(
                      '同意',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 2.0),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14.0),
          // 不同意
          Center(
            child: GestureDetector(
              onTap: _exitApp,
              child: const Text(
                '不同意',
                style: TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 正文 + 协议链接
  Widget _buildBodyText() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14.0, color: Color(0xFF666666), height: 1.7),
        children: <InlineSpan>[
          const TextSpan(text: '在使用本软件前，请认真阅读并充分理解'),
          TextSpan(
            text: '《惠买服务协议》',
            style: const TextStyle(color: _primary, fontWeight: FontWeight.w500),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'SERVICE'}),
          ),
          const TextSpan(text: '和'),
          TextSpan(
            text: '《隐私政策》',
            style: const TextStyle(color: _primary, fontWeight: FontWeight.w500),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'PRIVACY'}),
          ),
          const TextSpan(text: '的详细信息。\n为便于您更直观了解我们如何保护您的个人信息，现将隐私政策简要说明如下：\n\n'),
          const TextSpan(text: '1、为提供服务收集使用的个人信息：为使用账户注册、登录、验证，我们可能需要收集账号、密码、手机号；为了实现网络身份识别，我们可能需要收集昵称、性别、生日及其他；为了实现实名认证，我们可能需要收集身份证信息、姓名及其他。\n\n'),
          const TextSpan(text: '2、个人信息存储和对外提供：我们会严格保密您的个人信息，除法律法规规定或经您同意的情况外，不会向第三方提供。\n\n'),
          const TextSpan(text: '3、您的权利：您有权访问、更正、删除您的个人信息，并可通过本协议约定方式与我们联系。'),
        ],
      ),
    );
  }
}
