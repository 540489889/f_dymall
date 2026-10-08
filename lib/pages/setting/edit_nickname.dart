/// 修改昵称(独立页)
/// 从「个人信息」页点击「昵称」进入
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';

class EditNicknamePage extends StatefulWidget {
  final String initial;

  const EditNicknamePage({super.key, this.initial = ''});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  late final TextEditingController _controller;
  bool loading = false;

  // 允许中英文、数字、_、-，长度 4-20
  static final RegExp _nicknameRegExp = RegExp(r'^[a-zA-Z0-9_\-\u4e00-\u9fa5]{4,20}$');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
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
                      child: Text('修改昵称',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 42.0),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                height: 2.0,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFFFEEF0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D5F)),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24.0),
                    // 输入框
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF2F2F2))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !loading,
                              autofocus: true,
                              maxLength: 20,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              decoration: const InputDecoration(
                                hintText: '请输入昵称',
                                hintStyle: TextStyle(fontSize: 16.0, color: Color(0xFFBDBDBD)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              style: const TextStyle(fontSize: 16.0, color: Colors.black87),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (_, value, __) {
                              if (value.text.isEmpty) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8.0),
                                  child: const Icon(Icons.cancel, size: 16.0, color: Color(0xFFCCCCCC)),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    // 提示文案
                    const Text(
                      '4-20个字符，可由中英文、数字、"_"、"-"组成',
                      style: TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 40.0),
                    // 提交按钮
                    SizedBox(
                      width: double.infinity,
                      height: 46.0,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FStyle.primaryColor,
                          disabledBackgroundColor: FStyle.primaryColor.withOpacity(0.6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23.0),
                          ),
                        ),
                        child: loading
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      MyDialog.toast('昵称不能为空');
      return;
    }
    if (value == widget.initial) {
      MyDialog.toast('与原昵称一致');
      return;
    }
    if (!_nicknameRegExp.hasMatch(value)) {
      MyDialog.toast('4-20个字符，可由中英文、数字、_、-组成');
      return;
    }
    if (loading) return;
    setState(() => loading = true);
    try {
      await MemberApi.modifyNickname(value);
      await auth.loadMemberInfo();
      if (!mounted) return;
      MyDialog.toast('修改成功');
      Get.back();
    } catch (e) {
      MyDialog.toast(MemberApi.errorMsg(e, '修改失败'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
