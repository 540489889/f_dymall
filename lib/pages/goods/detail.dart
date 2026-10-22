/// 商品详情页
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../components/common_empty.dart';
import '../../components/live_float_window.dart';
import '../../controller/auth_store.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../api/cart.dart';
import '../../api/goods.dart';
import '../../api/goods_evaluate.dart';
import '../../api/store.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/backtop.dart';
import '../../components/loading.dart';
import '../../styles/index.dart';
import '../../config/index.dart';
import './coupon_sheet.dart';
import './sku_sheet.dart';
import './delivery_sheet.dart';
import './evaluate.dart';

/// 轮播页码角标(1/2 形式)
class _NumberPaginationBuilder extends SwiperPlugin {
  const _NumberPaginationBuilder();

  @override
  Widget build(BuildContext context, SwiperPluginConfig config) {
    final int active = config.activeIndex;
    final int total = config.itemCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        '${active + 1}/$total',
        style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 通用底部弹窗骨架(标题 + 关闭 + 可滚动内容)
class _PromoSheet extends StatelessWidget {
  const _PromoSheet({ required this.title, required this.child, this.footer });
  final String title;
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
    child: SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48.0,
            child: Stack(
              children: <Widget>[
                Center(child: Text(title, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600))),
                Positioned(
                  right: 5.0,
                  top: 0.0,
                  bottom: 0.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.close, size: 20.0, color: Colors.black45)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          if (footer != null) ...<Widget>[
            const Divider(height: 1.0, thickness: 1.0, color: Color(0xFFEEEEEE)),
            footer!,
          ],
        ],
      ),
    ),
  );
}

class Goods extends StatefulWidget {
  const Goods({
    super.key,
    // 直播间商品面板内嵌显示时直接传 id / 房间号,不走路由参数
    this.goodsId,
    this.liveRoomId,
    // 返回按钮: 面板里是"关闭面板",默认退路由
    this.onBack,
  });

/// 商品id: 非空时优先于路由参数(直播间面板直接传)
final int? goodsId;
/// 直播间房间号: 非空时优先于路由参数(面板里加购/下单同样要回传 live_roomid)
final String? liveRoomId;
/// 返回/关闭回调(面板里传关闭面板)
final VoidCallback? onBack;

@override
State<Goods> createState() => _GoodsState();
}

class _GoodsState extends State<Goods> {
// 路由参数: initState 里快照一份(后续路由变化不会改到 Get.arguments,且小窗要用到)
late final Map<String, dynamic> args = Get.arguments is Map
    ? Map<String, dynamic>.from(Get.arguments as Map)
    : const <String, dynamic>{};
late final ScrollController scrollController = ScrollController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);
// 接口返回的商品详情
Map<String, dynamic> detail = const {};
// 加载状态
bool loading = true;
// 错误信息(非空表示加载失败/无数据)
String errorMsg = '';
// 用户已领取的券标识集合(本地记录, 关闭弹窗时回写)
Set<int> fetchedCoupons = <int>{};
// 限时折扣倒计时(剩余秒数), 每秒刷新
final ValueNotifier<int> discountRemain = ValueNotifier<int>(0);
Timer? _discountTimer;
// 规格属性是否展开
bool attrExpanded = false;
// 加入购物车请求中
bool addingCart = false;
// 收藏/取消收藏请求中
bool addingCollect = false;
// 购物车商品总件数(用于底部购物车角标,取 /api/cart/lists)
int cartNum = 0;
// 适用门店(/api/store/page 第一条)
int storeId = 0;
// 适用门店名
String storeName = '';
// 适用门店地址(full_address + address)
String storeAddress = '';
// 商品评价(配置 evaluate_show == 1 时展示)
bool evaluateShow = false;
int evaluateCount = 0;
List<Map<String, dynamic>> evaluateList = <Map<String, dynamic>>[];
// 商品视频(media_kit 播放器)
Player? _player;
VideoController? _videoController;
bool _showVideo = false;
bool _videoError = false;

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;
  });
  loadDetail();
  loadCartNum();
  // loadStore(); // 适用门店暂时隐藏, 暂不请求
  loadEvaluate();
  // 限时折扣倒计时(每秒刷新剩余时间)
  _discountTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickDiscount());
  // 从直播间进来的: 等首帧布局完再挂悬浮小窗(小窗继续播直播画面,点它回直播间)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint('[live]商品详情: fromLive=$fromLive liveRoomId=$liveRoomId cover=${liveCover.isNotEmpty} pullUrl=${livePullUrl.isNotEmpty}');
    }
    // 直播间进来就挂小窗: 房间号为空(演示房间)也要挂,点小窗靠退栈回直播间
    if (!fromLive && liveRoomId.isEmpty) return;
    LiveFloatWindow.instance.show(
      context: context,
      roomSn: liveRoomId,
      cover: liveCover,
      anchorName: liveAnchor,
      pullUrl: livePullUrl,
    );
  });
}

/// 拉取购物车总件数(未登录或接口异常时静默失败,保持原值)
Future<void> loadCartNum() async {
  try {
    final int total = await CartApi.count();
    if (!mounted) return;
    setState(() => cartNum = total);
  } catch (_) {
    // 忽略: 角标非关键信息
  }
}

/// 拉取适用门店(取 /api/store/page 第一条, 接口异常时不展示该行)
Future<void> loadStore() async {
  try {
    final List<Map<String, dynamic>> list = await StoreApi.page(pageSize: 1);
    if (!mounted || list.isEmpty) return;
    final Map<String, dynamic> store = list.first;
    setState(() {
      storeId = int.tryParse('${store['store_id'] ?? 0}') ?? 0;
      storeName = '${store['store_name'] ?? ''}';
      storeAddress = '${store['full_address'] ?? ''}${store['address'] ?? ''}';
    });
  } catch (_) {
    // 忽略: 门店信息非下单关键项
  }
}

/// 加载商品评价(评价配置开启时展示: 总数 + 前 2 条)
Future<void> loadEvaluate() async {
  try {
    final Map<String, dynamic> config = await GoodsEvaluateApi.config();
    if (!mounted || '${config['evaluate_show'] ?? '0'}' != '1') return;
    final Map<String, dynamic> count = await GoodsEvaluateApi.count(goodsId);
    final Map<String, dynamic> data = await GoodsEvaluateApi.page(goodsId: goodsId, pageSize: 2);
    if (!mounted) return;
    setState(() {
      evaluateShow = true;
      evaluateCount = int.tryParse('${count['total'] ?? 0}') ?? 0;
      evaluateList = GoodsEvaluateApi.listOf(data);
    });
  } catch (_) {
    // 忽略: 评价非下单关键项
  }
}

@override
void dispose() {
  // 离开详情页收起直播间悬浮小窗(返回直播间时也是走这里)
  LiveFloatWindow.instance.hide();
  _discountTimer?.cancel();
  _player?.dispose();
  scrollController.dispose();
  super.dispose();
}

/// 商品id: 支持路由传 Map({'goodsId' 或 'id'})、数字或字符串
int get goodsId {
  if (args.isNotEmpty) return int.tryParse('${args['goodsId'] ?? args['id'] ?? 1}') ?? 1;
  final dynamic raw = Get.arguments;
  return int.tryParse('$raw') ?? 1;
}

/// 直播间房间号 sn: 从直播间点商品进来时由直播间页带过来
/// * 加购 / 下单都要回传给后台(live_roomid),用于统计直播间成交
/// * 普通商品详情没有这个参数,为空表示非直播间下单(演示房间的 sn 也可能为空)
String get liveRoomId => '${args['live_roomid'] ?? ''}'.trim();

/// 是否从直播间进来: 房间号为空(演示房间)时也要靠它判断要不要挂悬浮小窗
/// * 直播间在栈里,点小窗退栈就能回去,所以没有 sn 也能回
bool get fromLive {
  final dynamic v = args['fromLive'];
  return v == true || '$v' == 'true';
}

/// 直播间封面 / 主播名 / 拉流地址: 直播间进来时带上,给悬浮小窗用
String get liveCover => '${args['liveCover'] ?? ''}'.trim();

String get liveAnchor => '${args['liveAnchor'] ?? ''}'.trim();

String get livePullUrl => '${args['livePullUrl'] ?? ''}'.trim();

/// 加载商品详情
Future<void> loadDetail() async {
  setState(() {
    loading = true;
    errorMsg = '';
  });
  try {
    final Map<String, dynamic> res = await GoodsApi.detail(goodsId);
    if (!mounted) return;
    setState(() {
      detail = res;
      loading = false;
      errorMsg = res.isEmpty ? '未查询到商品信息' : '';
    });
    // 有视频时初始化播放器(视频地址在详情返回后才确定)
    _initVideo();
  } catch (e) {
    if (!mounted) return;
    setState(() {
      loading = false;
      errorMsg = '$e'.replaceAll(RegExp(r'^DioException.*message: '), '');
    });
  }
}

/// 初始化商品视频播放器(仅在 videoUrl 非空且未初始化时)
void _initVideo() {
  if (videoUrl.isEmpty || _player != null) return;
  _player = Player();
  _videoController = VideoController(_player!);
  _player!.stream.error.listen((dynamic e) {
    if (mounted) setState(() => _videoError = true);
  });
  _player!.open(Media(videoUrl), play: false).catchError((dynamic e) {
    if (mounted) setState(() => _videoError = true);
  });
}

/// 限时折扣每秒刷新剩余秒数(promotion_type==1 且未过期才计数)
void _tickDiscount() {
  if (promotionType != 1 || discountEndTime <= 0) {
    if (discountRemain.value != 0) discountRemain.value = 0;
    return;
  }
  final int remain = discountEndTime - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final int next = remain < 0 ? 0 : remain;
  if (discountRemain.value != next) discountRemain.value = next;
}

/// 秒 -> 天/时/分/秒 文案
String _formatCountdown(int remain) {
  if (remain <= 0) return '已结束';
  final int d = remain ~/ 86400;
  final int h = (remain % 86400) ~/ 3600;
  final int m = (remain % 3600) ~/ 60;
  final int s = remain % 60;
  if (d > 0) return '$d天${_pad2(h)}:${_pad2(m)}:${_pad2(s)}';
  return '${_pad2(h)}:${_pad2(m)}:${_pad2(s)}';
}

String _pad2(int v) => v < 10 ? '0$v' : '$v';

/// 图片地址处理(配置了 imageProxy 时走代理, 与 GoodsApi._fixImage 一致)
String _fixImg(String url) {
  if (url.isEmpty || Config.imageProxy.isEmpty) return url;
  return '${Config.imageProxy}${Uri.encodeComponent(url)}';
}

/// 安全转 num(接口字段多为字符串)
num _num(dynamic value) {
  if (value == null || '$value'.isEmpty) return 0;
  return num.tryParse('$value') ?? 0;
}

/* 数据快捷读取 */
List<String> get images => (detail['images'] as List? ?? const []).map((e) => '$e').toList();
num get price => detail['price'] as num? ?? 0;
num get marketPrice => detail['marketPrice'] as num? ?? 0;
bool get showMarketPrice => detail['showMarketPrice'] == true && marketPrice > 0;
String get title => '${detail['title'] ?? ''}';
String get introduction => '${detail['introduction'] ?? ''}';
String get labelName => '${detail['labelName'] ?? ''}';
String get content => '${detail['content'] ?? ''}';
num get saleNum => detail['saleNum'] as num? ?? 0;
num get stock => detail['stock'] as num? ?? 0;
bool get showSale => detail['showSale'] == true;
bool get showStock => detail['showStock'] == true;
bool get isFreeShipping => detail['isFreeShipping'] == true;
bool get isCollect => detail['isCollect'] == true;
bool get onSale => detail['onSale'] == true;
int get skuId => int.tryParse('${detail['skuId'] ?? 0}') ?? 0;
String get skuName => '${detail['skuName'] ?? title}';
String get skuImage => '${detail['skuImage'] ?? ''}';
// 商品视频地址(为空表示无视频)
String get videoUrl => '${detail['videoUrl'] ?? ''}';
List<dynamic> get couponList => (detail['couponList'] as List? ?? const []);
List<dynamic> get specGroups => (detail['specGroups'] as List? ?? const []);
/// 规格属性(商品参数)
List<dynamic> get attrList => (detail['attrList'] as List? ?? const []);
Map<String, dynamic> get expressType => (detail['expressType'] as Map? ?? const {}).cast<String, dynamic>();
// 限时折扣: promotion_type==1 且未过期才展示折扣价/标签
int get promotionType => detail['promotionType'] as int? ?? 0;
int get discountEndTime => detail['discountEndTime'] as int? ?? 0;
bool get showDiscount =>
    promotionType == 1 && discountEndTime * 1000 > DateTime.now().millisecondsSinceEpoch;
// 满减活动(原始 map, 含 type / manjian_name / rule_json)
Map<String, dynamic> get manjian => (detail['manjian'] as Map? ?? const {}).cast<String, dynamic>();
// 组合套餐列表(每项: bl_id / bl_name / bl_price / bundling_goods[])
List<Map<String, dynamic>> get bundlingList =>
    (detail['bundlingList'] as List? ?? const []).cast<Map<String, dynamic>>();

/// 金额格式化(保留两位)
String money(num value) => value.toStringAsFixed(2);

/// 券后价: 取第一张可用的满减券
num get couponPrice {
  for (final dynamic item in couponList) {
    if (item is! Map) continue;
    final num money = num.tryParse('${item['money'] ?? 0}') ?? 0;
    final num atLeast = num.tryParse('${item['at_least'] ?? 0}') ?? 0;
    if (money > 0 && price >= atLeast) return (price - money) < 0 ? 0 : price - money;
  }
  return price;
}

@override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: loading
      ? const Center(child: Loading(title: '加载中...'))
      : (errorMsg.isNotEmpty ? _buildError() : _buildContent()),
    // 商品导航栏(加载失败时不显示)
    bottomNavigationBar: (loading || errorMsg.isNotEmpty) ? null : _buildBottomBar(context),
  // 返回顶部
  floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}

/// 加载失败/空态
Widget _buildError() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10.0,
      children: [
        const Icon(Icons.inbox_outlined, color: Colors.grey, size: 40.0),
        Text(errorMsg, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
        TextButton(onPressed: loadDetail, child: const Text('重新加载')),
      ],
    ),
  );
}

// 顶部圆形按钮直径(返回/搜索/购物车统一)
static const double _kTopBtnSize = 40.0;
// 价格块压在轮播图上的高度: 设为 0 表示价格块不再覆盖轮播图,
// 图片完整显示, 价格块紧贴轮播图下方(顶部圆角衔接)
static const double _kPriceOverlap = 0.0;

Widget _buildContent() {
  return Stack(
    children: <Widget>[
      CustomScrollView(
    scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
    controller: scrollController,
    slivers: [
      _buildSliverAppBar(),
      SliverToBoxAdapter(
        child: ScrollConfiguration(
          behavior: CustomScrollBehavior().copyWith(scrollbars: false),
          child: Column(
            children: [
              _buildPriceBlock(),
              Container(
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
                ),
                // 不再用负位移去压价格块: 价格块已不覆盖轮播, 这里让浅灰内容卡片
                // 从价格块正下方平铺开始, 红橙金额板块完整显示、不被白色背景遮挡
                child: Column(
                  children: [
                    _buildTitle(),
                    _buildPromotion(),
                    _buildEvaluate(),
                    _buildAttr(),
                    _buildDetail(),
                  ],
                ),
              ),
              // 底部按钮安全间距(卡片多压了 _kPriceOverlap,这里相应减掉,底部留白不变)
              SizedBox(height: 20.0 - _kPriceOverlap),
            ],
          ),
        ),
      ),
    ],
      ),
      // 顶部按钮栏(返回/搜索/购物车)自己画,不走 AppBar 的 leading/actions
      _buildTopBar(),
    ],
  );
}

/// SliverAppBar: 默认透明, 滚动到商品区后背景变白(不显示标题)
/// * 对齐参考图: 未滚动时背景透明;滚动超过商品图后吸顶,背景白色
Widget _buildSliverAppBar() {
  return ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (BuildContext context, double offset, Widget? child) {
      final double t = (offset / 120.0).clamp(0.0, 1.0);
      final Color bg = Color.lerp(Colors.transparent, Colors.white, t)!;
      return SliverAppBar(
        pinned: true,
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        // 360 是轮播可视高度(接近 1:1 主图比例,避免商家图底部贴边的促销贴片被裁掉),
        // 价格块接在其正下方(由 _kPriceOverlap 控制是否上压)
        expandedHeight: 360.0 + _kPriceOverlap,
        // 按钮自己画(见 _buildTopBar),这里不要默认的返回按钮和标题
        automaticallyImplyLeading: false,
        flexibleSpace: FlexibleSpaceBar(background: _buildMedia()),
      );
    },
  );
}

/// 顶部按钮栏: 返回/搜索/购物车
/// * 不用 AppBar 的 leading/actions 是因为 NavigationToolbar 给 leading 的约束为
///   tight(width: leadingWidth) + tight(height: toolbarHeight) —— 会把 34x34 的圆底
///   按钮撑成大圆, 跟右边 34 的圆对不上;这里用 Stack 自己排,左右尺寸完全一致
Widget _buildTopBar() {
  final double statusBar = MediaQuery.paddingOf(context).top;
  return ValueListenableBuilder<double>(
    valueListenable: scrollOffset,
    builder: (BuildContext context, double offset, Widget? child) {
      final double t = (offset / 120.0).clamp(0.0, 1.0);
      final Color iconColor = Color.lerp(Colors.white, const Color(0xFF333333), t)!;
      return Positioned(
        // 与 AppBar 的 toolbar 垂直居中对齐
        top: statusBar + (kToolbarHeight - _kTopBtnSize) / 2.0,
        left: 10.0,
        right: 10.0,
        child: Row(
          children: <Widget>[
            _buildIconButton(Icons.close, () => Get.back(), t, iconColor, marginRight: 0.0),
            const SizedBox(width: 6.0),
            // 吸顶后展开成搜索框(滚动前透明占位,右侧按钮照常靠右)
            Expanded(
              child: Opacity(
                opacity: t,
                child: IgnorePointer(
                  ignoring: t < 0.9,
                  child: _buildSearchBox(),
                ),
              ),
            ),
            // 滚动前是圆形搜索按钮,吸顶后收起让位给搜索框
            ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1 - t,
                child: _buildIconButton(Icons.search, () => Get.toNamed('/search'), t, iconColor),
              ),
            ),
            // 购物车: 跟底部操作栏用同一张切图 assets/images/c3.png
            _buildTopImageButton('assets/images/c3.png', () => Get.toNamed('/cart'), t, iconColor),
            // 收藏: 已收藏实心红色,未收藏线框
            _buildIconButton(
              isCollect ? Icons.favorite : Icons.favorite_border,
              addingCollect ? () {} : _toggleCollect,
              t,
              isCollect ? const Color(0xFFFF2C55) : iconColor,
              marginRight: 0.0,
            ),
          ],
        ),
      );
    },
  );
}

/// 吸顶后的搜索框(点击进搜索页)
/// * 顶栏吸顶后只有白色背景没有标题,用搜索框把中间的空间填起来
Widget _buildSearchBox() {
  return GestureDetector(
    onTap: () => Get.toNamed('/search'),
    child: Container(
      height: 36.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18.0),
      ),
      child: Row(
        children: const <Widget>[
          Icon(Icons.search, size: 18.0, color: Color(0xFF999999)),
          SizedBox(width: 6.0),
          Expanded(
            child: Text(
              '搜索商品',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13.0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 收藏/取消收藏
/// * 接口 /api/goodscollect/add(带当前规格信息) 与 /api/goodscollect/delete(goods_id)
Future<void> _toggleCollect() async {
  if (addingCollect) return;
  // 未登录先去登录,登录回来重新拉详情刷新收藏状态
  if (!AuthStore.to.isLogin) {
    await Get.toNamed('/login');
    if (AuthStore.to.isLogin) loadDetail();
    return;
  }
  setState(() => addingCollect = true);
  try {
    if (isCollect) {
      final int ok = await GoodsApi.collectDelete(goodsId: goodsId);
      if (ok > 0) {
        detail['isCollect'] = false;
        MyDialog.toast('已取消收藏');
      }
    } else {
      final int id = await GoodsApi.collectAdd(
        goodsId: goodsId,
        skuId: skuId,
        skuName: skuName,
        skuPrice: price,
        skuImage: skuImage,
      );
      if (id > 0) {
        detail['isCollect'] = true;
        MyDialog.toast('收藏成功');
      }
    }
  } catch (e) {
    MyDialog.toast('$e'.replaceAll(RegExp(r'^DioException.*message: '), ''));
  } finally {
    if (mounted) setState(() => addingCollect = false);
  }
}

/// 顶部圆形图标按钮(透明时带半透明黑底,吸顶后无底色)
Widget _buildIconButton(IconData icon, VoidCallback onTap, double t, Color iconColor, {double marginRight = 6.0}) {
  return _buildTopButton(
    Icon(icon, size: 22.0, color: iconColor),
    onTap,
    t,
    marginRight: marginRight,
  );
}

/// 顶部圆形切图按钮(和底部操作栏用同一张图,按 iconColor 染色)
Widget _buildTopImageButton(String asset, VoidCallback onTap, double t, Color iconColor, {double marginRight = 6.0}) {
  return _buildTopButton(
    Image.asset(
      asset,
      width: 22.0,
      height: 22.0,
      fit: BoxFit.contain,
      color: iconColor,
      isAntiAlias: true,
      // 切图缺失时退化成同尺寸占位,避免红屏
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          const SizedBox(width: 22.0, height: 22.0),
    ),
    onTap,
    t,
    marginRight: marginRight,
  );
}

/// 顶部按钮外壳: 40x40 圆底(滚动到商品区后底色透明),内容居中
Widget _buildTopButton(Widget child, VoidCallback onTap, double t, {double marginRight = 6.0}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: _kTopBtnSize,
      height: _kTopBtnSize,
      margin: EdgeInsets.only(right: marginRight),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.black.withValues(alpha: 0.25), const Color(0x00FFFFFF), t),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    ),
  );
}

/// 顶部媒体区: 图片轮播 + 商品视频(可切换, 仅在 videoUrl 非空时显示切换标签)
Widget _buildMedia() {
  final bool hasVideo = videoUrl.isNotEmpty;
  return Stack(
    children: <Widget>[
      // 图片轮播(始终挂载, 切到视频时作为底层被覆盖)
      _buildSwiper(),
      // 视频(条件挂载: 已切到视频且播放器就绪)
      if (hasVideo && _showVideo && _videoController != null)
        Positioned.fill(child: Video(controller: _videoController!, fit: BoxFit.cover)),
      // 视频加载失败提示
      if (hasVideo && _showVideo && _videoError)
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: const Center(child: Text('视频加载失败', style: TextStyle(color: Colors.white, fontSize: 13.0))),
          ),
        ),
      // 视频/图片切换标签(底部居中)
      if (hasVideo)
        Positioned(
          bottom: 14.0,
          left: 0.0,
          right: 0.0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14.0)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _mediaTag('视频', _showVideo),
                  _mediaTag('图片', !_showVideo),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// 媒体切换标签(视频 / 图片), 点击切换并控制播放/暂停
Widget _mediaTag(String text, bool active) {
  return GestureDetector(
    onTap: () {
      setState(() {
        _showVideo = text == '视频';
        if (_showVideo) {
          _player?.play();
        } else {
          _player?.pause();
        }
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFF2C55) : Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12.0, fontWeight: FontWeight.w600)),
    ),
  );
}

/// 顶部轮播(接口 images)
Widget _buildSwiper() {
  final List<String> list = images;
  if (list.isEmpty) {
    return Container(
      height: 360.0,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40.0),
    );
  }
  return Swiper.children(
    pagination: SwiperPagination(
      alignment: .bottomRight,
      // 页码角标上移,避开被价格块压住的那一截
      margin: EdgeInsets.only(right: 12.0, bottom: 10.0 + _kPriceOverlap),
      builder: const _NumberPaginationBuilder(),
    ),
    children: list.map((String url) => CachedNetworkImage(
      imageUrl: url,
      // 切图时不要淡入淡出(默认 500ms 的淡入会跟着轮播切换闪一下)
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(color: Colors.grey[50]),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30.0),
      ),
      fit: BoxFit.cover,
    )).toList(),
  );
}

/// 价格区(价格 / 券后价 / 划线价)
/// * 做成卡片压在轮播图底部: 上移 _kPriceOverlap + 顶部圆角 + 向上的阴影,
///   轮播区已多留同样高度,所以只是"压住"不会裁掉图片内容
Widget _buildPriceBlock() {
  return Container(
    transform: Matrix4.translationValues(0.0, -_kPriceOverlap, 0.0),
    // 上压 _kPriceOverlap 后顶部要多补这么多的内边距,金额才不会被顶到图片上
    padding: EdgeInsets.fromLTRB(15.0, 10.0 + _kPriceOverlap, 15.0, 25.0),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF2C55), Color(0xFFFF9C55)
        ]
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF2C55).withValues(alpha: 0.25),
          blurRadius: 8.0,
          offset: const Offset(0.0, 2.0),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5.0,
      children: [
        if (showDiscount)
          Row(
            spacing: 8.0,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.0)),
                child: const Text('限时折扣', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, fontWeight: FontWeight.w700)),
              ),
              ValueListenableBuilder<int>(
                valueListenable: discountRemain,
                builder: (BuildContext context, int remain, _) => Text(
                  '距结束 ${_formatCountdown(remain)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.0),
                ),
              ),
            ],
          ),
        Row(
        spacing: 5.0,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('¥${money(price)}', style: TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w700),),
          // 券后价
          if (couponPrice < price)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: Text('券后价¥${money(couponPrice)}', style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, fontWeight: FontWeight.w600)),
            ),
          // 划线价
          if (showMarketPrice)
            Text('¥${money(marketPrice)}', style: TextStyle(color: Colors.white70, fontSize: 13.0, decoration: TextDecoration.lineThrough),),
        ],
      ),
      // 卖点/副标题
      if (introduction.isNotEmpty)
        Text(introduction, style: TextStyle(color: Colors.white, fontSize: 12.0), maxLines: 1, overflow: TextOverflow.ellipsis,),
      // 库存 / 销量
      if (showStock || showSale)
        Row(
          spacing: 8.0,
          children: <Widget>[
            if (showStock) _buildPriceMeta('库存${trimNum(stock)}件'),
            if (showStock && showSale)
              Container(width: 1.0, height: 9.0, color: Colors.white.withValues(alpha: 0.5)),
            if (showSale) _buildPriceMeta('销量${trimNum(saleNum)}件'),
          ],
        ),
      ],
    ),
  );
}

/// 价格区半透明小字(库存/销量)
Widget _buildPriceMeta(String text) {
  return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11.0));
}

/// 标题区(标签 + 商品名)
Widget _buildTitle() {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(10.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (labelName.isNotEmpty)
                TextSpan(text: ' $labelName ', style: TextStyle(fontSize: 12.0, backgroundColor: const Color(0xFFFF2C55), color: Colors.white)),
              TextSpan(text: title.isEmpty ? '商品名称' : ' $title', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700),),
            ]
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

/// 已选规格文本(来自 sku_spec_format)
String get selectedSpecText {
  final List<dynamic> specs = (detail['specFormat'] as List? ?? const []);
  if (specs.isEmpty) return '请选择规格';
  final List<String> names = specs
      .map((dynamic e) => '${(e is Map ? e['spec_value_name'] : '') ?? ''}')
      .where((String s) => s.isNotEmpty)
      .toList();
  if (names.isEmpty) return '请选择规格';
  return '商品规格/${names.join('/')}';
}

/// 配送方式文本
String get deliveryText {
  final List<String> names = <String>[];
  for (final String key in const <String>['express', 'store']) {
    final dynamic value = expressType[key];
    if (value is Map && '${value['name'] ?? ''}'.isNotEmpty) {
      names.add('${value['name']}');
    }
  }
  if (names.isEmpty) return '快递发货 · 门店自提';
  return names.join(' · ');
}



/// 单张券 chip(票券样式: 渐变底 + 左右齿孔), 点击打开券弹窗
Widget _buildCouponChip(Map item) {
  const double chipHeight = 24.0;
  const double notchSize = 6.0;
  final String amount = couponAmountText(item);
  final String condition = couponConditionText(item, short: true);
  return GestureDetector(
    onTap: _showCouponSheet,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          height: chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 7.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A45)],
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                amount,
                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w700),
              ),
              if (condition.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4.0),
                Container(width: 1.0, height: 9.0, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 4.0),
                Text(condition, style: const TextStyle(color: Colors.white, fontSize: 10.0)),
              ],
            ],
          ),
        ),
        // 左右齿孔(白卡背景色)
        Positioned(
          left: -notchSize / 2,
          top: (chipHeight - notchSize) / 2,
          child: _buildCouponNotch(notchSize),
        ),
        Positioned(
          right: -notchSize / 2,
          top: (chipHeight - notchSize) / 2,
          child: _buildCouponNotch(notchSize),
        ),
      ],
    ),
  );
}

Widget _buildCouponNotch(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size / 2),
    ),
  );
}

/// 打开优惠券弹窗
Future<void> _showCouponSheet() async {
  final List<Map> coupons = couponList.whereType<Map>().toList();
  if (coupons.isEmpty) return;
  fetchedCoupons = await showCouponSheet(context, coupons: coupons, fetched: fetchedCoupons);
  if (mounted) setState(() {});
}

/// 满减规则文案列表(解析 manjian.rule_json: 满减 / 满送 / 包邮)
List<String> get _manjianRules {
  final dynamic raw = manjian['rule_json'];
  if (raw is! Map) return const [];
  final int type = _num(manjian['type']).toInt();
  final String unit = type == 1 ? '件' : '元';
  final List<String> rules = <String>[];
  raw.forEach((dynamic key, dynamic value) {
    if (value is! Map) return;
    final num limit = _num(value['limit']);
    final num discount = _num(value['discount_money']);
    if (discount > 0) rules.add('满${trimNum(limit)}$unit减${trimNum(discount)}元');
    final num point = _num(value['point']);
    if (point > 0) rules.add('满${trimNum(limit)}$unit送${trimNum(point)}积分');
    if (value['free_shipping'] != null) rules.add('满${trimNum(limit)}$unit包邮');
  });
  return rules;
}

/// 满减入口摘要(优先活动名, 否则拼接前两条规则)
String get _manjianSummary {
  final String name = '${manjian['manjian_name'] ?? ''}';
  if (name.isNotEmpty) return name;
  final List<String> rules = _manjianRules;
  return rules.isEmpty ? '查看优惠' : rules.take(2).join('；');
}

/// 组合套餐入口预览(活动名 + 首组商品缩略图横向滚动)
Widget _buildBundlingPreview() {
  final Map<String, dynamic> first = bundlingList.first;
  final List<dynamic> goods = (first['bundling_goods'] as List? ?? const []);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    spacing: 6.0,
    children: <Widget>[
      Text('${first['bl_name'] ?? ''}', style: const TextStyle(fontSize: 12.0, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
      if (goods.isNotEmpty)
        SizedBox(
          height: 44.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: goods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6.0),
            itemBuilder: (BuildContext context, int i) {
              final Map<String, dynamic> g = (goods[i] as Map? ?? const {}).cast<String, dynamic>();
              return ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: CachedNetworkImage(
                  imageUrl: _fixImg('${g['sku_image'] ?? ''}'),
                  width: 44.0,
                  height: 44.0,
                  fit: BoxFit.cover,
                  errorWidget: (BuildContext c, String u, Object e) => Container(color: Colors.grey[200]),
                ),
              );
            },
          ),
        ),
      Text('套餐价 ¥${money(_num(first['bl_price']))}', style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0, fontWeight: FontWeight.w600)),
    ],
  );
}

/// 满减弹窗
Future<void> _showManjianSheet() async {
  final List<String> rules = _manjianRules;
  if (rules.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _PromoSheet(
      title: '促销活动',
      footer: _sheetConfirmButton(context),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
        itemCount: rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12.0),
        itemBuilder: (BuildContext context, int i) => _manjianRuleItem(rules[i]),
      ),
    ),
  );
}

/// 单条满减规则(类型标签 + 文案)
Widget _manjianRuleItem(String text) {
  final String tag;
  final Color tagColor;
  if (text.contains('包邮')) {
    tag = '包邮';
    tagColor = const Color(0xFF3B82F6);
  } else if (text.contains('送')) {
    tag = '满送';
    tagColor = const Color(0xFFFF7A45);
  } else {
    tag = '满减';
    tagColor = const Color(0xFFFF2C55);
  }
  return Container(
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8.0)),
    child: Row(
      spacing: 10.0,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
          decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(4.0)),
          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.0, color: Colors.black87))),
      ],
    ),
  );
}

/// 弹窗底部确认按钮(全宽品牌渐变, 点击关闭弹窗)
Widget _sheetConfirmButton(BuildContext context) {
  return Container(
    padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 12.0),
    child: SizedBox(
      width: double.infinity,
      height: 44.0,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A45)]),
            borderRadius: BorderRadius.circular(22.0),
          ),
          child: const Text('确认', style: TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}

/// 组合套餐弹窗
Future<void> _showBundlingSheet() async {
  final List<Map<String, dynamic>> list = bundlingList;
  if (list.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _PromoSheet(
      title: '组合套餐',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 10.0),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14.0),
        itemBuilder: (BuildContext context, int i) {
          final Map<String, dynamic> item = list[i];
          final List<dynamic> goods = (item['bundling_goods'] as List? ?? const []);
          return Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: <Widget>[
                Row(
                  spacing: 6.0,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(color: const Color(0xFFFF2C55), borderRadius: BorderRadius.circular(4.0)),
                      child: const Text('套餐', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text('${item['bl_name'] ?? ''}', style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                SizedBox(
                  height: 62.0,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: goods.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Center(child: Text('＋', style: TextStyle(fontSize: 18.0, color: Colors.grey, fontWeight: FontWeight.w700))),
                    ),
                    itemBuilder: (BuildContext context, int j) {
                      final Map<String, dynamic> g = (goods[j] as Map? ?? const {}).cast<String, dynamic>();
                      return Column(
                        spacing: 3.0,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: CachedNetworkImage(
                              imageUrl: _fixImg('${g['sku_image'] ?? ''}'),
                              width: 48.0,
                              height: 48.0,
                              fit: BoxFit.cover,
                              errorWidget: (BuildContext c, String u, Object e) => Container(color: Colors.grey[200]),
                            ),
                          ),
                          SizedBox(
                            width: 48.0,
                            child: Text('${g['sku_name'] ?? ''}', style: const TextStyle(fontSize: 10.0, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  children: <Widget>[
                    Text('套餐价 ', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                    Text('¥${money(_num(item['bl_price']))}', style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 15.0, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        final List<dynamic> gs = (item['bundling_goods'] as List? ?? const []);
                        if (gs.isNotEmpty) {
                          final int gid = _num((gs.first as Map? ?? const {})['goods_id']).toInt();
                          if (gid > 0) Get.toNamed('/goods/detail', arguments: <String, dynamic>{'goodsId': gid});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        decoration: BoxDecoration(color: const Color(0xFFFF2C55), borderRadius: BorderRadius.circular(20.0)),
                        child: const Text('立即购买', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 打开规格选择弹窗
/// * 单规格商品也弹窗(弹窗内可选购买数量), 不再直接下单
Future<void> _showSkuSheet({String? action}) async {
  final SkuSheetResult? result = await showSkuSheet(context, detail: detail);
  if (result == null) return;
  if (result.detail['skuId'] != detail['skuId']) {
    setState(() => detail = result.detail);
  }
  if (result.action == 'buy') {
    _goToOrderSure(num: result.num);
  } else if (result.action == 'cart') {
    await _addToCart(num: result.num);
  }
}

/// 加入购物车(/api/cart/add)
Future<void> _addToCart({int num = 1}) async {
  final int skuId = detail['skuId'] as int? ?? 0;
  if (skuId == 0) {
    Get.snackbar('提示', '商品规格有误,请重新选择');
    return;
  }
  if (addingCart) return;
  setState(() => addingCart = true);
  try {
    // 直播间加购: 带上房间号 sn; 非直播间进来时为空,不传该字段
    await CartApi.add(
      skuId: skuId,
      num: num,
      liveRoomId: liveRoomId.isEmpty ? null : liveRoomId,
    );
    if (!mounted) return;
    // 先乐观 +num 保证即时反馈,再用服务端真实值校正
    setState(() => cartNum += num);
    await loadCartNum();
  } catch (e) {
    Get.snackbar('提示', CartApi.errorMsg(e), snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  } finally {
    if (mounted) setState(() => addingCart = false);
  }
}

/// 跳转到订单确认
void _goToOrderSure({int num = 1}) {
  Get.toNamed('/order/ordersure', arguments: <String, dynamic>{
    'goodsId': detail['goodsId'],
    'skuId': detail['skuId'],
    'num': num,
    'title': title,
    'price': price,
    'image': images.isEmpty ? '' : images.first,
    // 直播间下单: 把房间号 sn 透传给结算页,再由它写进 orderCreateData.live_roomid
    'live_roomid': liveRoomId,
  });
}

/// 打开配送说明弹窗
Future<void> _showDeliverySheet() async {
  await showDeliverySheet(context, expressType: expressType);
}



/// 信息行(领券/规格/配送/适用门店)
Widget _buildInfoRow({required String label, required Widget content, VoidCallback? onTap, bool showArrow = true}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 45.0,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12.0), textAlign: TextAlign.center),
          ),
          Expanded(child: content),
          if (showArrow) const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0),
        ],
      ),
    ),
  );
}

/// 醒目促销行: 左侧红色标签 + 内容 + 箭头(用于领券 / 满减 / 组合套餐)
Widget _buildPromoRow({required String tag, required Widget content, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2C55),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: content),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0),
        ],
      ),
    ),
  );
}

/// 领券 / 选择规格 / 配送
Widget _buildPromotion() {
  final List<Widget> rows = <Widget>[];

  // 领券
  if (couponList.isNotEmpty) {
    rows.add(_buildPromoRow(
      tag: '券',
      onTap: _showCouponSheet,
      // 单行横向滚动: 券多时也不换行占满整行
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 12.0,
          children: couponList.whereType<Map>().map<Widget>((Map item) => _buildCouponChip(item)).toList(),
        ),
      ),
    ));
  }

    // 满减(促销)
    if (_manjianRules.isNotEmpty)
      rows.add(_buildPromoRow(
        tag: '满减',
        onTap: _showManjianSheet,
        content: Text(
          _manjianSummary,
          style: const TextStyle(fontSize: 12.0, color: Color(0xFFFF2C55), fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    // 组合套餐
    if (bundlingList.isNotEmpty)
      rows.add(_buildPromoRow(
        tag: '套餐',
        onTap: _showBundlingSheet,
        content: _buildBundlingPreview(),
      ));

  // 适用门店暂时隐藏(后续开放时去掉注释即可, 需同时放开 initState 里的 loadStore)
  // if (storeName.isNotEmpty) {
  //   rows.add(_buildInfoRow(
  //     label: '适用\n门店',
  //     onTap: () => Get.toNamed('/store/detail', arguments: <String, dynamic>{'store_id': storeId}),
  //     content: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisSize: MainAxisSize.min,
  //       children: <Widget>[
  //         Text(storeName, style: const TextStyle(fontSize: 12.0, color: Colors.black87)),
  //         if (storeAddress.isNotEmpty) ...<Widget>[
  //           const SizedBox(height: 2.0),
  //           Text(
  //             storeAddress,
  //             style: const TextStyle(fontSize: 11.0, color: Colors.grey),
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ],
  //       ],
  //     ),
  //   ));
  // }

  // 选择规格(单规格商品没有可选规格, 点了也没用, 直接不展示)
  if (specGroups.isNotEmpty) {
    rows.add(_buildInfoRow(
      label: '选择',
      onTap: _showSkuSheet,
      content: Text(
        selectedSpecText,
        style: const TextStyle(fontSize: 12.0, color: Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ));
  }

  // 配送方式
  rows.add(_buildInfoRow(
    label: '配送',
    onTap: _showDeliverySheet,
    content: Text(
      deliveryText,
      style: const TextStyle(fontSize: 12.0, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  ));

  return Container(
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      spacing: 0.0,
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) FStyle.divider,
          rows[i],
        ],
      ],
    ),
  );
}

/// 规格属性(接口 goods_attr_format): 表格 + 展开收起
/// 商品评价(总数 + 前 2 条 + 查看全部)
Widget _buildEvaluate() {
  if (!evaluateShow) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => Get.toNamed('/goods/evaluate', arguments: <String, dynamic>{'goods_id': goodsId}),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: <Widget>[
              Text(
                '商品评价($evaluateCount)',
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const Spacer(),
              if (evaluateCount > 0) ...<Widget>[
                const Text('查看全部', style: TextStyle(fontSize: 12.0, color: FStyle.c999)),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12.0, color: FStyle.c999),
              ] else
                const Text('暂无评价', style: TextStyle(fontSize: 12.0, color: FStyle.c999)),
            ],
          ),
        ),
        ...evaluateList.map((Map<String, dynamic> item) => _buildEvaluateItem(item)),
      ],
    ),
  );
}

/// 评价条目(简版: 头像 + 昵称 + 星级 + 内容 + 图片)
Widget _buildEvaluateItem(Map<String, dynamic> item) {
  final List<String> images = GoodsEvaluateApi.imagesOf(item);
  final String headimg = GoodsEvaluateApi.headimgOf(item);
  final String content = '${item['content'] ?? ''}';
  return Padding(
    padding: const EdgeInsets.only(top: 10.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            ClipOval(
              child: headimg.isEmpty
                  ? Container(
                      width: 26.0,
                      height: 26.0,
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(Icons.person_outline, size: 16.0, color: Colors.grey),
                    )
                  : CachedNetworkImage(
                      imageUrl: headimg,
                      width: 26.0,
                      height: 26.0,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 26.0,
                        height: 26.0,
                        color: const Color(0xFFF0F0F0),
                        child: const Icon(Icons.person_outline, size: 16.0, color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                GoodsEvaluateApi.memberNameOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.0, color: Colors.black87),
              ),
            ),
            StarRating(score: item['scores'] as num? ?? 0, size: 12.0),
          ],
        ),
        if (content.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6.0),
          Text(content, style: const TextStyle(fontSize: 12.0, color: Colors.black87, height: 1.5)),
        ],
        if (images.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: images
                .map((String url) => ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 56.0,
                        height: 56.0,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 56.0,
                          height: 56.0,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 16.0),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    ),
  );
}

Widget _buildAttr() {
  final List<Map<String, String>> items = <Map<String, String>>[];
  for (final dynamic item in attrList) {
    if (item is! Map) continue;
    final String name = '${item['attr_name'] ?? ''}'.trim();
    // 多值用英文逗号分隔,展示时换成顿号
    final String value = '${item['attr_value_name'] ?? ''}'.trim().replaceAll(',', '、');
    if (name.isEmpty || value.isEmpty) continue;
    items.add(<String, String>{'name': name, 'value': value});
  }
  if (items.isEmpty) return const SizedBox.shrink();

  const int defaultRows = 5;
  final bool hasMore = items.length > defaultRows;
  final List<Map<String, String>> visibleItems =
      (attrExpanded || !hasMore) ? items : items.sublist(0, defaultRows);

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10.0),
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10.0,
      children: <Widget>[
        const Text('规格属性', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
            ),
            child: Table(
              columnWidths: const <int, TableColumnWidth>{
                0: FixedColumnWidth(90.0),
                1: FlexColumnWidth(),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
                verticalInside: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
              ),
              children: visibleItems.map<TableRow>((Map<String, String> item) => TableRow(
                children: <Widget>[
                  _buildAttrCell(item['name'] ?? '', color: Colors.grey),
                  _buildAttrCell(item['value'] ?? '', color: Colors.black87),
                ],
              )).toList(),
            ),
          ),
        ),
        if (hasMore)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => attrExpanded = !attrExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(attrExpanded ? '收起' : '展开', style: const TextStyle(fontSize: 13.0, color: Colors.black54)),
                  Icon(attrExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16.0, color: Colors.black54),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _buildAttrCell(String text, {required Color color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
    child: Text(text, style: TextStyle(fontSize: 13.0, color: color, height: 1.5)),
  );
}

/// 图文详情(接口 goods_content 为 HTML)
Widget _buildDetail() {
  return Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 10.0),
    padding: EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10.0,
      children: [
        const Text('商品详情', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
        content.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: const CommonEmpty(text: '暂无详情')),
            )
          : Html(
              data: content,
              shrinkWrap: true,
              style: {
                'body': Style(margin: Margins.zero, fontSize: FontSize(14.0)),
                'img': Style(width: Width(MediaQuery.of(context).size.width - 40.0)),
              },
            ),
      ],
    ),
  );
}

/// 底部操作栏(下架时按钮置灰)
Widget _buildBottomBar(BuildContext context) {
  final Color primary = const Color(0xFFFF2C55);
  final Color disabled = Colors.grey.shade400;
  final double bottomInset = MediaQuery.of(context).padding.bottom;
  return Container(
    color: Colors.white,
    padding: EdgeInsets.only(bottom: bottomInset),
    child: Container(
      height: 54.0,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
      children: [
      Expanded(
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.offAllNamed('/'),
            child: _buildBarIcon('assets/images/c1.png', '首页'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.toNamed('/chat'),
            child: _buildBarIcon('assets/images/c2.png', '客服'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.toNamed('/cart'),
            child: _buildBarIcon('assets/images/c3.png', '购物车', badge: cartNum),
          ),
        ],
      ),
      ),
      Container(
        alignment: Alignment.center,
      height: 36.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onSale ? const Color(0xFFFFEBEB) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSale ? (addingCart ? null : () => _showSkuSheet(action: 'cart')) : null,
              child: addingCart
                ? const SizedBox(
                    width: 14.0,
                    height: 14.0,
                    child: CircularProgressIndicator(color: Color(0xFFFF2C55), strokeWidth: 2.0),
                  )
                : Text('加入购物车', style: TextStyle(color: onSale ? primary : disabled, fontSize: 14.0),),
            ),
          ),
          GestureDetector(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              color: onSale ? primary : disabled,
              child: Text(onSale ? '立即购买' : '已下架', style: const TextStyle(color: Colors.white, fontSize: 14.0),),
            ),
            onTap: onSale ? () => _showSkuSheet(action: 'buy') : null,
          ),
        ],
      ),
      ),
      ],
    ),
    ),
  );
}

/// 底部操作栏图标(首页 / 客服 / 购物车): 用本地切图 assets/images/c1.png ~ c3.png
/// * [badge] > 0 时右上角显示数量红点(购物车)
Widget _buildBarIcon(String asset, String label, {int badge = 0}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            width: 22.0,
            height: 22.0,
            fit: BoxFit.contain,
            isAntiAlias: true,
            // 切图缺失时退化成同尺寸占位,避免红屏
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                const SizedBox(width: 22.0, height: 22.0),
          ),
          Text(label, style: TextStyle(fontSize: 12.0),)
        ],
      ),
      if (badge > 0)
        Positioned(
          right: -6.0,
          top: -2.0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16.0, minHeight: 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2C55),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.white, width: 1.0),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w600),
            ),
          ),
        ),
    ],
  );
}
}
