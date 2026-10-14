/// 连麦音视频: Web 端空实现
///
/// * Flutter Web 没有 dart:ffi, tencent_rtc_sdk 一 import 整包就编译不过, 所以 Web 端不能引 TRTC
/// * 这里把接口全部实现成空操作, 页面用 [LinkMicEngine.supported] 判断, 不支持时提示用户
/// * 真要在 H5 上连麦得走 TRTC 的 Web SDK(JS), 与本插件不是一套, 需要另外接
library;

import 'package:flutter/material.dart';

import 'link_mic_engine.dart';

/// 视图占位: Web 端没有真实视频纹理, 回调 -1 告诉上层"别起播"
class LinkMicVideoView extends StatefulWidget {
  const LinkMicVideoView({super.key, required this.onViewCreated});

  final void Function(int viewId) onViewCreated;

  @override
  State<LinkMicVideoView> createState() => _LinkMicVideoViewState();
}

class _LinkMicVideoViewState extends State<LinkMicVideoView> {
  @override
  void initState() {
    super.initState();
    // -1: 上层拿到也只会走空实现(见 LinkMicEngineWeb)
    widget.onViewCreated(-1);
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

/// 创建当前平台的连麦引擎(Web)
LinkMicEngine createLinkMicEngine() => LinkMicEngineWeb();

/// Web 端空实现: 方法都在, 但什么都不做
class LinkMicEngineWeb implements LinkMicEngine {
  @override
  bool get supported => false;

  @override
  Future<void> prepare() async {}

  @override
  void startPreview(bool frontCamera, int viewId) {}

  @override
  void setMicMuted(bool muted) {}

  @override
  void switchCamera(bool frontCamera) {}

  @override
  Future<void> enterRoom(
    Map<String, dynamic> params, {
    required bool micMuted,
    required void Function(String userId) onRemoteEnter,
    required void Function(String userId) onRemoteLeave,
  }) async {}

  @override
  void startRemoteView(String userId, int viewId) {}

  @override
  Future<void> exit() async {}
}
