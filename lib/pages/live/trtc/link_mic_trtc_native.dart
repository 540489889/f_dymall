/// 连麦音视频: 移动端/桌面端实现(腾讯云 TRTC)
///
/// * 只在非 Web 编译产物里(link_mic_trtc.dart 的条件导出保证), 所以这里可以放心 import TRTC
/// * 页面侧只认 link_mic_engine.dart 里的 LinkMicEngine 接口, 不直接碰 TRTCCloud
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import 'link_mic_engine.dart';

/// 本地/远端画面视图: TRTC 的纹理视图
class LinkMicVideoView extends StatelessWidget {
  const LinkMicVideoView({super.key, required this.onViewCreated});

  final void Function(int viewId) onViewCreated;

  @override
  Widget build(BuildContext context) {
    return TRTCCloudVideoView(onViewCreated: onViewCreated);
  }
}

/// 创建当前平台的连麦引擎(非 Web)
LinkMicEngine createLinkMicEngine() => LinkMicEngineNative();

/// TRTC 实现
class LinkMicEngineNative implements LinkMicEngine {
  TRTCCloud? _cloud;
  TRTCCloudListener? _listener;

  @override
  bool get supported => true;

  @override
  Future<void> prepare() async {
    final TRTCCloud cloud = await TRTCCloud.sharedInstance();
    _cloud = cloud;
    _applyBeauty();
  }

  @override
  void startPreview(bool frontCamera, int viewId) {
    final TRTCCloud? cloud = _cloud;
    // viewId < 0: 视图还没建好/不是真实视图, 起播没有意义
    if (cloud == null || viewId < 0) return;
    cloud.startLocalPreview(frontCamera, viewId);
    // 预览视图重建后补一次(美颜绑定在采集侧, 保险起见重设)
    _applyBeauty();
  }

  @override
  void setMicMuted(bool muted) {
    final TRTCCloud? cloud = _cloud;
    if (cloud == null) return;
    if (muted) {
      cloud.stopLocalAudio();
    } else {
      cloud.startLocalAudio(TRTCAudioQuality.defaultMode);
    }
  }

  @override
  void switchCamera(bool frontCamera) {
    _cloud?.getDeviceManager().switchCamera(frontCamera);
  }

  @override
  Future<void> enterRoom(
    Map<String, dynamic> params, {
    required bool micMuted,
    required void Function(String userId) onRemoteEnter,
    required void Function(String userId) onRemoteLeave,
  }) async {
    final TRTCCloud cloud = await TRTCCloud.sharedInstance();
    _cloud = cloud;
    final TRTCCloudListener value = TRTCCloudListener(
      onError: (int errCode, String errMsg) => debugPrint('[link]TRTC 错误: $errCode $errMsg'),
      onEnterRoom: (int result) => debugPrint('[link]TRTC 进房: $result'),
      onExitRoom: (int reason) => debugPrint('[link]TRTC 退房: $reason'),
      onRemoteUserEnterRoom: onRemoteEnter,
      onRemoteUserLeaveRoom: (String userId, int reason) => onRemoteLeave(userId),
    );
    _listener = value;
    cloud.registerListener(value);
    _applyBeauty();
    // 等待期间就静音过的话, 进房后沿用: 不在这里又把麦克风打开
    setMicMuted(micMuted);
    cloud.enterRoom(
      TRTCParams(
        sdkAppId: params['sdkAppId'] as int,
        userId: '${params['userId']}',
        userSig: '${params['userSig']}',
        roomId: (params['roomId'] as int?) ?? 0,
        strRoomId: '${params['strRoomId'] ?? ''}',
        role: params['role'] == 21 ? TRTCRoleType.audience : TRTCRoleType.anchor,
      ),
      TRTCAppScene.live,
    );
  }

  @override
  void startRemoteView(String userId, int viewId) {
    if (viewId < 0) return;
    _cloud?.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
  }

  @override
  Future<void> exit() async {
    final TRTCCloud? cloud = _cloud;
    final TRTCCloudListener? value = _listener;
    _cloud = null;
    _listener = null;
    if (cloud == null) return;
    if (value != null) cloud.unRegisterListener(value);
    cloud.stopLocalPreview();
    cloud.stopLocalAudio();
    cloud.exitRoom();
  }

  /// 应用默认美颜: 进房前设一次, 本地预览起播后再设一次(预览视图重建时仍保持)
  /// * 只对本地采集生效: 连麦者自己看到的预览和推给主播的画面都会带上
  /// * 全部为 0 即关闭美颜; 直播期间退出房间不会残留
  void _applyBeauty() {
    final TRTCCloud? cloud = _cloud;
    if (cloud == null) return;
    cloud.setBeautyStyle(
      // 接口层用 int(见 link_mic_engine.dart): 0 smooth / 1 nature
      kBeautyStyle == 0 ? TRTCBeautyStyle.smooth : TRTCBeautyStyle.nature,
      kBeautyLevel,
      kWhitenessLevel,
      kRuddinessLevel,
    );
    if (kDebugMode) {
      debugPrint('[link]默认美颜: style=$kBeautyStyle 磨皮$kBeautyLevel 美白$kWhitenessLevel 红润$kRuddinessLevel');
    }
  }
}
