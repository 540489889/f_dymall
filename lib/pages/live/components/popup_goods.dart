/// 底部商品框
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupGoods extends StatefulWidget {
  const PopupGoods({
    super.key,
    this.goodsList,
    this.onRefresh,
    this.anchorName,
    this.anchorAvatar,
    this.roomTitle,
  });

  // 带货商品列表(首屏数据; 打开后会被 onRefresh 的结果覆盖)
  final List? goodsList;
  // 打开时重新拉取商品: 直播间商品会上下架/改价, 进房时拉的那份到打开购物车时可能已过期
  final Future<List<Map<String, dynamic>>> Function()? onRefresh;
  // 主播名(直播间 anchor_name): 为空时标题回退「商品橱窗」
  final String? anchorName;
  // 主播头像(直播间 anchor_img, 完整地址)
  final String? anchorAvatar;
  // 直播间标题(直播间 name): 头部第二行, 没下发时不展示
  final String? roomTitle;

  @override
  State<PopupGoods> createState() => _PopupGoodsState();
}

class _PopupGoodsState extends State<PopupGoods> with SingleTickerProviderStateMixin {
// 商品分类标签
List goodsTag = ['全部', '书籍杂志', '学习用品', '零食特产', '生鲜', '粮油调味', '生活电器', '内衣裤袜', '3C数码配件'];

late TabController tabController = TabController(initialIndex: 0, length: goodsTag.length, vsync: this);

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
}

/// 外部传入的 List 归一化成 List<Map>(接口返回与本地演示数据混用时类型可能不一致)
static List<Map<String, dynamic>> _normalize(List? list) {
  if (list == null || list.isEmpty) return <Map<String, dynamic>>[];
  return list.whereType<Map>().map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>()).toList();
}

/// 重新拉取商品列表
/// * 返回空 / 请求失败时保留原列表, 避免把已有内容刷没
Future<void> _refreshGoods() async {
  final Future<List<Map<String, dynamic>>> Function()? onRefresh = widget.onRefresh;
  if (onRefresh == null) return;
  setState(() => refreshing = true);
  try {
    final List<Map<String, dynamic>> list = await onRefresh();
    if (!mounted || list.isEmpty) return;
    setState(() => goods = list);
  } catch (_) {
    // 失败静默: 保留首屏数据
  } finally {
    if (mounted) setState(() => refreshing = false);
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
                                  Icon(Icons.shopping_cart_rounded, color: Colors.black54, size: 16.0,),
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
                                Icon(Icons.my_library_books_rounded, color: Colors.black54, size: 16.0,),
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      // 底部补安全距离: 弹窗已铺到屏幕底, 不补的话最后一个商品会被 home 指示条压住
                      padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + bottomInset),
                      itemCount: goods.length,
                      itemBuilder: (context, index) {
                    final Map<String, dynamic> item = goods[index];
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
                        Get.toNamed('/goods', arguments: <String, dynamic>{'goodsId': gid});
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
                          child: Image.network('${goods[index]['image']}', height: 100.0, width: 100.0, fit: BoxFit.cover,),
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
                            Text('${goods[index]['title']}', maxLines: 1, style: const TextStyle(fontSize: 15.0,), overflow: TextOverflow.ellipsis,),
                            // 副标题(tips): 服务端未下发时不留空行(空文本照样占一行高度, 视觉上就是标题下方一大块空白)
                            if ('${goods[index]['tips']}'.trim().isNotEmpty)
                            Text('${goods[index]['tips']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 12.0,),),
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
                                  child: Text('${goods[index]['price']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 16.0),),
                                ),
                                // 划线价: 接口 market_price 常下发 0, 没有原价时整段不展示(否则显示 "¥0")
                                if ('${goods[index]['mprice']}'.trim().isNotEmpty)
                                const SizedBox(width: 5.0,),
                                if ('${goods[index]['mprice']}'.trim().isNotEmpty)
                                const Text(' 券后价 ', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
                                if ('${goods[index]['mprice']}'.trim().isNotEmpty)
                                Flexible(
                                  child: Text('¥${goods[index]['mprice']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 10.0, decoration: TextDecoration.lineThrough),),
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
