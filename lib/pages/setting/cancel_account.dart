/// 注销账号(独立页,替换原协议弹窗)
/// 从「账户安全」页点击「注销账号」进入
/// * 已提交过申请(审核中/已注销/已拒绝)时展示状态,不再重复提交
/// * 未申请过: 展示注销协议 -> 勾选同意 -> /membercancel/api/membercancel/apply
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';
import '../../styles/index.dart';
import '../../widgets/field_error.dart';
import '../../widgets/html_content.dart';

/// 主色
const Color _primary = Color(0xFFFF2C55);

class CancelAccountPage extends StatefulWidget {
  const CancelAccountPage({super.key});

  @override
  State<CancelAccountPage> createState() => _CancelAccountPageState();
}

class _CancelAccountPageState extends State<CancelAccountPage> {
  AuthStore get auth => Get.isRegistered<AuthStore>() ? AuthStore.to : Get.put(AuthStore());

  bool pageLoading = true;
  bool submitting = false;
  bool agreed = false;

  /// 协议加载失败文案(非空时展示重试)
  String? loadError;
  /// 表单级错误(未勾选协议 / 服务端返回)
  String? formError;

  /// 已有的注销申请(null 表示未申请过)
  Map<String, dynamic>? applyInfo;
  /// 注销协议 {title, content}
  Map<String, dynamic> agreement = <String, dynamic>{};

  /// status 0 审核中 / 1 已注销 / 2 已拒绝
  String get statusText {
    final int status = int.tryParse('${applyInfo?['status'] ?? ''}') ?? 0;
    switch (status) {
      case 0:
        return '注销申请审核中';
      case 1:
        return '账号已注销';
      default:
        return '注销申请已被拒绝';
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 拉取申请状态 + 注销协议
  Future<void> load() async {
    setState(() {
      pageLoading = true;
      loadError = null;
    });
    try {
      final Map<String, dynamic> info = await MemberApi.cancelInfo();
      if (!mounted) return;
      final bool applied = info.isNotEmpty;
      Map<String, dynamic> agreementRes = <String, dynamic>{};
      if (!applied) agreementRes = await MemberApi.cancelAgreement();
      if (!mounted) return;
      setState(() {
        applyInfo = applied ? info : null;
        agreement = agreementRes;
        pageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pageLoading = false;
        loadError = MemberApi.errorMsg(e, '注销协议加载失败');
      });
    }
  }

  /// 提交注销申请
  Future<void> submit() async {
    if (!agreed) return showError('请先阅读并勾选同意注销协议');
    if (submitting) return;
    setState(() {
      submitting = true;
      formError = null;
    });
    try {
      await MemberApi.cancelApply();
      await auth.loadMemberInfo();
      if (!mounted) return;
      MyDialog.toast('注销申请已提交');
      Get.back<bool>(result: true);
    } catch (e) {
      if (!mounted) return;
      showError(MemberApi.errorMsg(e, '注销失败'));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void showError(String message) {
    if (!mounted) return;
    setState(() => formError = message);
  }

  // ============== 页面 ==============

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
            Expanded(child: _buildBody()),
          ],
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
          const Expanded(
            child: Center(
              child: Text('注销账号',
                  style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 42.0), // 占位平衡左右
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (pageLoading) {
      return const Center(
        child: SizedBox(
          width: 24.0,
          height: 24.0,
          child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(_primary)),
        ),
      );
    }
    if (loadError != null) return _buildLoadError();
    if (applyInfo != null) return _buildStatus();
    return _buildForm();
  }

  /// 协议加载失败
  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(loadError!, style: const TextStyle(fontSize: 14.0, color: Color(0xFF999999))),
          const SizedBox(height: 16.0),
          TextButton(onPressed: load, child: const Text('重新加载', style: TextStyle(color: _primary))),
        ],
      ),
    );
  }

  /// 已提交过申请: 展示状态
  Widget _buildStatus() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.hourglass_top_rounded, size: 48.0, color: _primary),
            const SizedBox(height: 16.0),
            Text(
              statusText,
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            const Text(
              '如需处理进度问题,请联系客服。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.0, color: Color(0xFF999999), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 协议 + 勾选 + 提交
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Text(
            '${agreement['title'] ?? '注销协议'}',
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: HtmlContent('${agreement['content'] ?? ''}'),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: FStyle.dividerColor)),
          ),
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildAgreementCheck(),
              FieldError(formError, top: 10.0),
              const SizedBox(height: 12.0),
              _buildSubmit(),
            ],
          ),
        ),
      ],
    );
  }

  /// 勾选同意
  Widget _buildAgreementCheck() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        agreed = !agreed;
        formError = null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 18.0,
                height: 18.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: agreed ? _primary : Colors.transparent,
                  border: Border.all(color: agreed ? _primary : Colors.grey.shade400, width: 1.0),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: agreed ? const Icon(Icons.check, size: 13.0, color: Colors.white) : null,
              ),
              const SizedBox(width: 8.0),
              const Text(
                '已阅读并同意注销协议',
                style: TextStyle(fontSize: 13.0, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ),
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
            : const Text('确认注销', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
