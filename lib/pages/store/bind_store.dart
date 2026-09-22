/// 绑定门店
library;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/member.dart';
import '../../controller/auth_store.dart';

class BindStorePage extends StatelessWidget {
  const BindStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F6),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFFFF3EE), Colors.white],
            ),
          ),
          child: Stack(
            children: <Widget>[
              // 顶部装饰圆
              Positioned(
                top: -MediaQuery.of(context).padding.top - 40,
                right: -60,
                child: Container(
                  width: 220.0,
                  height: 220.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF7A52).withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: -40,
                child: Container(
                  width: 100.0,
                  height: 100.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2C55).withValues(alpha: 0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 50.0),
                      _buildBrand(),
                      const Spacer(flex: 2),
                      _buildCard(context),
                      const Spacer(flex: 3),
                      _buildSkip(),
                      const SizedBox(height: 24.0),
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

  /// 顶部品牌
  Widget _buildBrand() {
    return Column(
      children: <Widget>[
        Image.asset('assets/images/logo.png', width: 76.0, fit: BoxFit.contain),
        const SizedBox(height: 14.0),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF7A52)],
            ).createShader(bounds);
          },
          child: const Text(
            '乐惠新零售',
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2.0),
          ),
        ),
      ],
    );
  }

  /// 中部操作卡
  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24.0, 34.0, 24.0, 32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20.0, offset: const Offset(0.0, 6.0)),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Text(
            '绑定常去门店！',
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 8.0),
          const Text(
            '领取专属特惠福利',
            style: TextStyle(fontSize: 14.0, color: Colors.black45),
          ),
          const SizedBox(height: 34.0),
          _buildPrimaryButton(
            label: '扫一扫绑定门店',
            icon: Icons.qr_code_scanner_rounded,
            onTap: () => _scanToBind(context),
          ),
          const SizedBox(height: 14.0),
          _buildSecondaryButton(
            label: '输入店员账号',
            onTap: _inputAccount,
          ),
        ],
      ),
    );
  }

  /// 主按钮
  Widget _buildPrimaryButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      height: 48.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A52)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0xFFFF2C55).withValues(alpha: 0.25), blurRadius: 10.0, offset: const Offset(0.0, 4.0)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.0),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18.0, color: Colors.white),
                const SizedBox(width: 6.0),
                Text(label, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 次按钮
  Widget _buildSecondaryButton({required String label, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      height: 48.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFFF7A52), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.0),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFFFF7A52)),
            ),
          ),
        ),
      ),
    );
  }

  /// 暂不绑定
  Widget _buildSkip() {
    return GestureDetector(
      onTap: () => Get.offAllNamed('/'),
      child: const Text(
        '暂不绑定',
        style: TextStyle(fontSize: 14.0, color: Colors.black38),
      ),
    );
  }

  /// 扫码绑定
  /// 直接使用成熟扫码组件 ai_barcode_scanner(mobile_scanner 的 UI 封装):
  /// 自带全屏取景框、闪光灯、切换镜头、相册识别、权限引导,无需自己写扫码页
  Future<void> _scanToBind(BuildContext context) async {
    final BarcodeCapture? capture = await showAiBarcodeScanner(
      context,
      // 组件文案默认是英文,未传的字段会保留英文默认值,所以这里逐项覆盖
      labels: const ScannerLabels(
        galleryButton: '从相册选择',
        galleryTooltip: '从图片中识别二维码',
        torchOnTooltip: '关闭闪光灯',
        torchOffTooltip: '打开闪光灯',
        torchAutoTooltip: '闪光灯为自动模式',
        switchCameraTooltip: '切换摄像头',
        switchLensTooltip: '切换镜头',
        closeTooltip: '关闭',
        zoomTooltip: '缩放',
        resetZoomTooltip: '重置缩放',
        scanHint: '将门店二维码放入框内,即可自动扫描',
        scanHintIdle: '保持稳定,稍微靠近一些',
        doneButton: '完成',
        retryButton: '重试',
        openSettingsButton: '去设置',
        cameraErrorTitle: '相机启动失败',
        cameraErrorMessage: '请检查相机权限或稍后重试',
        permissionDeniedTitle: '未获取相机权限',
        permissionDeniedMessage: '请在系统设置中开启相机权限后重试',
        cameraUnsupportedTitle: '无法使用扫码功能',
        cameraUnsupportedMessage: '当前设备没有可用的摄像头',
        startingCamera: '正在启动相机…',
        noBarcodeFoundInImage: '该图片中未找到二维码',
        galleryUnsupported: '当前平台不支持从相册识别',
        invalidBarcode: '该二维码无法识别',
        copiedConfirmation: '已复制',
      ),
      // 只接受有内容的码,其余继续扫描
      validator: (BarcodeCapture capture) => _firstRawValue(capture).isNotEmpty,
    );

    final String code = _firstRawValue(capture);
    if (code.isEmpty) return;
    if (!context.mounted) return;
    await Get.dialog(BindScanNameDialog(scanResult: code));
  }

  /// 取扫码结果里第一个非空原始值
  String _firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return '';
    for (final Barcode barcode in capture.barcodes) {
      final String raw = (barcode.rawValue ?? '').trim();
      if (raw.isNotEmpty) return raw;
    }
    return '';
  }

  /// 输入店员账号弹窗
  void _inputAccount() {
    Get.dialog(const BindAccountDialog());
  }
}

/// 弹窗输入框
Widget _bindInput(
  TextEditingController controller,
  String hint, {
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
  int? maxLength,
  bool digitsOnly = false,
}) {
  return Container(
    height: 46.0,
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(23.0),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      maxLength: maxLength,
      inputFormatters: digitsOnly ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14.0, color: Colors.black.withValues(alpha: 0.30)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        // 隐藏右下角字数统计
        counterText: '',
      ),
    ),
  );
}

/// 中国大陆手机号: 1 开头,第二位 3-9,共 11 位
final RegExp _phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

/// 弹窗内的错误提示(显示在输入框下方)
Widget _bindErrorText(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 6.0, left: 16.0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 12.0, color: Color(0xFFFF2C55)),
      ),
    ),
  );
}

/// 弹窗取消按钮
Widget _bindCancelButton() {
  return Container(
    height: 42.0,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(21.0),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(21.0),
        onTap: Get.back,
        child: const Center(
          child: Text('取消', style: TextStyle(fontSize: 14.0, color: Colors.black54)),
        ),
      ),
    ),
  );
}

/// 弹窗确认按钮
Widget _bindConfirmButton({required bool loading, required VoidCallback? onTap}) {
  return Container(
    height: 42.0,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(21.0),
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A52)],
      ),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(21.0),
        onTap: onTap,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16.0,
                  height: 16.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Text('确认绑定', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ),
  );
}

/// 弹窗外壳
Widget _bindDialogShell({required String title, required String desc, required List<Widget> children}) {
  return UnconstrainedBox(
    constrainedAxis: Axis.vertical,
    child: SizedBox(
      width: 345.0,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        contentPadding: const EdgeInsets.fromLTRB(22.0, 28.0, 22.0, 24.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            Text(
              desc,
              style: const TextStyle(fontSize: 13.0, color: Colors.black45),
            ),
            const SizedBox(height: 22.0),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// 绑定成功: 刷新会员信息后关闭弹窗并进入首页
Future<void> _bindSuccess() async {
  Get.back();
  Get.snackbar('提示', '绑定成功');
  // 重新拉取会员信息,更新已绑定门店
  await AuthStore.to.loadMemberInfo();
  Get.offAllNamed('/');
}

/// 手动输入店员账号绑定弹窗
class BindAccountDialog extends StatefulWidget {
  const BindAccountDialog({super.key});

  @override
  State<BindAccountDialog> createState() => _BindAccountDialogState();
}

class _BindAccountDialogState extends State<BindAccountDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  // 内联错误提示
  String? _phoneError;
  String? _nameError;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _bindDialogShell(
      title: '门店绑定',
      desc: '请填写店员信息完成绑定',
      children: <Widget>[
        _bindInput(
          _phoneController,
          '请输入店员手机号码',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          digitsOnly: true,
          onChanged: (String _) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
        ),
        if (_phoneError != null) _bindErrorText(_phoneError!),
        const SizedBox(height: 12.0),
        _bindInput(
          _nameController,
          '请输入您的姓名',
          onChanged: (String _) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) _bindErrorText(_nameError!),
        const SizedBox(height: 24.0),
        Row(
          children: <Widget>[
            Expanded(child: _bindCancelButton()),
            const SizedBox(width: 12.0),
            Expanded(child: _bindConfirmButton(loading: _submitting, onTap: _submitting ? null : _confirm)),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final String phone = _phoneController.text.trim();
    final String name = _nameController.text.trim();
    // 校验失败时在输入框下方提示,不再用 snackbar(会被弹窗蒙层挡住)
    setState(() {
      _phoneError = phone.isEmpty
          ? '请输入店员手机号码'
          : (_phoneRegExp.hasMatch(phone) ? null : '请输入正确的手机号码');
      _nameError = name.isEmpty ? '请输入您的姓名' : null;
    });
    if (_phoneError != null || _nameError != null) return;

    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await MemberApi.bindStore(type: 'input', nickname: name, value: phone);
      if (!mounted) return;
      setState(() => _submitting = false);
      await _bindSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // 接口错误显示在手机号输入框下方
        _phoneError = MemberApi.errorMsg(e);
      });
    }
  }
}

/// 扫码后确认绑定弹窗(仅需填写姓名)
class BindScanNameDialog extends StatefulWidget {
  const BindScanNameDialog({super.key, required this.scanResult});

  /// 扫码结果
  final String scanResult;

  @override
  State<BindScanNameDialog> createState() => _BindScanNameDialogState();
}

class _BindScanNameDialogState extends State<BindScanNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _bindDialogShell(
      title: '确认绑定',
      desc: '请输入您的姓名完成绑定',
      children: <Widget>[
        _bindInput(
          _nameController,
          '请输入您的姓名',
          onChanged: (String _) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (_nameError != null) _bindErrorText(_nameError!),
        const SizedBox(height: 24.0),
        Row(
          children: <Widget>[
            Expanded(child: _bindCancelButton()),
            const SizedBox(width: 12.0),
            Expanded(child: _bindConfirmButton(loading: _submitting, onTap: _submitting ? null : _confirm)),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final String name = _nameController.text.trim();
    setState(() => _nameError = name.isEmpty ? '请输入您的姓名' : null);
    if (_nameError != null) return;

    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await MemberApi.bindStore(
        type: 'scan',
        nickname: name,
        value: Uri.encodeComponent(widget.scanResult),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _bindSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameError = MemberApi.errorMsg(e);
      });
    }
  }
}
