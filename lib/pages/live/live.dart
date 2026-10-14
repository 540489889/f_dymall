/// 直播模板
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../api/live.dart';
import '../../config/index.dart';
import '../../controller/auth_store.dart';
import '../../router/fade_route.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../utils/danmu_zoom.dart';
import '../../utils/live_socket.dart';
import '../../utils/player_config.dart';
import '../../utils/request.dart';
import './components/animation_join.dart';
// import './components/animation_gift.dart'; // 送礼物消息动效: 已停用, 与下方 AnimationLiveGift 一并恢复
import './components/popup_comment.dart';
import './components/popup_activity_winner.dart';
import './components/popup_goods.dart';
import './components/popup_hongbao.dart';
import './components/popup_luckybag.dart';
import './components/popup_sign_stamp.dart';
// import './components/popup_gift.dart'; // 礼物弹窗: 随底部礼物入口一起停用, 恢复入口时一并放开
import './components/popup_more.dart';
import './components/popup_share.dart';
// import './components/popup_recharge.dart'; // 充值弹窗: 只被礼物弹窗调用, 随礼物入口一起停用
import './components/popup_redpacket.dart';

// 直播间播放器: 进程内单例, 页面销毁时不释放(只停流, 见 _LiveState.dispose)
//
// 为什么不能跟页面一起 dispose:
// * player.dispose() 是异步的。关闭直播间后退栈, 旧播放器还在异步收尾; 这时再从列表点进
//   另一个直播间, 新的 State 立刻 createLivePlayer() 建了第二个播放器 —— 两台同时抢硬解码器,
//   海思这类芯片在 1080p 上开不出第二路, 新那路没有视频轨, 表现就是"只有封面, 没有画面"。
// * 上下滑动切房不重建播放器, 所以那条路径一直是好的(也就只有"关闭后再进"会复现)。
// * 复用同一个播放器还有两个顺带的好处: 不用重新建 Surface, 起播更快。
late Player livePlayer = createLivePlayer();
// waitUntilFirstFrameRendered 是否已经完成过(播放器/输出都是全局单例, 它只会完成一次)
// * 见 _LiveState.initState 里的说明: 完成过之后不再拿它当"新房间首帧"的信号
bool liveFirstFrameRenderedOnce = false;
// 直播间画面输出(Surface/纹理): 跟着上面的播放器一起复用
late VideoController liveController = VideoController(
  livePlayer,
  // Android 配置见 androidLiveVideoConfig(mediacodec-copy)
  configuration: isAndroidPlatform
    ? androidLiveVideoConfig
    : const VideoControllerConfiguration(),
);

class Live extends StatefulWidget {
  const Live({super.key});

  @override
  State<Live> createState() => _LiveState();
}

class _LiveState extends State<Live> {
  // 接收参数
dynamic arguments = Get.arguments;
// 本页面的进房会话号: dispose 时用它判断播放器是否已经归新房间用了(见 dispose 里的停流)
int session = 0;
// 换流基准进度 / 新流是否已出帧: 播放器是复用的, 换流瞬间纹理里还是上一个房间的最后一帧,
// 只凭"视频轨就绪(width)"就显示画面, 第一帧会露出上一个房间 —— 要等新流的进度真的走起来
Duration streamBasePos = Duration.zero;
bool streamTicking = false;
// 因"进度还没走"而继续等的轮数(兜底上限, 见 _scheduleVideoShow)
int videoShowWaits = 0;
// 垂直滑动页面controller
late PageController pageVerticalController;
// 水平滑动controller
late PageController pageHorizontalController;

// 播放器: 复用文件顶部的单例(不随页面重建, 见 livePlayer 的说明)
Player get player => livePlayer;
VideoController get liveVideoController => liveController;

// 当前索引
final ValueNotifier<int> liveIndexNotifier = ValueNotifier(0);
// 当前时长
final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
// 首帧信号: 画面稳定后才置 true, 在此之前一直显示封面, 避免起播瞬间露出 Video 的黑底
final ValueNotifier<bool> firstFrameNotifier = ValueNotifier(false);
// 画面稳定计时器: 出帧后再稳一会儿才显示(见 _scheduleVideoShow), 避免"画面一闪 -> 黑屏"
Timer? _videoStableTimer;
// 播放器流订阅(进度 / 画面尺寸): 页面销毁时显式取消, 不留挂着全局 notifier 的回调
StreamSubscription<Duration>? _positionSubscription;
StreamSubscription<int?>? _widthSubscription;
// 起播前预置 Surface 尺寸的 Future(同一个 Player 只需一次, 切房沿用同一个 Surface)
Future<void>? _presetFuture;
// 上次预设用的尺寸: 与最新实测尺寸(lastLiveVideo*)不一致时重设一次
// * 只跑一次是不够的: 切到分辨率不同的房间时, 出帧那次 SetSurfaceSize 必然不匹配,
//   Surface 重建 -> seek -> RTMP 被打断 -> 又要重连一次(观感: 画面出来黑一下再出来)
int? _presetWidth;
int? _presetHeight;
// 直播流自动重连(Surface 重建触发的 seek 会打断 RTMP)
late LiveReconnector liveReconnector;
bool goodsTalkVisible = true;
// 带货商品列表: 进入直播间用 /live/api/shop/onlineGoods(参数 no = sn 房间号)查询, 底部购物弹窗用
// * 接口拿不到(空/失败)时弹窗沿用本地演示数据, 不至于空窗
List<Map<String, dynamic>> onlineGoods = <Map<String, dynamic>>[];
// 讲解中商品: socket goods 消息下发(与H5 livepull.nvue: msgGoods = msg.data 一致)
// * 已归一化(见 LiveApi.goodsItem), 未下发为 null(讲解卡回落本地房间数据)
Map<String, dynamic>? msgGoods;
// 排障用(仅 debug): 进房起播链路的诊断订阅与巡检定时器, 页面销毁时统一取消
final List<StreamSubscription<dynamic>> _diagSubs = <StreamSubscription<dynamic>>[];
Timer? _diagTimer;
// 进入时的房间下标(该房间优先使用接口数据)
int entryIndex = 0;
// 上下滑动的直播间列表: /live/api/shop/roomPage 接口数据(已用 _roomFromApi 归一化)
// * 分页: 滑到倒数第二条时自动加载下一页(hasMore 由接口 page_count 判断)
final List<Map<String, dynamic>> roomList = <Map<String, dynamic>>[];
bool roomListLoading = false;
// 列表是否已加载过(首次加载完成前展示加载中, 加载完仍为空才是"暂无直播间")
bool roomListLoaded = false;
int roomListPage = 1;
bool roomListHasMore = true;
// 直播间信息: 进入直播间时用 /live/api/shop/getRoomInfo 查询(拿不到为 null)
Map<String, dynamic>? roomInfo;
// [临时] 上下滑动切房的开关: 调试期间先关掉, 只保留进入的那一间
// * 关掉后: 竖向 PageView 不可手势滑动, onPageChanged 也不再触发 _switchRoom(不会换房/换流)
//   —— 但 controller.jumpToPage(进房定位到当前房间)仍然可用, 那是定位不是切房
// * 恢复: 把这里改回 true
static const bool liveRoomSwipeEnabled = true;

// 进房会话号: 每次进入直播间 +1
// * 离开直播间时旧页面的 dispose 要等路由过渡动画结束才执行, 这期间旧页面挂着的异步接口
//   (_loadRoomList / _loadRoomInfo / _loadRoomDetail) 会陆续返回, 而它们写的是上面这几个
//   文件级变量 —— 新页面已经建好了, 旧回调再把上一个房间的数据/拉流地址写回来,
//   于是新房间开屏第一帧渲染的是上一个房间(观感: 进 B 先闪一下 A 的封面, 甚至起播 A 的流)
// * 每个异步流程出发时记下当时的会话号, 回来发现会话号变了就直接作废
int liveSession = 0;
// 直播间状态: 0 直播预告 / 1 直播中 / 2 直播暂停中 / 3 直播已结束
// * 非直播中(0/2/3)不拉流, 用封面 + 状态提示兜底; 取不到该字段按直播中处理
int liveStatus = 1;
// 是否横屏直播间: 以 getRoomInfo 返回的 type 为准('horizontal' 横屏)
// * 接口返回前先用首页传入的 type 预判, 避免进来先竖版闪一下; 其余值一律按竖屏处理
// * 直播预告(status=0)一律按竖屏(接口此时常不下发 type), 预告卡片才不会被压成 16:9
bool isHorizontal = false;
// 直播预告: 开播时间(接口 start_time)与倒计时(每秒刷新, 到点自动复查房间状态)
DateTime? liveStartTime;
// 倒计时归零后的复查只做一次(否则房间还是预告时会反复请求详情)
bool startChecked = false;
// 预告片(getRoomInfo 的 pre_video): 非空时预告页播视频, 为空则展示封面图
String preVideo = '';
final ValueNotifier<Duration> countdownNotifier = ValueNotifier<Duration>(Duration.zero);
Timer? countdownTimer;
// 是否已预约直播(接口 subscribe_status / subscribe 字段), 已预约时按钮置灰
bool subscribed = false;
bool subscribing = false;
// 拉流地址: /live/api/shop/getPullUrl(参数 no = sn 房间号)返回的 url,拿不到为空
String pullUrl = '';
// 房间号: 进入时取首页传入的 sn, 上下滑动切房后跟随当前房间(进房消息/拉流都用它)
String currentSn = '';
String get roomSn => currentSn;
// 横屏直播间画面高度(16:9): 宽度撑满, 高度按 9 / 16 换算
double get videoHeight => MediaQuery.sizeOf(context).width * 9.0 / 16.0;
// 横屏画面顶部留白: 画面下移到弹幕区上方, 顶部给主播信息条(约46) + 福袋/活动入口(约43) 留出位置, 再与福袋留 12 间距
double get videoTop => MediaQuery.of(context).padding.top + 108.0;
// 直播间 WebSocket: 进入直播间即连接(地址 Config.socketUrl, 协议对齐 H5 livepull.nvue)
late LiveSocket liveSocket;
// 进房报文兜底: 当前尝试的格式下标 + 无推送看门狗(详见 _sendJoinPayload)
int _joinTryIndex = 0;
Timer? _joinWatchdog;
// 是否被禁言: socket 下发 mute/unmute, 禁言时不能发评论
bool userMuted = false;
// 在线人数 / 本场点赞数: socket room 消息下发 {online, zan}(与H5 onLine, zanNum 一致), 未下发为 0
int roomOnline = 0;
int roomZan = 0;
// 点赞飘心动画队列 + 自增 id(与H5 likeAnimations, likeSeed 一致)
// * 用 ValueNotifier 局部刷新: 连点只重建飘心层, 不触发整页 setState
final ValueNotifier<List<LikeHeart>> likeHearts = ValueNotifier<List<LikeHeart>>(const <LikeHeart>[]);
int likeSeed = 0;
// 点赞上行节流时间戳(ms): 与H5 一致 120ms, 连点时只飘心不重复上行
int lastZanAt = 0;
// 本地点赞乐观值: 点击后立即 +1, 收到 room 推送后清零(服务端累计已含本次, 避免重复计)
int localZanExtra = 0;
// 飘心随机参数(位置抖动/大小/时长/路径/颜色)
final Random likeRandom = Random();
// 弹幕消息(msg): socket 下发 [{mid, user:{nickname, member_level, chatrole}, msg}](与H5 messageList 一致)
// * 转成渲染条目后入队(上限 50 条), ValueNotifier 局部刷新避免高频消息触发整页重建
final ValueNotifier<List<Map<String, dynamic>>> danmuMessages = ValueNotifier<List<Map<String, dynamic>>>(const <Map<String, dynamic>>[]);
// 已展示弹幕的 id 集合: 服务端重推同一条时不重复展示(H5 未去重, 这里补上)
final Set<String> danmuIds = <String>{};
// 系统消息(msg_sys): {msg}, 转成公告条目并入弹幕队列(与H5 messageSys 一致, 不额外占版面)
String sysMessage = '';
// 进场消息(join): {user:{nickname}, msg}, 交给进场动效按顺序播放(与H5 merber_join 一致)
final ValueNotifier<List<Map<String, dynamic>>> joinMessages = ValueNotifier<List<Map<String, dynamic>>>(const <Map<String, dynamic>>[]);
// 活动列表(activity): 福袋/红包/签到/集章等, 每条为 LiveApi.activityItem 归一化结果
// * 只在真实直播间展示(socket 下发); 剩余时间每秒本地递减(与H5 initCountdown 一致)
final ValueNotifier<List<Map<String, dynamic>>> activityList = ValueNotifier<List<Map<String, dynamic>>>(const <Map<String, dynamic>>[]);
// 活动倒计时定时器: 收到 activity 后启动, 页面销毁时取消
Timer? activityTimer;
// 福袋弹窗关闭信号: 参与成功(luckybag_join) / 开奖(luckybag_end)时自增, 已打开的弹窗收到后自行关闭
final ValueNotifier<int> luckyBagCloseTick = ValueNotifier<int>(0);
// 已结束的活动 id(开奖推送 / 查到 end-* 状态): 左上角入口要跟着消失
// * 服务端结束活动后不一定再下发 activity 整表, 本地登记后入口也不会被后续整表刷回来
final Set<String> endedActivityIds = <String>{};

  @override
  void initState() {
  super.initState();
  // 看直播期间保持常亮: 长时间不操作也不熄屏(离开页面在 dispose 里恢复)
  WakelockPlus.enable();
  // 停掉首页的直播预览: 那是另一路硬解, 两台同时开会抢解码器(部分机型第二路直接开不出来,
  // 表现就是直播间没有视频轨、只剩封面)。离开直播间在 dispose 里恢复
  livePreviewSuspended.value = true;

  // 没有传参(直接打开直播页)时用空参数, 房间数据全部来自 roomPage 接口
  arguments ??= <String, dynamic>{};
  // 当前房间号: 进入时为首页传入的 sn, 上下滑动切房后由 _switchRoom 更新
  currentSn = '${arguments['sn'] ?? ''}'.trim();

  // 横竖屏(type): 先用首页传入的 type 预判, getRoomInfo 返回后以接口为准
  isHorizontal = LiveApi.isHorizontalRoom(arguments is Map ? arguments.cast<String, dynamic>() : null);

  // 进入的房间在第几位要等 roomPage 列表回来才知道, 由 _loadRoomList 定位并跳页
  entryIndex = 0;
  liveIndexNotifier.value = 0;
  // 每次进入直播间重置首帧信号(全局 notifier 会保留上次的值)
  firstFrameNotifier.value = false;
  // 进度同样复位: 上一个房间的播放进度会留在全局 notifier 里, 不清会带到新房间
  positionNotifier.value = Duration.zero;
  // 上一个房间的数据先清干净: roomList / roomInfo / 分页状态都是文件级变量, 退出房间不会自动
  // 清空, 于是进新房间的头几帧会先按旧列表渲染(封面走缓存, 出得比接口还快) —— 观感就是
  // "新画面出来前闪一下上一个房间的背景"
  // * 列表清掉后 _roomItem 会走 _roomFromArguments 兜一条, 那条用的是首页入参, 正是本房间的数据
  // 进房会话号 +1: 上一个房间还没返回的接口回调就此作废(见 liveSession 的说明)
  liveSession++;
  session = liveSession;
  roomList.clear();
  roomListPage = 1;
  roomListHasMore = true;
  roomListLoading = false;
  roomListLoaded = false;
  // 详情同理: 不清会先渲染上一个房间的状态/开播时间等, 接口回来再跳一次
  roomInfo = null;
  // 状态类同理(_switchRoom 里会清, 进房这条路径没清): 上一个房间是预告/结束时, liveStatus 会
  // 残留成 0/3, 新房间首帧就按"非直播中"处理 —— 不挂载画面也不起播
  // * 首页有传 status 就用它预判, 没传按直播中(1), getRoomInfo 回来后以接口为准
  liveStatus = LiveApi.statusOf(arguments is Map ? arguments.cast<String, dynamic>() : null);
  preVideo = '';
  liveStartTime = null;
  startChecked = false;
  pageVerticalController = PageController(initialPage: liveIndexNotifier.value, viewportFraction: 1.0);
  pageHorizontalController = PageController(initialPage: 1, viewportFraction: 1.0);
  // 走 LiveReconnector: 抵消 Surface 重建触发的 seek 对直播流的打断
  // 重连时用 _refreshPullUrl 重新取地址(m3u8 的 auth_key 有时效, 过期旧地址会 403)
  liveReconnector = LiveReconnector(
    player,
    srcProvider: _refreshPullUrl,
    // 重连期间画面是空的: 上层要把封面重新露出来, 否则这会儿就是一整片黑屏
    onReconnecting: _onReconnecting,
  );
  player.setPlaylistMode(PlaylistMode.loop);
  // 监听视频播放进度
  _positionSubscription = player.stream.position.listen((event) {
    // 会话号变了 = 播放器已经归新房间: 这个进度是新房间的, 别再写全局进度(旧页面还没 dispose)
    if (session != liveSession) return;
    positionNotifier.value = event;
    // 新流是否真的在出帧: 换流后进度会回退(新流时间轴从头开始)或从 0 起步
    // * 旧流的进度也在走, 所以只看"推进"不够, 要看它相对换流那一刻(基准)跳变
    if (!streamTicking &&
        (event < streamBasePos || (streamBasePos <= Duration.zero && event > Duration.zero))) {
      streamTicking = true;
    }
    });
  // 监听画面尺寸: 解码出首帧后 width 才有值, 用它控制 Video 的显示时机(未出画前保持封面)
  // * 不能直接置 true: 拿到尺寸时纹理可能还没渲染, 这时露出 Video 就是一片黑(它的 fill 是纯黑)
  // * 视频轨没了(被 seek 打断 / 重连中)就撤掉画面继续显示封面: 黑屏比"退回封面"难看得多
  _widthSubscription = player.stream.width.listen((event) {
    // 会话号变了 = 已经进了新房间: 这个尺寸事件属于新房间的流,
    // 旧页面再拿它调度显示会在新房间的帧上屏前就把画面放出来(露出残留画面)
    if (session != liveSession) return;
    if ((event ?? 0) > 0) {
      _scheduleVideoShow('视频轨就绪');
      return;
    }
    _videoStableTimer?.cancel();
    _videoStableTimer = null;
    if (firstFrameNotifier.value) firstFrameNotifier.value = false;
    });
  // 首帧真正渲染上屏(纹理已交给 Flutter)再显示画面
  // * 只回调一次: 重连后不会再触发, 所以上面那个 width 兜底必须保留
  // * 这个 Future 属于全局单例 VideoController, 只会完成一次: 第一次进房完成后,
  //   以后每次进房再注册 .then 都会立刻回调(那是上一次的"首帧", 不是新房间的),
  //   于是 700ms 后提前把封面藏了 -> 露出上一房间残留/黑屏(观感: 进房闪一下)
  //   所以只认第一次, 之后一律靠 player.stream.width(视频轨就绪) 兜底
  if (!liveFirstFrameRenderedOnce) {
    liveVideoController.waitUntilFirstFrameRendered.then((_) {
      liveFirstFrameRenderedOnce = true;
      if (kDebugMode) debugPrint('[live]首帧已渲染');
      _scheduleVideoShow('首帧已渲染');
    });
  }
  // 上下滑动的直播间列表: roomPage 接口(与房间信息并行加载)
  _loadRoomList();
  // 进入直播间: 先查房间信息(getRoomInfo)与拉流地址(getPullUrl),拿到后再起播
  _loadRoomInfo();
  // 进入直播间即连接 socket(与H5一致: 连上后发进房消息, 断线自动重连)
  _initSocket();
  // 排障用(仅 debug): 进房后把起播链路的状态打出来(切房没画面时靠它定位)
  if (kDebugMode) _startEntryDiag();
  }

// 上下滑动的直播间列表(/live/api/shop/roomPage): 首屏加载 + 滑到底加载下一页
// * 接口返回已由 LiveApi.roomItem 归一化, 这里再转成页面渲染字段(见 _roomFromApi)
// * 进入的房间不在列表里(接口没返回/被筛掉)时, 用首页入参补一条放首位, 保证进房就有房间
Future<void> _loadRoomList({bool loadMore = false}) async {
  if (roomListLoading) return;
  if (loadMore && !roomListHasMore) return;
  roomListLoading = true;
  final int page = loadMore ? roomListPage + 1 : 1;
  final int session = liveSession;
  final Map<String, dynamic> res = await LiveApi.roomPage(page: page, pageSize: 10);
  // 会话号变了 = 这期间又进了新房间: 结果作废, 不能再写回共享的房间列表
  // * 否则新房间开屏先渲染上一个房间的封面, 等自己的列表回来才换过来(观感: 闪一下上个房间)
  if (!mounted || session != liveSession) return;
  final dynamic rawList = res['list'];
  final List<Map<String, dynamic>> list = rawList is List
      ? rawList.whereType<Map<String, dynamic>>().map(_roomFromApi).toList()
      : <Map<String, dynamic>>[];
  setState(() {
    roomListPage = page;
    roomListHasMore = res['hasMore'] == true;
    roomListLoading = false;
    roomListLoaded = true;
    if (loadMore) {
      roomList.addAll(list);
    } else {
      roomList
        ..clear()
        ..addAll(list);
    }
    // 进入的房间在列表中的位置: 按房间号 sn 命中
    final int hit = roomSn.isEmpty
        ? -1
        : roomList.indexWhere((Map<String, dynamic> item) => '${item['sn'] ?? ''}'.trim() == roomSn);
    if (roomSn.isNotEmpty && hit < 0) {
      roomList.insert(0, _roomFromArguments());
      entryIndex = 0;
    } else {
      entryIndex = hit < 0 ? 0 : hit;
    }
    // 上下滑动切房关掉后(liveRoomSwipeEnabled), onPageChanged 不再触发 _switchRoom, 页码就
    // 不会跟着 jumpToPage 变 —— 这里直接同步成进入的房间, 否则 Video 按 liveIndex 挂载,
    // 进入的房间不在第 0 页时会一直不挂载(只有封面没画面)
    liveIndexNotifier.value = entryIndex;
    // 房间详情可能比列表先回来: 补一次合并, 进入的房间才不会退回列表里的简略字段
    if (roomInfo != null && entryIndex < roomList.length) {
      roomList[entryIndex] = _mergeRoomDetail(roomList[entryIndex], roomInfo!);
    }
  });
  // 列表是异步回来的(PageController 创建时还在第 0 页), 拿到后再跳到进入的房间
  // * 列表刚到位时 PageView 可能还没建起来(此前列表为空不建), 这会儿 hasClients 还是 false,
  //   直接 jumpToPage 会静默失效 -> 停在列表第一个房间: 播的是进来的房间, 界面/数据却是另一个
  // * 推到下一帧再跳: 那时 PageView 已建好, hasClients 才为 true
  if (!loadMore && entryIndex > 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pageVerticalController.hasClients) return;
      pageVerticalController.jumpToPage(entryIndex);
    });
  }
}

// 主播名: 接口字段是 anchor_name(name 是直播间标题, 不是主播名), 没下发时回退 name
// * 与直播列表页一致: 头像旁显示 anchor_name, 标题显示 name
String anchorNameOf(Map<String, dynamic> item) {
  final String anchor = '${item['anchor_name'] ?? ''}'.trim();
  if (anchor.isNotEmpty && anchor != 'null') return anchor;
  return '${item['name'] ?? ''}'.trim();
}

// 列表项的封面: feeds_img 优先, 取不到用 live_bg
String _posterOf(Map<String, dynamic> room) {
  final String feeds = LiveApi.imageOf(room['feeds_img']);
  if (feeds.isNotEmpty) return feeds;
  return LiveApi.imageOf(room['live_bg']);
}

// 接口房间 -> 页面渲染字段(沿用原来的字段名, 渲染层不用改)
// * 真实房间没有演示字段: 销量/点赞走 socket, 历史弹幕为空, 关注默认未关注
Map<String, dynamic> _roomFromApi(Map<String, dynamic> room) => <String, dynamic>{
      'id': '${room['sn'] ?? ''}'.trim(),
      'sn': '${room['sn'] ?? ''}'.trim(),
      'name': '${room['name'] ?? ''}'.trim(),
      // 主播名(顶部主播信息栏/红包"xxx的红包"用)
      'anchor_name': '${room['anchor_name'] ?? ''}'.trim(),
      'logo': '${room['anchor_img'] ?? ''}'.trim(),
      // 封面: feeds_img 优先, 没有用 live_bg; 都走 imageOf(补域名 + 拆多图串),
      // 否则拿到相对路径/多图串会请求失败 -> 封面位空着露出黑底
      'poster': _posterOf(room),
      'src': '${room['push_link'] ?? ''}'.trim(),
      // 横竖屏默认竖屏: 接口不下发 type 时(直播预告常见)按 vertical 处理
      'type': '${room['type'] ?? ''}'.trim().isEmpty ? 'vertical' : '${room['type']}'.trim(),
      'status': LiveApi.statusOf(room),
      'status_name': LiveApi.statusName(room),
      // 开播时间(预告倒计时用): 文本 "2026-09-22 10:57:53" 或时间戳, 原样保留由 _parseStartTime 解析
      'start_time': '${room['start_time'] ?? ''}'.trim(),
      'online': LiveApi.intOf(room['online']),
      'desc': '',
      'saleNum': '',
      'likeNum': '',
      // 关注状态: 接口下发(is_collect/is_follow)时以接口为准, 没下发默认未关注
      'isFollow': LiveApi.followStatusOf(room) ?? false,
      // 主播会员id(关注主播 collectLive 的 member_id)
      'anchor_member_id': LiveApi.anchorMemberIdOf(room),
      'message': <dynamic>[],
    };

// 首页/列表页传入的房间(接口列表里没有时的兜底): 字段与 _roomFromApi 保持一致
Map<String, dynamic> _roomFromArguments() => <String, dynamic>{
      'id': currentSn,
      'sn': currentSn,
      'name': '${arguments?['name'] ?? ''}'.trim(),
      'anchor_name': '${arguments?['anchor_name'] ?? ''}'.trim(),
      'logo': '',
      'poster': '${arguments?['cover'] ?? ''}'.trim(),
      'src': '${arguments?['src'] ?? ''}'.trim(),
      // 同上: 首页没传 type 时默认竖屏
      'type': '${arguments?['type'] ?? ''}'.trim().isEmpty ? 'vertical' : '${arguments?['type']}'.trim(),
      'status': 1,
      'status_name': '',
      'online': 0,
      'desc': '',
      'saleNum': '',
      'likeNum': '',
      'isFollow': false,
      'message': <dynamic>[],
    };

// 用 getRoomInfo 详情补齐列表里的房间(标题/头像/封面/横竖屏/状态), 只覆盖非空字段
Map<String, dynamic> _mergeRoomDetail(Map<String, dynamic> item, Map<String, dynamic> room) {
  final Map<String, dynamic> merged = Map<String, dynamic>.from(item);
  final String name = '${room['name'] ?? ''}'.trim();
  if (name.isNotEmpty) merged['name'] = name;
  // 主播名单独字段: 详情回来后补齐(列表页可能没下发)
  final String anchor = '${room['anchor_name'] ?? ''}'.trim();
  if (anchor.isNotEmpty) merged['anchor_name'] = anchor;
  final String logo = LiveApi.imageOf(room['anchor_img']);
  if (logo.isNotEmpty) merged['logo'] = logo;
  String cover = LiveApi.imageOf(room['feeds_img']);
  if (cover.isEmpty) cover = LiveApi.imageOf(room['live_bg']);
  if (cover.isNotEmpty) merged['poster'] = cover;
  final String type = '${room['type'] ?? ''}'.trim();
  if (type.isNotEmpty) merged['type'] = type;
  merged['status'] = LiveApi.statusOf(room);
  merged['status_name'] = LiveApi.statusName(room);
  // 关注状态 / 主播会员id(详情里才有, 列表页可能没下发)
  final bool? followed = LiveApi.followStatusOf(room);
  if (followed != null) merged['isFollow'] = followed;
  final String memberId = LiveApi.anchorMemberIdOf(room);
  if (memberId.isNotEmpty) merged['anchor_member_id'] = memberId;
  return merged;
}

// 进入直播间: 只等拉流地址(getPullUrl)就开始起播
// * 原实现把 roomInfo / pullUrl / onlineGoods 三个接口 Future.wait 一起等, 最慢的那个(带货商品)
//   决定起播时机, 进房要多等 1~3 秒才出画面; 现在房间信息与商品后台请求, 回来后各自刷新界面
// * 拉流地址: getPullUrl 优先,其次接口 push_link,最后首页传入的 src
Future<void> _loadRoomInfo() async {
  // getRoomInfo / getPullUrl 的 no 参数就是 sn(房间号)
  final String sn = '${arguments['sn'] ?? ''}'.trim();
  if (sn.isEmpty) return;
  final Stopwatch cost = Stopwatch()..start();
  final int session = liveSession;
  // 起播只等拉流地址: 房间详情与带货商品并行发出, 回来后自己刷新, 不参与等待
  final Future<String> urlFuture = LiveApi.pullUrl(sn);
  unawaited(_loadRoomDetail(sn, index: entryIndex));
  unawaited(_loadOnlineGoods(sn));
  // 入口已带 push_link(首页/列表页都有): 先用它立刻起播, 不占 getPullUrl 那一个接口往返
  // * 起播本身才是大头(建连 + 缓冲 + 首帧), 能早 1 个 RTT 就早 1 个 RTT
  // * 接口地址回来后不再二次起播: 那会把已经出来的画面重新缓冲一遍, 看着就是"播了两遍"
  //   入口地址万一失效, 由 LiveReconnector 重连时换成最新的 pullUrl(见 srcProvider)
  final String entrySrc = '${arguments['src'] ?? ''}'.trim();
  final bool started = entrySrc.isNotEmpty && shouldOpenStream(entryIndex);
  // 预置 Surface 与 getPullUrl 并行: 不额外占一个接口往返的时间
  final Future<void> presetFuture = _presetSurfaceFor(entryIndex);
  if (started) {
    await presetFuture;
    // 会话号变了(已离开/又进了新房间): 这个地址是上一个房间的, 不能再起播
    if (!mounted || session != liveSession) return;
    unawaited(_openStream(entrySrc));
  }
  final String url = (await urlFuture).trim();
  if (!mounted || session != liveSession) return;
  if (kDebugMode) debugPrint('[live]详情页 getPullUrl: sn=$sn url=$url 入口src=$entrySrc');
  setState(() {
    pullUrl = url;
    // 拉流地址同步到列表(竖滑回本房间时直接用, 不用再取一次)
    if (url.isNotEmpty && entryIndex < roomList.length) {
      roomList[entryIndex]['src'] = url;
    }
  });
  // 会话号变了: 下面的起播属于上一个房间, 直接收住
  if (session != liveSession) return;
  // 非直播中(0 预告 / 2 暂停 / 3 已结束)不拉流, 由封面 + 状态提示兜底
  if (!shouldOpenStream(entryIndex)) return;
  // 入口已有地址时上面就起播了, 这里不要再起一次
  if (!started) await _openEntryStream();
  if (kDebugMode) debugPrint('[live]进房到发起起播耗时: ${cost.elapsedMilliseconds}ms');
}

// 房间详情(getRoomInfo): 单独请求, 回来后刷新界面, 不阻塞起播
// * [updateStatus] 只有进入的那个房间才更新 roomInfo/liveStatus(头部状态提示用), 滑到的房间只补列表
Future<void> _loadRoomDetail(String sn, {int? index, bool updateStatus = true}) async {
  final int session = liveSession;
  final Map<String, dynamic>? room = await LiveApi.roomInfo(sn);
  // 同上: 会话号变了说明这是上一个房间的详情, 不能写进共享的 roomInfo / liveStatus
  if (!mounted || session != liveSession) return;
  if (room == null) return;
  final int i = index ?? liveIndexNotifier.value;
  setState(() {
    if (updateStatus) {
      roomInfo = room;
      liveStatus = LiveApi.statusOf(room);
      // getRoomInfo 的 start_time 常为 0, 这时回退用列表里那条的(roomPage 下发的开播时间)
      liveStartTime = _parseStartTime(room) ?? _parseStartTime(i < roomList.length ? roomList[i] : null);
      startChecked = false;
      // 兼容 1 / "1" / true 三种写法, 避免后端已返回已预约却识别成未预约(点了一次没变化)
      subscribed = room['subscribe_status'] == true ||
          LiveApi.intOf(room['subscribe_status']) > 0 ||
          LiveApi.intOf(room['subscribe']) > 0;
      debugPrint('[live]预约字段: subscribe_status=${room['subscribe_status']} subscribe=${room['subscribe']} -> subscribed=$subscribed');
      // 排查关注用: 主播会员id / 关注状态字段名不确定, 打一次详情字段方便对照
      debugPrint('[live]房间详情字段: ${room.keys.toList()}');
      debugPrint('[live]主播会员id=${LiveApi.anchorMemberIdOf(room)} 关注状态=${LiveApi.followStatusOf(room)}');
      // 预告片: 只有预告房间才播(相对路径按图片域名规则补全)
      final String pre = '${room['pre_video'] ?? ''}'.trim();
      if (liveStatus == 0 && pre.isNotEmpty && pre != 'null') preVideo = LiveApi.fixImage(pre);
    }
    // 横竖屏以接口 type 为准(首页传入的 type 只是预判)
    // * 详情是后台请求: 回来时用户可能已滑到别的房间, 这时不能改当前房间的布局
    // * 直播预告(status=0)按竖屏展示(type 默认 vertical), 预告卡片不被压成 16:9
    if (liveIndexNotifier.value == i) {
      isHorizontal = LiveApi.isHorizontalRoom(room) && LiveApi.statusOf(room) != 0;
    }
    if (i < roomList.length) roomList[i] = _mergeRoomDetail(roomList[i], room);
  });
  // 预告房间: 起播倒计时(到点自动复查是否已开播) + 有预告片就播预告片
  if (updateStatus && liveStatus == 0) {
    _startCountdown();
    unawaited(_openPreviewVideo());
  }
  // 接口回来才发现已结束/暂停/预告: 停掉刚起的流, 交给封面 + 状态提示
  // * 用最新的 entryIndex 判断(房间列表回来后它可能已经变过)
  if (updateStatus && !shouldOpenStream(entryIndex)) {
    // 先清掉重连地址, 否则 LiveReconnector 会把这次 stop 当成断流并重连
    liveReconnector.src = '';
    await player.stop();
  }
}

// 关注/取消关注主播(/live/api/shop/collectLive, 参数 member_id = 主播会员id)
// * 接口是切换语义: 未关注调一次变已关注, 再调一次取消
// * 主播会员id 取不到(接口没下发)时不发请求, 只提示, 避免点了没反应还报脏数据
Future<void> _onFollowTap(int index, Map<String, dynamic> item) async {
  if (!AuthStore.to.isLogin) {
    Get.toNamed('/login');
    return;
  }
  final String memberId = '${item['anchor_member_id'] ?? ''}'.trim();
  if (memberId.isEmpty) {
    MyDialog.toast('未获取到主播信息');
    return;
  }
  final bool before = item['isFollow'] == true;
  final Map<String, dynamic> res = await LiveApi.collectLive(memberId: memberId);
  if (!mounted) return;
  if (res['ok'] != true) {
    MyDialog.toast('${res['message']}');
    return;
  }
  // 服务端没下发关注状态就按"原来取反"处理
  final dynamic followed = res['followed'];
  final bool after = followed is bool ? followed : !before;
  setState(() {
    item['isFollow'] = after;
  });
  MyDialog.toast(after ? '关注成功' : '已取消关注');
}

// 开播时间(转成"开播时刻"), 接口 start_time 有两种含义:
// * getRoomInfo: 距开播的剩余秒数(如 13044 = 3小时37分后开播)
// * roomPage 列表: 绝对时间文本(如 "2026-09-22 10:57:53"), 也可能是秒级/毫秒级时间戳
// * 区分方法: 数字小于 1e8(约 115 天) 按剩余秒数, 否则按绝对时间戳
DateTime? _parseStartTime(Map<String, dynamic>? room) {
  if (room == null) return null;
  final dynamic raw = room['start_time'] ?? room['startTime'];
  if (raw == null) return null;
  DateTime? fromSeconds(int seconds) {
    if (seconds <= 0) return null;
    // 剩余秒数: 以当前时间为基准往后推(每次解析都按当下算, 接口回来即可用)
    if (seconds < 100000000) return DateTime.now().add(Duration(seconds: seconds));
    // 绝对时间戳: 毫秒级(1.7e12)直接用, 秒级(1.7e9)乘 1000
    return DateTime.fromMillisecondsSinceEpoch(seconds > 1000000000000 ? seconds : seconds * 1000);
  }
  if (raw is num) return fromSeconds(raw.toInt());
  final String text = '$raw'.trim();
  if (text.isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed;
  final int? ts = int.tryParse(text);
  return ts == null ? null : fromSeconds(ts);
}

// 预告片(getRoomInfo 的 pre_video): 静音循环播放, 开播时会被直播流顶掉
Future<void> _openPreviewVideo() async {
  if (preVideo.isEmpty) return;
  await player.setVolume(0.0);
  await _openStream(preVideo);
}

// 开播倒计时: 每秒刷新, 归零后再查一次房间状态(已开播就起播)
void _startCountdown() {
  countdownTimer?.cancel();
  countdownTimer = null;
  if (liveStartTime == null || startChecked) return;
  void tick() {
    final DateTime? start = liveStartTime;
    if (start == null) return;
    final Duration left = start.difference(DateTime.now());
    countdownNotifier.value = left.isNegative ? Duration.zero : left;
    if (countdownNotifier.value != Duration.zero) return;
    countdownTimer?.cancel();
    countdownTimer = null;
    startChecked = true;
    unawaited(_refreshAfterStart());
  }
  tick();
  countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
}

// 倒计时归零: 重新查房间详情, 已开播(status=1)就直接起播
Future<void> _refreshAfterStart() async {
  if (!mounted) return;
  final String sn = roomSn.isNotEmpty ? roomSn : currentSn;
  if (sn.isEmpty) return;
  await _loadRoomDetail(sn);
  if (!mounted || liveStatus != 1) return;
  await _openEntryStream();
}

// 倒计时文案: 超过一天带天数; 接口没给开播时间时提示待定
String get countdownText {
  if (liveStartTime == null) return '开播时间待定';
  final Duration d = countdownNotifier.value;
  if (d == Duration.zero) return '即将开播';
  String two(int v) => v.toString().padLeft(2, '0');
  final String hms = '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  return d.inDays > 0 ? '${d.inDays}天 $hms' : hms;
}

// 预约直播: 成功后按钮置灰(已预约)
// * [sn] 预告卡片那条数据的 sn(与 H5 item.sn 一致), 不传则回退当前房间 sn
Future<void> _onSubscribeTap([String? sn]) async {
  debugPrint('[live]预约直播点击: subscribed=$subscribed subscribing=$subscribing sn=${sn ?? ''} roomSn=$roomSn');
  if (subscribing || subscribed) return;
  final String no = '${sn ?? ''}'.trim().isNotEmpty ? '${sn!}'.trim() : (roomSn.isNotEmpty ? roomSn : currentSn);
  if (no.isEmpty) {
    _toast('房间信息还在加载');
    return;
  }
  debugPrint('[live]预约直播 no=$no');
  setState(() => subscribing = true);
  final bool ok = await LiveApi.subscribeRoom(no);
  debugPrint('[live]预约直播结果 ok=$ok');
  if (!mounted) return;
  setState(() {
    subscribing = false;
    if (ok) subscribed = true;
  });
  // 成功只改按钮状态(置灰 + 文案变"已预约"), 不弹提示; 只有失败才提示
  if (!ok) _toast('预约失败，请稍后再试');
}

// 带货商品(onlineGoods, 底部购物弹窗用): 单独请求, 不阻塞起播; 拿不到则保持空列表, 弹窗回落本地演示数据
Future<void> _loadOnlineGoods(String sn) async {
  final List<Map<String, dynamic>> goods = await LiveApi.onlineGoods(sn);
  // 同上: 会话号变了说明这是上一个房间的商品, 不能带进新房间的购物弹窗
  if (!mounted || session != liveSession || goods.isEmpty) return;
  setState(() {
    onlineGoods = goods;
  });
}

// 换流统一走这里: 记下换流前的进度, 之后进度回退/起步才算新流在出帧(见 streamTicking)
// * 播放器是复用的, 换过去之后不会立刻换纹理, 不等新流出帧就显示会露出上一个房间的画面
Future<void> _openStream(String src) async {
  streamBasePos = player.state.position;
  streamTicking = false;
  videoShowWaits = 0;
  await liveReconnector.open(src);
}

// 起播当前房间: 进入的房间用 getPullUrl 拿到的地址, 其余用列表里同步好的 push_link
Future<void> _openEntryStream() async {
  final int index = liveIndexNotifier.value;
  String liveSrc = index == entryIndex ? pullUrl : '${_roomItem(index)['src'] ?? ''}'.trim();
  if (liveSrc.isEmpty) liveSrc = '${roomInfo?['push_link'] ?? ''}'.trim();
  if (liveSrc.isEmpty) liveSrc = '${arguments['src'] ?? ''}'.trim();
  if (kDebugMode) debugPrint('[live]详情页起播地址: index=$index sn=$roomSn src=$liveSrc');
  // 拿不到拉流地址就不起播(由封面 + 状态提示兜底), 不再回落到演示地址
  if (liveSrc.isEmpty) return;
  // 预告片是静音播的, 起直播流时恢复音量
  await player.setVolume(100.0);
  // 起播前预置 Surface 尺寸(按当前房间的横竖屏): 避免出帧后重建 Surface 打断 RTMP 触发重连
  await _presetSurfaceFor(index);
  if (!mounted) return;
  await _openStream(liveSrc);
}

// 重连时回调: 接下来画面会空一段时间, 把封面露出来(否则这几秒就是一整片黑屏)
void _onReconnecting() {
  if (!mounted) return;
  _videoStableTimer?.cancel();
  _videoStableTimer = null;
  firstFrameNotifier.value = false;
}

// 画面出现后再稳一会儿才显示
// * 起播第一轮画面常刚出来就被 Surface 重建打断(videoParams 变回 null、画面黑掉),
//   一有帧就显示, 观感是"封面 -> 画面一闪 -> 黑屏 -> 再出画面"; 稳住 700ms 再显示,
//   观感就是干净的"封面 -> 画面"
// * 这 700ms 里画面又没了(被打断/重连)就不显示, 等下一轮重新计时
// * 代价: 出画面比"一有帧就显示"晚 0.7s, 换来的是中间不闪
void _scheduleVideoShow(String from) {
  // 会话号变了 = 已经进了新房间: 这个定时器属于上一个房间, 不能再碰全局的首帧信号
  // * 旧页面的 dispose 要等路由动画结束, 这期间它收到新房间的 width 事件会把画面提前放出来,
  //   那时新房间的帧还没上屏 —— 露出来的就是残留画面(观感: 第一帧是上一个房间)
  if (!mounted || session != liveSession) return;
  _videoStableTimer?.cancel();
  // 稳定时长 400ms(原 700ms): Surface 预设命中后不会再重建, 画面不会被 seek 打断,
  // 不需要留原来的余量; 省下的 300ms 直接体现在"进房多久出画面"上
  if (kDebugMode) debugPrint('[live]画面出现($from), 稳住 400ms 再显示');
  _videoStableTimer = Timer(const Duration(milliseconds: 400), () {
    _videoStableTimer = null;
    // 同上: 排队这 400ms 期间可能已经进了新房间, 这时不能再改全局首帧信号
    if (!mounted || session != liveSession) return;
    if ((player.state.width ?? 0) <= 0) return;
    // 还在缓冲就再等一轮: 缓冲中画面随时会空掉, 这时候显示就是"画面一闪又黑回去"
    // 新流的进度还没走起来同理: 这会儿纹理里还是上一个房间的最后一帧
    // * 兜底: 最多等 6 轮(约 2.4s), 超了就按现状显示, 免得一直停在封面
    if ((player.state.buffering || !streamTicking) && videoShowWaits < 6) {
      videoShowWaits++;
      final String why = player.state.buffering ? '仍在缓冲' : '新流进度未走';
      if (kDebugMode) debugPrint('[live]画面待显示($from): $why, 第 $videoShowWaits 轮继续等');
      _scheduleVideoShow(from);
      return;
    }
    if (!firstFrameNotifier.value) firstFrameNotifier.value = true;
  });
}

// 排障用(仅 debug): 进房后的起播诊断, 区分"没起播 / 起了没解码 / 解码了没渲染"
// * 播放器层: playing / buffering / 视频尺寸(有没有解码出画面) / 播放错误
// * 输出层:   textureId / rect(纹理有没有交给 Flutter)
// * UI 层:    当前房间/状态/应不该起播/画面有没有显示出来
// * 打印 8 次(约 16s)后自动停, 覆盖一次起播 + 一次自动重连的完整过程
void _startEntryDiag() {
  _diagSubs.add(player.stream.error.listen((String error) => debugPrint('[live]播放错误: $error')));
  _diagSubs.add(player.stream.playing.listen((bool playing) => debugPrint('[live]playing=$playing')));
  _diagSubs.add(player.stream.buffering.listen((bool buffering) => debugPrint('[live]buffering=$buffering')));
  _diagSubs.add(player.stream.width.listen((int? width) =>
      debugPrint('[live]视频尺寸: ${width ?? 0}x${player.state.height ?? 0}')));
  _diagSubs.add(player.stream.videoParams.listen((VideoParams params) =>
      debugPrint('[live]videoParams: ${params.dw}x${params.dh} rotate=${params.rotate}')));
  _diagSubs.add(player.stream.log.listen((PlayerLog log) {
    final String line = '${log.prefix}: ${log.text}';
    final String lower = line.toLowerCase();
    if (lower.contains('error') || lower.contains('fail') || lower.contains('rtmp') ||
        lower.contains('vo:') || lower.contains('gpu')) {
      debugPrint('[live][mpv] $line');
    }
  }));
  _diagTimer?.cancel();
  int tick = 0;
  _diagTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
    tick += 1;
    if (!mounted) {
      timer.cancel();
      return;
    }
    final int index = liveIndexNotifier.value;
    debugPrint('[live]进房巡检$tick'
        ' sn=$roomSn index=$index/$entryIndex 状态=${index < roomList.length ? '${roomList[index]['status']}' : '-'}'
        ' 应起播=${shouldOpenStream(index)}'
        ' | 播放器: playing=${player.state.playing} buffering=${player.state.buffering}'
        ' 尺寸=${player.state.width}x${player.state.height}'
        ' | 输出: textureId=${liveVideoController.id.value} rect=${liveVideoController.rect.value}'
        ' | UI: 显示画面=${firstFrameNotifier.value}');
    if (tick >= 8) {
      timer.cancel();
      _diagTimer = null;
    }
  });
}

// 起播前把 Surface 尺寸设成视频实际尺寸
// * 命中时出帧后那次 SetSurfaceSize 会被跳过: Surface 不重建 -> 不触发 seek -> RTMP 不断 -> 不用重连
//   也就没有"画面出来又被打断"那一段黑屏(见 presetLiveSurfaceSize)
// * 不是"只跑一次": 目标是"尺寸对得上"。首次(还没实测过)用 1080p 兜底试; 之后每出现一个
//   新的实测尺寸就重设一次(切到分辨率不同的房间), 尺寸没变则复用已完成的 Future(不耗时)
// * [maxTries] 探测上限: 尺寸猜错时会跑满才放弃, 切房不能白等, 传小一点
Future<void> _presetSurfaceOnce({int maxTries = 10, int? width, int? height}) {
  final int w = width ?? lastLiveVideoWidth ?? 1920;
  final int h = height ?? lastLiveVideoHeight ?? 1080;
  final Future<void>? cached = _presetFuture;
  if (cached != null && _presetWidth == w && _presetHeight == h) return cached;
  _presetWidth = w;
  _presetHeight = h;
  return _presetFuture =
      presetLiveSurfaceSize(player, liveVideoController, maxTries: maxTries, width: w, height: h);
}

// 该房间是不是横屏(列表里的 type 优先, 列表还没回来时用进房预判的 isHorizontal)
bool _isHorizontalRoomAt(int index) {
  if (index >= 0 && index < roomList.length) {
    final String type = '${roomList[index]['type'] ?? ''}'.trim();
    if (type.isNotEmpty) return type == 'horizontal';
  }
  return isHorizontal;
}

// 按当前房间的横竖屏预设 Surface 尺寸(起播前调用)
// * 尺寸取"同横竖屏上次实测的值", 没实测过才用常规比例兜底(见 presetWidthOf)
// * 不能沿用"上一条流的实测尺寸": 换到横竖屏不同的房间时它必然对不上,
//   出帧那次 SetSurfaceSize 会重建 Surface -> seek 打断 RTMP -> 白重连一次(进房黑 4~5 秒)
Future<void> _presetSurfaceFor(int index, {int maxTries = 10}) {
  final bool landscape = _isHorizontalRoomAt(index);
  return _presetSurfaceOnce(
    maxTries: maxTries,
    width: presetWidthOf(landscape),
    height: presetHeightOf(landscape),
  );
}

// 重连前重新获取拉流地址: m3u8 带 auth_key 时效, 过期后必须换新地址才连得上
// * 拿到新地址时同步覆盖 pullUrl(界面复用), 拿不到返回空串由 LiveReconnector 沿用旧地址
Future<String> _refreshPullUrl() async {
  // 重连取的是当前房间的地址(切房后 roomSn 已跟着变)
  final String sn = roomSn;
  if (sn.isEmpty) return '';
  final String url = await LiveApi.pullUrl(sn);
  if (url.isEmpty || !mounted) return url;
  setState(() {
    pullUrl = url;
  });
  return url;
}

// 上下滑动切房: 换房间号 -> 清掉上一个房间的实时数据 -> 取该房间详情/拉流地址/带货商品 -> 起播并重进 socket
Future<void> _switchRoom(int index) async {
  // 跳页但房间没变(进房后列表回来再 jumpToPage 到进入的房间就是这种): 画面/数据都不用重置
  // * 原来先 setState 把 firstFrameNotifier 置 false 再 return, 已经播出来的画面会被封面
  //   重新盖住, 等下一轮才再露出来 —— 观感就是"画面刚出来又闪一下"
  if (index >= 0 && index < roomList.length) {
    final String pageSn = '${_roomItem(index)['sn'] ?? ''}'.trim();
    if (pageSn.isEmpty || pageSn == currentSn) {
      if (liveIndexNotifier.value != index) {
        setState(() {
          liveIndexNotifier.value = index;
        });
      }
      return;
    }
  }
  setState(() {
    liveIndexNotifier.value = index;
    positionNotifier.value = Duration.zero;
    // 切房: 等新流解码出首帧再显示画面, 期间继续显示封面
    // * 顺带撤掉上一个房间待显示的计时, 否则它会在新流还没出帧时就把画面露出来(露出的是黑底)
    _videoStableTimer?.cancel();
    _videoStableTimer = null;
    firstFrameNotifier.value = false;
    // 预告片/倒计时是上一个房间的, 新房间详情回来后重新取
    preVideo = '';
    liveStartTime = null;
    startChecked = false;
    countdownTimer?.cancel();
    subscribed = false;
    // 上一个房间的实时数据不带过来: 弹幕/活动/进场/在线人数/点赞/讲解中商品
    danmuMessages.value = const <Map<String, dynamic>>[];
    danmuIds.clear();
    activityList.value = const <Map<String, dynamic>>[];
    joinMessages.value = const <Map<String, dynamic>>[];
    roomOnline = 0;
    roomZan = 0;
    localZanExtra = 0;
    msgGoods = null;
    // 带货商品: 先清空, 新房间的接口回来再填(商品是后台请求, 不能把上一个房间的带过来)
    onlineGoods = <Map<String, dynamic>>[];
  });
  // 滑到倒数第二条时预加载下一页
  if (roomListHasMore && index >= roomList.length - 2) _loadRoomList(loadMore: true);
  if (index < 0 || index >= roomList.length) return;
  final String sn = '${_roomItem(index)['sn'] ?? ''}'.trim();
  // 同一个房间(如列表回来后的跳页)不重复起播
  if (sn.isEmpty || sn == currentSn) return;
  currentSn = sn;
  // 起播只等拉流地址: 房间详情 / 带货商品并行发出, 回来后各自刷新, 不参与等待
  final Future<String> urlFuture = LiveApi.pullUrl(sn);
  unawaited(_loadRoomDetail(sn, index: index, updateStatus: false));
  unawaited(_loadOnlineGoods(sn));
  // 换房: 断开旧连接再重连(与H5一致: 换直播间重新连一次)
  // * 只在上一条连接上补发进房消息不够: 服务端按连接注册房间, 旧连接仍绑着上一个房间
  // * 重连成功后回调 onConnected -> _sendJoinRoom, 此时 roomSn 已是新房间的房间号
  // * 不等它: 重连与拉流地址请求并行, 别让 socket 拖慢起播
  if (kDebugMode) {
    debugPrint('[live]切换到房间 $sn, 重新连接 WebSocket');
  }
  _joinWatchdog?.cancel();
  _joinTryIndex = 0;
  unawaited(liveSocket.reconnect());
  // 列表里已带 push_link 时先用它起播(与进房同理, 不等 getPullUrl 往返)
  final String listSrc = '${_roomItem(index)['src'] ?? ''}'.trim();
  final bool started = listSrc.isNotEmpty && shouldOpenStream(index);
  if (started) {
    // 起播前把 Surface 设成上一个房间实测的尺寸: 尺寸对得上时出帧那次 SetSurfaceSize 会被跳过,
    // Surface 不重建 -> 不触发 seek -> RTMP 不断 -> 不用重连(切房每次都重连一次就是缺了这一步)
    // * 先清重连地址: 改 Surface 会打断上一个房间还在播的流, 不清会被当成断流去重连旧房间
    // * 尺寸没变时预设立刻返回(复用已完成的 Future, 0 耗时); 变了才真跑, 上限 3 次(300ms),
    //   猜错就尽早起播, 交给 LiveReconnector 兜底, 别把 1s 压在起播前面
    liveReconnector.src = '';
    unawaited(_presetSurfaceFor(index, maxTries: 3).then((_) {
      if (!mounted) return;
      unawaited(_openStream(listSrc));
    }));
  }
  final String url = (await urlFuture).trim();
  if (!mounted) return;
  if (kDebugMode) debugPrint('[live]切房 getPullUrl: sn=$sn url=$url 列表src=$listSrc');
  setState(() {
    if (url.isNotEmpty && index < roomList.length) roomList[index]['src'] = url;
  });
  if (!shouldOpenStream(index)) {
    // 非直播中的房间(预告/暂停/结束): 停掉上一个房间的流, 只展示封面
    // * 先清掉重连地址, 否则 LiveReconnector 会把这次 stop 当成断流并重连旧房间
    liveReconnector.src = '';
    await player.stop();
    return;
  }
  // 列表地址已经起播了, 不再用接口地址起第二次(否则画面出来后又要重新缓冲一遍)
  if (started) return;
  String src = url;
  if (src.isEmpty) src = listSrc;
  if (src.isEmpty) return;
  // 列表没带地址的慢路径同样要预置: 走到这里说明上面的预设没跑过
  liveReconnector.src = '';
  await _presetSurfaceFor(index, maxTries: 3);
  if (!mounted) return;
  await _openStream(src);
}

// 进入直播间连接 socket(地址与H5 Config.socketUrl 一致)
// * 连接成功/重连成功都会回调 onConnected, 由 _sendJoinRoom 重新进房
// * onMessage 收到的业务消息交 _onSocketMessage 分发
void _initSocket() {
  liveSocket = LiveSocket(
    url: Config.socketUrl,
    onMessage: _onSocketMessage,
    onConnected: _sendJoinRoom,
    onReconnectFail: (int times, int maxTimes) {
      debugPrint('[live]WebSocket 重连失败($times/$maxTimes), 直播间消息已断开');
    },
  );
  liveSocket.connect();
}

// 进房报文候选: 各端服务端字段/包装方式不一致时逐个尝试
// * #0 与 H5 sendJoinRoom 一致 {type:'join', data:{room_id, token}}; #1 data 平铺; #2 enter 别名
List<Map<String, dynamic>> _joinPayloads() {
  final Map<String, dynamic> data = <String, dynamic>{
    'room_id': roomSn,
    'sn': roomSn,
    'token': Request.currentToken,
  };
  return <Map<String, dynamic>>[
    <String, dynamic>{'type': 'join', 'data': data},
    <String, dynamic>{'type': 'join', ...data},
    <String, dynamic>{'type': 'enter', 'data': data},
  ];
}

// 进房消息: (重)连成功后发送; 服务端 5s 内一条帧都不推时换下一种格式重试
// * 判定依据是 liveSocket.gotAnyFrame(任意帧都算): 有推送说明格式已被接受, 不再补发
void _sendJoinRoom() {
  if (roomSn.isEmpty) {
    debugPrint('[live]缺少房间号, 不发送进房消息');
    return;
  }
  _joinTryIndex = 0;
  _sendJoinPayload();
}

// 发送第 _joinTryIndex 种进房报文, 并挂一个 5s 看门狗决定是否换格式
void _sendJoinPayload() {
  final List<Map<String, dynamic>> payloads = _joinPayloads();
  if (_joinTryIndex >= payloads.length) {
    debugPrint('[live]进房报文已试完 ${payloads.length} 种, 服务端仍无任何推送'
        '(房间号/token 未被接受, 或服务端没为这条连接注册推送)');
    return;
  }
  liveSocket.sendRaw(payloads[_joinTryIndex]);
  if (kDebugMode) {
    debugPrint('[live]已发送进房消息(格式#${_joinTryIndex + 1}/${payloads.length}): '
        'room_id=$roomSn, token=${Request.currentToken.isEmpty ? '(空)' : '(已带上)'}');
  }
  _joinWatchdog?.cancel();
  _joinWatchdog = Timer(const Duration(seconds: 5), () {
    if (!mounted || !liveSocket.gotAnyFrame) {
      _joinTryIndex += 1;
      debugPrint('[live]进房后 5s 无任何推送, 换用进房格式 #${_joinTryIndex + 1} 重试');
      _sendJoinPayload();
    }
  });
}

// socket 业务消息分发(与H5 livepull.nvue onMessage 一致)
// * 已接入: livestart 开播(带拉流地址) / livepause 暂停 / liverestore 恢复
//   liveend 结束 / forbid 被踢出房间 / mute, unmute 禁言 / room 在线人数与本场点赞
//   msg 弹幕 / msg_sys 系统消息 / join 用户进场 / goods 讲解中商品
// * 已接入: activity 活动表(福袋/红包/签到/集章入口与倒计时) / luckybag_start 开启
//   / luckybag_join 参与成功 / luckybag_end 开奖 / hongbao_start 红包
//   / sign_start 签到 / stamp_sign 集章开始 / stamp_award 集章开奖
void _onSocketMessage(Map<String, dynamic> msg) {
  final String type = '${msg['type'] ?? ''}'.trim();
  final dynamic data = msg['data'];
  debugPrint('[live]socket 消息: $type');
  switch (type) {
    // 主播开播/重新开播: 消息里带拉流地址, 直接用它起播
    case 'livestart':
      final String url = LiveApi.pullUrlOf(data);
      if (url.isNotEmpty) {
        setState(() {
          pullUrl = url;
        });
      }
      _setLiveState(1);
      break;
    // 主播离开直播间: 暂停中
    case 'livepause':
      _setLiveState(2);
      break;
    // 主播恢复直播: 提示并回到直播中(H5 提示"主播回来了")
    case 'liverestore':
      _toast('主播回来了');
      _setLiveState(1, refresh: true);
      break;
    // 直播结束: 停流并断开连接(与H5一致)
    case 'liveend':
      _setLiveState(3);
      break;
    // 被踢出房间: 提示后关闭连接并退出直播间(与H5一致)
    case 'forbid':
      _onForbidden();
      break;
    case 'mute':
      setState(() {
        userMuted = true;
      });
      break;
    case 'unmute':
      setState(() {
        userMuted = false;
      });
      break;
    // 房间实时数据: {online: 在线人数, zan: 本场点赞}(与H5一致, 每次推送覆盖)
    case 'room':
      setState(() {
        roomOnline = _dataInt(data, 'online');
        roomZan = _dataInt(data, 'zan');
        // 服务端累计值已含本地点赞, 清掉乐观值避免重复计
        localZanExtra = 0;
      });
      break;
    // 弹幕消息: data 为消息数组(与H5 messageList 一致)
    case 'msg':
      _appendDanmu(data);
      break;
    // 系统消息: data 为 {msg}(与H5 messageSys 一致)
    case 'msg_sys':
      _setSysMessage(data);
      break;
    // 用户进场: data 为 {user:{nickname}, msg}(与H5 merber_join 一致)
    case 'join':
      _addJoinMessage(data);
      break;
    // 讲解中商品: data 为当前讲解的商品(与H5 livepull.nvue: msgGoods = msg.data 一致)
    case 'goods':
      _setTalkGoods(data);
      break;
    // 活动表: data 为活动数组 [{type, game_id, time, joinnum, info:{...}}](与H5 activity 一致)
    // * 福袋入口与倒计时都取自这里; 每次推送整表覆盖, 空数组表示活动已结束
    case 'activity':
      _setActivityList(data);
      break;
    // 福袋开启(与H5 luckybag_start 一致): 只播开启动画, 活动数据由 activity 下发, 无需额外处理
    case 'luckybag_start':
      break;
    // 福袋参与成功: data 为提示文案(与H5 luckybag_join 一致), 顺手关掉未参与弹窗
    case 'luckybag_join':
      _toast('${data ?? ''}'.trim().isEmpty ? '参与成功' : '$data');
      luckyBagCloseTick.value += 1;
      break;
    // 福袋开奖: data 为 game_id(与H5 luckybag_end 一致, 有的端给对象), 先收掉入口再查状态弹结果
    case 'luckybag_end': {
      final String gameId = data is Map
          ? '${data['game_id'] ?? data['gameId'] ?? ''}'.trim()
          : '${data ?? ''}'.trim();
      _endActivity(gameId);
      _openLuckyBag(gameId);
      break;
    }
    // 红包开启: data 为活动对象(与H5 hongbao_start 一致), 查状态后弹红包(未参与先拆包, 已参与直接出结果)
    case 'hongbao_start': {
      final Map<String, dynamic>? item = _pushedActivity(data, 'hongbao');
      _openHongbao('${item?['gameId'] ?? ''}', item: item);
      break;
    }
    // 签到开启: data 为签到活动(与H5 sign_start 一致), 查状态后弹签到弹窗
    case 'sign_start': {
      final Map<String, dynamic>? item = _pushedActivity(data, 'sign');
      _openSign('${item?['gameId'] ?? ''}', item: item);
      break;
    }
    // 集章开始: data 为集章活动(与H5 stamp_sign 一致), 直接弹「收集奖章」弹窗
    case 'stamp_sign': {
      final Map<String, dynamic>? item = _pushedActivity(data, 'stamp');
      final String gameId = '${item?['gameId'] ?? ''}'.trim();
      if (gameId.isEmpty) break;
      navigator?.push(FadeRoute(child: PopupStamp(item: item!, roomId: roomSn)));
      break;
    }
    // 集章开奖: data 为集章信息(与H5 stamp_award 一致), 直接弹信息弹窗
    case 'stamp_award':
      navigator?.push(FadeRoute(child: PopupStampInfo(item: LiveApi.stampInfoItem(data))));
      break;
    default:
      debugPrint('[live]socket 消息暂未接入: $type');
  }
}

// 讲解中商品(goods): data 为当前讲解的商品(字段命名由 LiveApi.goodsItem 多候选兼容)
// * 收到即更新讲解卡并重新展示(与H5 拿到 msgGoods 就显示一致); 解析不出内容时忽略该条消息
void _setTalkGoods(dynamic data) {
  // 排查字段用: 展示异常时先看这条日志(不同房间下发的字段名可能不一样)
  if (kDebugMode) debugPrint('[live]goods 消息原始数据: $data');
  final Map<String, dynamic>? goods = LiveApi.goodsItem(data);
  if (goods == null) {
    debugPrint('[live]goods 消息无有效商品数据');
    return;
  }
  if (!mounted) return;
  setState(() {
    msgGoods = goods;
    goodsTalkVisible = true;
  });
}

// 活动表(activity): data 为活动数组(与H5 activity 一致), 每次推送整表覆盖
// * 福袋入口/倒计时都取自这里; 空数组(活动结束)时入口随之消失
void _setActivityList(dynamic data) {
  if (kDebugMode) debugPrint('[live]activity 活动数据: $data');
  // 已开奖结束的活动不再进列表(服务端可能还把它留在整表里)
  final List<Map<String, dynamic>> list = LiveApi.activityItems(data)
      .where((Map<String, dynamic> item) => !endedActivityIds.contains('${item['gameId'] ?? ''}'.trim()))
      .toList();
  if (!mounted) return;
  activityList.value = list;
  _startActivityCountdown();
}

// 活动结束(开奖推送 luckybag_end / 详情查询拿到 end-* 状态): 登记并立即收掉左上角入口
void _endActivity(String gameId) {
  if (gameId.isEmpty) return;
  endedActivityIds.add(gameId);
  if (!mounted) return;
  final List<Map<String, dynamic>> rest = activityList.value
      .where((Map<String, dynamic> item) => '${item['gameId'] ?? ''}'.trim() != gameId)
      .toList();
  if (rest.length == activityList.value.length) return;
  activityList.value = rest;
  if (rest.isEmpty) activityTimer?.cancel();
}

// 活动倒计时: 每秒把每条活动的剩余秒数减 1(与H5 initCountdown 一致)
void _startActivityCountdown() {
  activityTimer?.cancel();
  if (activityList.value.isEmpty) return;
  activityTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
    if (!mounted || activityList.value.isEmpty) {
      timer.cancel();
      return;
    }
    activityList.value = activityList.value.map((Map<String, dynamic> item) {
      final int time = LiveApi.intOf(item['time']);
      return <String, dynamic>{...item, 'time': time > 0 ? time - 1 : 0};
    }).toList();
  });
}

// 活动入口图标: 福袋/红包/集章/签到(对应H5 bag-tip 的四种图标), 未支持的类型返回空
String _activityIcon(String type) {
  switch (type) {
    case 'luckybag':
      return 'assets/images/icon-fudai.png';
    case 'hongbao':
      return 'assets/images/icon-hb.png';
    case 'stamp':
      return 'assets/images/icon-jizhang.png';
    case 'sign':
      return 'assets/images/sign-icon.png';
  }
  return '';
}

// 活动入口: 图标 + 剩余时间(与H5 bag-tip 一致), 点击按类型弹对应弹窗
Widget _activityEntry(Map<String, dynamic> item) {
  final int time = LiveApi.intOf(item['time']);
  final String timeDown = time > 0
      ? '${'${time ~/ 60}'.padLeft(2, '0')}:${'${time % 60}'.padLeft(2, '0')}'
      : '';
  return GestureDetector(
    onTap: () => _openActivity(item),
    child: Stack(
      children: [
        Container(
          height: 36.0,
          width: 36.0,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(_activityIcon('${item['type']}'), width: 36.0,),
          ),
        ),
        if (timeDown.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 3.0,
            right: 3.0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(timeDown, style: const TextStyle(color: Colors.white, fontSize: 8.0),),
            ),
          ),
      ],
    ),
  );
}

// 福袋详情: 点入口或收到开奖推送后查状态(LiveApi.luckybagDetail), 按 type 弹对应弹窗
// * 与H5 showBagDetail 一致: ing-nojoin 未参与 / ing-join 已参与 / end-award 中奖
//   / end-noaward 未中奖 / end-nojoin 结束未参与
Future<void> _openLuckyBag(String gameId, {Map<String, dynamic>? item}) async {
  if (gameId.isEmpty) return;
  final Map<String, dynamic>? res = await LiveApi.luckybagDetail(gameId);
  if (!mounted) return;
  if (res == null) return;
  // 弹窗数据: 接口字段优先, 缺的用入口下发的快照补齐
  final Map<String, dynamic> data = <String, dynamic>{
    ...?item,
    'gameId': gameId,
    'time': LiveApi.intOf(res['time'] ?? item?['time']),
    'joinNum': LiveApi.intOf(res['joinnum'] ?? item?['joinNum']),
  };
  final String status = '${res['type'] ?? ''}'.trim();
  // 已结束(end-*): 入口不该继续留在左上角(否则点它只会走到一个不弹窗的"已结束"状态)
  if (status.startsWith('end')) _endActivity(gameId);
  final List<String> award = _luckyBagAward(res);
  switch (status) {
    case 'ing-nojoin':
      navigator?.push(FadeRoute(
        child: PopupLuckyBagJoin(
          item: data,
          closeTick: luckyBagCloseTick,
          onJoin: () => _openCommentInput(prefill: '${data['joinContent'] ?? ''}'),
        ),
      ));
      break;
    case 'ing-join':
      navigator?.push(FadeRoute(
        child: PopupLuckyBagResult(status: 'joined', item: data),
      ));
      break;
    case 'end-award':
      navigator?.push(FadeRoute(
        child: PopupLuckyBagResult(
          status: 'award',
          item: data,
          awardNum: award[0],
          awardTypeName: award[1],
          onLookWinner: () => _openWinnerList(gameId, ActivityWinnerType.luckybag),
        ),
      ));
      break;
    case 'end-noaward':
      navigator?.push(FadeRoute(
        child: PopupLuckyBagResult(
          status: 'noaward',
          item: data,
          onLookWinner: () => _openWinnerList(gameId, ActivityWinnerType.luckybag),
        ),
      ));
      break;
    default:
      // end-nojoin(结束且未参与)与未知状态都不弹空窗
      break;
  }
}

// 福袋中奖结果: award 可能是对象或数组(取第一条), 字段命名多候选
List<String> _luckyBagAward(Map<String, dynamic> data) {
  dynamic raw = data['award'] ?? data['award_info'];
  if (raw is List && raw.isNotEmpty) raw = raw.first;
  if (raw is! Map) return const <String>['', ''];
  return <String>[
    '${raw['num'] ?? raw['award_num'] ?? ''}'.trim(),
    '${raw['type_name'] ?? raw['award_typename'] ?? ''}'.trim(),
  ];
}

// 中奖名单: 福袋/红包共用一个弹窗(分页数据由弹窗内自己拉取)
void _openWinnerList(String gameId, ActivityWinnerType type) {
  if (gameId.isEmpty) return;
  navigator?.push(FadeRoute(child: PopupActivityWinner(gameId: gameId, type: type)));
}

// 主播昵称(红包封面展示"xxx的红包")
String get anchorName => anchorNameOf(roomInfo ?? const <String, dynamic>{});

// 主播头像(与 _roomItem 取值口径一致)
String get anchorAvatar => LiveApi.imageOf(roomInfo?['anchor_img']);

// 活动入口点击: 按活动类型弹对应详情弹窗(与H5 showBagDetail/showSignDetail/showStampDetail 一致)
void _openActivity(Map<String, dynamic> item) {
  final String type = '${item['type'] ?? ''}'.trim();
  final String gameId = '${item['gameId'] ?? ''}'.trim();
  if (gameId.isEmpty) return;
  switch (type) {
    case 'luckybag':
      _openLuckyBag(gameId, item: item);
      break;
    case 'hongbao':
      _openHongbao(gameId, item: item);
      break;
    case 'sign':
      _openSign(gameId, item: item);
      break;
    case 'stamp':
      _openStampInfo(gameId);
      break;
  }
}

// 红包详情: 查状态(LiveApi.hongbaoDetail) → 未参与先弹可拆的红包封面, 已参与/已结束直接出结果
// * 与H5 showBagDetail 的 hongbao 分支一致
Future<void> _openHongbao(String gameId, {Map<String, dynamic>? item}) async {
  if (gameId.isEmpty) return;
  final Map<String, dynamic>? res = await LiveApi.hongbaoDetail(gameId);
  if (!mounted) return;
  if (res == null) return;
  navigator?.push(FadeRoute(
    child: PopupHongbao(
      item: <String, dynamic>{
        'gameId': gameId,
        'title': '${res['title'] ?? item?['title'] ?? ''}'.trim(),
        'awardTypeName': '${res['award_typename'] ?? item?['awardTypeName'] ?? ''}'.trim(),
      },
      avatar: anchorAvatar,
      nickname: anchorName,
      // 未参与: 等用户点「开」; 其余状态打开即拆(与H5 一致)
      autoOpen: '${res['type'] ?? ''}'.trim() != 'ing-nojoin',
      onLookWinner: () => _openWinnerList(gameId, ActivityWinnerType.hongbao),
    ),
  ));
}

// 签到详情: 查状态(LiveApi.signDetail) → 弹签到弹窗(与H5 showSignDetail 一致)
Future<void> _openSign(String gameId, {Map<String, dynamic>? item}) async {
  if (gameId.isEmpty) return;
  final Map<String, dynamic>? res = await LiveApi.signDetail(gameId);
  if (!mounted) return;
  if (res == null) return;
  navigator?.push(FadeRoute(
    child: PopupSign(
      item: <String, dynamic>{
        'gameId': '${res['game_id'] ?? gameId}',
        'status': '${res['type'] ?? ''}'.trim(),
        'title': '${res['title'] ?? item?['title'] ?? ''}'.trim(),
        'notice': '${res['notice'] ?? item?['notice'] ?? ''}'.trim(),
        'time': LiveApi.intOf(res['time'] ?? item?['time']),
      },
    ),
  ));
}

// 集章信息: 查接口(LiveApi.stampDetail) → 弹集章信息弹窗(与H5 showStampDetail 一致)
Future<void> _openStampInfo(String gameId) async {
  if (gameId.isEmpty) return;
  final Map<String, dynamic>? res = await LiveApi.stampDetail(gameId);
  if (!mounted) return;
  if (res == null) return;
  navigator?.push(FadeRoute(child: PopupStampInfo(item: LiveApi.stampInfoItem(res))));
}

// socket 推送的单条活动(hongbao_start/sign_start/stamp_sign): 有的端 type 是活动类型,
// 有的端是活动状态, 这里强制按 [type] 归一化, 再走各活动自己的详情查询
Map<String, dynamic>? _pushedActivity(dynamic data, String type) {
  if (data is! Map) return null;
  return LiveApi.activityItem(<String, dynamic>{...data.cast<String, dynamic>(), 'type': type});
}

// 弹幕消息(msg): data 为消息数组 [{mid, user:{nickname, member_level, chatrole}, msg}](与H5 messageList 一致)
// * 与H5 f-danmu.handleMessageArray 一致: 缺 user/msg 的条目丢弃
// * mid 去重(服务端重推不重复展示); 队列上限 50 条, 超出移除最早的
void _appendDanmu(dynamic data) {
  List<dynamic> list = const <dynamic>[];
  if (data is List) {
    list = data;
  } else if (data is Map) {
    final dynamic inner = data['list'] ?? data['data'] ?? data['messages'];
    if (inner is List) {
      list = inner;
    } else if (data['msg'] != null || data['content'] != null) {
      // 兜底: 有的房间一次只推一条消息对象(不是数组)
      list = <dynamic>[data];
    }
  }
  if (list.isEmpty) return;
  final List<Map<String, dynamic>> items = danmuMessages.value.toList();
  bool changed = false;
  for (final dynamic raw in list) {
    if (raw is! Map) continue;
    final dynamic user = raw['user'];
    final String content = '${raw['msg'] ?? raw['content'] ?? ''}'.trim();
    if (user is! Map || content.isEmpty) continue;
    final String nickname = '${user['nickname'] ?? user['name'] ?? ''}'.trim();
    final String mid = '${raw['mid'] ?? raw['id'] ?? ''}'.trim();
    // 有 mid 用 mid 去重, 没有就用"昵称+内容"兜底
    final String id = mid.isEmpty ? '$nickname:$content' : 'id$mid';
    if (!danmuIds.add(id)) continue;
    items.add(<String, dynamic>{
      'id': id,
      'type': 'chat',
      'user': nickname.isEmpty ? '未知用户' : nickname,
      'content': content,
      // 主播身份(socket chatrole): 复用弹幕条目原有的角色标签字段, 不新增UI
      'tag': '${user['chatrole'] ?? ''}'.trim() == 'streamer' ? '主播' : null,
    });
    changed = true;
  }
  // 超出队列上限时移除最早的, 同时释放其去重标记
  while (items.length > 50) {
    danmuIds.remove('${items.removeAt(0)['id']}');
  }
  if (changed) danmuMessages.value = items;
}

// 系统消息(msg_sys): data 为 {msg}(与H5 messageSys 一致)
// * 不改弹幕区排版: 转成公告条目并入弹幕队列(沿用公告样式), 空文本/重复内容不重复入队
void _setSysMessage(dynamic data) {
  final bool explicit = data is Map && data.containsKey('msg');
  final String text = data is Map ? '${data['msg'] ?? ''}'.trim() : '${data ?? ''}'.trim();
  if (!explicit && text.isEmpty) return;
  if (text == sysMessage) return;
  sysMessage = text;
  if (text.isEmpty) return;
  final List<Map<String, dynamic>> items = danmuMessages.value.toList();
  items.add(<String, dynamic>{
    'id': 'sys${DateTime.now().microsecondsSinceEpoch}',
    'type': 'notice',
    'content': text,
  });
  while (items.length > 50) {
    danmuIds.remove('${items.removeAt(0)['id']}');
  }
  danmuMessages.value = items;
}

// 用户进场(join): data 为 {user:{nickname}, msg}(与H5 merber_join 一致)
// * 追加进进场队列, 由 AnimationLiveJoin 按顺序滑入播放(并行进入时排队, 不叠加)
void _addJoinMessage(dynamic data) {
  if (data is! Map) return;
  final dynamic user = data['user'];
  final String name = user is Map ? '${user['nickname'] ?? user['name'] ?? ''}'.trim() : '';
  final String text = '${data['msg'] ?? ''}'.trim();
  if (name.isEmpty && text.isEmpty) return;
  final Map<String, dynamic> item = <String, dynamic>{
    'name': name.isEmpty ? '观众' : name,
    'msg': text,
  };
  joinMessages.value = <Map<String, dynamic>>[...joinMessages.value, item];
}

// 从接口/socket 数据中取整型字段: data 可能是 Map(带 key) 或数字本身
int _dataInt(dynamic data, String key) {
  if (data is Map) {
    final dynamic value = data[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
  if (data is num) return data.toInt();
  return int.tryParse('$data') ?? 0;
}

// 讲解中商品的展示数据: socket goods 消息优先
// * 输出: image(商品图/回落房间封面) / title(标题) / price(价格) / saleNum(热卖数, 字段 hot 已由 LiveApi.goodsItem 兼容)
// * demo(本地演示房间)才回落房间演示数据/写死价格; 真实直播间字段全部来自 socket, 取不到留空(不展示)
Map<String, dynamic> _talkGoodsItem(Map<String, dynamic> item, {bool demo = true}) {
  final Map<String, dynamic> goods = msgGoods ?? const <String, dynamic>{};
  String pick(String key, String fallback) {
    final String val = '${goods[key] ?? ''}'.trim();
    return val.isEmpty ? fallback : val;
  }

  return <String, dynamic>{
    // 商品id(点讲解卡跳详情用): 商城商品id goods_id 优先, 没有再回退 id
    // * 原来这里没往外带 id, 讲解卡点了跳不过去
    'goods_id': pick('goods_id', ''),
    'id': pick('id', ''),
    'image': pick('image', demo ? '${item['poster'] ?? ''}' : ''),
    'title': pick('title', demo ? '${item['desc'] ?? ''}' : ''),
    'price': pick('price', demo ? '520' : ''),
    'saleNum': pick('saleNum', demo ? '${item['saleNum'] ?? item['hot'] ?? ''}' : ''),
  };
}

// 本场点赞文案: socket room 消息下发真实数量(与H5 zanNum 一致)
// * 进入的真实房间以 socket 数据为准, 未下发时按 0 展示(与H5 初始值一致)
// * 其余本地演示房间沿用本地数据
String _zanText(int index, dynamic item) {
  // 点赞数由 socket room 消息下发: 未进房的房间还没有推送, 按 0 展示(列表数据里没有演示点赞数)
  if (index != entryIndex) return '0本场点赞';
  final int zan = roomZan + localZanExtra;
  return '$zan本场点赞';
}

// 直播状态变更: 0 预告 / 1 直播中 / 2 暂停中 / 3 已结束
// * 1 重新起播(地址可能已变), 2 暂停播放, 3 停流并断开 socket
Future<void> _setLiveState(int status, {bool refresh = false}) async {
  if (!mounted || liveStatus == status) return;
  // 状态变更属于当前停留的房间(切房后跟着当前房间, 不一定是进入的那个)
  final int index = liveIndexNotifier.value;
  setState(() {
    liveStatus = status;
    if (index < roomList.length) roomList[index]['status'] = status;
  });
  if (status == 1) {
    if (refresh) await _refreshPullUrl();
    if (!mounted || !shouldOpenStream(index)) return;
    await _openEntryStream();
    return;
  }
  if (status == 2) {
    await player.pause();
    return;
  }
  // 直播已结束: 先清掉重连地址再停流
  // * 否则 LiveReconnector 会把这次 stop 当成"流断了", 对已经结束的房间反复重连(最多 3 次)
  liveReconnector.src = '';
  await player.stop();
  _joinWatchdog?.cancel();
  await liveSocket.close();
}

// 离开直播间: 停流 + 断 socket + 停所有定时器(右上关闭 / 被踢 / 页面销毁 都走这里)
// * 顺序很关键: 必须先把重连地址清掉再 stop —— LiveReconnector 靠 src 判断是否要重连,
//   直接 stop 会被当成断流, 退出后还会再起播一次(对已停的流/已销毁的 player 调 open)
// * 定时器先撤: 进房看门狗 / 活动倒计时 / 开播倒计时 / 首帧稳定计时, 否则退栈后仍会回调
Future<void> _leaveRoom() async {
  _joinWatchdog?.cancel();
  activityTimer?.cancel();
  countdownTimer?.cancel();
  _videoStableTimer?.cancel();
  _videoStableTimer = null;
  liveReconnector.src = '';
  await player.stop();
  await liveSocket.close();
}

// 右上角关闭: 停干净再退栈(清理由 _leaveRoom 完成, dispose 再跑一遍是幂等的)
Future<void> _onCloseTap() async {
  await _leaveRoom();
  if (!mounted) return;
  Get.back();
}

// 被踢出房间: 关闭连接并退出直播间
Future<void> _onForbidden() async {
  _toast('你已被踢出房间');
  await _leaveRoom();
  if (!mounted) return;
  // 只有当前还停留在直播间时才退栈(避免误退其它页面)
  if (Get.currentRoute == '/live') Get.back();
}

// 轻提示(直播页为全屏黑底, 统一用底部snackbar)
void _toast(String message) {
  if (!mounted) return;
  Get.snackbar('提示', message, snackPosition: SnackPosition.BOTTOM);
}

// 发送弹幕评论: {type:'chat', data:{msg}}(与H5 submitSendMsg 一致)
void _sendComment(String content) {
  final String text = content.trim();
  if (text.isEmpty) return;
  if (userMuted) {
    _toast('你已被禁言');
    return;
  }
  liveSocket.send('chat', <String, dynamic>{'msg': text});
}

// 点击屏幕点赞: 点击位置飘心 + 上行(与H5 handleScreenTap -> createLikeEffect + sendTapLike 一致)
void _onScreenLike(Offset position) {
  // 非直播中不点赞(与H5 handleScreenTap 的 liveState 判断一致)
  if (liveStatus != 1 && liveStatus != 2) return;
  _addLikeHeart(position);
  _sendZan();
}

// 底部爱心按钮点赞: 从按钮位置飘心(按钮在右下角工具栏)
void _onLikeButtonTap() {
  if (liveStatus != 1 && liveStatus != 2) return;
  final Size screen = MediaQuery.of(context).size;
  final EdgeInsets safe = MediaQuery.of(context).padding;
  _addLikeHeart(Offset(screen.width - 105.0, screen.height - safe.bottom - 40.0));
  _sendZan();
}

// 点赞上行: {type:'zan', data:1}(与H5 changeLick 一致); 120ms 内连点只飘心不重复上行
void _sendZan() {
  final int now = DateTime.now().millisecondsSinceEpoch;
  if (now - lastZanAt >= 120) {
    lastZanAt = now;
    liveSocket.send('zan', 1);
  }
  // 真实直播间本场点赞乐观 +1(room 推送后清零校正); 本地演示房间展示"万"数据, 不累加
  if (!mounted || roomSn.isEmpty) return;
  setState(() {
    localZanExtra += 1;
  });
}

// 生成一颗飘心: 位置/大小/时长/缩放/旋转/路径/颜色随机(参数对齐H5 createLikeEffect)
void _addLikeHeart(Offset position) {
  final Size screen = MediaQuery.of(context).size;
  final double rpx = screen.width / 750.0; // rpx -> 逻辑像素(H5 以 750rpx 为满宽)
  final double size = (42.0 + likeRandom.nextInt(10)) * rpx;
  // 4 条飘动路径(与H5 likeFloat1~4 关键帧对应): 终点水平/垂直位移(rpx)
  const List<List<double>> paths = <List<double>>[
    <double>[-70.0, -260.0],
    <double>[72.0, -280.0],
    <double>[26.0, -300.0],
    <double>[-22.0, -290.0],
  ];
  final List<double> path = paths[likeRandom.nextInt(paths.length)];
  // 6 种飘心颜色(对齐H5 6 张彩心图 bg1~bg6)
  const List<Color> colors = <Color>[
    Color(0xFFFF2C55),
    Color(0xFFFF5A79),
    Color(0xFFFF7A9C),
    Color(0xFFFFB020),
    Color(0xFFFF4D6D),
    Color(0xFFB06CFF),
  ];
  final double left = (position.dx - size / 2 + likeRandom.nextInt(21) - 10)
      .clamp(0.0, max(0.0, screen.width - size));
  // 心的底部落在点击点上方 40rpx(与H5 bottom 计算一致)
  final double top = (position.dy - 40.0 * rpx - size).clamp(0.0, screen.height);
  final LikeHeart heart = LikeHeart(
    id: likeSeed++,
    x: left,
    y: top,
    size: size,
    duration: Duration(milliseconds: 900 + likeRandom.nextInt(280)),
    scale: 0.9 + likeRandom.nextDouble() * 0.35,
    rotate: (likeRandom.nextInt(40) - 20) * pi / 180,
    dx: path[0] * rpx,
    dy: path[1] * rpx,
    color: colors[likeRandom.nextInt(colors.length)],
  );
  if (!mounted) return;
  likeHearts.value = <LikeHeart>[...likeHearts.value, heart];
}

// 飘心动画结束: 从队列移除(对应H5 likeTimerMap 定时清理)
void _removeLikeHeart(int id) {
  if (!mounted) return;
  likeHearts.value = likeHearts.value.where((LikeHeart heart) => heart.id != id).toList();
}

// 打开评论输入框: 禁言时不弹输入框(与H5 sendLiveMsg 一致)
// * [prefill] 预填内容(如福袋参与口令, 用户直接发送即可参与)
void _openCommentInput({String prefill = ''}) {
  if (userMuted) {
    _toast('你已被禁言');
    return;
  }
  navigator?.push(FadeRoute(
    child: PopupComment(
      prefill: prefill,
      onChanged: (value) => _sendComment('$value'),
    ),
  ));
}

// 该房间是否需要拉起直播流: 进入的房间非直播中(预告/暂停/结束)时不拉流, 只展示封面
// 该房间是否需要拉起直播流: 非直播中(0 预告 / 2 暂停 / 3 已结束)只展示封面
// * 进入的房间状态由 getRoomInfo / socket 维护(liveStatus), 其余房间用列表里的 status
bool shouldOpenStream(int index) {
  if (index == entryIndex) return liveStatus == 1;
  return LiveApi.statusOf(_roomItem(index)) == 1;
}

// 非直播中的状态提示文案(status 枚举: 0 预告 / 1 直播中 / 2 暂停 / 3 已结束)
String get liveStatusHint {
  switch (liveStatus) {
    case 0:
      return '敬请期待开播';
    case 2:
      return '主播暂时离开，稍后回来';
    case 3:
      return '本场直播已结束';
    default:
      return '';
  }
}

// 房间展示数据: 直接取 roomPage 列表里的那条(接口数据, 见 _roomFromApi)
// * 列表还没回来 / 索引越界时用首页入参兜一条, 避免首帧取不到房间数据
// * 进入的房间已由 _loadRoomInfo 把 getRoomInfo 详情合并进列表(_mergeRoomDetail)
Map<String, dynamic> _roomItem(int index) {
  if (index < 0 || index >= roomList.length) return _roomFromArguments();
  return roomList[index];
}

// 是否本地演示房间: 上下滑动的房间全部来自 roomPage 接口, 没有演示房间(恒 false)
// * 保留这个方法是为了需要回退到本地演示数据时只改这里, 渲染层不用动
bool _isDemoRoom(int index) => false;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
  // 离开直播间恢复系统息屏策略(不还原的话回到其它页面也一直亮着, 白耗电)
  WakelockPlus.disable();
  // 解除首页直播预览的挂起: 回首页后按卡片可见性自动恢复播放
  livePreviewSuspended.value = false;
  // 离开直播间断开 socket(与H5 onUnload/onBackPress 一致)
  _joinWatchdog?.cancel();
  // 活动倒计时: 离开直播间一并停掉
  activityTimer?.cancel();
  // 开播倒计时(预告房间)
  countdownTimer?.cancel();
  _videoStableTimer?.cancel();
  _videoStableTimer = null;
  // 播放器流订阅: 显式取消(进度回调还挂着全局 notifier, 只靠 player.dispose 关流不够干净)
  _positionSubscription?.cancel();
  _positionSubscription = null;
  _widthSubscription?.cancel();
  _widthSubscription = null;
  // 清掉重连地址: 物理返回键/侧滑返回不经过右上关闭, 也要防住"退出后还重连一次"
  // * 重连回调是 async, 取消订阅拦不住已经在 await 中的那一次, 只能靠 src 为空拦
  liveReconnector.src = '';
  liveSocket.close();
  likeHearts.dispose();
  danmuMessages.dispose();
  joinMessages.dispose();
  activityList.dispose();
  endedActivityIds.clear();
  liveReconnector.dispose();
  // 播放器不随页面销毁: 复用文件顶部的单例(见 livePlayer 的说明), 这里只停流
  // * 以前是 player.dispose(): 异步释放没走完, 新页面已经又建了一个播放器, 两台抢硬解码器,
  //   新那路起不来 -> 关闭后再从列表进直播间只有封面没有画面
  // * 会话号变了 = 期间又进了新房间(B), 播放器已经归 B 用了: 再 stop 会把 B 刚起的流停掉
  if (liveSession == session) unawaited(player.stop());
  // 排障订阅/巡检: 随页面一起取消(否则多次进房会重复监听, 日志翻倍)
  for (final StreamSubscription<dynamic> sub in _diagSubs) {
    sub.cancel();
  }
  _diagSubs.clear();
  _diagTimer?.cancel();
  _diagTimer = null;
  pageVerticalController.dispose();
  pageHorizontalController.dispose();
  super.dispose();
}

// 直播预告卡片(status=0): 封面图 + 开播倒计时 + 预约直播按钮
// * 预告没有流可播, 画面就是封面; 卡片浮在封面之上, 倒计时到点会自动复查是否已开播
Widget _previewCard(Map<String, dynamic> item) {
  final String poster = '${item['poster'] ?? ''}'.trim();
  // 卡片里只显示直播间标题(name): 主播信息(头像+名字)直播间左上角已经有了, 这里不重复展示
  final String title = '${item['name'] ?? ''}'.trim();
  // 略高于垂直居中: 底部还要留出主播信息/购物栏的位置, 卡片整体再往上一点
  return Align(
    alignment: const Alignment(0.0, -0.3),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 32.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题 + "预告"标签(主播信息不在这里展示: 左上角已有)
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '直播预告' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2C55),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Text('预告', style: TextStyle(color: Colors.white, fontSize: 11.0)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          // 封面位置: 有预告片(pre_video)就在这个位置播视频, 没有就只显示封面图
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: SizedBox(
              height: 170.0,
              width: double.infinity,
              child: Stack(
                children: [
                  poster.isEmpty
                      ? Container(
                          color: Colors.white10,
                          child: const Center(child: Icon(Icons.image_outlined, size: 32.0, color: Colors.white38)),
                        )
                      : CachedNetworkImage(
                          imageUrl: poster,
                          height: 170.0,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                        ),
                  // 预告片出帧后才盖上去: 加载期间仍显示封面, 不会露出黑块
                  if (preVideo.isNotEmpty)
                    ValueListenableBuilder<bool>(
                      valueListenable: firstFrameNotifier,
                      builder: (BuildContext context, bool firstFrame, Widget? child) => firstFrame
                          ? Video(controller: liveVideoController, fit: BoxFit.cover, controls: NoVideoControls)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('距开播', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
              const SizedBox(width: 6.0),
              ValueListenableBuilder<Duration>(
                valueListenable: countdownNotifier,
                builder: (BuildContext context, Duration value, Widget? child) => Text(
                  countdownText,
                  style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          GestureDetector(
            // opaque: 保证点击落在按钮自己身上, 不被上下层的手势抢走
            behavior: HitTestBehavior.opaque,
            onTap: () => _onSubscribeTap('${item['sn'] ?? ''}'.trim()),
            child: Container(
              height: 40.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: subscribed ? Colors.white24 : const Color(0xFFFF2C55),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: subscribing
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : Text(
                      subscribed ? '已预约，开播提醒我' : '预约直播',
                      style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 弹幕列表
// * [zoom] 弹幕字体缩放(1 标 / 1.3 中 / 1.6 大, 见 utils/danmu_zoom.dart), 作用在所有聊天文本上
List<Widget> danmuList(dynamic list, {double zoom = 1.0}) {
  List<Widget> danmu = [];
  final double size = 13.0 * zoom;
  for (var item in list) {
    // 公告
    if (item['type'] == 'notice') {
      danmu.add(
        Container(
          margin: EdgeInsets.symmetric(vertical: 2.0),
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text('${item['content']}', style: TextStyle(color: Color(0xFF8CE7FF), fontSize: size),),
        ),
      );
    }
    // 礼物消息
    else if (item['type'] == 'gift') {
      danmu.add(
        Container(),
      );
    }
    // 其它消息（直播聊天弹幕消息自适应布局: Flexible配合Text.rich / TextSpan）
    else {
      danmu.add(
        Row(
          children: [
            Flexible(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 2.0),
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        child: Visibility(
                          visible: item['tag'] != null,
                          child: Container(
                            margin: EdgeInsets.only(right: 5.0,),
                            padding: EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              color: Color(0xFFD631F3),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text('${item['tag']}', style: TextStyle(color: Colors.white, fontSize: size),),
                            ),
                            ),
                            ),
                            TextSpan(text: '${item['user']}：', style: TextStyle(color: Color(0xFF8CE7FF), fontSize: size),),
                            TextSpan(text: '${item['isbuy'] != null ? '下单1号商品' : item['content']}', style: TextStyle(color: item['isbuy'] != null ? Colors.yellow : Colors.white, fontSize: size),),
                      WidgetSpan(
                        child: Visibility(
                          visible: item['isbuy'] != null,
                          child: Container(
                            margin: EdgeInsets.only(left: 5.0,),
                            padding: EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF2C55),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text('去购买', style: TextStyle(color: Colors.white, fontSize: size),),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  return danmu;
}

  @override
  Widget build(BuildContext context) {
    // 横屏直播间(type=horizontal): 复用竖版整页结构, 只是画面按 16:9 显示(不铺满), 聊天区随之上移
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
    appBar: AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      toolbarHeight: 0,
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
          children: [
          PageView.builder(
            scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
            scrollDirection: Axis.vertical,
            controller: pageVerticalController,
            // [临时] 上下滑动切房已关闭(见 liveRoomSwipeEnabled): 关掉时禁掉手势滑动
            physics: liveRoomSwipeEnabled ? null : const NeverScrollableScrollPhysics(),
            // [临时] 同上: 关掉时不回调 _switchRoom, 不会换房间/换流
            onPageChanged: liveRoomSwipeEnabled
                ? (index) async {
                    // 切房: 换房间号并重新取该房间的详情/拉流地址/带货商品, 再起播重进 socket
                    await _switchRoom(index);
                  }
                : null,
            // 列表还没回来时先用首页入参渲染进入的这一间(_roomItem 已兜底), 不再显示加载占位
            itemCount: roomList.isEmpty ? 1 : roomList.length,
            itemBuilder: (context, index) {
            // 加载完仍为空、且不是从首页点进来的(没有房间号): 才提示暂无直播间
            if (roomList.isEmpty && roomListLoaded && currentSn.isEmpty) {
              return const Center(
                child: CommonEmpty(text: '暂无直播间', textColor: Colors.white70),
              );
            }
            // 上下滑动的房间全部来自 roomPage 接口, 没有本地演示房间:
            // 演示内容(人气榜/红包福袋演示/购买动效/演示弹幕)一律不展示, 只展示接口 + socket 数据
            final bool demoRoom = _isDemoRoom(index);
            final item = _roomItem(index);
            // 讲解中商品: socket goods 消息优先(与H5 msgGoods 一致), 演示房间才回落本地房间数据
            final Map<String, dynamic> talk = _talkGoodsItem(item, demo: demoRoom);
            // 讲解卡是否展示: 演示房间按本地数据展示; 真实直播间只有收到 socket goods 消息后才展示(否则是空的演示卡)
            final bool talkVisible = goodsTalkVisible && (demoRoom || msgGoods != null);
            return Stack(
              children: [
                // 封面模糊底: 始终铺满整屏作为背景(横屏时画面只占中间 16:9, 上下留白同样由封面兜住)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                  // 封面为空(真实直播间接口还没返回)时不请求空地址, 用黑底兜住
                  child: '${item['poster']}'.isEmpty
                      ? Container(color: Colors.black)
                      // 不做淡入: 图片解码完直接铺满, 避免从黑底渐变过来那一瞬
                      : CachedNetworkImage(imageUrl: '${item['poster']}', fit: BoxFit.cover, fadeInDuration: Duration.zero,),
                ),
              ),
              // 视频区域: 横屏按 16:9 显示在弹幕区上方, 竖屏铺满整屏
              Positioned(
                top: isHorizontal ? videoTop : 0,
                left: 0,
                right: 0,
                bottom: isHorizontal ? null : 0,
                height: isHorizontal ? videoHeight : null,
                child: Stack(
                    children: [
                    ValueListenableBuilder(
                      valueListenable: liveIndexNotifier,
                    builder: (context, liveIndex, child) {
                      // 当前房间才挂载 Video(非当前房间挂载会跟当前房间抢同一个 controller 的输出)
                      // * 挂载/卸载会重建 Surface: 收到分辨率后 SetSurfaceSize -> 内部 seek -> 直播流被打断,
                      //   然后触发一次自动重连, 观感就是"视频播了两遍"。所以挂载时机不能跟着首帧走
                      // 直播预告(status=0)不挂载全屏 Video: 预告片在预告卡片的封面位置播,
                      // 同一个 controller 不能同时给两个 Video 用, 否则两边抢输出
                      if (liveIndex != index || (index == entryIndex && liveStatus == 0)) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: firstFrameNotifier,
                      builder: (context, firstFrame, child) {
                          return Visibility(
                            // 解码出首帧才显示画面: 起播缓冲期间继续显示封面, 不再露出黑底
                            // * 不可见时也要维持挂载(maintain*): Surface 一直存在, 起播不会被打断重来
                            visible: firstFrame,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            maintainInteractivity: false,
                            child: Video(
                              controller: liveVideoController,
                              fit: BoxFit.cover,
                                // 无控制条
                                controls: NoVideoControls,
                              ),
                              );
                            }
                            );
                          },
                          ),
                          // 暂停(2) / 已结束(3): 保持状态文案提示, 不拉流
                          if (index == entryIndex && liveStatus != 1 && liveStatus != 0)
                            Positioned.fill(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Text(
                                        LiveApi.statusName(roomInfo),
                                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                                      ),
                                    ),
                                    const SizedBox(height: 10.0),
                                    Text(liveStatusHint, style: const TextStyle(color: Colors.white70, fontSize: 13.0)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    /// 水平滚动模块(清屏/浮层)
                    PageView(
                      scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
                      scrollDirection: Axis.horizontal,
                    controller: pageHorizontalController,
                    onPageChanged: (index) {
                      // ...
                    },
                    children: [
                      // 直播清屏
                      Container(
                      alignment: Alignment.bottomRight,
                      padding: EdgeInsets.all(7.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 7.0,
                        children: [
                            Container(
                                alignment: Alignment.center,
                                height: 35.0,
                                width: 35.0,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                              child: Icon(Icons.help, color: Colors.white,),
                            ),
                            Container(
                              alignment: Alignment.center,
                              height: 35.0,
                              width: 35.0,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                              child: Icon(Icons.clear_all_rounded, color: Colors.white,),
                            ),
                            ],
                          ),
                          ),
                          // 直播浮层
                          Stack(
                            children: [
                              Positioned(
                              top: MediaQuery.of(context).padding.top + 7,
                              left: 10.0,
                              right: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              // 直播间头像
                              Container(
                                margin: const EdgeInsets.only(bottom: 7.0, right: 10.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(1.0),
                                  decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(50.0),
                                ),
                                child: Row(
                                  children: [
                                    // 头像为空(真实直播间接口还没返回)时不请求空地址, 用灰底圆兜住
                                    // * 加载失败(服务端默认头像 404 等)同样回落灰底圆, 不再抛 NetworkImageLoadException
                                    ClipOval(
                                      child: '${item['logo']}'.isEmpty
                                          ? Container(height: 36.0, width: 36.0, color: Colors.white24)
                                          : Image.network(
                                              '${item['logo']}',
                                              height: 36.0,
                                              width: 36.0,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(height: 36.0, width: 36.0, color: Colors.white24),
                                            ),
                                    ),
                                    SizedBox(width: 3.0,),
                                    // 昵称/点赞数: 顶部信息条在 Row 中是无界约束, 不限制宽度时长文案会把整条撑破
                                    // (曾报 RenderFlex overflowed by 566 pixels), 这里收口到 150 并单行省略
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 170.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(anchorNameOf(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 14.0),),
                                          Text(_zanText(index, item), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 10.0),),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      child: Container(
                                        height: 30.0,
                                        width: 56.0,
                                        margin: EdgeInsets.all(2.0),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: item['isFollow'] ? Colors.white : Color(0xFFFF2C55),
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: Text(item['isFollow'] ? '已关注' : '关注', style: TextStyle(color: item['isFollow'] ? Color(0xFFFF2C55) : Colors.white, fontSize: 13.0),),
                                        ),
                                        onTap: () => _onFollowTap(index, item),
                                          )
                                        ],
                                        ),
                                      ),
                                    Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // 在线人数: socket room 消息下发(与H5顶部"{onLine}人"一致), 未下发不展示
                                            if (index == entryIndex && roomOnline > 0)
                                              Container(
                                                margin: const EdgeInsets.only(right: 7.0),
                                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.black12,
                                                  borderRadius: BorderRadius.circular(50.0),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.visibility_outlined, color: Colors.white70, size: 15.0),
                                                    const SizedBox(width: 4.0),
                                                    Text('$roomOnline人', style: const TextStyle(color: Colors.white, fontSize: 14.0),),
                                                  ],
                                                ),
                                              ),
                                            Container(
                                              height: 32.0,
                                              width: 32.0,
                                              alignment: Alignment.center,
                                              child: IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white70, size: 20.0),
                                                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black12)),
                                                padding: EdgeInsets.zero,
                                                // 先停干净再退栈: 只 Get.back() 的话退栈动画这几帧还在播,
                                                // 而且退出瞬间可能触发一次重连(见 _leaveRoom)
                                                onPressed: _onCloseTap,
                                              ),
                                            )
                                          ],
                                            ),
                                          ),
                                          ],
                                        ),
                                      ),
                                      // 排名统计(人气榜标签): 写死的演示文案, 真实直播间没有榜单数据, 只在演示房间展示
                                      if (demoRoom)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 7.0),
                                    child: Row(
                                      children: [
                                        // 带货总榜: 先隐藏(人气榜同样只在演示房间展示), 需要时取消下面整段注释即可
                                        /*
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(3.0, 1.0, 7.0, 1.0),
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.military_tech_outlined, color: Colors.yellow, size: 14.0,),
                                              Text('带货总榜第1名', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 5.0,),
                                        */
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(3.0, 1.0, 7.0, 1.0),
                                          decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(50.0),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.bar_chart_rounded, color: Colors.yellow, size: 14.0,),
                                            Text('人气榜', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                          ],
                                        ),
                                        ),
                                      ],
                                      ),
                                    ),
                                    // 红包/福袋活动: 倒计时是本地演示数据(真实直播间待接入活动数据), 只在演示房间展示
                                    if (demoRoom)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 7.0),
                                  child: Row(
                                    spacing: 5.0,
                                    children: [
                                      Stack(
                                        children: [
                                        GestureDetector(
                                          child: Container(
                                        height: 36.0,
                                        width: 36.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(6.0),
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Image.asset('assets/images/icon-hb.png', width: 36.0,),
                                        ),
                                      ),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return PopupRedpacket();
                                            },
                                          );
                                          },
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 3.0,
                                        right: 3.0,
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: Colors.black38,
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: const Text('03:25', style: TextStyle(color: Colors.white, fontSize: 8.0),),
                                          ),
                                          )
                                          ],
                                        ),
                                        Stack(
                                        children: [
                                          Container(
                                            height: 36.0,
                                          width: 36.0,
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                            borderRadius: BorderRadius.circular(6.0),
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Image.asset('assets/images/icon-fudai.png', width: 36.0,),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 3.0,
                                          right: 3.0,
                                          child: Container(
                                            alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.black38,
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: const Text('01:30', style: TextStyle(color: Colors.white, fontSize: 8.0),),
                                            ),
                                          )
                                          ],
                                        ),
                                        ],
                                      ),
                                      ),
                                    // 活动入口(福袋/红包/签到/集章): 真实直播间由 socket activity 下发(演示房间继续用上面的演示块)
                                    if (!demoRoom)
                                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                                        valueListenable: activityList,
                                        builder: (BuildContext context, List<Map<String, dynamic>> activities, Widget? child) {
                                          final List<Map<String, dynamic>> items = activities
                                              .where((Map<String, dynamic> item) =>
                                                  _activityIcon('${item['type']}').isNotEmpty &&
                                                  !endedActivityIds.contains('${item['gameId'] ?? ''}'.trim()))
                                              .toList();
                                          if (items.isEmpty) return const SizedBox.shrink();
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 7.0),
                                            child: Row(
                                              spacing: 5.0,
                                              children: [
                                                for (final Map<String, dynamic> item in items) _activityEntry(item),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              // 底部区域: 横屏直播间聊天区紧跟在画面下方
                              Positioned(
                                top: isHorizontal ? videoTop + videoHeight : null,
                                bottom: 7.0,
                                left: 10.0,
                              right: 10.0,
                              child: Column(
                                mainAxisAlignment: isHorizontal ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              // 画面下方内容组: 购买动效 + 进场提示 + 弹幕, 整组紧贴画面下沿(进场提示固定在弹幕上方)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              // 商品购买动效: 本地演示数据(真实直播间的下单动效需要 socket 订单消息, 暂未接入, 先不展示)
                              if (demoRoom)
                              Container(
                              margin: EdgeInsets.only(top: 7.0),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFFF00B3), Colors.transparent
                                ],
                              ),
                              border: Border.all(color: Colors.white, width: .1),
                              borderRadius: BorderRadius.circular(10.0)
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              ClipRRect(
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(10.0)),
                              child: Image.network('${item['poster']}', height: 50.0, width: 50.0, fit: BoxFit.cover,),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 5.0),
                              constraints: BoxConstraints(
                                maxWidth: 160.0,
                                ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                        Text('Andy', style: TextStyle(color: Colors.yellow, fontSize: 16.0),),
                                        // 等N人在购买: Flexible + 省略号收口, 销量文案变长时不再撑破卡片(曾报 RenderFlex overflow 1.9px)
                                        Flexible(
                                          child: Text(' 等${item['saleNum']}人在购买', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 14.0),),
                                        ),
                                      ],
                                    ),
                                    Text('${item['desc']}', maxLines: 1, style: TextStyle(color: Colors.white70, fontSize: 10.0), overflow: TextOverflow.ellipsis,),
                                  ],
                                    ),
                                  ),
                                  Container(
                                    height: 26.0,
                                  width: 60.0,
                                margin: EdgeInsets.all(5.0),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  child: Text('去购买', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),),
                                ),
                                ],
                                ),
                              ),
                              // 送礼物消息动效: 先不播送礼消息, 需要时取消下面整段注释即可
                              /*
                              AnimationLiveGift(
                                giftQueryList: [
                                {'label': '小心心', 'gift': 'assets/images/gift/gift1.png', 'user': '岁月如梭', 'avatar': 'assets/images/avatar/img01.jpg', 'num': 6},
                                {'label': '棒棒糖', 'gift': 'assets/images/gift/gift2.png', 'user': 'Andy', 'avatar': 'assets/images/avatar/img02.jpg', 'num': 75},
                                {'label': '大啤酒', 'gift': 'assets/images/gift/gift3.png', 'user': '白昼流星', 'avatar': 'assets/images/avatar/img03.jpg', 'num': 211},
                                {'label': '人气票', 'gift': 'assets/images/gift/gift4.png', 'user': 'Luck', 'avatar': 'assets/images/avatar/img04.jpg', 'num': 68},
                                {'label': '鲜花', 'gift': 'assets/images/gift/gift5.png', 'user': '时过境迁', 'avatar': 'assets/images/avatar/img05.jpg', 'num': 12},
                                {'label': '捏捏小脸', 'gift': 'assets/images/gift/gift6.png', 'user': 'Apple', 'avatar': 'assets/images/avatar/img06.jpg', 'num': 38},
                                {'label': '你真好看', 'gift': 'assets/images/gift/gift7.png', 'user': '竹叶青', 'avatar': 'assets/images/avatar/img07.jpg', 'num': 119},
                                {'label': '亲吻', 'gift': 'assets/images/gift/gift8.png', 'user': '娜娜', 'avatar': 'assets/images/avatar/img08.jpg', 'num': 100},
                                {'label': '玫瑰', 'gift': 'assets/images/gift/gift12.png', 'user': '颜如玉', 'avatar': 'assets/images/avatar/img09.jpg', 'num': 2},
                                {'label': '私人飞机', 'gift': 'assets/images/gift/gift16.png', 'user': 'Davi', 'avatar': 'assets/images/avatar/img10.jpg', 'num': 168},
                              ],
                              ),
                              */
                              // 进场动效: 真实直播间播 socket join 推送, 本地演示房间播内置演示数据
                              AnimationLiveJoin(
                                joinQueryList: roomSn.isNotEmpty ? null : [
                                {'avatar': 'assets/images/logo.png', 'name': 'Andy'},
                                {'avatar': 'assets/images/logo.png', 'name': 'Tom'},
                                {'avatar': 'assets/images/logo.png', 'name': '平安喜乐'},
                                {'avatar': 'assets/images/logo.png', 'name': '简单的幸福'},
                                {'avatar': 'assets/images/logo.png', 'name': '生如夏花'},
                                {'avatar': 'assets/images/logo.png', 'name': 'alice'},
                                  {'avatar': 'assets/images/logo.png', 'name': '小喵'},
                                  {'avatar': 'assets/images/logo.png', 'name': '沐浴阳光'},
                                  {'avatar': 'assets/images/logo.png', 'name': '给生活加点糖'},
                                  {'avatar': 'assets/images/logo.png', 'name': 'Victor'},
                                ],
                                joinMessages: joinMessages,
                              ),
                              // 弹幕区: 与上方进场提示保持 20 间距
                              Container(
                                margin: const EdgeInsets.only(top: 20.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                Expanded(
                                  child: ScrollConfiguration(
                                  behavior: CustomScrollBehavior(),
                                  // 弹幕区数据源: 真实直播间为 socket 下发的 msg, 本地演示房间沿用接口数据
                                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                                    valueListenable: danmuMessages,
                                    builder: (BuildContext context, List<Map<String, dynamic>> messages, Widget? child) {
                                      final dynamic mockMsg = item['message'];
                                      // 弹幕区 = 房间历史 + socket 实时消息
                                      // * 真实直播间: 房间历史为空(见 _roomItem), 只展示 socket 下发的消息
                                      // * 本地演示房间: 只展示本地演示历史, 不混入 socket 消息
                                      final List<dynamic> list = <dynamic>[
                                        if (mockMsg is List) ...mockMsg,
                                        if (!demoRoom) ...messages,
                                      ];
                                      final dynamic lastMsg = list.isEmpty ? null : list.last;
                                      // 末条消息 id 作为"是否有新消息"的标识(队列满 50 条时长度不变, 只看末条)
                                      final String lastId = lastMsg is Map ? '${lastMsg['id'] ?? ''}' : '${list.length}';
                                      // 字体档位变了也要重建弹幕(缩放值在 danmu_zoom 里, 改档位不触发消息队列变更)
                                      // 新消息入队后自动滚到底部(滚动状态在 DanmuScrollView 内部维护)
                                      return ValueListenableBuilder<double>(
                                        valueListenable: danmuZoom,
                                        builder: (BuildContext context, double zoom, Widget? child) =>
                                            DanmuScrollView(items: danmuList(list, zoom: zoom), lastId: lastId),
                                      );
                                    },
                                  ),
                                  ),
                                ),
                                SizedBox(
                                  width: talkVisible ? 7 : 35,
                                ),
                                // 商品讲解
                                Visibility(
                                  visible: talkVisible,
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  // 热卖条: 热卖数(saleNum, 兼容 hot)取不到时不展示
                                  if (talk['saleNum'].toString().trim().isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(bottom: 7.0),
                                padding: EdgeInsets.symmetric(horizontal: 7.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFFFBB00), Color.fromARGB(0, 255, 238, 0)
                                    ],
                                      ),
                                      borderRadius: BorderRadius.circular(10.0)
                                    ),
                                    child: Row(
                                      spacing: 3.0,
                                      children: [
                                        Image.asset('assets/images/icon-hot.png', height: 15.0, width: 15.0, fit: BoxFit.cover,),
                                        // 热卖条在 Row 的非 flex 位(宽度无界), 只用 maxLines/ellipsis 收口, 不加 Flexible
                                        Text('热卖 x${talk['saleNum']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 14.0),),
                                      ],
                                      ),
                                    ),
                                    GestureDetector(
                                      child: Container(
                                      width: 110.0,
                                      padding: EdgeInsets.all(2.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
                                          child: Image.network('${talk['image']}', height: 110.0, width: 110.0, fit: BoxFit.cover,),
                                        ),
                                        Positioned(
                                          left: 3.0,
                                          top: 3.0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                                            decoration: BoxDecoration(
                                              color: Colors.black38,
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                            child: Text('•讲解中', style: TextStyle(color: Colors.white, fontSize: 10.0),),
                                            ),
                                          ),
                                          Positioned(
                                            right: 3.0,
                                            top: 3.0,
                                            child: InkWell(
                                              child: Icon(Icons.close, color: Colors.white, size: 12.0),
                                              onTap: () {
                                                setState(() {
                                                goodsTalkVisible = false;
                                              });
                                            },
                                                ),
                                              )
                                            ],
                                              ),
                                          SizedBox(height: 3.0,),
                                          Text(' ${talk['title']}', maxLines: 1, style: TextStyle(color: Colors.black, fontSize: 12.0), overflow: TextOverflow.ellipsis,),
                                          Text(' 7天无理由退货', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 10.0), overflow: TextOverflow.ellipsis,),
                                          SizedBox(height: 3.0,),
                                          // 价格条: 价格取不到(真实直播间 socket 未下发)时不展示, 不写死演示价
                                          if (talk['price'].toString().trim().isNotEmpty)
                                          Container(
                                            margin: EdgeInsets.all(2.0),
                                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFFF2C55),
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text('¥${talk['price']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 16.0, fontFamily: 'Arial'),),
                                                ),
                                                Text('抢', style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),),
                                              ],
                                            ),
                                          ),
                                          ],
                                        ),
                                      ),
                                      onTap: () {
                                          // 携带商品id跳详情(讲解中商品 socket goods 里带 id)
                                          // * 详情页按 int 解析, 非数字会被兜成 goodsId=1, 打开的是别的商品, 所以这里先挡掉
                                          // 商城商品id(goods_id)优先: id 可能是直播商品记录的主键
                                          final int? gid = int.tryParse('${talk['goods_id'] ?? talk['id'] ?? ''}'.trim());
                                          if (gid == null) return;
                                          // 当前房间数据: 给详情页的悬浮小窗用(封面 / 主播名 / 拉流地址)
                                          final Map<String, dynamic> room = _roomItem(liveIndexNotifier.value);
                                          // 带房间号: 详情页加购 / 下单要回传 live_roomid
                                          Get.toNamed('/goods', arguments: <String, dynamic>{
                                            'goodsId': gid,
                                            // 标记来源: 详情页据此挂悬浮小窗(房间号为空的演示房间也要挂)
                                            'fromLive': true,
                                            'live_roomid': roomSn,
                                            // 悬浮小窗: 小窗继续播这路流,点它回直播间
                                            'liveCover': '${room['poster'] ?? ''}'.trim(),
                                            'liveAnchor': anchorNameOf(room),
                                            'livePullUrl': pullUrl.isNotEmpty ? pullUrl : '${room['src'] ?? ''}'.trim(),
                                          });
                                        },
                                      ),
                                        ],
                                      ),
                                      ),
                                    ],
                                    ),
                                  ),
                                  ],
                                  ),
                                  // 底部工具栏
                                  Container(
                                    margin: const EdgeInsets.only(top: 7.0),
                                    child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                    height: 38.0,
                                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(50.0),
                                    ),
                                    child: const Text('说点什么...', style: TextStyle(color: Colors.white, fontSize: 14.0,),),
                                  ),
                                  onTap: () {
                                    // 发送弹幕评论: 禁言时不弹输入框
                                    _openCommentInput();
                                    },
                                  ),
                                  ),
                                    const SizedBox(width: 10.0,),
                                    Wrap(
                                        spacing: 7.0,
                                    children: [
                                    // GestureDetector 替代 InkWell: 去掉点击时的水波纹/高亮背景效果
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                          alignment: Alignment.center,
                                          height: 38.0,
                                          width: 38.0,
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: Image.asset('assets/images/icon-cart.png', width: 23.0,),
                                        ),
                                        onTap: () {
                                          // 一律打开橱窗, 不再做任何前置拦截/toast:
                                          // * 商品由弹窗自己拉(见 onRefresh), 拉不到由弹窗显示空态
                                          navigator?.push(FadeRoute(
                                            effect: 'bottom',
                                            child: PopupGoods(
                                            // 首屏占位用进房那份, 打开后立即被 onRefresh 的结果整体替换
                                            // * 不再做演示数据兜底: 演示房间已停用(_isDemoRoom 恒 false),
                                            //   真实房间串进写死的演示商品会误导
                                            goodsList: onlineGoods,
                                            // 每次打开购物车 / 切分类都重新拉一次(商品会上下架/改价, 进房时那份可能已过期)
                                            // * 参数是当前选中的商品分类 id(「全部」为空串), 后端按 category_id 返回
                                            onRefresh: (String categoryId) => LiveApi.onlineGoods(roomSn, categoryId: categoryId),
                                            // 头部主播信息(真实: 当前房间 anchor_name / anchor_img / name)
                                            // * 用 item 而不是 roomInfo: 上下滑切房后 roomInfo 未必跟着更新
                                            anchorName: anchorNameOf(item),
                                            anchorAvatar: '${item['logo'] ?? ''}'.trim(),
                                            roomTitle: '${item['name'] ?? ''}'.trim(),
                                            // 房间号: 橱窗里点商品进详情后,加购 / 下单要回传 live_roomid
                                            roomSn: roomSn,
                                            // 悬浮小窗: 封面 + 拉流地址(主播名走上面的 anchorName)
                                            liveCover: '${item['poster'] ?? ''}'.trim(),
                                            livePullUrl: pullUrl.isNotEmpty ? pullUrl : '${item['src'] ?? ''}'.trim(),
                                            )
                                          ));
                                            goodsTalkVisible = true;
                                          }
                                        ),
                                        // 点赞: 从按钮位置飘心并上行
                                        // * GestureDetector 替代 InkWell: 去掉点击时的水波纹/高亮背景效果
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _onLikeButtonTap,
                                          child: Container(
                                        alignment: Alignment.center,
                                        height: 38.0,
                                        width: 38.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(50.0),
                                        ),
                                        child: Image.asset('assets/images/icon-aixin.png', width: 23.0,),
                                      ),
                                    ),
                                    // 底部礼物入口: 先停用(礼物弹窗 + 钻石不足充值弹窗), 需要时取消下面整段注释即可
                                    /*
                                    InkWell(
                                      child: Container(
                                        alignment: Alignment.center,
                                      height: 35.0,
                                      width: 35.0,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(50.0),
                                      ),
                                      child: Image.asset('assets/images/icon-gift.png', width: 20.0,),
                                    ),
                                    onTap: () {
                                      navigator?.push(FadeRoute(
                                      effect: 'bottom',
                                      child: PopupGift(
                                      onChanged: (value) {
                                        // debugPrint('coins ---$value');
                                      // 钻石不足充值弹窗
                                      navigator?.push(FadeRoute(
                                        effect: 'bottom',
                                        child: PopupRecharge(
                                          onChanged: (value) {
                                            // debugPrint('recharge ---$value');
                                          },
                                        )
                                      ));
                                      },
                                      )
                                    ));
                                    }
                                  ),
                                  */
                                  // GestureDetector 替代 InkWell: 去掉点击时的水波纹/高亮背景效果
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                    alignment: Alignment.center,
                                    height: 38.0,
                                    width: 38.0,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  child: const Icon(Icons.more_horiz_outlined, color: Colors.white, size: 23),
                                ),
                                onTap: () {
                                      navigator?.push(FadeRoute(
                                        effect: 'bottom',
                                        child: PopupMore(
                                          roomId: roomSn,
                                          // 点「分享」: 收起更多框后打开分享弹窗
                                          // * 分享内容用当前房间的标题 + share_href
                                          onShare: () {
                                            navigator?.push(FadeRoute(
                                              effect: 'bottom',
                                              child: PopupShare(
                                                roomId: roomSn,
                                                title: '${roomInfo?['name'] ?? ''}'.trim(),
                                                shareUrl: '${roomInfo?['share_href'] ?? ''}'.trim(),
                                                coverUrl: LiveApi.imageOf(roomInfo?['feeds_img']),
                                              ),
                                            ));
                                          },
                                        ),
                                      ));
                                    }
                                  ),
                                  ],
                                ),
                              ],
                            ),
                            ),
                          ],
                            ),
                          ),
                        ],
                      ),
                      ],
                      ),
                    ],
                  );
                },
              ),
              // 点击屏幕点赞: 只覆盖视频中部空白区(避开顶部工具栏/榜单/红包、右侧货卡、底部工具栏, 与H5 touch-layer 定位一致)
              // * 只在直播中(1)挂载: 这层在预告卡片之上, 预告/暂停/已结束时它会吞掉"预约直播"等按钮的点击(变成点赞)
              if (liveStatus == 1)
                Positioned(
                  left: 0,
                  right: 130.0,
                  top: MediaQuery.of(context).padding.top + 170.0,
                  bottom: 200.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (TapDownDetails details) => _onScreenLike(details.globalPosition),
                    child: const SizedBox.expand(),
                  ),
                ),
              // 点赞飘心层: 不拦截手势(与H5 like-effect-layer pointer-events: none 一致)
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<List<LikeHeart>>(
                    valueListenable: likeHearts,
                    builder: (BuildContext context, List<LikeHeart> hearts, Widget? child) {
                      return Stack(
                        children: [
                          for (final LikeHeart heart in hearts)
                            Positioned(
                              left: heart.x,
                              top: heart.y,
                              child: LikeFlyingHeart(
                                key: ValueKey<int>(heart.id),
                                heart: heart,
                                onCompleted: () => _removeLikeHeart(heart.id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // 直播预告(0): 预告卡片必须挂在整页最上层(所有浮层/点赞层之后),
              // * 之前挂在房间 item 的 Stack 里, 被外层的点赞层等覆盖, 点"预约直播"会被上层手势吃掉(表现为点了没反应)
              ValueListenableBuilder<int>(
                valueListenable: liveIndexNotifier,
                builder: (BuildContext context, int liveIndex, Widget? child) {
                  if (liveIndex != entryIndex || liveStatus != 0) return const SizedBox.shrink();
                  return Positioned.fill(child: _previewCard(_roomItem(entryIndex)));
                },
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一颗点赞飘心(参数对齐 H5 createLikeEffect)
class LikeHeart {
  const LikeHeart({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.duration,
    required this.scale,
    required this.rotate,
    required this.dx,
    required this.dy,
    required this.color,
  });

  /// 唯一 id(用作 key 与移除标记)
  final int id;
  /// 起点左上角(逻辑像素, 已含随机抖动)
  final double x;
  final double y;
  /// 心的边长(42~52rpx 换算)
  final double size;
  /// 飘动时长(900~1180ms)
  final Duration duration;
  /// 基础缩放(0.9~1.25)
  final double scale;
  /// 基础旋转(±20 度, 弧度)
  final double rotate;
  /// 终点位移(逻辑像素, dy 为负表示向上)
  final double dx;
  final double dy;
  /// 心形颜色(对齐H5 6 张彩心图)
  final Color color;
}

/// 点赞飘心动画
/// * 位移与缩放 ease-out 跟随, 透明度 0%→20% 淡入、20%→100% 淡出(对齐H5 likeFloat1~4 关键帧)
/// * 动画结束后回调上层从队列移除, 避免节点堆积
class LikeFlyingHeart extends StatefulWidget {
  const LikeFlyingHeart({
    super.key,
    required this.heart,
    required this.onCompleted,
  });

  final LikeHeart heart;
  final VoidCallback onCompleted;

  @override
  State<LikeFlyingHeart> createState() => _LikeFlyingHeartState();
}

class _LikeFlyingHeartState extends State<LikeFlyingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: widget.heart.duration,
  );

  @override
  void initState() {
    super.initState();
    controller.forward().whenComplete(widget.onCompleted);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = controller.value;
        final double ease = Curves.easeOut.transform(progress);
        final double opacity = progress < 0.2 ? progress / 0.2 : 1.0 - (progress - 0.2) / 0.8;
        final double scale = widget.heart.scale * (0.6 + 1.48 * ease);
        return Transform.translate(
          offset: Offset(widget.heart.dx * ease, widget.heart.dy * ease),
          child: Transform.rotate(
            angle: widget.heart.rotate,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: SvgPicture.asset(
                  'assets/images/svg/heart.svg',
                  width: widget.heart.size,
                  height: widget.heart.size,
                  colorFilter: ColorFilter.mode(widget.heart.color, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 弹幕滚动区: 新消息(或切换房间换数据)后自动滚到底部看最新一条
/// * controller 由各房间页各持一个: PageView 滑动时相邻页会同时存在, 共用一个会命中"多个 ScrollPosition"异常
class DanmuScrollView extends StatefulWidget {
  const DanmuScrollView({
    super.key,
    required this.items,
    required this.lastId,
    this.expanded = false,
    this.height = 200.0,
  });

  /// 渲染好的弹幕条目
  final List<Widget> items;
  /// 末条消息标识: 变化视为有新消息(队列满 50 条时长度不变, 所以只看末条)
  final String lastId;
  /// 不限制自身高度: 由外层 Expanded 撑满剩余空间(横屏下方聊天区); 为 false 时按 [height] 固定高度(竖屏底部弹幕区)
  final bool expanded;
  /// 固定高度(仅 [expanded] 为 false 时生效)
  final double height;

  @override
  State<DanmuScrollView> createState() => _DanmuScrollViewState();
}

class _DanmuScrollViewState extends State<DanmuScrollView> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 首屏也定位到最新一条(与H5 弹幕区停在底部一致)
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant DanmuScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastId != oldWidget.lastId) _scrollToBottom();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  // 滚到底部: 等本帧布局完成再滚(弹幕条目高度不定, maxScrollExtent 布局后才准)
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, i) => widget.items[i],
    );
    // 高度交给外层 Expanded(横屏下方聊天区随下半屏撑满), 否则固定高度(竖屏底部弹幕区)
    return widget.expanded ? list : SizedBox(height: widget.height, child: list);
  }
}