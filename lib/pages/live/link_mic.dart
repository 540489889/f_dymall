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
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, SystemChrome, SystemUiMode, SystemUiOverlay, SystemUiOverlayStyle, TextInputFormatter;
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
/// 等待接听页底色(预览还没起来时的兜底深色): 白字白图标
const Color kCallBgBottom = Color(0xFF191C23);
/// 通话页文字阴影: 画面上不盖遮罩, 靠阴影保证白字在任何画面上都看得清
const List<Shadow> kCallTextShadows = <Shadow>[
  Shadow(color: Color(0x99000000), blurRadius: 6.0, offset: Offset(0.0, 1.0)),
];

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
  /// 本地预览视图 id(等待主播同意时就起预览, 所以视图在 waiting 阶段就已创建)
  int? localViewId;
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
    // 边到边: 视频画面铺到状态栏/导航栏区域(否则顶部电量栏那一条是系统底色, 看着像没铺满)
    // * 内容层本来就有 SafeArea, 按钮不会被系统栏压住; 离开页面在 dispose 里恢复
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    // 退出边到边: 恢复其他页面的默认系统栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
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
    // 申请后就要起本地预览(等待期间展示自己的画面): 没权限别进等待态, 不然只有黑屏
    if (!await _requestPermissions()) {
      if (await _permissionBlocked()) {
        // 被永久拒绝(勾了"不再询问"/系统里关掉): 再 request 也不会弹窗, 只能去设置页
        MyDialog.toast('相机/麦克风权限已被拒绝，请在系统设置中开启');
        await openAppSettings();
      } else {
        MyDialog.toast('需要相机和麦克风权限才能连麦');
      }
      return;
    }
    // 先把 TRTC 实例准备好, 再切等待态: 预览视图一创建就能立刻出画面
    await _preparePreview();
    if (!mounted) return;
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
    // 等待期间就静音过的话, 进房后沿用: 不在这里又把麦克风打开
    if (micMuted) {
      cloud.stopLocalAudio();
    } else {
      cloud.startLocalAudio(TRTCAudioQuality.defaultMode);
    }
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

  /// 起本地预览(自己的画面): 主播同意前也要展示(仿微信视频通话的等待页)
  /// * TRTC 允许进房前先 startLocalPreview; 主播同意后进房, 预览不中断直接开始推流
  Future<void> _preparePreview() async {
    final TRTCCloud cloud = await TRTCCloud.sharedInstance();
    trtc = cloud;
    _applyBeauty(cloud);
    // 视图可能已经先创建好了(比如从连麦中退回再申请): 补一次起播
    _startPreviewIfReady();
  }

  /// 本地预览起播: viewId 和 TRTC 实例都就绪才调(两者创建顺序不定, 所以各自就绪时都试一次)
  void _startPreviewIfReady() {
    final int? viewId = localViewId;
    final TRTCCloud? cloud = trtc;
    if (viewId == null || cloud == null) return;
    cloud.startLocalPreview(frontCamera, viewId);
    // 预览视图重建后补一次(美颜绑定在采集侧, 保险起见重设)
    _applyBeauty(cloud);
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
    // 预览停了, 视图也跟着销毁: 清掉 viewId, 下次申请重新起
    localViewId = null;
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
      // 等待中/连麦中拦截返回键: 先停预览/退房再退出, 否则相机/麦克风会被一直占着
      canPop: step == LinkMicStep.input,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (step == LinkMicStep.waiting) {
          _cancelApply();
          Get.back<dynamic>();
          return;
        }
        unawaited(_hangUp().then((_) => Get.back<dynamic>()));
      },
      child: Scaffold(
        // 等待接听用通话底色; 输入态仍是白底表单
        backgroundColor: calling ? kCallBgBottom : Colors.white,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            // 等待接听/连麦中: 本地预览(自己的画面)铺满; 连麦中再叠远端小窗
            if (step != LinkMicStep.input) _buildVideoLayer(),
            SafeArea(child: _buildContent()),
          ],
        ),
      ),
    ),
    );
  }

  /// 连麦画面层
  Widget _buildVideoLayer() {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // 本地预览(自己): 等待主播同意/连麦中都铺满当底图
          Positioned.fill(
            child: TRTCCloudVideoView(
              onViewCreated: (int viewId) {
                localViewId = viewId;
                _startPreviewIfReady();
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
        // 左上角返回: 这页没有 AppBar(连麦中/等待中画面要铺满)
        // * 连麦中不给返回: 走 PopScope 先退房再退出
        // * 等待中底图是自己的画面(深色): 图标改白色, 点返回等于取消申请
        if (step != LinkMicStep.linking)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: step == LinkMicStep.waiting ? _cancelApply : () => Get.back<dynamic>(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20.0,
                  color: step == LinkMicStep.waiting ? Colors.white : kLinkText,
                ),
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

  /// 等待主播同意: 仿微信视频通话等待页
  /// * 底图是自己的本地预览画面, 上面叠主播头像/名字/标题 + 等待点 + 底部三按钮
  Widget _buildWaiting() {
    final Map<String, dynamic>? room = roomInfo;
    final String avatar = '${room?['anchor_img'] ?? ''}'.trim();
    final String anchorName = '${room?['anchor_name'] ?? ''}'.trim();
    final String title = '${room?['name'] ?? ''}'.trim();
    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          // 底部按钮区渐变(顶部不遮画面, 铺到状态栏)
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: Container(
              height: 280.0,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0xB3000000)],
                ),
              ),
            ),
          ),
          Column(
            children: <Widget>[
              const SizedBox(height: 56.0),
              if (title.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white70,
                      shadows: kCallTextShadows,
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
              ],
              _callingAvatar(avatar),
              const SizedBox(height: 12.0),
              Text(
                anchorName.isEmpty ? '主播' : anchorName,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: kCallTextShadows,
                ),
              ),
              const SizedBox(height: 10.0),
              _callingDots(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // 静音(左): 图标/文字随状态切换
                    _callButton(
                      icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: micMuted ? '麦克风已关' : '麦克风已开',
                      active: micMuted,
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
                    // 挂断(中): 取消申请
                    _callButton(
                      icon: Icons.call_end_rounded,
                      label: '取消申请',
                      isHangup: true,
                      onTap: _cancelApply,
                    ),
                    // 切换摄像头(右): 等待期间调整自己的画面
                    _callButton(
                      icon: Icons.cameraswitch_rounded,
                      label: '摄像头切换',
                      onTap: () {
                        frontCamera = !frontCamera;
                        trtc?.getDeviceManager().switchCamera(frontCamera);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28.0),
            ],
          ),
        ],
      ),
    );
  }

  /// 等待中的头像: 圆角矩形(仿截图), 静止不抖动
  Widget _callingAvatar(String avatar) {
    return Container(
      width: 80.0,
      height: 80.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.0),
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white54, width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 10.0),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar.isEmpty
          ? const Icon(Icons.person_rounded, size: 44.0, color: Colors.white70)
          : CachedNetworkImage(
              imageUrl: avatar,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (BuildContext c, String u) =>
                  const Icon(Icons.person_rounded, size: 44.0, color: Colors.white70),
              errorWidget: (BuildContext c, String u, Object e) =>
                  const Icon(Icons.person_rounded, size: 44.0, color: Colors.white70),
            ),
    );
  }

  /// 等待中的三个点(对方未接提示): 循环淡入淡出
  Widget _callingDots() {
    return AnimatedBuilder(
      animation: callingCtrl,
      builder: (BuildContext context, Widget? child) {
        final double t = callingCtrl.value;
        double wave(double x) {
          final double v = (x - x.floor()) * 2.0 - 1.0;
          return 0.25 + 0.75 * (1.0 - v.abs());
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _callDot(wave(t * 3.0)),
            const SizedBox(width: 6.0),
            _callDot(wave(t * 3.0 + 1.0)),
            const SizedBox(width: 6.0),
            _callDot(wave(t * 3.0 + 2.0)),
          ],
        );
      },
    );
  }

  Widget _callDot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6.0,
        height: 6.0,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      ),
    );
  }

  /// 通话页底部按钮(等待态): 圆按钮 + 下方文字
  /// * 静音/切换摄像头 48px + 24px 图标; 挂断 66px + 32px 图标
  /// * [label] 传空就不显示文字(挂断按钮只留图标)
  /// * [active] 静音关闭态: 白底变主色底, 图标变白
  /// * [isHangup] 挂断: 主色底, 白图标
  Widget _callButton({
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    bool active = false,
    bool isHangup = false,
  }) {
    // 三颗按钮统一尺寸: 只有颜色不同(挂断是主色底), 避免大小不一看着不整齐
    const double size = 56.0;
    const double iconSize = 28.0;
    final Color bg;
    final Color iconColor;
    if (isHangup) {
      bg = kLinkPrimary;
      iconColor = Colors.white;
    } else if (active) {
      bg = kLinkPrimary;
      iconColor = Colors.white;
    } else {
      bg = const Color(0xE6FFFFFF);
      iconColor = kLinkText;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x1A000000), blurRadius: 6.0, offset: Offset(0.0, 2.0)),
              ],
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: 8.0),
          Text(
            label,
            style: const TextStyle(fontSize: 12.0, color: Colors.white, shadows: kCallTextShadows),
          ),
        ],
      ],
    );
  }

  /// 取消申请: 关掉连接/呼叫音/本地预览, 回到输入态
  void _cancelApply() {
    socket?.close();
    unawaited(_stopRing());
    // 预览在等待期间就起了: 取消时必须一起停掉, 否则相机一直被占着
    unawaited(_exitTrtc());
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
                active: micMuted,
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
  /// * [active] 关闭态(如已静音): 换成主色底 + 白图标, 一眼能看出麦克风关着
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          color: active ? kLinkPrimary : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1A000000), blurRadius: 6.0, offset: Offset(0.0, 2.0)),
          ],
        ),
        child: Icon(icon, color: active ? Colors.white : kLinkText, size: 20.0),
      ),
    );
  }
}
