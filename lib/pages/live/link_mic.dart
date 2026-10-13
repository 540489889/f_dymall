/// 直播连麦页(观众/嘉宾端)
/// * 对齐 H5 pages_tool/live/liveChat.nvue 的流程:
///   输入连麦码 -> POST /live/api/shop/applyLink -> 等主播同意(等待中) -> socket 推 meeting_accept
///   -> 用下发的参数进 TRTC 房间 -> 连麦中(本地大画面 + 远端小窗); 主播结束/拒绝时推 meeting_close
/// * 本页自己连一条 WebSocket 进房(与 H5 liveChat 的 soketInit 一致), 不依赖观看页那条连接
/// * 只做音视频连麦, 弹幕/商品等仍走观看页(连麦期间主播那边的画面由云端混流回 CDN 给观众)
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../../api/live.dart';
import '../../config/index.dart';
import '../../utils/live_socket.dart';
import '../../utils/request.dart';

/// 连麦状态
/// * input 输入连麦码 / waiting 等待主播同意 / linking 连麦中
enum LinkMicStep { input, waiting, linking }

class LinkMicPage extends StatefulWidget {
  const LinkMicPage({super.key});

  @override
  State<LinkMicPage> createState() => _LinkMicPageState();
}

class _LinkMicPageState extends State<LinkMicPage> {
  LinkMicStep step = LinkMicStep.input;
  final TextEditingController codeController = TextEditingController();
  bool submitting = false;

  /// 连麦房间号(applyLink 返回, 用它发 join 才能收到 meeting_accept)
  String roomSn = '';
  LiveSocket? socket;

  TRTCCloud? trtc;
  TRTCCloudListener? listener;
  /// 远端连麦者(连麦中渲染成右侧小窗)
  final List<String> remoteUsers = <String>[];
  bool frontCamera = true;
  bool micMuted = false;

  @override
  void initState() {
    super.initState();
    // 从观看页跳过来: 那边收到 meeting_accept 时会直接带进房参数开本页, 这里直接进房
    final dynamic args = Get.arguments;
    if (args is Map && args['trtc'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterRoom(args['trtc']));
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    socket?.close();
    unawaited(_exitTrtc());
    super.dispose();
  }

  /// 申请连麦: 拿到房间号后连接 WebSocket 进房, 等主播同意
  Future<void> apply() async {
    if (submitting) return;
    final String code = codeController.text.trim();
    if (code.isEmpty) {
      Get.snackbar('提示', '请输入连麦码');
      return;
    }
    setState(() {
      submitting = true;
    });
    final Map<String, dynamic> res = await LiveApi.applyLink(code);
    if (!mounted) return;
    setState(() {
      submitting = false;
    });
    if (res['ok'] != true) {
      Get.snackbar('提示', '${res['message'] ?? '申请失败'}');
      return;
    }
    roomSn = '${res['sn'] ?? ''}'.trim();
    if (roomSn.isEmpty) {
      Get.snackbar('提示', '未获取到直播间信息');
      return;
    }
    _initSocket();
    setState(() {
      step = LinkMicStep.waiting;
    });
  }

  /// 进房: (重)连成功后发 join, 服务端据此把 meeting_accept/meeting_close 推给这条连接
  void _initSocket() {
    socket?.close();
    socket = LiveSocket(
      url: Config.socketUrl,
      onMessage: _onSocketMessage,
      onConnected: _sendJoinRoom,
    );
    socket!.connect();
  }

  void _sendJoinRoom() {
    if (roomSn.isEmpty) return;
    // 与 H5 sendJoinRoom / 观看页进房格式 #0 一致
    socket?.send('join', <String, dynamic>{
      'room_id': roomSn,
      'token': Request.currentToken,
    });
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    final String type = '${msg['type'] ?? ''}'.trim();
    final dynamic data = msg['data'];
    debugPrint('[link]socket 消息: $type');
    switch (type) {
      // 主播同意: data 就是 TRTC 进房参数(sdkAppId/userSig/userId/roomId/role)
      case 'meeting_accept':
        unawaited(_enterRoom(data));
        break;
      // 主播拒绝/结束连麦
      case 'meeting_close':
        _onClosed('${data is Map ? (data['message'] ?? '') : ''}'.trim().isEmpty ? '连麦已结束' : '$data');
        break;
    }
  }

  /// 主播结束/拒绝: 退房回到输入态
  void _onClosed(String message) {
    if (!mounted) return;
    Get.snackbar('提示', message);
    unawaited(_exitTrtc());
    setState(() {
      step = LinkMicStep.input;
    });
  }

  /// 进 TRTC 房间(参数由服务端下发, 客户端不持有密钥)
  Future<void> _enterRoom(dynamic data) async {
    final Map<String, dynamic> params = LiveApi.trtcParamsOf(data);
    if (params.isEmpty) {
      Get.snackbar('提示', '连麦参数不完整，请重新申请');
      setState(() {
        step = LinkMicStep.input;
      });
      return;
    }
    // 相机/麦克风: 没授权就先申请, 被拒直接不进房(进了也只有黑屏)
    final bool granted = await _requestPermissions();
    if (!granted) {
      Get.snackbar('提示', '需要相机和麦克风权限才能连麦');
      setState(() {
        step = LinkMicStep.input;
      });
      return;
    }
    final TRTCCloud cloud = await TRTCCloud.sharedInstance();
    trtc = cloud;
    final TRTCCloudListener value = TRTCCloudListener(
      onError: (int errCode, String errMsg) => debugPrint('[link]TRTC 错误: $errCode $errMsg'),
      onEnterRoom: (int result) => debugPrint('[link]TRTC 进房: $result'),
      onExitRoom: (int reason) => debugPrint('[link]TRTC 退房: $reason'),
      onRemoteUserEnterRoom: (String userId) {
        if (!remoteUsers.contains(userId)) {
          setState(() {
            remoteUsers.add(userId);
          });
        }
      },
      onRemoteUserLeaveRoom: (String userId, int reason) {
        setState(() {
          remoteUsers.remove(userId);
        });
      },
    );
    listener = value;
    cloud.registerListener(value);
    cloud.startLocalAudio(TRTCAudioQuality.defaultMode);
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
    if (!mounted) return;
    setState(() {
      step = LinkMicStep.linking;
    });
  }

  /// 申请相机 + 麦克风权限
  Future<bool> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.camera,
      Permission.microphone,
    ].request();
    return statuses[Permission.camera]?.isGranted == true && statuses[Permission.microphone]?.isGranted == true;
  }

  /// 结束连麦(主动挂断 / 主播结束 / 页面销毁)
  Future<void> _exitTrtc() async {
    final TRTCCloud? cloud = trtc;
    final TRTCCloudListener? value = listener;
    trtc = null;
    listener = null;
    if (cloud == null) return;
    if (value != null) cloud.unRegisterListener(value);
    cloud.stopLocalPreview();
    cloud.stopLocalAudio();
    cloud.exitRoom();
    if (!mounted) return;
    setState(() {
      remoteUsers.clear();
    });
  }

  /// 主动挂断
  Future<void> _hangUp() async {
    await _exitTrtc();
    if (!mounted) return;
    setState(() {
      step = LinkMicStep.input;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 连麦中拦截返回键: 先退房再退出, 否则相机/麦克风会被一直占着
      canPop: step != LinkMicStep.linking,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        unawaited(_hangUp().then((_) => Get.back<dynamic>()));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212A),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            // 连麦中: 本地大画面 + 右上角远端小窗
            if (step == LinkMicStep.linking) _buildVideoLayer(),
            SafeArea(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  /// 连麦画面层
  Widget _buildVideoLayer() {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // 本地预览(自己): 大画面铺满
          Positioned.fill(
            child: TRTCCloudVideoView(
              onViewCreated: (int viewId) {
                trtc?.startLocalPreview(frontCamera, viewId);
              },
            ),
          ),
          // 远端连麦者: 右上角竖排小窗
          Positioned(
            top: 80.0,
            right: 10.0,
            child: Column(
              children: <Widget>[
                for (final String userId in remoteUsers)
                  Container(
                    width: 96.0,
                    height: 136.0,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: TRTCCloudVideoView(
                      onViewCreated: (int viewId) {
                        trtc?.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 内容层: 输入态 / 等待态 / 连麦中的控制条
  Widget _buildContent() {
    if (step == LinkMicStep.linking) return _buildLinkingBar();
    if (step == LinkMicStep.waiting) return _buildWaiting();
    return _buildInput();
  }

  /// 连麦码输入
  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, kToolbarHeight, 24.0, 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 40.0),
          const Icon(Icons.connect_without_contact_rounded, size: 64.0, color: Color(0xFFFF2C55)),
          const SizedBox(height: 16.0),
          const Text(
            '申请连麦',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8.0),
          const Text(
            '输入主播给你的连麦码，申请通过后即可与主播同屏',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.0, color: Colors.white54),
          ),
          const SizedBox(height: 32.0),
          Container(
            height: 46.0,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2F3A),
              borderRadius: BorderRadius.circular(23.0),
            ),
            child: TextField(
              controller: codeController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => apply(),
              cursorColor: const Color(0xFFFF2C55),
              style: const TextStyle(fontSize: 14.0, color: Colors.white),
              decoration: const InputDecoration(
                hintText: '请输入连麦码',
                hintStyle: TextStyle(fontSize: 13.0, color: Colors.white30),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          GestureDetector(
            onTap: apply,
            child: Container(
              height: 46.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23.0),
                gradient: const LinearGradient(colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF9C55)]),
              ),
              child: Center(
                child: submitting
                    ? const SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                      )
                    : const Text(
                        '申请连麦',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 2.0),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 等待主播同意
  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 36.0,
            height: 36.0,
            child: CircularProgressIndicator(strokeWidth: 3.0, color: Color(0xFFFF2C55)),
          ),
          const SizedBox(height: 18.0),
          const Text(
            '已提交申请，等待主播同意…',
            style: TextStyle(fontSize: 15.0, color: Colors.white),
          ),
          const SizedBox(height: 24.0),
          GestureDetector(
            onTap: () {
              socket?.close();
              setState(() {
                step = LinkMicStep.input;
              });
            },
            child: const Text('取消申请', style: TextStyle(fontSize: 13.0, color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  /// 连麦中控制条: 静音 / 切换摄像头 / 挂断
  Widget _buildLinkingBar() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: <Widget>[
              _circleButton(
                icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                onTap: () {
                  micMuted = !micMuted;
                  if (micMuted) {
                    trtc?.stopLocalAudio();
                  } else {
                    trtc?.startLocalAudio(TRTCAudioQuality.defaultMode);
                  }
                  setState(() {});
                },
              ),
              const SizedBox(width: 12.0),
              _circleButton(
                icon: Icons.cameraswitch_rounded,
                onTap: () {
                  frontCamera = !frontCamera;
                  trtc?.getDeviceManager().switchCamera(frontCamera);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: GestureDetector(
            onTap: _hangUp,
            child: Container(
              width: 64.0,
              height: 64.0,
              decoration: const BoxDecoration(color: Color(0xFFFF2C55), shape: BoxShape.circle),
              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20.0)),
        child: Icon(icon, color: Colors.white, size: 20.0),
      ),
    );
  }
}
