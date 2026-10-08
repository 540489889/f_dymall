/// 个人信息(独立页)
/// 仅承载 头像 / 账号 / 昵称 / 性别 / 生日 的展示与修改
/// 入口在「个人资料」页顶部,跳转: Get.to(const PersonalInfoIndexPage())
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide DatePickerTheme;
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import 'edit_nickname.dart';

class PersonalInfoIndexPage extends StatefulWidget {
  const PersonalInfoIndexPage({super.key});

  @override
  State<PersonalInfoIndexPage> createState() => _PersonalInfoIndexPageState();
}

class _PersonalInfoIndexPageState extends State<PersonalInfoIndexPage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  // 本地选择的头像(为空则显示会员真实头像)
  String avatarPath = '';
  // 提交中(顶部细进度条)
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (auth.memberInfo.isEmpty) auth.loadMemberInfo();
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
                      child: Text('个人信息',
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
            // 列表(响应式: 会员信息变化时自动刷新)
            Expanded(
              child: Obx(
                () => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _avatarItem(),
                    _divider(),
                    // 账号: is_edit_username == 1 才可改,否则只读
                    auth.canEditUsername
                        ? _editableItem('账号', auth.username, () => _editUsername())
                        : _readonlyItem('账号', auth.username),
                    _divider(),
                    _editableItem(
                      '昵称',
                      auth.nickname,
                      () => Get.to(() => EditNicknamePage(initial: auth.nickname)),
                    ),
                    _divider(),
                    _pickItem('性别', auth.sexName, const ['未知', '男', '女'], _saveSex),
                    _divider(),
                    _editableItem('生日', auth.birthday, _editBirthday, hint: '请选择生日'),
                    const SizedBox(height: 24.0),
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
    if (avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('assets/')) {
        return Image.asset(avatarPath, fit: BoxFit.cover);
      }
      return Image.file(File(avatarPath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
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
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent)),
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

  /// 输入弹窗(昵称 / 账号)
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
              onPressed: () => Get.back<String>(result: controller.text.trim()), child: const Text('保存')),
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


  /// 性别: 未知 / 男 / 女 -> 0 / 1 / 2
  Future<void> _saveSex(String value) async {
    final int sex = value == '男' ? 1 : (value == '女' ? 2 : 0);
    if (sex == auth.sex) return;
    await _run(() => MemberApi.modifySex(sex), ok: '性别修改成功');
  }

  /// 生日: 滚轮日期选择器 -> 秒级时间戳
  Future<void> _editBirthday() async {
    final DateTime now = DateTime.now();
    DateTime initial = DateTime(1990);
    if (auth.birthday.isNotEmpty) initial = DateTime.tryParse(auth.birthday) ?? initial;
    DatePicker.showDatePicker(
      Get.overlayContext ?? context,
      showTitleActions: true,
      minTime: DateTime(now.year - 80),
      maxTime: now,
      currentTime: initial,
      locale: LocaleType.zh,
      theme: const DatePickerTheme(
        headerColor: Colors.white,
        backgroundColor: Colors.white,
        itemStyle: TextStyle(color: Colors.black87, fontSize: 18.0),
        doneStyle: TextStyle(color: Color(0xFFFF2C55), fontSize: 16.0, fontWeight: FontWeight.w600),
        cancelStyle: TextStyle(color: Colors.grey, fontSize: 16.0),
      ),
      onConfirm: (DateTime date) {
        final String text =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (text == auth.birthday) return;
        // 生日以当日 12 点为基准转时间戳,避免时区导致跨天
        final int stamp = DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch ~/ 1000;
        _run(() => MemberApi.modifyBirthday(stamp), ok: '生日修改成功');
      },
    );
  }

  // ============== 头像 ==============

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAvatar() async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 操作项卡片
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSheetButton('拍照', () {
                      Get.back<void>();
                      _takePhoto();
                    }),
                    const Divider(height: 0.5, color: Color(0xFFEEEEEE), indent: 0, endIndent: 0),
                    _buildSheetButton('我的相册', () {
                      Get.back<void>();
                      _pickFromAlbum();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),
              // 取消
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: _buildSheetButton('取消', () => Get.back<void>(), isCancel: true),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
    );
  }

  Widget _buildSheetButton(String text, VoidCallback onTap, {bool isCancel = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16.0,
            color: isCancel ? const Color(0xFF333333) : Colors.black87,
            fontWeight: isCancel ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 拍照
  Future<void> _takePhoto() async {
    if (loading) return;
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file != null) await _uploadAvatar(file);
  }

  /// 我的相册
  Future<void> _pickFromAlbum() async {
    if (loading) return;
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file != null) await _uploadAvatar(file);
  }

  /// 选图后: 本地预览 -> 上传 -> 修改头像 -> 刷新会员信息(全局同步)
  Future<void> _uploadAvatar(XFile file) async {
    // 先本地预览,保证选图后头像立即变化(不依赖上传/接口结果)
    setState(() => avatarPath = file.path);
    await _run(() async {
      final String pic = await MemberApi.uploadHeadImg(file.path);
      await MemberApi.modifyHeadImg(pic);
    }, ok: '修改成功');
  }
}
