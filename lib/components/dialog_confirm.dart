/// 通用确认弹窗(自定义, 替代系统 AlertDialog)
/// * 样式与项目内 showLogoutDialog / showPrivacyExitDialog 一致: 白卡圆角 + 缩放入场
///   + 渐变主按钮; 比系统弹窗更贴合 App 风格
/// * 只负责弹窗与结果返回, 真正的删除 / 操作由调用方处理
/// * 返回 true = 确认; 取消 / 点遮罩 / 返回键 都为 false
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 弹出确认框
/// * [title] 标题, 默认「提示」
/// * [message] 正文(支持多行)
/// * [confirmText] / [cancelText] 两个按钮文案
/// * [icon] 顶部图标(传 null 则不显示图标)
/// * [brandColor] 主色(确认按钮渐变 + 图标底色), 默认危险红
Future<bool> showConfirmDialog({
  String title = '提示',
  required String message,
  String confirmText = '确定',
  String cancelText = '取消',
  IconData? icon,
  Widget? iconWidget,
  Color brandColor = const Color(0xFFFF4D5F),
}) async {
  final bool? ok = await Get.dialog<bool>(
    _ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      iconWidget: iconWidget,
      brandColor: brandColor,
    ),
    // 点遮罩关闭(结果为 null, 下面按 false 处理)
    barrierDismissible: true,
  );
  return ok == true;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    this.icon,
    this.iconWidget,
    required this.brandColor,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final Widget? iconWidget;
  final Color brandColor;

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
        builder: (BuildContext context, double value, Widget? child) =>
            Transform.scale(scale: value, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20.0, 28.0, 20.0, 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null || iconWidget != null) ...<Widget>[
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    color: brandColor.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: iconWidget ?? Icon(icon, color: brandColor, size: 28.0),
                ),
                const SizedBox(height: 16.0),
              ],
              Text(
                title,
                style: const TextStyle(
                    fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
              ),
              const SizedBox(height: 8.0),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.0, height: 1.5, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 24.0),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DialogButton(
                      label: cancelText,
                      backgroundColor: const Color(0xFFF5F5F7),
                      foregroundColor: const Color(0xFF666666),
                      onTap: () => Get.back<bool>(result: false),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _DialogButton(
                      label: confirmText,
                      gradient: LinearGradient(
                        colors: <Color>[brandColor.withOpacity(0.85), brandColor],
                      ),
                      foregroundColor: Colors.white,
                      shadowColor: brandColor.withAlpha(51),
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
/// * [confirm] true 时点击返回 true(确认), 否则返回 false
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.foregroundColor,
    this.backgroundColor,
    this.gradient,
    this.shadowColor,
    this.confirm = false,
    this.onTap,
  });

  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? shadowColor;
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
        boxShadow: shadowColor != null
            ? <BoxShadow>[
                BoxShadow(color: shadowColor!, blurRadius: 10.0, offset: const Offset(0, 4)),
              ]
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
              style: TextStyle(
                  fontSize: 15.0, fontWeight: FontWeight.w600, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}
