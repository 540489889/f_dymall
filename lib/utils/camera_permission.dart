/// 相机使用前的「应用内说明」确认(隐私合规 5.6)
/// * 监管要求: 申请相机权限前,须先让用户明确知晓使用目的并主动确认,
///   不能一进功能就弹系统权限框(会被判「未使用相关功能时提前申请权限」)。
/// * 策略(避免每次都弹,又不牺牲合规):
///   - 相机权限「已授予」: 后续不会再弹系统权限框(系统权限本来就一次性的),
///     直接放行,不再弹说明框 —— 用户只在首次走一次确认。
///   - 权限「未授予」(首次 / 被拒绝 / 去系统设置撤销过): 即将弹系统权限框,
///     此时必须先弹说明框,用户点「允许使用」后才由调用方触发真正的权限申请。
///   用权限状态而非一次性布尔记忆,可保证用户撤销权限后重新申请时仍有说明环节。
library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/dialog_confirm.dart';

/// 相机使用前确认; 返回 true = 可继续调起相机; false = 用户取消,应停止
Future<bool> confirmCameraUse(String purpose) async {
  // 已授权: 不会再触发系统权限弹窗,直接放行(无需重复说明)
  final bool granted = await Permission.camera.status.isGranted;
  if (granted) return true;

  // 未授权: 即将弹系统权限框,先弹应用内说明,用户主动确认后才继续
  return showConfirmDialog(
    title: '使用相机',
    message: '即将使用相机用于$purpose。\n仅在你主动使用该功能时开启，不会在后台调用。',
    confirmText: '允许使用',
    cancelText: '暂不',
    icon: Icons.photo_camera_outlined,
    brandColor: const Color(0xFFFF4D5F),
  );
}
