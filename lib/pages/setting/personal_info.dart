/// 个人资料(设置)
/// 对齐 H5: pages_tool/member/info.vue + public/js/info.js
/// * 资料项: 头像 / 账号 / 昵称 / 真实姓名 / 微信 / 性别 / 生日 / 手机 / 密码 / 所在地址
/// * 修改走 /api/member/modifyxxx, 成功后重新拉 /api/member/info 刷新全局会员信息
/// * 注销依赖 membercancel 插件, 接口未开启时隐藏入口
/// * 头像: 当前端无相册上传能力, 沿用本地预设头像(仅本地预览)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/address.dart';
import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  /// 全局会员状态(用 getter 而非字段: 热重载会保留旧 State 实例, 新增字段会读到 null)
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  // 本地选择的头像(为空则显示会员真实头像)
  String avatarPath = '';
  // 提交中(顶部细进度条)
  bool loading = false;
  // 注销功能是否开启(/membercancel/api/membercancel/config)
  bool cancelEnable = false;
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
    _loadCancelConfig();
  }

  @override
  void dispose() {
    super.dispose();
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
                      child: Text('个人资料',
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
                  _avatarItem(),
                  _divider(),
                  // 账号: is_edit_username == 1 才可改,否则只读
                  auth.canEditUsername
                      ? _editableItem('账号', auth.username, () => _editUsername())
                      : _readonlyItem('账号', auth.username),
                  _divider(),
                  _editableItem('昵称', auth.nickname, _editNickname),
                  _divider(),
                  _editableItem('真实姓名', auth.realname, _editRealName, hint: '请输入真实姓名'),
                  _divider(),
                  _actionItem(
                    '微信',
                    auth.wxBound ? '重新绑定' : '未绑定',
                    _bindWechat,
                    actionColor: auth.wxBound ? const Color(0xFF19C650) : const Color(0xFFFF4D5F),
                  ),
                  _divider(),
                  _pickItem('性别', auth.sexName, const ['未知', '男', '女'], _saveSex),
                  _divider(),
                  _editableItem('生日', auth.birthday, _editBirthday, hint: '请选择生日'),
                  _divider(),
                  _actionItem('手机', auth.mobile.isEmpty ? '去绑定' : _maskMobile(auth.mobile), _editMobile),
                  _divider(),
                  _actionItem('密码', auth.hasPassword ? '修改' : '未设置', _editPassword),
                  _divider(),
                  _editableItem('所在地址', _addressText, _editAddress, hint: '去设置'),
                  _divider(),
                  if (cancelEnable) _navItem('注销账号', _cancelAccount),
                  if (cancelEnable) _divider(),
                  _navItem('隐私协议',
                      () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'PRIVACY'})),
                  _divider(),
                  _navItem('用户协议',
                      () => Get.toNamed('/agreement', arguments: <String, dynamic>{'type': 'SERVICE'})),
                  _divider(),
                  _versionItem(),
                  _divider(),
                  _switchItem(),
                  const SizedBox(height: 24.0),
                  _logoutButton(),
                  const SizedBox(height: 30.0),
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

  Widget _avatarItem() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          const Expanded(
              child: Text('头像', style: TextStyle(fontSize: 15.0, color: Colors.black87))),
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 50.0,
              height: 50.0,
              margin: const EdgeInsets.only(right: 6.0),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatar(),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
        ],
      ),
    );
  }

  // 头像: 本地选择 > 会员真实头像 > 灰色人像占位
  Widget _buildAvatar() {
    const Widget placeholder = Icon(Icons.person, color: Colors.black26, size: 34.0);
    if (avatarPath.isNotEmpty) return Image.asset(avatarPath, fit: BoxFit.cover);
    final String url = auth.headimg;
    if (url.isEmpty) return placeholder;
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }

  /// 只读项(账号不可修改时): 文案右对齐且不显示箭头
  Widget _readonlyItem(String label, String value) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          SizedBox(
              width: 80.0,
              child: Text(label, style: const TextStyle(fontSize: 15.0, color: Colors.black87))),
          Expanded(
            child: Text(value.isEmpty ? '未设置' : value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15.0, color: Colors.black54)),
          ),
          const SizedBox(width: 18.0),
        ],
      ),
    );
  }

  Widget _editableItem(String label, String value, VoidCallback onTap, {String hint = '请输入'}) {
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
              child: Text(
                value.isEmpty ? hint : value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15.0, color: value.isEmpty ? const Color(0xFFBDBDBD) : Colors.black54),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
          ],
        ),
      ),
    );
  }

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

  Widget _pickItem(String label, String value, List<String> options, ValueChanged<String> onPick) {
    return GestureDetector(
      onTap: loading
          ? null
          : () async {
              final String? picked = await Get.bottomSheet<String>(
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final String o in options)
                        ListTile(
                          title: Text(o, textAlign: TextAlign.center),
                          onTap: () => Get.back<String>(result: o),
                        ),
                      Container(
                        margin: const EdgeInsets.only(top: 8.0),
                        decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                        child: ListTile(
                          title: const Text('取消',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent)),
                          onTap: () => Get.back<String>(),
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Colors.transparent,
              );
              if (picked != null) onPick(picked);
            },
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
              child: Text(value.isEmpty ? '请选择' : value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 15.0, color: value.isEmpty ? const Color(0xFFBDBDBD) : Colors.black54)),
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

  /// 输入弹窗(昵称 / 真实姓名 / 账号)
  Future<void> _showInputDialog(
      String label, String value, String hint, ValueChanged<String> onSaved) async {
    final TextEditingController controller = TextEditingController(text: value);
    final String? result = await Get.dialog<String>(
      AlertDialog(
        title: Text('修改$label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back<String>(), child: const Text('取消')),
          TextButton(
              onPressed: () => Get.back<String>(result: controller.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (result != null) onSaved(result);
  }

  Future<void> _editUsername() async {
    await _showInputDialog('账号', auth.username, '请输入账号', (String v) {
      if (v.isEmpty) {
        MyDialog.toast('账号不能为空');
        return;
      }
      if (v == auth.username) {
        MyDialog.toast('与原账号一致');
        return;
      }
      _run(() => MemberApi.modifyUsername(v), ok: '账号修改成功');
    });
  }

  Future<void> _editNickname() async {
    await _showInputDialog('昵称', auth.nickname, '请输入昵称', (String v) {
      if (v.isEmpty) {
        MyDialog.toast('昵称不能为空');
        return;
      }
      if (v == auth.nickname) {
        MyDialog.toast('与原昵称一致');
        return;
      }
      _run(() => MemberApi.modifyNickname(v), ok: '昵称修改成功');
    });
  }

  Future<void> _editRealName() async {
    await _showInputDialog('真实姓名', auth.realname, '请输入真实姓名', (String v) {
      if (v.isEmpty) {
        MyDialog.toast('真实姓名不能为空');
        return;
      }
      if (v == auth.realname) {
        MyDialog.toast('与原真实姓名一致,无需修改');
        return;
      }
      _run(() => MemberApi.modifyRealName(v), ok: '真实姓名修改成功');
    });
  }

  /// 性别: 未知 / 男 / 女 -> 0 / 1 / 2
  Future<void> _saveSex(String value) async {
    final int sex = value == '男' ? 1 : (value == '女' ? 2 : 0);
    if (sex == auth.sex) return;
    await _run(() => MemberApi.modifySex(sex), ok: '性别修改成功');
  }

  /// 生日: 日期选择器 -> 秒级时间戳
  Future<void> _editBirthday() async {
    final DateTime now = DateTime.now();
    DateTime initial = DateTime(1990);
    if (auth.birthday.isNotEmpty) initial = DateTime.tryParse(auth.birthday) ?? initial;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 80),
      lastDate: now,
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null) return;
    final String text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (text == auth.birthday) return;
    // 生日以当日 12 点为基准转时间戳,避免时区导致跨天
    final int stamp = DateTime(picked.year, picked.month, picked.day, 12).millisecondsSinceEpoch ~/ 1000;
    await _run(() => MemberApi.modifyBirthday(stamp), ok: '生日修改成功');
  }

  // ============== 微信 / 手机 / 密码 / 地址 ==============

  /// 微信绑定: 需微信授权 code(uni.login),当前端无微信 SDK,提示在小程序端操作
  Future<void> _bindWechat() async {
    MyDialog.toast(auth.wxBound ? '请在微信/小程序端重新授权绑定' : '当前端未接入微信授权,请在微信端绑定');
  }

  /// 手机号脱敏: 138****8888(H5 filters.mobile)
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

  /// 所在地址: 省市区三级 + 详细地址
  String get _addressText {
    final String full = auth.fullAddress;
    final String detail = auth.address;
    if (full.isEmpty && detail.isEmpty) return '';
    return '$full $detail'.trim();
  }

  Future<void> _editAddress() async {
    final TextEditingController detailCtl = TextEditingController(text: auth.address);
    List<Map<String, dynamic>> provinces = await AddressApi.areas(0);
    List<Map<String, dynamic>> cities = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> districts = <Map<String, dynamic>>[];
    Map<String, dynamic>? province;
    Map<String, dynamic>? city;
    Map<String, dynamic>? district;

    /// 已保存地址回填: 逐级拉取下级后按 id 匹配
    if (auth.provinceId > 0) {
      province = _findArea(provinces, auth.provinceId);
      if (province != null) cities = await AddressApi.areas(auth.provinceId);
    }
    if (auth.cityId > 0) {
      city = _findArea(cities, auth.cityId);
      if (city != null) districts = await AddressApi.areas(auth.cityId);
    }
    if (auth.districtId > 0) district = _findArea(districts, auth.districtId);
    if (!mounted) return;

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialog) {
          String regionText() {
            final String p = province == null ? '' : '${province!['name'] ?? ''}';
            final String c = city == null ? '' : '-${city!['name'] ?? ''}';
            final String d = district == null ? '' : '-${district!['name'] ?? ''}';
            return '$p$c$d';
          }

          /// 打开省市区三级选择
          Future<void> openPicker() async {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
              builder: (BuildContext ctx) {
                return StatefulBuilder(
                  builder: (BuildContext ctx, void Function(void Function()) setSheet) {
                    Future<void> selectProvince(Map<String, dynamic> item) async {
                      province = item;
                      city = null;
                      district = null;
                      districts = <Map<String, dynamic>>[];
                      cities = await AddressApi.areas(int.tryParse('${item['id'] ?? ''}') ?? 0);
                      setSheet(() {});
                      setDialog(() {});
                    }

                    Future<void> selectCity(Map<String, dynamic> item) async {
                      city = item;
                      district = null;
                      districts = await AddressApi.areas(int.tryParse('${item['id'] ?? ''}') ?? 0);
                      setSheet(() {});
                      setDialog(() {});
                    }

                    return SizedBox(
                      height: 340.0,
                      child: Column(
                        children: [
                          const SizedBox(height: 12.0),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Text('选择地区',
                                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  icon: const Icon(Icons.close, size: 18.0, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                _regionColumn(provinces, province, selectProvince),
                                _regionColumn(cities, city, selectCity),
                                _regionColumn(districts, district, (Map<String, dynamic> item) {
                                  district = item;
                                  setSheet(() {});
                                  setDialog(() {});
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }

          return AlertDialog(
            title: const Text('所在地址'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: openPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                      child: Text(
                        regionText().isEmpty ? '请选择所在地区' : regionText(),
                        style: TextStyle(
                            fontSize: 15.0,
                            color: regionText().isEmpty ? const Color(0xFFBDBDBD) : Colors.black87),
                      ),
                    ),
                  ),
                  TextField(
                    controller: detailCtl,
                    decoration: const InputDecoration(hintText: '请输入详细地址'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back<void>(), child: const Text('取消')),
              TextButton(
                onPressed: () async {
                  if (province == null) return MyDialog.toast('请选择所在地区');
                  final String detail = detailCtl.text.trim();
                  if (detail.isEmpty) return MyDialog.toast('请输入详细地址');
                  Get.back<void>();
                  await _run(
                    () => MemberApi.modifyAddress(
                      provinceId: int.tryParse('${province!['id'] ?? ''}') ?? 0,
                      cityId: int.tryParse('${city?['id'] ?? ''}') ?? 0,
                      districtId: int.tryParse('${district?['id'] ?? ''}') ?? 0,
                      address: detail,
                      fullAddress: regionText(),
                    ),
                    ok: '地址修改成功',
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 地区列
  Widget _regionColumn(List<Map<String, dynamic>> data, Map<String, dynamic>? selected,
      ValueChanged<Map<String, dynamic>> onSelect) {
    return Expanded(
      child: Container(
        color: const Color(0xFFF8F8F8),
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        child: ListView.builder(
          itemCount: data.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> item = data[index];
            final bool active = selected != null && '${selected['id']}' == '${item['id']}';
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                color: active ? Colors.white : Colors.transparent,
                child: Text('${item['name'] ?? ''}',
                    style: TextStyle(fontSize: 13.0, color: active ? const Color(0xFFFF4D5F) : Colors.black54)),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, dynamic>? _findArea(List<Map<String, dynamic>> list, int id) {
    for (final Map<String, dynamic> item in list) {
      if ('${item['id']}' == '$id') return item;
    }
    return null;
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

  // ============== 头像 / 工具 ==============

  /// 头像可选资源（取自 assets/images/avatar）
  /// * H5 是相册上传(/api/upload/headimg + /api/member/modifyheadimg)
  /// * 当前端未接入图片选择/上传,仅做本地预览
  static const List<String> avatarList = [
    'assets/images/avatar/img01.jpg',
    'assets/images/avatar/img02.jpg',
    'assets/images/avatar/img03.jpg',
    'assets/images/avatar/img04.jpg',
    'assets/images/avatar/img05.jpg',
    'assets/images/avatar/img06.jpg',
  ];

  Future<void> _pickAvatar() async {
    await Get.bottomSheet<void>(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 14.0,
          runSpacing: 14.0,
          children: [
            for (final String a in avatarList)
              GestureDetector(
                onTap: () {
                  setState(() => avatarPath = a);
                  Get.back<void>();
                  MyDialog.toast('头像仅本地预览,上传需接入相册能力');
                },
                child: Container(
                  width: 60.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: avatarPath == a ? const Color(0xFFFF4D5F) : Colors.transparent, width: 2.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(a, fit: BoxFit.cover),
                ),
              ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

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


