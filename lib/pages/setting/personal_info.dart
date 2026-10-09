/// 设置(原个人资料页)
/// 对齐 H5: pages_tool/member/info.vue + public/js/info.js
/// * 资料项: 微信 / 手机 / 密码
/// * 修改走 /api/member/modifyxxx, 成功后重新拉 /api/member/info 刷新全局会员信息
/// * 注销依赖 membercancel 插件, 接口未开启时隐藏入口
/// * 头像: 当前端无相册上传能力, 沿用本地预设头像(仅本地预览)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import '../../utils/wx.dart';
import 'account_security.dart';
import 'personal_info_index.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  /// 全局会员状态(用 getter 而非字段: 热重载会保留旧 State 实例, 新增字段会读到 null)
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  // 提交中(顶部细进度条)
  bool loading = false;
  // 个性化推荐开关(本地持久化, 对齐 H5 storage: condSwitch)
  bool personalizedRecommend = true;
  // 版本号(pubspec version)
  static const String version = '1.0.0';
  static const String _switchKey = 'condSwitch';

  @override
  void initState() {
    super.initState();
    // 会员信息为空(如启动时拉取失败)时补拉一次
    if (auth.memberInfo.isEmpty) auth.loadMemberInfo();
    personalizedRecommend = GetStorage().read(_switchKey) == true;
  }

  @override
  void dispose() {
    super.dispose();
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
        backgroundColor: const Color(0xFFF6F7F9), // 浅灰底: 分组卡片浮在上方
        body: Column(
          children: [
            // 状态栏占位 + 标题栏: 整体白底,保证状态栏区域也是白色
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部状态栏占位
                  SizedBox(height: statusTop),
                  // 标题栏
                  Padding(
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
                            child: Text('设置',
                                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 42.0), // 占位平衡左右
                      ],
                    ),
                  ),
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
            // 列表(响应式: 会员信息变化时自动刷新 nickname/头像等)
            Expanded(
              child: Obx(
                () => ListView(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  children: <Widget>[
                    const SizedBox(height: 12.0),
                    // 账号: 个人资料 / 微信绑定 / 账户安全
                    _group(
                      items: <Widget>[
                        _personalInfoEntry(),
                        _wxItem(),
                        _navItem('账户安全', _openAccountSecurity),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    // 协议 / 关于我们
                    _group(
                      items: <Widget>[
                        _navItem('隐私协议',
                            () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'PRIVACY'})),
                        _navItem('用户协议',
                            () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'SERVICE'})),
                        _navItem('关于我们', () => Get.toNamed('/about')),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    // 个性化推荐 / 版本号
                    _group(
                      items: <Widget>[
                        _switchItem(),
                        _versionItem(),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    _logoutButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== 组件 ==============

  /// 分组卡片: 白底圆角,组内条目之间自动插入分隔线
  Widget _group({required List<Widget> items}) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      rows.add(items[i]);
      if (i != items.length - 1) rows.add(_divider());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ],
    );
  }

  /// 顶部「个人信息」入口: 头像 + 昵称 + 进入箭头,跳转独立个人信息页
  Widget _personalInfoEntry() {
    return GestureDetector(
      onTap: () => Get.to(const PersonalInfoIndexPage()),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            _entryAvatar(),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.nickname.isEmpty ? '未设置昵称' : auth.nickname,
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  const Text('查看 / 编辑个人信息', style: TextStyle(fontSize: 12.0, color: Colors.black45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  /// 入口处的小头像(仅展示,不编辑)
  Widget _entryAvatar() {
    const Widget placeholder = Icon(Icons.person, color: Colors.black26, size: 30.0);
    final String url = auth.headimg;
    final Widget image = url.isEmpty
        ? placeholder
        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    return Container(
      width: 44.0,
      height: 44.0,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  /// 跳转到「账户安全」页(手机号 / 密码 / 注销账号)
  void _openAccountSecurity() => Get.to(const AccountSecurityPage());

  Widget _divider() => Container(
        color: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(left: 16.0),
          height: 0.5,
          color: FStyle.dividerColor,
        ),
      );



  Widget _navItem(String label, VoidCallback onTap, {Color textColor = Colors.black87}) {
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
              Expanded(child: Text(label, style: TextStyle(fontSize: 15.0, color: textColor))),
              const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  /// 微信绑定项: 状态与操作分开展示(徽章 = 是否已绑定,右侧文案 = 点击后的动作)
  /// * 当前端不支持微信授权(web/桌面端 或 未配置 AppID)时整项置灰,文案改「暂不支持」
  Widget _wxItem() {
    final bool bound = auth.wxBound;
    final bool enabled = WxAuth.supported && WxAuth.configured;
    final bool tappable = enabled && !loading;
    return Opacity(
      opacity: tappable ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: loading
            ? null
            : () {
                if (!enabled) {
                  MyDialog.toast('当前环境不支持微信绑定,请在 App 内操作');
                  return;
                }
                _bindWechat();
              },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              const SizedBox(
                  width: 80.0, child: Text('微信', style: TextStyle(fontSize: 15.0, color: Colors.black87))),
              Expanded(child: _boundBadge(bound)),
              Text(
                !enabled ? '暂不支持' : (bound ? '重新绑定' : '去绑定'),
                style: TextStyle(
                  fontSize: 15.0,
                  color: !enabled
                      ? const Color(0xFFBBBBBB)
                      : (bound ? const Color(0xFF666666) : FStyle.primaryColor),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  /// 绑定状态徽章: 已绑定绿色打勾 / 未绑定灰色叹号
  Widget _boundBadge(bool bound) {
    final Color color = bound ? const Color(0xFF19C650) : const Color(0xFF999999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(bound ? Icons.check_circle : Icons.error_outline, size: 12.0, color: color),
              const SizedBox(width: 3.0),
              Text(
                bound ? '已绑定' : '未绑定',
                style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8.0),
      ],
    );
  }

  Widget _versionItem() {
    return GestureDetector(
      onTap: () => MyDialog.toast('当前已是最新版本(v$version)'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            const Expanded(
                child: Text('版本号', style: TextStyle(fontSize: 15.0, color: Colors.black87))),
            Text(version, style: const TextStyle(fontSize: 15.0, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _switchItem() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          const Expanded(
              child: Text('个性化推荐', style: TextStyle(fontSize: 15.0, color: Colors.black87))),
          Switch(
            value: personalizedRecommend,
            activeColor: const Color(0xFF34C759),
            onChanged: (bool v) {
              setState(() => personalizedRecommend = v);
              GetStorage().write(_switchKey, v);
            },
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 46.0,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D5F),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23.0)),
          ),
          onPressed: _logout,
          child: const Text('退出登录', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ============== 资料修改 ==============


  // ============== 微信 / 手机 / 密码 / 地址 ==============

  /// 微信绑定: fluwx 授权拿 code -> /api/member/bindWxopen
  /// * 未接入(web 端或未配置 AppID)时保持原提示
  Future<void> _bindWechat() async {
    if (!WxAuth.supported) {
      MyDialog.toast(auth.wxBound ? '请在微信/小程序端重新授权绑定' : '当前端未接入微信授权,请在微信端绑定');
      return;
    }
    try {
      final String code = await WxAuth.authCode();
      await MemberApi.bindWxopen(code);
      // 绑定结果体现在 wxopen_openid,重新拉会员信息刷新展示
      await auth.loadMemberInfo();
      if (!mounted) return;
      setState(() {});
      MyDialog.toast('微信绑定成功', icon: const Icon(Icons.check_circle_rounded), style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)));
    } catch (e) {
      MyDialog.toast(WxAuth.errorMsg(e), icon: const Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
    }
  }

  // ============== 注销 / 退出 ==============

  Future<void> _logout() async {
    final bool? ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Get.back<bool>(result: false), child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('退出', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    auth.logout();
    Get.offAllNamed('/login');
  }

}


