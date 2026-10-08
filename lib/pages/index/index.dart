/// 首页模板
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/custom_sticky_header.dart';
import '../../components/loading.dart';
import '../../components/live_playing_bars.dart';
import '../../components/backtop.dart';
import '../../components/custom_pageview_indicator.dart';
import '../../utils/player_config.dart';
import '../../api/goods.dart';
import '../../api/live.dart';
import '../../pages/live/index.dart';
import '../../api/seckill.dart';
import '../../api/cart.dart';
import '../../controller/auth_store.dart';
import '../../api/index.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/services.dart';
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});
  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<String> tabList = ['推荐', '新品', '手机', '酒水饮料', '男装', '女装', '爱车', '食品', '生鲜', '家电', '生活旅行'];

  // 瀑布流列表
  List waterfallData = [
    {
    'price': 69.00,
    'title': '一家超级美貌的面包甜品店🎅🏻🎄。',
    'shop': '甜品治愈店',
    'image': 'https://qcloud.dpfile.com/pc/v1bIsYHx3Y87jclud6DDqfNBYql3vxbAqq-znhZU9TH6C11FNL1SypW4dSClWkDpY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '8764'
  },
  {
    'price': 139.00,
    'title': '尝了第一口，立马决定加单了，真正的咸甜永动机啊🍬 ',
    'shop': '薄荷牛舌卷旗舰店',
    'image': 'https://qcloud.dpfile.com/pc/bPtiRX0q9JgU1nEzQCdo1YTkckPFWjHP0R9JSmB0C7Msmqt_iFFDpyVDwTmNHIV2Y0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '1639'
  },
  {
    'price': 468.00,
    'title': '皮尔卡丹男装羽绒服男女同款冬季新款长款过膝加长加厚情侣款外套 黑色（可拆卸帽） 2XL',
    'shop': '皮尔卡丹专卖店',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/39114/14/20805/86340/638b4940E942d72fb/348e214e2d5c22f1.jpg',
    'saleNum': '1200'
  },
  {
    'price': 19.00,
    'title': '半价圣诞蛋糕🎄',
    'shop': '萨莉亚专卖店',
    'image': 'https://qcloud.dpfile.com/pc/YJ4OOVWA5sj34gPWC8Nkwpc8wuTQF9y4IfNQ2cimzKkuclZKFe3DWF0_YvlhKe8mY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '2.1万'
  },
  {
    'price': 2099.00,
    'title': '小米 REDMI K80 国家补贴 第三代骁龙 8 6550mAh大电池 澎湃OS 玄夜黑 12GB+256GB 红米5G至尊手机',
    'shop': '小米京东自营旗舰店',
    'image': 'https://img10.360buyimg.com/n1/s450x450_jfs/t1/264409/38/13856/102861/678dcfdaFb723c58f/5b97cf154bbba96c.jpg',
    'saleNum': '9726'
  },
  {
    'price': 1.00,
    'title': '圣菲尔伯爵法国红酒Saintfilcount干红葡萄酒珍藏13.5度单瓶送礼红酒 一元试饮',
    'shop': '小森葡萄酒专营店',
    'image': 'https://img10.360buyimg.com/n7/jfs/t1/226168/23/3411/118733/65537e5fF2db2d109/7d1d11a8013d6e8f.jpg',
    'saleNum': '9.9万'
  },
  {
    'price': 1499.90,
    'title': '茅台（MOUTAI）飞天 53%vol 500ml 贵州茅台酒（带杯）',
    'shop': '茅台京东自营旗舰店',
    'image': 'https://img13.360buyimg.com/n1/jfs/t1/97097/12/15694/245806/5e7373e6Ec4d1b0ac/9d8c13728cc2544d.jpg',
    'saleNum': '1254'
  },
  {
    'price': 42.00,
    'title': '美的（Midea）LED便携充电小台灯书桌学习阅读灯学生宿舍卧室床头灯学习台灯',
    'shop': '美的（Midea）旗舰店',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/226233/4/10194/156936/658e8f88Fcfc9cb40/cea4a48783f11a7a.jpg',
    'saleNum': '5106'
  },
  {
    'price': 19.90,
    'title': '『 江西炒米粉 』本次最佳😋香就一个字话。锅气的香🔥干辣椒的焦香🌶️油的润香🐷蔬菜混合的清香🥬',
    'shop': '去月球野餐嗎',
    'image': 'https://qcloud.dpfile.com/pc/pOAOL-DQRBWfkVZIWYVoy0mMQf6_UutNlOpEpGkT_nz3b1n7ZbpikPgtXMhMsjXNY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '3.2万'
  },
  {
    'price': 22.90,
    'title': '蒙都 羊杂500g 加热即食 京东超市肉干肉脯及礼包11.11真便宜',
    'shop': '蒙都旗舰店',
    'image': 'https://img10.360buyimg.com/n7/jfs/t1/155306/32/25324/231912/62d22fb8E4ffab855/c6001ee702fb240a.jpg',
    'saleNum': '1.6万'
    },
  ];
  // 列表
  List dataList = [];
  // 是否加载中
  bool isLoading = false;
  // 是否下拉刷新中(刷新时不显示底部"加载中",列表本身也不清空)
  bool isRefreshing = false;
  // 商品列表是否横向单列布局(默认横向单列)
  bool isHorizontalList = true;
  // 当前页码
  int page = 1;
  // 每页条数
  final int pageSize = 12;
  // 是否还有更多数据
  bool hasMore = true;
  // 当前选中的分类id(0 = 推荐, 走 /api/goodssku/pageComponents)
  int currentCategoryId = 0;
  // 吸顶 tab 板块缓存: SliverLayoutBuilder 滚动中每帧回调,缓存后不再每帧重建 TabBar 子树
  Widget? _stickyTabsHeader;
  Widget? _normalTabsHeader;
  // 请求序号: 切换分类时自增, 用于丢弃在途的旧请求响应
  int requestSeq = 0;
  // tab 板块的吸顶滚动偏移(SliverLayoutBuilder 布局时记录, 即该 sliver 到达视口顶部的偏移)
  double tabStickyOffset = 0;

  // iOS 首启网络授权弹窗拦截后, 生命周期 resumed 时自动重试首页数据
  Timer? _resumeRetryTimer;
  int _resumeRetryCount = 0;
  static const int _maxResumeRetries = 3;

  // 网络可用性监听: 网络从无到有时触发首页重刷
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ConnectivityResult? _lastConnectivity;

  // 首页直播信息(无直播间时为 null,直播板块不展示)
  Map<String, dynamic>? liveRoom;
  // 首页直播预览播放器(静音播放 push_link,点进直播间才有声音)
  Player? livePlayer;
  VideoController? liveVideoController;
  LiveReconnector? liveReconnector;
  // 重入锁: 防止 loadLiveRoom 并发进入(首启时 initState 与生命周期 resumed 重试可能同时调用,
  // 两者都会 dispose 旧 Player 再新建, 并发会互相 dispose 掉正在创建的 Player, 导致起播失败、封面一直盖住画面)
  bool _liveLoading = false;
  // 直播卡片key: 用于判断卡片是否滚出视口
  final GlobalKey liveCardKey = GlobalKey();
  // 直播预览是否已出首帧(出帧后隐藏封面,避免封面盖住画面)
  final ValueNotifier<bool> liveFirstFrame = ValueNotifier(false);

  // 限时秒杀板块: 当前场次
  SeckillTime? seckillTime;
  // 当前场次状态: 0 已结束 / 1 抢购中 / 2 即将开始
  int seckillStatus = 1;
  // 限时秒杀板块: 商品(首页展示前 10 个)
  List<Map<String, dynamic>> seckillGoods = [];
  // 服务器当日秒数 + 同步时刻(秒),用于无漂移倒计时
  int seckillServerSeconds = 0;
  int seckillSyncedAt = 0;
  // 剩余秒数(每秒刷新,局部重建倒计时)
  final ValueNotifier<int> seckillRemain = ValueNotifier<int>(0);
  Timer? seckillTimer;
  // 滚动停止判定: 滚动中先暂停直播预览(解码 + 纹理合成抢 GPU),停手 300ms 后再按可见性恢复
  Timer? liveScrollIdleTimer;

  // 首页 tab 分类(来自 /api/goodscategory/tree 一级分类)
  List<Map<String, dynamic>> categoryList = [];

  // 首页聚合配置(来自 /api/index/index): 轮播 / 金刚区 / 弹窗
  List bannerList = [];
  List navList = [];
  Map<String, dynamic> popupInfo = {};
  bool _popupShown = false;
  int cartCount = 0;

late ScrollController scrollController = ScrollController();

// 金刚区翻页控制器(PageView, 每页 5 个, 配合下方 CustomPageViewIndicator)
final PageController pageController = PageController();

// 轮播图翻页控制器(配合底部 CustomPageViewIndicator, 下标与金刚区一致)
final PageController bannerController = PageController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);
// TabBar 的 tabs 由 tabList 生成, 并统一用 DefaultTabController 托管(长度=tabList.length),
// 避免手动 TabController 与 tabs 数量不同步而断言崩溃

// 滚动回调: 每一帧都会执行,只放轻量逻辑
void _onScroll() {
  scrollOffset.value = scrollController.offset;
  // 直播预览: 滚动过程中直接暂停解码(视频解码 + 纹理合成会抢 GPU/CPU,是滚动掉帧的主因之一),
  // 停手 300ms 后再按卡片可见性恢复;滚动期间不再做 RenderObject 计算
  if(livePlayer != null) {
    if(livePlayer!.state.playing) livePlayer!.pause();
    liveScrollIdleTimer?.cancel();
    liveScrollIdleTimer = Timer(const Duration(milliseconds: 300), () {
      if(mounted) syncLivePlayState();
    });
  }
  // 提前一屏触发加载更多,避免滑到底部才发请求造成停顿
  if(isLoading || !hasMore) return;
  final ScrollPosition position = scrollController.position;
  if(position.maxScrollExtent - position.pixels <= 300) {
    loadMoreData();
  }
}
// 加载更多(上拉触底 / 首次进入)
// * refresh = true 为下拉刷新: 用第一页数据整体替换列表,不清空,避免列表闪一下(空态 + 加载中转一圈)
Future<void> loadMoreData({bool refresh = false}) async {
  if(isLoading || !hasMore) return;
  setState(() {
    isLoading = true;
  });
  // 记录请求序号: 请求返回时若已切换分类, 该响应直接丢弃
  final int seq = requestSeq;
  try {
    // 推荐(0)走首页推荐接口, 其余分类走 /api/goodssku/page?category_id=
    final Map<String, dynamic> res = currentCategoryId > 0
      ? await GoodsApi.pageList(page: page, pageSize: pageSize, categoryId: currentCategoryId)
      : await GoodsApi.pageComponents(page: page, pageSize: pageSize);
    final List list = res['list'] as List;
    final int pageCount = (res['page_count'] ?? 1) as int;
    final List<Map<String, dynamic>> cardList = GoodsApi.toCardList(list);
    if(!mounted || seq != requestSeq) return;
    setState(() {
      // 刷新: 整页替换(旧数据一直留在屏幕上,直到新数据到位);加载更多: 追加
      if(refresh) {
        dataList = cardList;
      } else {
        dataList.addAll(cardList);
      }
      page += 1;
      hasMore = page <= pageCount;
      isLoading = false;
    });
  } catch (e) {
    if(!mounted || seq != requestSeq) return;
    setState(() {
      isLoading = false;
    });
    debugPrint('[index]商品列表加载失败: $e');
  }
}

// tab 下标 -> 一级分类id(0 表示推荐 tab)
int _categoryIdOfTab(int index) {
  if(index <= 0) return 0;
  final int position = index - 1;
  if(position >= categoryList.length) return 0;
  return int.tryParse('${categoryList[position]['category_id']}') ?? 0;
}

// 分类 tab 点击: 切换分类并重新拉第一页商品
void _onTabTap(int index) {
  final int categoryId = _categoryIdOfTab(index);
  if(categoryId == currentCategoryId) return;
  // 分类变了: 丢弃在途请求 + 重置分页
  requestSeq += 1;
  final int seq = requestSeq;
  setState(() {
    currentCategoryId = categoryId;
    dataList = [];
    page = 1;
    hasMore = true;
    isLoading = false;
  });
  // 首屏数据回来后再滚到 tab 吸顶位置: 列表清空瞬间滚动范围变小,
  // 此时滚动会被 clamp, tab 栏会掉出吸顶态(甚至看不见)
  loadMoreData().whenComplete(() {
    if(!mounted || seq != requestSeq) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToStickyTabs());
  });
}

// 滚动到 tab 吸顶位置: 让分类栏正好落在折叠后的 AppBar 正下方,且首个商品完整露出
// * 关键: precedingScrollExtent 已包含折叠后的 AppBar 高度(toolbarHeight 94),
//   若直接滚到 tabStickyOffset,会多滚 94px,导致首个商品顶到顶部、被吸顶的 AppBar/分类栏盖住一半。
//   所以目标要减去 AppBar 折叠高度,使商品停在分类栏下方,而不是被吸顶栏覆盖。
Future<void> _scrollToStickyTabs() async {
  if(!mounted || !scrollController.hasClients) return;
  final ScrollPosition position = scrollController.position;
  // 94.0 = SliverAppBar.toolbarHeight(折叠后高度),用于把首个商品推到分类栏下方
  final double target = (tabStickyOffset - 94.0).clamp(0.0, position.maxScrollExtent);
  if((position.pixels - target).abs() < 1.0) return;
  await scrollController.animateTo(
    target,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOutCubic,
  );
}

// 下拉刷新
// * 不清空列表: 旧商品一直留在屏幕上,新数据回来后整体替换,避免"列表空白 + 加载中"闪一下
Future<void> handleRefresh() async {
  // 丢弃在途的分页请求(其响应会因序号不匹配被丢弃,不会覆盖刷新结果)
  requestSeq += 1;
  page = 1;
  hasMore = true;
  isLoading = false;
  isRefreshing = true;
  try {
    await loadMoreData(refresh: true);
    // 顺带刷新秒杀板块(倒计时重新对时)
    await loadSeckill();
  } finally {
    isRefreshing = false;
    if(mounted) setState(() {});
  }
}

/// 首页扫码: 打开全屏扫码界面,扫到结果后弹窗展示并支持复制
Future<void> _handleScan(BuildContext context) async {
  final BarcodeCapture? capture = await showAiBarcodeScanner(
    context,
    // 组件文案默认是英文,逐项覆盖为中文
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
      scanHint: '将二维码放入框内,即可自动扫描',
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
  if (!mounted) return;
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('扫码结果'),
      content: SelectableText(code, style: const TextStyle(fontSize: 14.0)),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.of(ctx).pop();
            Get.snackbar('提示', '已复制到剪贴板');
          },
          child: const Text('复制'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
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

// 首页直播信息(无直播间时不展示直播板块): 拿到拉流地址后首页静音预览
// * 用 _liveLoading 防止并发重入: initState 的调用与生命周期 resumed 重试可能同时进入,
//   并发会互相 dispose 掉正在创建的 Player, 导致起播失败(封面一直盖着视频, 观感=不播放)
Future<void> loadLiveRoom() async {
  if (_liveLoading) return;
  _liveLoading = true;
  try {
  final Map<String, dynamic>? room = await LiveApi.topRoom();
  if(!mounted) return;
  setState(() {
    liveRoom = room;
  });
  final String src = room == null ? '' : '${room['push_link'] ?? ''}';
  if(src.isEmpty) return;
  // 重新加载时先释放上一个播放器
  // 注意: VideoController 没有 dispose,随 Player 释放
  liveReconnector?.dispose();
  await livePlayer?.dispose();
  final Player player = createLivePlayer();
  livePlayer = player;
  final LiveReconnector reconnector = LiveReconnector(
    player,
    // 重连时把封面显示回来: "首帧已渲染"后封面是隐藏的, 重连这几秒 Video 没画面就会露出白板
    onReconnecting: () {
      if (mounted) liveFirstFrame.value = false;
    },
  );
  liveReconnector = reconnector;
  // Android 配置见 androidLiveVideoConfig(mediacodec-copy)
  final VideoController controller = VideoController(
  player,
  configuration: isAndroidPlatform
    ? androidLiveVideoConfig
    : const VideoControllerConfiguration(),
  );
  liveVideoController = controller;
  liveFirstFrame.value = false;
  // 真机排障日志: 拉流地址 / 播放状态 / 解码尺寸
  // * 这些流(尤其 mpv log)回调非常频繁,release 下直接不订阅,省掉主线程的字符串处理开销
  if(kDebugMode) {
    debugPrint('[live]拉流地址: $src');
    player.stream.error.listen((String error) => debugPrint('[live]播放错误: $error'));
    // mpv 层日志: 只看报错 / 视频输出 / rtmp 相关
    player.stream.log.listen((PlayerLog log) {
      final String line = '${log.prefix}: ${log.text}';
      final String lower = line.toLowerCase();
      if(lower.contains('error') || lower.contains('fail') || lower.contains('rtmp') || lower.contains('vo:') || lower.contains('vo ') || lower.contains('gpu')) {
        debugPrint('[live][mpv] $line');
      }
    });
    player.stream.playing.listen((bool playing) => debugPrint('[live]playing=$playing'));
    player.stream.buffering.listen((bool buffering) => debugPrint('[live]buffering=$buffering'));
    player.stream.width.listen((int? width) {
      debugPrint('[live]视频尺寸: ${width ?? 0}x${player.state.height ?? 0}');
      // 不能用解码尺寸判定首帧: 拿到尺寸时纹理可能还没渲染, 这时隐藏封面会露出卡片白底(一块白板)
    });
    player.stream.videoParams.listen((VideoParams params) {
      debugPrint('[live]videoParams: ${params.dw}x${params.dh} rotate=${params.rotate}');
    });
  }
  // 视频输出诊断: 纹理id / 输出矩形 / 首帧是否真的渲染出来
  // * 首帧以"纹理已创建 / 首帧已渲染"为准, 才不会被过早隐藏封面
  controller.id.addListener(() {
    if(kDebugMode) debugPrint('[live]textureId=${controller.id.value}');
    // iOS 上 id 是视频 UIView 的 tag: 视图一创建就有值(此时还没有画面),
    // 拿它当"已出首帧"会在 iOS 上过早隐藏封面 -> 露出空白;
    // Android 的 id 是纹理 id(出画面才创建),照旧用它; iOS 只认 waitUntilFirstFrameRendered
    if(isAndroidPlatform && (controller.id.value ?? -1) > 0 && !liveFirstFrame.value) liveFirstFrame.value = true;
  });
  if(kDebugMode) controller.rect.addListener(() => debugPrint('[live]输出rect=${controller.rect.value}'));
  controller.waitUntilFirstFrameRendered.then((_) {
    if(kDebugMode) debugPrint('[live]首帧已渲染');
    if(mounted) liveFirstFrame.value = true;
  });
  await player.setVolume(0.0);
  if(!mounted) return;
  // 先把 Video 控件挂上树、等平台视图真正创建好,再起播
  // * iOS 的 Video 是平台视图(UiKitView): 起播之后再 setState 创建视图,
  //   画面会"一闪而过然后变空白"(视图创建时播放器已在播,画面接不上)
  setState(() {});
  await WidgetsBinding.instance.endOfFrame;
  if(!mounted) return;
  // 走 LiveReconnector: 抵消 Surface 重建触发的 seek 对 RTMP 直播的打断
  await reconnector.open(src, play: true);
  if(!mounted) return;
  // 卡片挂载可能晚于接口返回(此刻 liveCardKey.currentContext 还是 null): 首帧后再同步一次,
  // 否则这一轮同步会直接 return, 之后只有滚动才会恢复预览
  WidgetsBinding.instance.addPostFrameCallback((_) => syncLivePlayState());
  // 卡片若已滚出视口则不播放
  syncLivePlayState();
  } finally {
    _liveLoading = false;
  }
}

// 直播预览播放状态: 卡片滚出视口自动暂停,滚回视口恢复播放
void syncLivePlayState() {
  final Player? player = livePlayer;
  if(player == null) return;
  final BuildContext? cardContext = liveCardKey.currentContext;
  if(cardContext == null) return;
  final RenderObject? cardObject = cardContext.findRenderObject();
  if(cardObject is! RenderBox || !cardObject.attached) return;
  // 用全局坐标求卡片矩形与视口矩形的交集,避免吸顶 AppBar 造成的偏移误差
  final RenderObject? viewObject = RenderAbstractViewport.of(cardObject);
  if(viewObject is! RenderBox || !viewObject.attached) return;
  final Rect cardRect = cardObject.localToGlobal(Offset.zero) & cardObject.size;
  final Rect viewRect = viewObject.localToGlobal(Offset.zero) & viewObject.size;
  final bool visible = cardRect.intersect(viewRect).height > 0;
  if(visible) {
    if(!player.state.playing) {
      debugPrint('[index]直播卡片进入视口,恢复预览');
      player.play();
    }
  } else if(player.state.playing) {
    debugPrint('[index]直播卡片离开视口,暂停预览');
    player.pause();
  }
}

// 直播间字段取值(真实字段名待确认: 按候选键依次取,取不到用默认文案)
String liveText(List<String> keys, String fallback) {
  final Map<String, dynamic> room = liveRoom ?? const <String, dynamic>{};
  for(final String key in keys) {
    final String val = '${room[key] ?? ''}'.trim();
    if(val.isNotEmpty && val != 'null') return val;
  }
  return fallback;
}

// 直播间封面 feeds_img(相对路径补全域名,取不到返回空)
String get liveCover {
  final String cover = liveText(const ['feeds_img', 'cover', 'cover_img'], '');
  return cover.isEmpty ? '' : LiveApi.fixImage(cover);
}

// 主播头像 anchor_img
String get liveAnchorImg {
  final String img = liveText(const ['anchor_img'], '');
  return img.isEmpty ? '' : LiveApi.fixImage(img);
}

// 副标题: 接口无 slogan 字段,有主播名时展示主播,否则用默认文案
String get liveSubtitle {
  final String anchor = liveText(const ['anchor_name'], '');
  return anchor.isEmpty ? '创新设计 享受品质生活' : '主播 $anchor';
}

// 直播卡片背景: 有封面用封面,否则用渐变兜底
Widget liveBg() {
  final BoxDecoration decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF7A1418), Color(0xFF3A0708)],
    ),
  );
  if (liveCover.isEmpty) return Container(decoration: decoration);
  return CachedNetworkImage(
    imageUrl: liveCover,
    // 限制解码尺寸(卡片宽约 200 逻辑像素,高清屏按 3x 折算)
    memCacheWidth: 720,
    fit: BoxFit.cover,
    placeholder: (BuildContext context, String url) => Container(decoration: decoration),
    errorWidget: (BuildContext context, String url, Object error) => Container(decoration: decoration),
  );
}

@override
void initState() {
  super.initState();
  scrollController.addListener(_onScroll);

  // 已登录但会员信息为空(启动时拉取失败): 补拉一次, 避免门店绑定状态拿不到还显示"去绑定门店"
  if (Get.isRegistered<AuthStore>() && AuthStore.to.isLogin && AuthStore.to.memberInfo.isEmpty) {
    AuthStore.to.loadMemberInfo();
  }

  // 初始化加载
  handleRefresh();
  // 首页直播信息
  loadLiveRoom();
  // 首页限时秒杀板块
  loadSeckill();
  // 首页 tab 分类(一级分类树)
  loadCategory();
  // 首页聚合配置(banner / nav / popup)
  loadIndexConfig();
  // 购物车数量(搜索栏角标)
  loadCartCount();
  // 秒杀倒计时(每秒局部刷新)
  seckillTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSeckill());

  // 监听 App 生命周期: iOS 首次网络授权后 resumed 触发首页重试
  WidgetsBinding.instance.addObserver(this);

  // 监听网络可用性: 网络从无到有时重刷首页(监听授权后网络真正可用)
  try {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  } catch (e) {
    debugPrint('[index] 网络监听注册异常: $e');
  }
  }

  // 首页 tab 分类: 取一级分类树(/api/goodscategory/tree)
  // * 第一个 tab 固定「推荐」(对应首页瀑布流), 后面接接口返回的分类
  // * 接口失败/为空时保留默认 tabList, 不影响首页
  Future<void> loadCategory() async {
    try {
      final List<Map<String, dynamic>> list = await GoodsApi.categoryTree();
      if (!mounted || list.isEmpty) return;
      final List<String> tabs = <String>['推荐'];
      for (final Map<String, dynamic> item in list) {
        final String name = '${item['category_name'] ?? ''}'.trim();
        if (name.isNotEmpty) tabs.add(name);
      }
      if (tabs.length < 2) return;
      setState(() {
        categoryList = list;
        tabList = tabs;
        // tab 内容变了: 作废吸顶 header 缓存,否则 TabBar 还是旧的 tabs
        _stickyTabsHeader = null;
        _normalTabsHeader = null;
        // 控制器由外层 DefaultTabController(length: tabList.length) 托管,
        // tabList 一变,其 length 自动跟随,无需手动重建/释放
      });
    } catch (_) {
      // 分类加载失败保留默认 tab
    }
  }

  /// 首页聚合配置: /api/index/index 的 banner_info / nav_info / popup_info
  Future<void> loadIndexConfig() async {
    try {
      final Map<String, dynamic> data = await IndexApi.index();
      if (!mounted) return;
      setState(() {
        bannerList = (data['banner_info'] as List? ?? const []).toList();
        navList = (data['nav_info'] as List? ?? const []).toList();
        popupInfo = data['popup_info'] is Map
            ? Map<String, dynamic>.from(data['popup_info'] as Map)
            : <String, dynamic>{};
      });
      // 弹窗: 仅首次进入弹一次
      if (!_popupShown &&
          popupInfo.isNotEmpty &&
          '${popupInfo['state']}' == '1' &&
          '${popupInfo['adv_image'] ?? ''}'.isNotEmpty) {
        _showPopupAd();
      }
    } catch (e) {
      debugPrint('[index]首页配置加载失败: $e');
    }
  }

  /// 购物车商品数量(用于搜索栏购物车角标)
  Future<void> loadCartCount() async {
    try {
      final int total = await CartApi.count();
      if (!mounted) return;
      setState(() => cartCount = total);
    } catch (e) {
      debugPrint('[index]购物车数量加载失败: $e');
    }
  }

  /// 启动弹窗广告
  void _showPopupAd() {
    _popupShown = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final String img = '${popupInfo['adv_image'] ?? ''}';
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (BuildContext ctx) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleNavUrl('${popupInfo['adv_url'] ?? ''}');
                },
                child: CachedNetworkImage(
                  imageUrl: img,
                  width: 300.0,
                  fit: BoxFit.contain,
                  placeholder: (BuildContext c, String u) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16.0),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.black54, size: 22.0),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 解析 nav_url / adv_url(JSON 字符串) 中的 name 跳转到对应页面
  void _handleNavUrl(String navUrlJson) {
    if (navUrlJson.isEmpty) return;
    Map<String, dynamic>? info;
    try {
      info = jsonDecode(navUrlJson) as Map<String, dynamic>?;
    } catch (_) {
      return;
    }
    if (info == null) return;
    final String name = '${info['name'] ?? ''}';
    switch (name) {
      case 'SIGN_IN':
        Get.toNamed('/my/signin');
        break;
      case 'SECKILL_PREFECTURE':
        Get.toNamed('/seckill');
        break;
      case 'GOODS_CATEGORY_PAGE':
        final String cid = '${info['category_id'] ?? ''}';
        Get.toNamed('/goods', arguments: <String, dynamic>{'category_id': cid});
        break;
      case 'MEMBER_CENTER':
        Get.toNamed('/my/wallet');
        break;
      default:
        Get.snackbar('提示', name.isNotEmpty ? '跳转:$name' : '该入口暂未配置',
            snackPosition: SnackPosition.BOTTOM);
    }
  }

  // 首页限时秒杀板块: 取当前(或最近一场)场次的前 10 个商品
  Future<void> loadSeckill() async {
    try {
      final Map<String, dynamic> res = await SeckillApi.timeList();
      final List<SeckillTime> times = (res['list'] as List? ?? const []).cast<SeckillTime>();
      if (times.isEmpty) return;
      final int timestamp = int.tryParse('${res['timestamp'] ?? 0}') ?? 0;
      final DateTime serverTime = timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          : DateTime.now();
      seckillServerSeconds = serverTime.hour * 3600 + serverTime.minute * 60 + serverTime.second;
      seckillSyncedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // 优先展示进行中的场次,其次即将开始的场次
      SeckillTime time = times.first;
      for (final SeckillTime t in times) {
        if (t.isNow(seckillServerSeconds)) {
          time = t;
          break;
        }
      }
      // 用 lists(不分页) —— page 接口会漏商品且 goods_stock 返回负值
      final List<Map<String, dynamic>> goods = await SeckillApi.goodsList(
        seckillTimeId: time.id,
        type: time.type,
      );
      if (!mounted) return;
      setState(() {
        seckillTime = time;
        seckillGoods = goods.take(10).toList();
      });
      _tickSeckill();
    } catch (_) {
      // 秒杀板块加载失败不阻塞首页
    }
  }

  // 秒杀倒计时: 每秒更新剩余秒数(只对时一次,之后按本机时间推算)
  void _tickSeckill() {
    final SeckillTime? time = seckillTime;
    if (time == null) return;
    final int now = seckillServerSeconds + (DateTime.now().millisecondsSinceEpoch ~/ 1000 - seckillSyncedAt);
    seckillStatus = time.statusOf(now);
    final int remain = seckillStatus == 1 ? time.endTime - now : time.remainSeconds(now);
    seckillRemain.value = remain < 0 ? 0 : remain;
  }

  // 秒杀倒计时文案(距结束 / 距开场)
  Widget _buildSeckillCountDown(int remain) {
    final String tip = seckillStatus == 1 ? '距结束' : (seckillStatus == 0 ? '已结束' : '距开场');
    final int h = remain ~/ 3600;
    final int m = (remain % 3600) ~/ 60;
    final int s = remain % 60;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tip, style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0)),
          if (seckillStatus != 0) ...[
            SizedBox(width: 4.0),
            Text(_two(h), style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0, fontWeight: FontWeight.w700, fontFamily: 'Arial')),
            Text(':', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0)),
            Text(_two(m), style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0, fontWeight: FontWeight.w700, fontFamily: 'Arial')),
            Text(':', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0)),
            Text(_two(s), style: TextStyle(color: Color(0xFFFF2C55), fontSize: 11.0, fontWeight: FontWeight.w700, fontFamily: 'Arial')),
          ],
        ],
      ),
    );
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  // 秒杀商品卡(首页板块): 图 + 标题 + 秒杀价 + 原价
  Widget _buildSeckillItem(Map<String, dynamic> item) {
    final String image = '${item['image'] ?? ''}';
    final num seckillPrice = item['seckillPrice'] as num? ?? 0;
    final num price = item['price'] as num? ?? 0;
    final int stock = (item['stock'] as num? ?? 0).toInt();
    return GestureDetector(
      onTap: () => Get.toNamed('/seckill/detail', arguments: <String, dynamic>{'seckillId': item['id']}),
      child: SizedBox(
        width: 104.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: image.isEmpty
                    ? Container(
                        width: 104.0,
                        height: 104.0,
                        color: Colors.grey[100],
                        alignment: Alignment.center,
                        child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 26.0),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        // 限制解码尺寸(104 逻辑像素小图)
                        memCacheWidth: 320,
                        width: 104.0,
                        height: 104.0,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 104.0, height: 104.0, color: Colors.grey[100]),
                        errorWidget: (context, url, error) => Container(
                          width: 104.0,
                          height: 104.0,
                          color: Colors.grey[100],
                          alignment: Alignment.center,
                          child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 26.0),
                        ),
                      ),
                ),
                if (stock <= 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(110),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      alignment: Alignment.center,
                      child: Text('已抢完', style: TextStyle(color: Colors.white, fontSize: 12.0)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 5.0),
            Text(
              '${item['title'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.0, color: Colors.black87),
            ),
            SizedBox(height: 2.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('¥', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 10.0)),
                Text(
                  seckillPrice.toStringAsFixed(2),
                  style: TextStyle(color: Color(0xFFFF2C55), fontSize: 15.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                ),
                if (price > seckillPrice) ...[
                  SizedBox(width: 4.0),
                  Text(
                    '¥${price.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey, fontSize: 10.0, decoration: TextDecoration.lineThrough),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 吸顶 tab 板块: 始终占 45 高
  // * 未吸顶时也不再隐藏(之前返回 0 高度,导致不滚动到顶就看不到分类、且要滚过商品才吸顶),
  //   现在在流里就显示,滚到顶部时吸顶固定,出现更早
  Widget _buildStickyTabs(bool sticky) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: CustomStickyHeader(
        child: PreferredSize(
          preferredSize: const Size.fromHeight(45.0),
          child: Container(
            color: Color(0xFFFCF7EE),
            height: 45.0,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    // 点击分类 tab: 拉取该分类下的商品(/api/goodssku/page)
                    onTap: _onTabTap,
                    tabs: tabList.map((String v) => Tab(text: v)).toList(),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    unselectedLabelColor: Colors.black87,
                    labelColor: const Color(0xFFFF2C55),
                    indicatorColor: const Color(0xFFFF2C55),
                    indicatorSize: TabBarIndicatorSize.tab,
                    unselectedLabelStyle: const TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei'),
                    labelStyle: const TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                    dividerHeight: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                  ),
                ),
                // 切换商品列表布局(瀑布流 / 横向单列)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isHorizontalList = !isHorizontalList;
                    });
                  },
                  child: Container(
                    width: 44.0,
                    alignment: Alignment.center,
                    child: Icon(
                      isHorizontalList ? Icons.grid_view_rounded : Icons.view_list_rounded,
                      size: 22.0,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 金刚区: 后端 nav_info 渲染(图片图标 + 名称 + 点击跳转), 每页 5 个翻页
  // 金刚区: 后端 nav_info 渲染(图片图标 + 名称 + 点击跳转), 每页 4 个翻页
  Widget _buildNavGrid() {
    return PageView.builder(
      controller: pageController,
      itemCount: (navList.length / 4).ceil(),
      itemBuilder: (BuildContext context, int index) {
        final int start = index * 4;
        final int end = min(start + 4, navList.length);
        final List group = navList.sublist(start, end);
        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 94.0,
            crossAxisSpacing: 0.0,
            mainAxisSpacing: 12.0,
          ),
          itemCount: group.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> n = group[i] as Map<String, dynamic>;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleNavUrl('${n['nav_url'] ?? ''}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                alignment: Alignment.center,
                child: Column(
                  spacing: 4.0,
                  children: [
                    CachedNetworkImage(
                      imageUrl: '${n['nav_image'] ?? ''}',
                      width: 48.0,
                      height: 48.0,
                      fit: BoxFit.contain,
                      placeholder: (BuildContext c, String u) => const SizedBox.shrink(),
                      errorWidget: (BuildContext c, String u, Object e) =>
                          const Icon(Icons.image, size: 48.0, color: Colors.grey),
                    ),
                    Text('${n['nav_name'] ?? ''}', style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeRetryTimer?.cancel();
    _connectivitySub?.cancel();
    scrollController.dispose();
    seckillTimer?.cancel();
    liveScrollIdleTimer?.cancel();
    liveReconnector?.dispose();
    livePlayer?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryReloadOnResume();
    }
  }

  /// 网络可用性变化: 仅在「无网络 -> 有网络」跳变时重刷首页
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.isEmpty) return;
    final ConnectivityResult current = results.first;
    final ConnectivityResult? last = _lastConnectivity;
    _lastConnectivity = current;
    // 状态未变化则跳过(避免重复触发)
    if (last != null && last == current) return;
    if (current == ConnectivityResult.none) return;
    debugPrint('[index] 网络恢复($current), 触发首页重刷');
    _tryReloadOnResume();
  }

  /// iOS 首次安装: 网络授权弹窗后 App resumed, 若首页关键数据仍为空则自动重试
  void _tryReloadOnResume() {
    if (!mounted) return;
    // 数据已就绪则不再重试
    if (dataList.isNotEmpty && bannerList.isNotEmpty && categoryList.isNotEmpty) return;
    if (_resumeRetryCount >= _maxResumeRetries) return;
    _resumeRetryTimer?.cancel();
    _resumeRetryTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      // 500ms 后再次检查, 防止在途请求已返回
      if (dataList.isNotEmpty && bannerList.isNotEmpty && categoryList.isNotEmpty) return;
      _resumeRetryCount += 1;
      debugPrint('[index] 生命周期 resumed, 首页数据为空, 触发第 $_resumeRetryCount 次重试');
      handleRefresh();
      loadLiveRoom();
      loadSeckill();
      loadCategory();
      loadIndexConfig();
      loadCartCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Color(0xFFFCF7EE),
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: RefreshIndicator(
        backgroundColor: Color(0xFFFCF7EE),
        color: Color(0xFFFF2C55),
        displacement: 10.0,
        onRefresh: handleRefresh,
        child: DefaultTabController(
          length: tabList.length,
          child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: Color(0xFFFCF7EE),
              foregroundColor: Colors.black87,
              pinned: true,
              toolbarHeight: 94.0,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
              titleSpacing: 0.0,
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 第一行: logo | 内部门店
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/home_logo.png',
                          width: 124.0,
                          height: 38.0,
                          fit: BoxFit.contain,
                          isAntiAlias: true,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(width: 110.0, height: 34.0),
                        ),
                        Spacer(),
                        Obx(() {
                          final bool bound = AuthStore.to.hasStore;
                          final String name = AuthStore.to.storeName;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(15.0),
                              onTap: () {
                                if (!bound) {
                                  Get.toNamed('/bind_store');
                                  return;
                                }
                                final int sid = AuthStore.to.storeId.value;
                                if (sid == 0) {
                                  Get.snackbar('提示', name.isNotEmpty ? '已绑定门店：$name' : '已绑定门店');
                                  return;
                                }
                                Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': sid});
                              },
                              child: Container(
                                padding: EdgeInsets.fromLTRB(4.0, 3.0, 8.0, 3.0),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.store, color: Colors.white, size: 13.0),
                                    SizedBox(width: 4.0),
                                    Text(bound ? '内部门店' : '绑定门店', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w500)),
                                    Icon(Icons.chevron_right, color: Colors.white, size: 14.0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.0),
                  // 搜索框 + 购物车(在搜索框外右侧)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36.0,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30.0),
                              border: Border.all(color: Color(0xFFEEEEEE), width: 1.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 8.0,
                                  offset: Offset(0.0, 2.0),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 12.0),
                                Icon(Icons.search, color: Color(0xFF999999), size: 20.0),
                                SizedBox(width: 8.0),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '请输入关键字搜索',
                                      hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14.0),
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    style: TextStyle(fontSize: 15.0),
                                    cursorColor: Color(0xFFFF2C55),
                                    onChanged: (val) => debugPrint(val),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _handleScan(context),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Image.asset('assets/images/icon_sm.png', width: 22.0, height: 22.0, fit: BoxFit.contain, isAntiAlias: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 10.0),
                        InkWell(
                          onTap: () => Get.toNamed('/cart'),
                          child: Padding(
                            padding: EdgeInsets.only(right: 2.0),
                            child: Badge.count(
                              count: cartCount,
                              isLabelVisible: cartCount > 0,
                              backgroundColor: Color(0xFFFB431D),
                              child: Image.asset('assets/images/newico/cat-ico.png', width: 24.0, height: 24.0, fit: BoxFit.contain, isAntiAlias: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 轮播图卡片
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 6.0),
                height: 150.0,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Stack(
                  children: <Widget>[
                    PageView(
                      controller: bannerController,
                      children: bannerList.isEmpty
                          ? <Widget>[Container(color: Color(0xFFFF9C55))]
                          : bannerList.map<Widget>((dynamic b) {
                              final String img = '${b['adv_image'] ?? ''}';
                              return GestureDetector(
                                onTap: () => _handleNavUrl('${b['adv_url'] ?? ''}'),
                                child: CachedNetworkImage(
                                  imageUrl: img,
                                  memCacheWidth: 1080,
                                  placeholder: (BuildContext c, String u) => Container(color: Color(0xFFFF9C55)),
                                  fit: BoxFit.cover,
                                ),
                              );
                            }).toList(),
                    ),
                    // 轮播下标
                    Positioned(
                      left: 0.0,
                      right: 0.0,
                      bottom: 8.0,
                      child: IgnorePointer(
                        child: CustomPageViewIndicator(
                          controller: bannerController,
                          count: bannerList.isEmpty ? 1 : bannerList.length,
                          color: const Color(0xFFCECECE),
                          activeColor: const Color(0xFFFF2C55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 金刚区(来自 /api/index/index 的 nav_info;每页 5 个, 可翻页)
          if (navList.isNotEmpty) SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(10.0, 6.0, 10.0, 10.0),
              height: 112.0,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: _buildNavGrid(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0, top: 2.0),
                    child: CustomPageViewIndicator(
                      controller: pageController,
                      count: (navList.length / 4).ceil(),
                      color: const Color(0xFFCECECE),
                      activeColor: const Color(0xFFFF2C55),
                    ),
                  ),
                ],
              ),
            ),
          ),

            // App直播板块(无直播间时隐藏)
            if (liveRoom != null) SliverToBoxAdapter(
              child: Container(
                key: liveCardKey,
                margin: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Text('App', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 20.0, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontFamily: 'Arial')),
                        Text('直播', style: TextStyle(color: Colors.black87, fontSize: 20.0, fontWeight: FontWeight.w900)),
                        Spacer(),
                        GestureDetector(
                          onTap: () => Get.to(() => const LivePage()),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('全部', style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                              Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.0),
                    // 直播卡片(点击跳转直播页面)
                    GestureDetector(
                      onTap: () {
                        // 携带直播间信息: sn 房间号(即 getRoomInfo 的 no 参数)
                        // src 拉流地址(push_link) / name 标题
                        // 进直播间前暂停首页预览,返回后恢复
                        livePlayer?.pause();
                        Get.toNamed('/live', arguments: <String, dynamic>{
                          'sn': liveText(const ['sn'], ''),
                          'name': liveText(const ['name'], ''),
                          'src': liveText(const ['push_link'], ''),
                          // 横竖屏: getTopRoom 的 type(horizontal 横屏), 进直播间后由 getRoomInfo 再校准
                          'type': liveText(const ['type'], ''),
                          // 封面: 进房先拿首页这张, 避免等 getRoomInfo 返回期间露出黑底
                          'cover': liveCover,
                        })?.then((dynamic _) {
                          // 返回首页后恢复预览,若卡片已滚出视口则下一次滚动时再暂停
                          livePlayer?.play();
                          syncLivePlayState();
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Column(
                        children: [
                          // 直播画面
                          SizedBox(
                            height: 200.0,
                            child: Stack(
                              children: [
                                // 背景: 有封面用封面,无封面用渐变;已出帧则隐藏,避免封面盖住画面
                                ValueListenableBuilder<bool>(
                                  valueListenable: liveFirstFrame,
                                  builder: (BuildContext context, bool hasFrame, Widget? child) {
                                    return hasFrame ? const SizedBox.shrink() : Positioned.fill(child: liveBg());
                                  },
                                ),
                                // 直播画面(首页静音预览)
                                if (liveVideoController != null)
                                  Positioned.fill(
                                    child: Video(
                                      controller: liveVideoController!,
                                      fit: BoxFit.cover,
                                      // 无控制条
                                      controls: NoVideoControls,
                                      // 没出帧时用深色兜底: 默认透明会露出卡片白底, 观感就是一块白板
                                      fill: const Color(0xFF2A0A0B),
                                    ),
                                  ),
                                // 观看人数 + 直播中标签
                                Positioned(
                                  top: 10.0,
                                  left: 10.0,
                                  right: 10.0,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(110),
                                          borderRadius: BorderRadius.circular(20.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.videocam, color: Colors.white, size: 13.0),
                                            SizedBox(width: 4.0),
                                            Text('${liveText(const ['online'], '0')}观看', style: TextStyle(color: Colors.white, fontSize: 11.0)),
                                          ],
                                        ),
                                      ),
                                      Spacer(),
                                      // 直播中: 红底白点, 一眼看出在播
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFF2C55),
                                          borderRadius: BorderRadius.circular(20.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LivePlayingBars(color: Colors.white, height: 11.0),
                                            SizedBox(width: 5.0),
                                            Text('直播中', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 信息区: 标题/副标题/看直播在画面正中(水平 + 垂直都居中)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                    child: Center(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(18.0),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_arrow_rounded, color: Color(0xFFFF2C55), size: 18.0),
                                                SizedBox(width: 4.0),
                                                Text('点击看直播', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 14.0, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 官方直播条: 头像 + 主播名/福利文案(两行) + 进入
                          Container(
                            height: 54.0,
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            color: Colors.white,
                            child: Row(
                              children: [
                                Container(
                                  width: 34.0,
                                  height: 34.0,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFE1E5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: liveAnchorImg.isEmpty
                                    ? Image.asset('assets/images/logo.png', fit: BoxFit.contain, isAntiAlias: true)
                                    : CachedNetworkImage(
                                        imageUrl: liveAnchorImg,
                                        memCacheWidth: 160,
                                        fit: BoxFit.cover,
                                        errorWidget: (BuildContext context, String url, Object error) =>
                                            Image.asset('assets/images/logo.png', fit: BoxFit.contain, isAntiAlias: true),
                                      ),
                                ),
                                SizedBox(width: 10.0),
                                // 名称 + 福利文案竖排: 名称再长也不会把右侧挤出去了
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        liveText(const ['anchor_name', 'shop_name', 'nickname'], '惠买官方直播'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Color(0xFF222222), fontSize: 15.0, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 2.0),
                                      Text(
                                        '限时福利特惠',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),
                                      ),
                                    ],
                                  ),
                                ),
                                // 原来的心形圆按钮只是装饰(点了没反应), 换成"进入"更明确
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFF2C55),
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                  child: Text('进入', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 限时秒杀板块(无场次/无商品时不展示)
            if (seckillGoods.isNotEmpty) SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
                padding: EdgeInsets.fromLTRB(10.0, 12.0, 10.0, 12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题行: 限时秒杀 + 倒计时 + 更多
                    GestureDetector(
                      onTap: () => Get.toNamed('/seckill'),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: Color(0xFFFF2C55), size: 20.0),
                          SizedBox(width: 4.0),
                          Text('限时秒杀', style: TextStyle(color: Colors.black87, fontSize: 18.0, fontWeight: FontWeight.w900)),
                          SizedBox(width: 8.0),
                          ValueListenableBuilder<int>(
                            valueListenable: seckillRemain,
                            builder: (BuildContext context, int remain, Widget? child) {
                              return _buildSeckillCountDown(remain);
                            },
                          ),
                          Spacer(),
                          Text('更多', style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                          Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.0),
                    // 秒杀商品(横向滑动)
                    SizedBox(
                      height: 154.0,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: seckillGoods.length,
                        separatorBuilder: (BuildContext context, int index) => SizedBox(width: 10.0),
                        itemBuilder: (BuildContext context, int index) => _buildSeckillItem(seckillGoods[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // tabbar列表(默认不显示, 滑动到吸顶位置时显示)
            SliverLayoutBuilder(
              builder: (BuildContext context, SliverConstraints constraints) {
                // scrollOffset > 0 表示该板块已经滑到顶部(即吸顶)
                final bool sticky = constraints.scrollOffset > 0;
                // 记录吸顶偏移(该板块到达视口顶部的滚动偏移), 供切分类后回滚定位使用
                tabStickyOffset = constraints.precedingScrollExtent;
                // SliverLayoutBuilder 滚动中每帧都会回调: 同状态复用缓存的 header,
                // 不再每帧重建 TabBar 子树(之前每帧都在重建,是滑动掉帧的来源之一)
                return sticky
                  ? (_stickyTabsHeader ??= _buildStickyTabs(true))
                  : (_normalTabsHeader ??= _buildStickyTabs(false));
              },
            ),

            // 商品列表(瀑布流 / 横向单列可切换)
            SliverPadding(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              sliver: isHorizontalList
                ? SliverList.separated(
                    itemCount: dataList.length,
                    itemBuilder: (BuildContext context, int index) => SizedBox(width: double.infinity, child: CardItem(item: dataList[index], horizontal: true)),
                    separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10.0),
                  )
                : SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childCount: dataList.length,
                    itemBuilder: (BuildContext context, int index) => CardItem(item: dataList[index]),
                  ),
            ),
          SliverToBoxAdapter(
            child: isLoading && !isRefreshing
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Loading(title: '加载中...'),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 40),
                  child: Center(
                    child: dataList.isEmpty
                        ? const CommonEmpty(text: '暂无商品', imageWidth: 80.0)
                        : (hasMore
                            ? const SizedBox.shrink()
                            : const Text('没有更多了', style: TextStyle(color: Colors.grey, fontSize: 12.0))),
                  ),
                ),
            ),
            // 兜底: 分类返回数据很少(甚至为空)时,内容高度可能不足一屏,
            // 列表无法滚动到 tab 吸顶位置,导致 tab 栏(只在吸顶时显示)消失、切不回去。
            // 这里补一段高度,保证页面始终能滚动到吸顶位置,tab 栏始终可达。
            if (dataList.length < pageSize)
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).size.height),
              ),
          ],
        ),
        ),
      ),
    ),
    // 返回顶部
    floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}
}

// 卡片组件
class CardItem extends StatelessWidget {
final dynamic item;
// 是否横向布局(左图右文)
final bool horizontal;
const CardItem({super.key, required this.item, this.horizontal = false});

@override
Widget build(BuildContext context) {
  return GestureDetector(
    child: Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: horizontal ? _buildHorizontal() : _buildVertical(),
    ),
    onTap: () {
      // 携带商品id跳转详情(接口按 query 传 goods_id)
      Get.toNamed('/goods', arguments: {'goodsId': item['id']});
    },
  );
  }

  // 竖向卡片(图片在上)
  Widget _buildVertical() {
    return Column(
      children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
      child: CachedNetworkImage(
        imageUrl: '${item['image']}',
        // 限制解码尺寸(瀑布流两列,约 180 逻辑像素)
        memCacheWidth: 540,
        placeholder: (context, url) => Container(
          height: 150.0,
          color: const Color(0xFFEEEEEE),
        ),
        errorWidget: (context, url, error) => Container(
          height: 150.0,
          color: const Color(0xFFEEEEEE),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30.0),
        ),
      ),
    ),
    _buildInfo(),
      ],
    );
  }

  // 横向大卡片(图片全宽 + 角标 + 底部直播横幅 + 标题/价格/马上抢)
  Widget _buildHorizontal() {
    // 划线价(后端 market_price 为 0 时按现价上浮兜底)
    final num priceNum = (item['price'] as num);
    final num marketPriceNum = (item['marketPrice'] as num?) ?? 0;
    final int originalPrice = marketPriceNum > 0 ? marketPriceNum.round() : (priceNum * 1.3).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 大图(占满宽度, 高度按宽度自适应)
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
          child: CachedNetworkImage(
            imageUrl: '${item['image']}',
            // 限制解码尺寸(整屏宽大图)
            memCacheWidth: 1080,
            width: double.infinity,
            height: 220.0,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 220.0,
              color: const Color(0xFFEEEEEE),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 220.0,
              color: const Color(0xFFEEEEEE),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36.0),
            ),
          ),
        ),
        // 信息区: 标题 + 价格 + 马上抢
        Container(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 第一排: 商品标题
              Text('${item['title']}', style: const TextStyle(fontSize: 15.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8.0),
              // 第二排: 金额(现价 + 划线价) + 马上抢
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, height: 1.0, fontWeight: FontWeight.w700, fontFamily: 'Arial'),
                            children: [
                              const TextSpan(text: '¥'),
                              TextSpan(text: '${item['price']}', style: const TextStyle(fontSize: 20.0, height: 1.0)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text('¥$originalPrice', style: const TextStyle(color: Colors.grey, fontSize: 12.0, height: 1.0, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  // 马上抢按钮
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2C55),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: const Text('马上抢', style: TextStyle(color: Colors.white, fontSize: 14.0, height: 1.0, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 图文信息(标题/价格/销量/店铺)
  Widget _buildInfo() {
    return Container(
      padding: EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5.0,
      children: [
        Text('${item['title']}', style: TextStyle(fontSize: 15.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis,),
      Row(
        spacing: 5.0,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(color: Colors.red, fontSize: 12.0, fontWeight: FontWeight.w700, fontFamily: 'Arial'),
              children: [
                TextSpan(text: '¥'),
                TextSpan(text: '${item['price']}', style: TextStyle(fontSize: 16.0,)),
              ]
            ),
          ),
            Text('已售${item['saleNum']}件', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
          ],
        ),
          // 店铺(接口无店铺名时隐藏)
          if ('${item['shop']}'.isNotEmpty)
            Text('${item['shop']}', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
        ],
        ),
        );
  }
}
