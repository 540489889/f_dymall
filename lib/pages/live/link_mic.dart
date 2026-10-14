/// 直播连麦页(观众/嘉宾端)
/// * 对齐 H5 pages_tool/live/liveChat.nvue 的流程:
///   输入连麦码 -> POST /live/api/shop/applyLink -> 等主播同意(等待中) -> socket 推 meeting_accept
///   -> 用下发的参数进 TRTC 房间 -> 连麦中(本地大画面 + 远端小窗); 主播结束/拒绝时推 meeting_close
/// * 本页自己连一条 WebSocket 进房(与 H5 liveChat 的 soketInit 一致), 不依赖观看页那条连接
/// * 只做音视频连麦, 弹幕/商品等仍走观看页(连麦期间主播那边的画面由云端混流回 CDN 给观众)
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, SystemUiOverlayStyle, TextInputFormatter;
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../../api/live.dart';
import '../../config/index.dart';
import '../../styles/index.dart';
import '../../utils/live_socket.dart';
import '../../utils/request.dart';

/// 连麦状态
/// * input 输入连麦码 / waiting 等待主播同意 / linking 连麦中
enum LinkMicStep { input, waiting, linking }

/// 连麦页强调色: 统一用 App 主题色(与登录/设置/隐私弹窗等页面一致)
/// * 主色 #FF2C55: 按钮渐变起点 / 光标 / 加载圈 / 顶部插图染色
const Color kLinkPrimary = FStyle.primaryColor;
/// 渐变终点(主题橙 #FF9C55): 与全站按钮渐变同一组配色
const Color kLinkPrimaryLight = Color(0xFFFF9C55);
/// 插图底板: 主色 10% 的浅色圆(白底上给插图一个视觉落点)
const Color kLinkBadgeBg = Color(0x1AFF2C55);
/// 白底上的正文/次要文案色
const Color kLinkText = Color(0xFF1F2126);
const Color kLinkTextSub = Color(0xFF8A8F99);
/// 输入框底色与描边(浅灰卡片 + 极淡描边)
const Color kLinkFieldBg = Color(0xFFF5F6F8);
const Color kLinkFieldBorder = Color(0xFFE9EBF0);
/// 等待接听页底色(仿微信语音通话等待页): 白字白图标; 有封面时上面还会叠一层封面做氛围底
const Color kCallBgBottom = Color(0xFF191C23);

/// 连麦默认美颜参数(基础美颜, 全部 0-9, 0 = 关闭)
/// * nature 自然风格: 保留面部细节, 比 smooth(光滑) 更适合普通连麦; 秀场想要更"磨皮"可换成 smooth
/// * 这里只给一个观感适中的默认值, 想调直接改这四个常量即可
const TRTCBeautyStyle kBeautyStyle = TRTCBeautyStyle.nature;
/// 磨皮(美颜)级别
const int kBeautyLevel = 5;
/// 美白级别
const int kWhitenessLevel = 4;
/// 红润级别
const int kRuddinessLevel = 3;

class LinkMicPage extends StatefulWidget {
  const LinkMicPage({super.key});

  @override
  State<LinkMicPage> createState() => _LinkMicPageState();
}

class _LinkMicPageState extends State<LinkMicPage> with SingleTickerProviderStateMixin {
  LinkMicStep step = LinkMicStep.input;
  final TextEditingController codeController = TextEditingController();
  bool submitting = false;

  /// 等待接听的呼吸/扩散光圈动画(仿微信呼叫中): 头像外圈循环放大淡出
  late final AnimationController callingCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  /// 连麦房间号(applyLink 返回, 用它发 join 才能收到 meeting_accept)
  String roomSn = '';
  /// 直播间信息(申请连麦的那个房间): 等待主播同意时展示主播头像/名字/直播间标题
  /// * applyLink 只给房间号, 详情另外查 /live/api/shop/getRoomInfo; 查不到就只显示文字提示
  Map<String, dynamic>? roomInfo;
  LiveSocket? socket;

  TRTCCloud? trtc;
  TRTCCloudListener? listener;
  /// 远端连麦者(连麦中渲染成右侧小窗)
  final   List<String> remoteUsers = <String>[];
  bool frontCamera = true;
  bool micMuted = false;

  /// 呼叫提示音: 申请连麦后循环播放, 主播同意/拒绝/取消/离开时停
  /// * 用 media_kit(项目已有, 不必再引一个音频插件); 资源在 pubspec 的 assets/audio/ 下
  static const String ringAsset = 'asset:///assets/audio/incoming-call-ringtone.wav';
  Player? ringPlayer;

  @override
  void initState() {
    super.initState();
    // 连麦期间保持常亮: 举手等待/通话中都不熄屏(离开页面在 dispose 里恢复)
    WakelockPlus.enable();
    // 从观看页跳过来: 那边收到 meeting_accept 时会直接带进房参数开本页, 这里直接进房
    final dynamic args = Get.arguments;
    if (args is Map && args['trtc'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterRoom(args['trtc']));
    }
  }

  @override
  void dispose() {
    // 离开连麦页恢复系统息屏策略
    WakelockPlus.disable();
    callingCtrl.dispose();
    codeController.dispose();
    socket?.close();
    // 离开页面必须停掉呼叫音, 否则它会一直响到进程结束
    unawaited(_stopRing());
    unawaited(_exitTrtc());
    super.dispose();
  }

  /// 申请连麦: 拿到房间号后连接 WebSocket 进房, 等主播同意
  Future<void> apply() async {
    if (submitting) return;
    final String code = codeController.text.trim();
    if (code.isEmpty) {
      // 提示与直播间一致: 居中 toast(不用顶部 snackbar)
      MyDialog.toast('请输入连麦码');
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
      MyDialog.toast('${res['message'] ?? '申请失败'}');
      return;
    }
    roomSn = '${res['sn'] ?? ''}'.trim();
    if (roomSn.isEmpty) {
      MyDialog.toast('未获取到直播间信息');
      return;
    }
    _initSocket();
    setState(() {
      // 直播间信息直接用 applyLink 返回的(data 里已带 sn/name/feeds_img/anchor_img/anchor_name)
      roomInfo = res['room'] is Map ? (res['room'] as Map).cast<String, dynamic>() : null;
      step = LinkMicStep.waiting;
    });
    // 等待主播同意期间播呼叫音(与拨电话一样, 让主播侧/用户知道还在呼叫)
    await _startRing();
  }

  /// 开始播呼叫提示音(循环)
  Future<void> _startRing() async {
    try {
      final Player ring = ringPlayer ?? Player();
      ringPlayer = ring;
      await ring.setPlaylistMode(PlaylistMode.loop);
      await ring.setVolume(100.0);
      await ring.open(Media(ringAsset), play: true);
    } catch (e) {
      debugPrint('[link]呼叫提示音播放失败(忽略): $e');
    }
  }

  /// 停止呼叫提示音(主播同意/拒绝、取消申请、挂断、离开页面)
  Future<void> _stopRing() async {
    final Player? ring = ringPlayer;
    ringPlayer = null;
    if (ring == null) return;
    try {
      await ring.stop();
      await ring.dispose();
    } catch (e) {
      debugPrint('[link]停止呼叫提示音异常(忽略): $e');
    }
  }

  /// 进房: (重)连成功后发 micer, 服务端据此把本连接标记为连麦者, 才会推 meeting_accept/meeting_close
  /// * 连麦者用 micer 而不是观看页的 join: join 只注册成观众, 收不到主播同意连麦的通知
  void _initSocket() {
    socket?.close();
    socket = LiveSocket(
      url: Config.socketUrl,
      onMessage: _onSocketMessage,
      onConnected: _sendJoinRoom,
    );
    socket!.connect();
  }

  /// 对齐 H5 liveChat.nvue sendJoinRoom: {type:'micer', data:{room_id, token}}
  void _sendJoinRoom() {
    if (roomSn.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[link]发送进房消息: type=micer room_id=$roomSn');
    }
    socket?.send('micer', <String, dynamic>{
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
    MyDialog.toast(message);
    unawaited(_stopRing());
    unawaited(_exitTrtc());
    setState(() {
      // 回到输入态顺手清掉直播间信息, 下次申请重新拉
      roomInfo = null;
      step = LinkMicStep.input;
    });
  }

  /// 进 TRTC 房间(参数由服务端下发, 客户端不持有密钥)
  Future<void> _enterRoom(dynamic data) async {
    // 主播已同意: 停掉呼叫音, 接下来说话走 TRTC
    await _stopRing();
    final Map<String, dynamic> params = LiveApi.trtcParamsOf(data);
    if (params.isEmpty) {
      MyDialog.toast('连麦参数不完整，请重新申请');
      setState(() {
        roomInfo = null;
        step = LinkMicStep.input;
      });
      return;
    }
    // 相机/麦克风: 没授权就先申请, 被拒直接不进房(进了也只有黑屏)
    final bool granted = await _requestPermissions();
    if (!granted) {
      if (await _permissionBlocked()) {
        // 被永久拒绝(勾了"不再询问"/系统里关掉): 再 request 也不会弹窗, 只能去设置页
        MyDialog.toast('相机/麦克风权限已被拒绝，请在系统设置中开启');
        await openAppSettings();
      } else {
        MyDialog.toast('需要相机和麦克风权限才能连麦');
      }
      setState(() {
        roomInfo = null;
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
    _applyBeauty(cloud);
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

  /// 应用默认美颜: 进房前设一次, 本地预览起播后再设一次(预览视图重建时仍保持)
  /// * 只对本地采集生效: 连麦者自己看到的预览和推给主播的画面都会带上
  /// * 全部为 0 即关闭美颜; 直播期间退出房间不会残留
  void _applyBeauty(TRTCCloud cloud) {
    cloud.setBeautyStyle(kBeautyStyle, kBeautyLevel, kWhitenessLevel, kRuddinessLevel);
    if (kDebugMode) {
      debugPrint('[link]默认美颜: ${kBeautyStyle.name} 磨皮$kBeautyLevel 美白$kWhitenessLevel 红润$kRuddinessLevel');
    }
  }

  /// 申请相机 + 麦克风权限
  /// * 前提是两端都声明了权限: AndroidManifest 的 CAMERA/RECORD_AUDIO、Info.plist 的 NSCamera/NSMicrophone
  ///   没声明时 request 直接返回 denied 且不弹系统弹窗, 表现就是"一进来就提示需要权限"
  Future<bool> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.camera,
      Permission.microphone,
    ].request();
    final bool ok = statuses[Permission.camera]?.isGranted == true && statuses[Permission.microphone]?.isGranted == true;
    if (kDebugMode) {
      debugPrint('[link]权限结果: camera=${statuses[Permission.camera]} mic=${statuses[Permission.microphone]}');
    }
    return ok;
  }

  /// 是否已被永久拒绝(勾过"不再询问" / 系统设置里关掉): 这种再 request 也不会弹窗
  Future<bool> _permissionBlocked() async {
    final PermissionStatus camera = await Permission.camera.status;
    final PermissionStatus mic = await Permission.microphone.status;
    return camera.isPermanentlyDenied || mic.isPermanentlyDenied;
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
    await _stopRing();
    await _exitTrtc();
    if (!mounted) return;
    setState(() {
      roomInfo = null;
      step = LinkMicStep.input;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 等待接听是深色全屏页: 状态栏图标要切成浅色, 其余白底页面用深色图标
    final bool calling = step == LinkMicStep.waiting;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (calling ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: PopScope(
      // 连麦中拦截返回键: 先退房再退出, 否则相机/麦克风会被一直占着
      canPop: step != LinkMicStep.linking,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        unawaited(_hangUp().then((_) => Get.back<dynamic>()));
      },
      child: Scaffold(
        // 等待接听用通话底色; 输入态仍是白底表单
        backgroundColor: calling ? kCallBgBottom : Colors.white,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            // 连麦中: 本地大画面 + 右上角远端小窗
            if (step == LinkMicStep.linking) _buildVideoLayer(),
            // 等待接听: 深色通话底铺满整屏(Scaffold 只支持单色背景, 底图放这层)
            if (calling) _buildCallBackground(),
            SafeArea(child: _buildContent()),
          ],
        ),
      ),
    ),
    );
  }

  /// 等待接听页底图: 直播间封面 + 深色渐变遮罩(没有封面时就是纯深色渐变通话底)
  /// * 封面压在暗色下面只当氛围底, 不影响白字/头像可读性
  Widget _buildCallBackground() {
    final String cover = '${roomInfo?['feeds_img'] ?? ''}'.trim();
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (cover.isNotEmpty)
            CachedNetworkImage(
              imageUrl: cover,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (BuildContext c, String u, Object e) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xC7333947), Color(0xF2171A21)],
              ),
            ),
          ),
        ],
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
                final TRTCCloud? cloud = trtc;
                if (cloud == null) return;
                cloud.startLocalPreview(frontCamera, viewId);
                // 预览视图重建后补一次(美颜是绑定采集侧的, 保险起见重设)
                _applyBeauty(cloud);
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
    return Stack(
      children: <Widget>[
        // 左上角返回: 这页没有 AppBar(连麦中画面要铺满), 白底上给一个深色返回键
        // * 连麦中不给返回: 走 PopScope 先退房再退出
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Get.back<dynamic>(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20.0, color: kLinkText),
            ),
          ),
        ),
        if (step == LinkMicStep.waiting) _buildWaiting() else _buildInput(),
      ],
    );
  }

  /// 连麦码输入
  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, kToolbarHeight, 24.0, 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 28.0),
          // 申请连麦头部插图: t-head-2.png 用主题色染色, 垫主色 10% 的浅色圆底
          Container(
            width: 112.0,
            height: 112.0,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: kLinkBadgeBg, shape: BoxShape.circle),
            // 用主题色整体染色(srcIn): 原图是蓝灰描边 + 蓝色波纹, 染成主色后与全站一致
            // * 透明区不受影响; 代价是变成单色剪影(机身与波纹同色), 层次比原图少一点
            child: Image.asset(
              'assets/images/t-head-2.png',
              width: 72.0,
              fit: BoxFit.contain,
              color: kLinkPrimary,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 22.0),
          const Text(
            '申请连麦',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: kLinkText),
          ),
          const SizedBox(height: 10.0),
          const Text(
            '输入主播给你的连麦码，申请通过后即可与主播同屏',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.0, height: 1.5, color: kLinkTextSub),
          ),
          const SizedBox(height: 36.0),
          Container(
            height: 48.0,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: kLinkFieldBg,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: kLinkFieldBorder),
            ),
            child: TextField(
              controller: codeController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => apply(),
              cursorColor: kLinkPrimary,
              style: const TextStyle(fontSize: 15.0, color: kLinkText),
              // 连麦码是纯数字: 弹数字键盘, 并用 formatter 过滤掉非数字(含粘贴进来的字母/符号)
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '请输入连麦码',
                hintStyle: TextStyle(fontSize: 14.0, color: Color(0xFFB6B9C0)),
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
              height: 48.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                gradient: const LinearGradient(colors: <Color>[kLinkPrimary, kLinkPrimaryLight]),
                // 白底上的投影: 主色 18% 的柔和投影, 按钮不至于"贴"在背景上
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x2EFF2C55), blurRadius: 12.0, offset: Offset(0.0, 6.0)),
                ],
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
          const SizedBox(height: 18.0),
          // 底部说明: 提前告知要授权, 避免申请时被系统弹窗吓到
          const Text(
            '首次连麦会申请相机和麦克风权限',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: kLinkTextSub),
          ),
        ],
      ),
    );
  }

  /// 等待主播同意: 仿微信语音通话的"等待对方接受邀请"页
  /// * 深色渐变全屏(不再是大片白底): 中间大头像 + 呼吸光圈, 下面是主播名/状态, 底部红色挂断按钮
  /// * 头像下方带一行直播间标题, 让用户确认自己连的是哪个直播间
  Widget _buildWaiting() {
    final Map<String, dynamic>? room = roomInfo;
    final String avatar = '${room?['anchor_img'] ?? ''}'.trim();
    final String anchorName = '${room?['anchor_name'] ?? ''}'.trim();
    final String title = '${room?['name'] ?? ''}'.trim();
    return SizedBox.expand(
      child: Column(
        children: <Widget>[
          const Spacer(flex: 3),
          _callingAvatar(avatar),
          const SizedBox(height: 22.0),
          Text(
            anchorName.isEmpty ? '主播' : anchorName,
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10.0),
          const Text(
            '正在等待对方接受邀请…',
            style: TextStyle(fontSize: 15.0, color: Colors.white70),
          ),
          if (title.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.0, color: Colors.white54),
              ),
            ),
          ],
          const Spacer(flex: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: _cancelApply,
                child: Container(
                  width: 66.0,
                  height: 66.0,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[kLinkPrimaryLight, kLinkPrimary],
                    ),
                  ),
                  child: const Icon(Icons.call_end_rounded, size: 32.0, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12.0),
              GestureDetector(
                onTap: _cancelApply,
                child: const Text(
                  '取消申请',
                  style: TextStyle(fontSize: 14.0, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36.0),
        ],
      ),
    );
  }

  /// 呼叫中的头像: 外圈循环扩散淡出(微信呼叫中那个光圈效果)
  Widget _callingAvatar(String avatar) {
    return AnimatedBuilder(
      animation: callingCtrl,
      builder: (BuildContext context, Widget? child) {
        final double t = callingCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Opacity(
              opacity: (1.0 - t) * 0.5,
              child: Container(
                width: 96.0 + 56.0 * t,
                height: 96.0 + 56.0 * t,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
      child: Container(
        width: 96.0,
        height: 96.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatar.isEmpty
            ? const Icon(Icons.person_rounded, size: 48.0, color: Colors.white70)
            : CachedNetworkImage(
                imageUrl: avatar,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (BuildContext c, String u) =>
                    const Icon(Icons.person_rounded, size: 48.0, color: Colors.white70),
                errorWidget: (BuildContext c, String u, Object e) =>
                    const Icon(Icons.person_rounded, size: 48.0, color: Colors.white70),
              ),
      ),
    );
  }

  /// 取消申请: 关掉连接/呼叫音回到输入态
  void _cancelApply() {
    socket?.close();
    unawaited(_stopRing());
    setState(() {
      roomInfo = null;
      step = LinkMicStep.input;
    });
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
              decoration: BoxDecoration(
                color: kLinkPrimary,
                shape: BoxShape.circle,
                // 白描边 + 投影: 悬浮在视频画面上时边界更清楚
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x33000000), blurRadius: 8.0, offset: Offset(0.0, 3.0)),
                ],
              ),
              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30.0),
            ),
          ),
        ),
      ],
    );
  }

  /// 连麦中的圆形控制按钮: 半透明白底 + 深色图标(视频画面亮度不定, 白底最稳)
  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          color: const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1A000000), blurRadius: 6.0, offset: Offset(0.0, 2.0)),
          ],
        ),
        child: Icon(icon, color: kLinkText, size: 20.0),
      ),
    );
  }
}
