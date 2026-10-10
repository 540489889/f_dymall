/// 底部商品框
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../api/goods.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupGoods extends StatefulWidget {
  const PopupGoods({
    super.key,
    this.goodsList,
    this.onRefresh,
    this.anchorName,
    this.anchorAvatar,
    this.roomTitle,
    this.roomSn,
  });

  // 带货商品列表(首屏数据; 打开后会被 onRefresh 的结果覆盖)
  final List? goodsList;
  // 打开时 / 切分类时重新拉取商品: 直播间商品会上下架/改价, 进房时拉的那份到打开购物车时可能已过期
  // * 参数是当前选中的分类 id(「全部」为空串), 由后端按分类返回
  final Future<List<Map<String, dynamic>>> Function(String categoryId)? onRefresh;
  // 主播名(直播间 anchor_name): 为空时标题回退「商品橱窗」
  final String? anchorName;
  // 主播头像(直播间 anchor_img, 完整地址)
  final String? anchorAvatar;
  // 直播间标题(直播间 name): 头部第二行, 没下发时不展示
  final String? roomTitle;
  // 直播间房间号 sn: 点商品进详情时带给详情页, 加购/下单要回传 live_roomid
  final String? roomSn;

  @override
  State<PopupGoods> createState() => _PopupGoodsState();
}

// 分类接口回来后要重建 TabController(长度随分类数量变), 会创建多个 ticker
// * 不能用 SingleTickerProviderStateMixin: 它只允许创建一次 ticker, 第二次直接抛异常,
//   新 controller 建不出来 -> TabBar 还绑着长度为 1 的旧 controller -> 点分类没反应
class _PopupGoodsState extends State<PopupGoods> with TickerProviderStateMixin {
// 商品分类标签: 第一个固定「全部」, 其余来自 /api/Shop/getGoodsCategory
// * 接口未回来/失败时只有「全部」, 不再内置写死的演示分类
List<String> goodsTag = <String>['全部'];
// 与 goodsTag 一一对应的分类 id(「全部」为空串), 切 tab 时用它筛选列表
List<String> categoryIds = <String>[''];
// 当前 tab 下标
int tabIndex = 0;

late TabController tabController = _newTabController();

/// 建 tab controller: 长度写在 controller 里,分类数量变化时必须重建
TabController _newTabController() {
  final TabController controller = TabController(initialIndex: 0, length: goodsTag.length, vsync: this);
  controller.addListener(_onTabChanged);
  return controller;
}

// 商品请求序号: 连着切 tab 时, 只认最后一次请求的结果(先发后到的旧结果不能覆盖新分类的列表)
int _refreshSeq = 0;

/// tab 切换: 只在实际选中项变化时刷新(拖动过程中 offset 每帧都回调)
/// * 切分类要重新请求: 商品列表由后端按 category_id 返回, 不是在本地筛首屏那份
void _onTabChanged() {
  if (!mounted || tabController.index == tabIndex) return;
  tabIndex = tabController.index;
  setState(() {});
  if (kDebugMode) {
    debugPrint('[live]购物车切分类 -> index=$tabIndex cid=${_currentCategoryId.isEmpty ? '(全部)' : _currentCategoryId}');
  }
  _refreshGoods(applyEmpty: true);
}

// 当前展示的商品(先用外部传入的首屏数据占位, 刷新成功后整体替换)
List<Map<String, dynamic>> goods = <Map<String, dynamic>>[];
// 是否正在重新拉取
bool refreshing = false;

// 头部主播信息(真实数据, 由直播间页传入)
String get _anchorAvatar => (widget.anchorAvatar ?? '').trim();
String get _roomTitle => (widget.roomTitle ?? '').trim();
// 橱窗标题「xxx的橱窗」; 主播名没下发时回退「商品橱窗」
String get _shopTitle {
  final String name = (widget.anchorName ?? '').trim();
  return name.isEmpty ? '商品橱窗' : '$name的橱窗';
}

@override
void initState() {
  super.initState();
  goods = _normalize(widget.goodsList);
  // 每次打开都重新拉一次商品列表
  _refreshGoods();
  // 商品分类 tab(/api/Shop/getGoodsCategory)
  _loadCategory();
}

/// 商品分类(/api/Shop/getGoodsCategory): 回来后重建 tab
/// * tab 数量变了必须换 controller(TabController 的 length 是构造时固定的)
/// * 接口为空/失败时保持只有「全部」, 商品列表照常展示
Future<void> _loadCategory() async {
  final List<Map<String, dynamic>> list = await GoodsApi.shopGoodsCategory();
  if (!mounted || list.isEmpty) return;
  final List<String> names = <String>['全部'];
  final List<String> ids = <String>[''];
  for (final Map<String, dynamic> item in list) {
    final String name = '${item['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    names.add(name);
    ids.add('${item['id'] ?? ''}'.trim());
  }
  if (names.length <= 1) return;
  final TabController old = tabController;
  setState(() {
    goodsTag = names;
    categoryIds = ids;
    tabIndex = 0;
    tabController = _newTabController();
  });
  old.dispose();
}

/// 当前选中分类的 id(「全部」为空串)
String get _currentCategoryId => tabIndex < categoryIds.length ? categoryIds[tabIndex] : '';

/// 列表数据: 选中具体分类时按分类 id 过滤(兜底)
/// * 主要靠接口带 category_id 返回; 后端忽略该参数时(商品自带分类字段)这里再筛一次
/// * 筛不出任何一条时不本地过滤: 说明接口已按分类返回/商品分类字段与 tab 对不上,
///   再过滤只会把列表清空, 看着就像点了没反应
List<Map<String, dynamic>> get visibleGoods {
  final String cid = _currentCategoryId;
  if (cid.isEmpty) return goods;
  final List<Map<String, dynamic>> matched =
      goods.where((Map<String, dynamic> e) => categoryIdOf(e) == cid).toList();
  return matched.isEmpty ? goods : matched;
}

/// 商品条目上的分类 id(兼容 category_id / cate_id)
static String categoryIdOf(Map<String, dynamic> item) =>
    '${item['category_id'] ?? item['cate_id'] ?? ''}'.trim();

/// 外部传入的 List 归一化成 List<Map>(接口返回与本地演示数据混用时类型可能不一致)
static List<Map<String, dynamic>> _normalize(List? list) {
  if (list == null || list.isEmpty) return <Map<String, dynamic>>[];
  return list.whereType<Map>().map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>()).toList();
}

/// 重新拉取商品列表(带当前分类 id)
/// * [applyEmpty] 是否接受空结果: 首次打开时不接受(请求失败/房间没商品时保留首屏数据, 不至于刷没),
///   切分类时接受(该分类就是没有商品, 要显示空态而不是留着上一个分类的列表)
/// * 请求期间又切了 tab: 用序号丢弃旧结果
Future<void> _refreshGoods({bool applyEmpty = false}) async {
  final Future<List<Map<String, dynamic>>> Function(String)? onRefresh = widget.onRefresh;
  if (onRefresh == null) return;
  final int seq = ++_refreshSeq;
  final String cid = _currentCategoryId;
  setState(() => refreshing = true);
  try {
    final List<Map<String, dynamic>> list = await onRefresh(cid);
    // 排查分类没反应: 打印每次请求的结果(含被丢弃的旧请求)
    if (kDebugMode) {
      debugPrint('[live]购物车 cid=${cid.isEmpty ? '(全部)' : cid} seq=$seq/$_refreshSeq -> ${list.length} 条');
    }
    if (!mounted || seq != _refreshSeq || cid != _currentCategoryId) return;
    if (list.isEmpty && !applyEmpty) return;
    setState(() => goods = list);
  } catch (_) {
    // 失败静默: 保留首屏数据
  } finally {
    if (mounted && seq == _refreshSeq) setState(() => refreshing = false);
  }
}

@override
void dispose() {
  tabController.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  // 底部安全距离(iPhone home 指示条): 弹窗要一直铺到屏幕最底, 否则底部会露出一条透明的缝
  // * 这个值改用在列表的底部内边距上, 避免最后一个商品被指示条压住
  final double bottomInset = MediaQuery.of(context).padding.bottom;
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: Column(
        children: [
          Expanded(
          child: GestureDetector(
            child: Container(
              color: Colors.transparent,
            ),
            onTap: () {
                Get.back();
              },
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 3 / 4, // 自定义高度
            child: Material(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 10.0, top: 10.0, bottom: 5.0, right: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                      Expanded(
                          child: Row(
                          spacing: 5.0,
                          children: [
                          ClipOval(
                            child: _anchorAvatar.isEmpty
                                // 接口没下发头像: 用灰底圆兜住, 不用写死的演示头像
                                ? Container(height: 35.0, width: 35.0, color: const Color(0xFFE5E5E5))
                                : CachedNetworkImage(
                                    imageUrl: _anchorAvatar,
                                    height: 35.0,
                                    width: 35.0,
                                    fit: BoxFit.cover,
                                    placeholder: (BuildContext c, String u) =>
                                        Container(height: 35.0, width: 35.0, color: const Color(0xFFE5E5E5)),
                                    // 加载失败(默认头像 404 等)同样回落灰底圆
                                    errorWidget: (BuildContext c, String u, Object e) =>
                                        Container(height: 35.0, width: 35.0, color: const Color(0xFFE5E5E5)),
                                  ),
                          ),
                          Expanded(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 橱窗名(真实主播名): 去掉原来的箭头图标
                              Text(_shopTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600),),
                              // 第二行: 直播间标题(真实数据); 接口没下发时不占高度
                              if (_roomTitle.isNotEmpty)
                              Text(_roomTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey, fontSize: 12.0,),),
                              ],
                            ),
                          ),
                              ],
                              ),
                            ),
                            Wrap(
                              spacing: 15.0,
                              children: [
                              // 购物车: 跳购物车页(/cart)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Get.toNamed('/cart'),
                                child: Column(
                                children: [
                                  // 用本地切图(原 16 的 Icon 偏小,放大到 22 更醒目)
                                  Image.asset(
                                    'assets/images/c3.png',
                                    width: 22.0,
                                    height: 22.0,
                                    fit: BoxFit.contain,
                                    isAntiAlias: true,
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                                        const SizedBox(width: 22.0, height: 22.0),
                                  ),
                                Text('购物车', style: TextStyle(color: Colors.black54, fontSize: 12.0,),),
                              ],
                            ),
                              ),
                            // 订单: 跳订单列表(/order)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Get.toNamed('/order'),
                              child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/c4.png',
                                  width: 22.0,
                                  height: 22.0,
                                  fit: BoxFit.contain,
                                  isAntiAlias: true,
                                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                                      const SizedBox(width: 22.0, height: 22.0),
                                ),
                                Text('订单', style: TextStyle(color: Colors.black54, fontSize: 12.0,),),
                              ],
                            ),
                              ),
                              ]
                            ),
                          ],
                      ),
                      Container(
                        height: 35.0,
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 5.0),
                      child: TabBar(
                        controller: tabController,
                        tabs: goodsTag.map((v) => Tab(text: v)).toList(),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        unselectedLabelColor: Colors.black38,
                        labelColor: Colors.black,
                        indicatorColor: Colors.black,
                        indicatorSize: TabBarIndicatorSize.tab,
                        unselectedLabelStyle: TextStyle(fontSize: 14.0, fontFamily: 'Microsoft YaHei'),
                        labelStyle: TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                        dividerHeight: 0,
                        labelPadding: EdgeInsets.symmetric(horizontal: 7.5),
                        indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
                        ),
                      ),
                    ],
                    ),
                  ),
                  // 刷新中: 顶部细进度条(商品列表整体替换前给个反馈)
                  if (refreshing)
                    const SizedBox(
                      height: 2.0,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2C55)),
                      ),
                    ),
                  Expanded(
                    // 列表为空(接口返回空/该分类下没商品): 给个空提示,而不是一片空白
                    // * 请求中不显示: 否则每次切 tab 都会先闪一下空态
                    child: visibleGoods.isEmpty && !refreshing
                        ? Center(
                            child: Text(
                              _currentCategoryId.isEmpty ? '暂无带货商品' : '该分类下暂无商品',
                              style: const TextStyle(color: Colors.black38, fontSize: 13.0),
                            ),
                          )
                        : ListView.builder(
                      shrinkWrap: true,
                      // 底部补安全距离: 弹窗已铺到屏幕底, 不补的话最后一个商品会被 home 指示条压住
                      padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + bottomInset),
                      itemCount: visibleGoods.length,
                      itemBuilder: (context, index) {
                    final Map<String, dynamic> item = visibleGoods[index];
                    // 商品id: 跳详情传的是商城商品id(goods_id, 如 38), 不是直播列表这条记录的 id(如 897)
                    // * 拿 id 去查 /api/goodssku/detail 会查到别的商品, 后端返回 code != 0
                    // * 详情页按 int 解析, 非数字会被兜成 1, 这里先挡掉
                    final int? gid = int.tryParse('${item['goods_id'] ?? item['id'] ?? ''}'.trim());
                    return InkWell(
                      // 整卡点击进商品详情(/goods); 右下「领券购买」在同一个热区内, 点它同样进详情
                      onTap: gid == null ? null : () {
                        if (kDebugMode) {
                          debugPrint('[live]购物车跳详情: goods_id=$gid live_id=${item['live_id'] ?? ''}');
                        }
                        Get.toNamed('/goods', arguments: <String, dynamic>{
                          'goodsId': gid,
                          // 直播间房间号: 详情里加购 / 下单要回传 live_roomid
                          'live_roomid': (widget.roomSn ?? '').trim(),
                        });
                      },
                      borderRadius: BorderRadius.circular(10.0),
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10.0,
                    children: [
                      Stack(
                        children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Image.network('${item['image']}', height: 100.0, width: 100.0, fit: BoxFit.cover,),
                        ),
                        Positioned(
                          left: 0.0,
                          top: 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(10.0), bottomRight: Radius.circular(6.0),),
                            ),
                            child: Text('${index+1}', style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w900),),
                          ),
                        ),
                        Visibility(
                          visible: index == 0,
                          child: Positioned(
                            left: 0.0,
                            right: 0.0,
                          bottom: 0.0,
                            child: Container(
                              padding: const EdgeInsets.all(3.0),
                              decoration: BoxDecoration(
                                color: Color(0xFFFF2C55).withAlpha(220),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.0)),
                              ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/wave.png', height: 18.0,),
                              Text('讲解中', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                            ],
                              ),
                            ),
                            ),
                          ),
                          ],
                        ),
                        Expanded(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['title']}', maxLines: 1, style: const TextStyle(fontSize: 15.0,), overflow: TextOverflow.ellipsis,),
                            // 副标题(tips): 服务端未下发时不留空行(空文本照样占一行高度, 视觉上就是标题下方一大块空白)
                            if ('${item['tips']}'.trim().isNotEmpty)
                            Text('${item['tips']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 12.0,),),
                            const SizedBox(height: 4.0,),
                            Wrap(
                              spacing: 5.0,
                              children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFFD7970), width: .5),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: const Text('立减3元', style: TextStyle(color: Colors.red, fontSize: 10.0,),),
                              ),
                              Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFFDBA54), width: .5),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: const Text('新人立减10元', style: TextStyle(color: Colors.orange, fontSize: 10.0,),),
                            ),
                            ],
                          ),
                          const SizedBox(height: 6.0,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // 价格行: 独占一行, 不再与购买按钮挤在一行
                            Row(
                              children: [
                                const Text('¥', style: TextStyle(color: Colors.red, fontSize: 12.0),),
                                Flexible(
                                  child: Text('${item['price']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 16.0),),
                                ),
                                // 划线价: 接口 market_price 常下发 0, 没有原价时整段不展示(否则显示 "¥0")
                                if ('${item['mprice']}'.trim().isNotEmpty)
                                const SizedBox(width: 5.0,),
                                if ('${item['mprice']}'.trim().isNotEmpty)
                                const Text(' 券后价 ', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
                                if ('${item['mprice']}'.trim().isNotEmpty)
                                Flexible(
                                  child: Text('¥${item['mprice']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 10.0, decoration: TextDecoration.lineThrough),),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8.0,),
                          // 购买行: 领券购买按钮独占下一行, 靠右对齐
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                alignment: Alignment.center,
                                height: 30.0,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  child: Row(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 7.0),
                                        child: Icon(Icons.add_shopping_cart, color: Colors.grey, size: 16.0,),
                                      ),
                                      Container(
                                        alignment: Alignment.center,
                                        height: 30.0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                        color: Color(0xFFFF2C55),
                                        child: const Text('领券购买', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                      ),
                                      ],
                                      ),
                                    ),
                                    ],
                                  ),
                          ],
                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
    );
  }
}
