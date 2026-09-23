/// 首页模板
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/custom_sticky_header.dart';
import '../../components/loading.dart';
import '../../components/backtop.dart';
import '../../components/custom_pageview_indicator.dart';
import '../../utils/player_config.dart';
import '../../api/goods.dart';
import '../../api/live.dart';
import '../../api/seckill.dart';
import '../../controller/auth_store.dart';
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});
  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with SingleTickerProviderStateMixin {
  // 分类列表
  List cateList = [
    {
    'id': 1,
  'list': [
    { 'icon': 'assets/images/svg/huiyuan.svg', 'label': '每日签到' },
    { 'icon': 'assets/images/svg/dianpu.svg', 'label': '刷短剧' },
    { 'icon': 'assets/images/svg/shoucang.svg', 'label': '看小说' },
    { 'icon': 'assets/images/svg/shiyong.svg', 'label': '看直播' }

  ]
},
{
  'id': 2,
  'list': [
    { 'icon': 'assets/images/svg/order.svg', 'label': '我的订单', 'count': '待发货2' },
    { 'icon': 'assets/images/svg/chongzhi.svg', 'label': '充值中心', 'count': '减10元' },
    { 'icon': 'assets/images/svg/coupon.svg', 'label': '券红包' },
    { 'icon': 'assets/images/svg/cart.svg', 'label': '购物车' }
  ]
},
{
  'id': 3,
  'list': [
    { 'icon': 'assets/images/svg/kefu.svg', 'label': '客服消息' },
    { 'icon': 'assets/images/svg/tuikuan.svg', 'label': '退款/售后' },
    { 'icon': 'assets/images/svg/comment.svg', 'label': '评价中心' },
    { 'icon': 'assets/images/svg/seckill.svg', 'label': '限时秒杀' }
    ]
    }
  ];

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
  // 请求序号: 切换分类时自增, 用于丢弃在途的旧请求响应
  int requestSeq = 0;
  // tab 板块的吸顶滚动偏移(SliverLayoutBuilder 布局时记录, 即该 sliver 到达视口顶部的偏移)
  double tabStickyOffset = 0;

  // 首页直播信息(无直播间时为 null,直播板块不展示)
  Map<String, dynamic>? liveRoom;
  // 首页直播预览播放器(静音播放 push_link,点进直播间才有声音)
  Player? livePlayer;
  VideoController? liveVideoController;
  LiveReconnector? liveReconnector;
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

  // 首页 tab 分类(来自 /api/goodscategory/tree 一级分类)
  List<Map<String, dynamic>> categoryList = [];

late ScrollController scrollController = ScrollController();
late TabController tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);
final PageController pageController = PageController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);
// 上次直播可见性检测时间(毫秒): 滚动中节流,避免每帧做 RenderObject 计算
int liveCheckedAt = 0;
// TabBar 的 Tab 列表(随 tabList 预生成,避免滚动中每帧重建都重新 map)
late List<Widget> tabWidgets = _buildTabWidgets(tabList);

List<Widget> _buildTabWidgets(List<String> tabs) =>
    tabs.map((String v) => Tab(text: v)).toList();

// 滚动回调: 每一帧都会执行,只放轻量逻辑
void _onScroll() {
  scrollOffset.value = scrollController.offset;
  // 直播预览: 卡片进出视口时暂停/恢复播放,按时间节流(RenderObject 计算较重)
  if(livePlayer != null) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if(now - liveCheckedAt >= 120) {
      liveCheckedAt = now;
      syncLivePlayState();
    }
  }
  // 提前一屏触发加载更多,避免滑到底部才发请求造成停顿
  if(isLoading || !hasMore) return;
  final ScrollPosition position = scrollController.position;
  if(position.maxScrollExtent - position.pixels <= 300) {
    loadMoreData();
  }
}
// 加载更多(上拉触底 / 首次进入)
Future<void> loadMoreData() async {
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
      dataList.addAll(cardList);
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

// 滚动到 tab 吸顶位置(吸顶判定为 scrollOffset > 0, 所以 +1 保证落在吸顶态)
Future<void> _scrollToStickyTabs() async {
  if(!mounted || !scrollController.hasClients) return;
  final ScrollPosition position = scrollController.position;
  final double target = (tabStickyOffset + 1.0).clamp(0.0, position.maxScrollExtent);
  if((position.pixels - target).abs() < 1.0) return;
  await scrollController.animateTo(
    target,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOutCubic,
  );
}

// 下拉刷新
Future<void> handleRefresh() async {
  page = 1;
  hasMore = true;
  setState(() {
    dataList.clear();
  });
  await loadMoreData();
  // 顺带刷新秒杀板块(倒计时重新对时)
  await loadSeckill();
}

// 首页直播信息(无直播间时不展示直播板块): 拿到拉流地址后首页静音预览
Future<void> loadLiveRoom() async {
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
  // 视频输出诊断: 纹理id / 输出矩形 / 首帧是否真的渲染出来
  // * 首帧以"纹理已创建 / 首帧已渲染"为准, 才不会被过早隐藏封面
  controller.id.addListener(() {
    debugPrint('[live]textureId=${controller.id.value}');
    if((controller.id.value ?? -1) > 0 && !liveFirstFrame.value) liveFirstFrame.value = true;
  });
  controller.rect.addListener(() => debugPrint('[live]输出rect=${controller.rect.value}'));
  controller.waitUntilFirstFrameRendered.then((_) {
    debugPrint('[live]首帧已渲染');
    if(mounted) liveFirstFrame.value = true;
  });
  await player.setVolume(0.0);
  // 走 LiveReconnector: 抵消 Surface 重建触发的 seek 对 RTMP 直播的打断
  await reconnector.open(src, play: true);
  if(!mounted) return;
  setState(() {});
  // 卡片挂载可能晚于接口返回(此刻 liveCardKey.currentContext 还是 null): 首帧后再同步一次,
  // 否则这一轮同步会直接 return, 之后只有滚动才会恢复预览
  WidgetsBinding.instance.addPostFrameCallback((_) => syncLivePlayState());
  // 卡片若已滚出视口则不播放
  syncLivePlayState();
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
  // 秒杀倒计时(每秒局部刷新)
  seckillTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSeckill());
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
      final TabController old = tabController;
      setState(() {
        categoryList = list;
        tabList = tabs;
        tabWidgets = _buildTabWidgets(tabs);
        // tab 数量变了, TabController 必须重建(否则 controller.length != tabs.length 报错)
        tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);
      });
      // 等 UI 重建后再释放旧的, 避免 TabBar 仍持有已 dispose 的 controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) old.dispose();
      });
    } catch (_) {
      // 分类加载失败保留默认 tab
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

  // 首页宫格点击
  void _onCateTap(String label) {
    switch (label) {
      case '限时秒杀':
        Get.toNamed('/seckill');
        break;
      case '购物车':
        Get.toNamed('/cart');
        break;
      case '我的订单':
        Get.toNamed('/order');
        break;
      case '券红包':
        Get.toNamed('/my/coupon');
        break;
      case '客服消息':
        Get.toNamed('/chat');
        break;
      default:
        Get.snackbar('提示', '$label 功能待接入', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    tabController.dispose();
    seckillTimer?.cancel();
    liveReconnector?.dispose();
    livePlayer?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.grey[50],
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: RefreshIndicator(
        backgroundColor: Colors.white,
        color: Color(0xFFFF2C55),
        displacement: 10.0,
        onRefresh: handleRefresh,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          pinned: true,
          expandedHeight: 220.0,
          toolbarHeight: 94.0,
          titleSpacing: 0.0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 第一行: logo + 品牌名  |  去绑定门店 + 购物车
              Padding(
                padding: EdgeInsets.only(left: 12.0, right: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', width: 26.0, height: 26.0, fit: BoxFit.contain, isAntiAlias: true),
                    SizedBox(width: 6.0),
                    Text('乐惠生活', style: TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Spacer(),
                    // 绑定门店入口: 已绑定显示门店名, 未绑定才显示"去绑定门店"(点进去绑定)
                    Obx(() {
                      final bool bound = AuthStore.to.hasStore;
                      final String name = AuthStore.to.storeName;
                      return Material(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(15.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15.0),
                          onTap: () {
                            // 未绑定: 去绑定门店页
                            if (!bound) {
                              Get.toNamed('/bind_store');
                              return;
                            }
                            // 已绑定: 进门店详情(/api/store/info?store_id=)
                            final int sid = AuthStore.to.storeId.value;
                            if (sid == 0) {
                              Get.snackbar('提示', name.isNotEmpty ? '已绑定门店：$name' : '已绑定门店');
                              return;
                            }
                            Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': sid});
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                            child: Text(
                              bound ? (name.isNotEmpty ? name : '已绑定门店') : '去绑定门店',
                              style: TextStyle(color: Colors.white, fontSize: 13.0),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(height: 6.0),
              // 搜索框(高斯模糊背景) + 右侧购物车
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
            borderRadius: BorderRadius.circular(30.0),
            child: Container(
                height: 42.0,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(215),
            ),
            child: TextField(
                decoration: InputDecoration(
                  isDense: true,
              hintText: "2026国补",
              prefixIcon: Icon(Icons.search, color: Colors.black54, size: 20.0,),
              suffixIcon: Container(
                padding: EdgeInsets.only(right: 15.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10.0,
                  children: [
                    Icon(Icons.keyboard_voice, color: Colors.black54, size: 20.0,),
                    Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 20.0,),
                  ],
                ),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0))
                ),
                style: TextStyle(fontSize: 15.0),
                cursorColor: Colors.black,
                onChanged: (val) {
                  debugPrint(val);
                },
                  ),
                ),
                    ),
                  ),
                  SizedBox(width: 4.0),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 30.0, minHeight: 30.0),
                    icon: Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22.0),
                    onPressed: () { Get.toNamed('/cart'); },
                  ),
                ],
              ),
              ),
            ],
          ),
            // 自定义伸缩区域(轮播图)
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF2C55), Color(0xFFFF9C55)
                  ]
                )
              ),
              child: FlexibleSpaceBar(
                // pin: 折叠时背景不跟随视差做 transform/裁剪合成,滚动更省
                collapseMode: CollapseMode.pin,
                background: Swiper.children(
                pagination: SwiperPagination(
                      builder: DotSwiperPaginationBuilder(
                  color: Colors.white70,
                  activeColor: Colors.white,
                )
              ),
              indicatorLayout: PageIndicatorLayout.SCALE,
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281118/356751/9/12253/82448/691d63f8Fc9511ae6/3d5a48eb2f613cd0.jpg',
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281126/363429/14/6762/278758/69283a1dFa354dd17/01953f5ca31b08fc.png',
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281125/363656/36/6056/154345/69267511F6c7bb231/ba21f9349fa661a6.jpg',
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281127/356616/26/17402/95517/69292231F262ad573/59e415cfbc72bfcb.jpg',
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
              ],
            ),
              ),
            ),
          ),

          // 分类
          SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(10.0),
            padding: EdgeInsets.only(bottom: 6.0),
            height: 90.0,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: cateList.length,
                    itemBuilder: (context, index) {
                      final item = cateList[index];
                      return GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                        ),
                        itemCount: item['list'].length,
                        itemBuilder: (BuildContext context, int index) {
                          final citem = item['list'][index];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onCateTap('${citem['label'] ?? ''}'),
                            child: Container(
                          padding: EdgeInsets.only(top: 12.0),
                            child: Column(
                              spacing: 3.0,
                              children: [
                                if (citem['icon'] != null)
                                  Badge(
                                    isLabelVisible: citem['count'] != null,
                                    backgroundColor: Colors.redAccent,
                                    label: Text('${citem['count']}'),
                                    child: SvgPicture.asset('${citem['icon']}', height: 30.0, width: 30.0,),
                                  ),
                                Text(citem['label']),
                              ],
                              ),
                              ),
                          );
                            },
                          );
                          },
                        ),
                      ),
                      CustomPageViewIndicator(
                      controller: pageController,
                      count: cateList.length,
                      color: Color(0xFFCECECE),
                      activeColor: Color(0xFFFF2C55),
                    ),
                  ],
                )
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
                        Text('更多', style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                        Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
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
                                // 遮罩: 上下都压一点深色(顶部标签/居中文字都可读), 中间留轻一点保持通透
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.0, 0.5, 1.0],
                                        colors: [
                                          Colors.black.withAlpha(110),
                                          Colors.black.withAlpha(60),
                                          Colors.black.withAlpha(130),
                                        ],
                                      ),
                                    ),
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
                                            Container(width: 5.0, height: 5.0, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                            SizedBox(width: 4.0),
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
                                          Text(
                                            liveText(const ['name', 'room_name', 'title'], '欧拿优选专场'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.w700, height: 1.2),
                                          ),
                                          SizedBox(height: 2.0),
                                          Text(
                                            liveSubtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11.0),
                                          ),
                                          SizedBox(height: 6.0),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14.0),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_arrow_rounded, color: Color(0xFFFF2C55), size: 14.0),
                                                Text('看直播', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, fontWeight: FontWeight.w700)),
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
                            color: Color(0xFFFFF1F2),
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
                return SliverPersistentHeader(
              pinned: true,
              delegate: CustomStickyHeader(
                child: PreferredSize(
                preferredSize: Size.fromHeight(sticky ? 45.0 : 0.0),
                child: sticky ? Container(
                  color: Colors.white,
                height: 45.0,
                child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                  controller: tabController,
                  // 点击分类 tab: 拉取该分类下的商品(/api/goodssku/page)
                  onTap: _onTabTap,
                  tabs: tabWidgets,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                unselectedLabelColor: Colors.black87,
                labelColor: Color(0xFFFF2C55),
                indicatorColor: Color(0xFFFF2C55),
                indicatorSize: TabBarIndicatorSize.tab,
                unselectedLabelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei'),
                labelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                dividerHeight: 0,
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                labelPadding: EdgeInsets.symmetric(horizontal: 10.0),
                indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
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
                ) : const SizedBox.shrink(),
              ),
              ),
                );
              },
            ),

            // 商品列表(瀑布流 / 横向单列可切换)
            SliverPadding(
            padding: const EdgeInsets.all(10),
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
            child: isLoading
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Loading(title: '加载中...'),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 10),
                  child: Center(
                    child: Text(
                      dataList.isEmpty ? '暂无商品' : (hasMore ? '' : '没有更多了'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                    ),
                  ),
                ),
            ),
          ],
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
      padding: EdgeInsets.all(5.0),
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
          padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
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
      padding: EdgeInsets.all(5.0),
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
