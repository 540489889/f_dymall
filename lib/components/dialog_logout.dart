/// 退出登录确认弹窗
/// * 替代系统默认 AlertDialog, 样式与「退出登录」按钮(0xFFFF4D5F)保持一致
/// * 只负责弹窗与结果返回, 真正的清登录态/跳登录页由调用方处理
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 弹出退出登录确认框
/// * 返回 true 表示用户确认退出; 点遮罩 / 返回键 / 取消 都为 false
Future<bool> showLogoutDialog() async {
  final bool? ok = await Get.dialog<bool>(
    const _LogoutDialog(),
    // 点遮罩关闭(结果为 null, 下面按 false 处理)
    barrierDismissible: true,
  );
  return ok == true;
}

/// 弹窗主色(与设置页「退出登录」按钮一致)
const Color _brandColor = Color(0xFFFF4D5F);

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      // 两侧留白, 窄屏也不会顶到边缘
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0),
      elevation: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20.0, 28.0, 20.0, 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 顶部图标: 浅色圆底 + 主色图标
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: _brandColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: _brandColor, size: 28.0),
              ),
              const SizedBox(height: 16.0),
              const Text(
                '退出登录',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
              ),
              const SizedBox(height: 8.0),
              const Text(
                '退出后将无法查看订单和个人资料,\n需要重新登录才能继续使用',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.0, height: 1.5, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 24.0),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      backgroundColor: const Color(0xFFF5F5F7),
                      foregroundColor: const Color(0xFF666666),
                      onTap: () => Get.back<bool>(result: false),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Expanded(
                    child: _DialogButton(
                      label: '退出',
                      gradient: LinearGradient(colors: <Color>[Color(0xFFFF7A50), _brandColor]),
                      foregroundColor: Colors.white,
                      confirm: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗按钮
/// * [confirm] true 时点击返回 true(确认退出), 否则返回 false
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.foregroundColor,
    this.backgroundColor,
    this.gradient,
    this.confirm = false,
    this.onTap,
  });

  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool confirm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: confirm
            ? const <BoxShadow>[BoxShadow(color: Color(0x33FF4D5F), blurRadius: 10.0, offset: Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.0),
          onTap: onTap ?? () => Get.back<bool>(result: confirm),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}
