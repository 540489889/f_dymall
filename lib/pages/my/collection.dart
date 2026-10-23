/// 我的收藏(我的 -> 顶部收藏图标)
/// * 接口: /api/goodscollect/page(page / page_size),与 H5 pages_tool/member/collection 同一接口
/// * 列表: 左图 + 商品名 + 价格,右侧按钮取消收藏(/api/goodscollect/delete)
/// * 点击整卡进商品详情(/goods);取消收藏后本地移除该项
/// * 状态: 首次加载 Loading / 无数据空态 / 滚到底部自动加载下一页
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/goods.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/common_empty.dart';
import '../../components/loading.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  /// 每页条数(与 H5 mescroll size 一致)
  static const int pageSize = 10;

  final ScrollController scrollController = ScrollController();

  /// 收藏列表(页面结构: goodsId / skuId / title / price / image)
  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  int page = 1;
  bool loading = false;
  /// 首次加载(用于 Loading 占位,避免先闪空态)
  bool firstLoad = true;
  bool hasMore = true;
  /// 正在取消收藏的商品id(按钮置灰,避免连点)
  int removingId = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    loadList(refresh: true);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  /// 拉取收藏(refresh: 重新查;否则加载下一页)
  Future<void> loadList({bool refresh = false}) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> res = await GoodsApi.collectPage(page: page, pageSize: pageSize);
      if (!mounted) return;
      final List<dynamic> rawList = (res['list'] ?? const <dynamic>[]) as List<dynamic>;
      final List<Map<String, dynamic>> newList = rawList
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        hasMore = (res['hasMore'] ?? false) as bool;
        if (refresh) {
          list = newList;
        } else {
          list.addAll(newList);
        }
        page += 1;
        firstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => firstLoad = false);
        MyDialog.toast('收藏加载失败,请重试');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 滚到底部加载更多
  void _onScroll() {
    if (loading || !hasMore) return;
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      loadList();
    }
  }

  /// 进商品详情
  void openDetail(Map<String, dynamic> item) {
    final int goodsId = (item['goodsId'] as num?)?.toInt() ?? 0;
    if (goodsId == 0) {
      MyDialog.toast('商品信息缺失');
      return;
    }
    Get.toNamed('/goods', arguments: <String, dynamic>{'goodsId': goodsId});
  }

  /// 取消收藏: 成功后本地移除该项(列表为空时接口会返回空,无需再刷新)
  Future<void> removeItem(Map<String, dynamic> item) async {
    final int goodsId = (item['goodsId'] as num?)?.toInt() ?? 0;
    if (goodsId == 0 || removingId != 0) return;
    setState(() => removingId = goodsId);
    try {
      final int rows = await GoodsApi.collectDelete(goodsId: goodsId);
      if (!mounted) return;
      if (rows <= 0) {
        MyDialog.toast('取消收藏失败,请重试');
        return;
      }
      setState(() {
        list.removeWhere((Map<String, dynamic> e) => (e['goodsId'] as num?)?.toInt() == goodsId);
      });
      MyDialog.toast('已取消收藏');
    } catch (e) {
      if (mounted) MyDialog.toast('取消收藏失败,请重试');
    } finally {
      if (mounted) setState(() => removingId = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Color(0xFF222222)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '我的收藏',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
        ),
      ),
      body: _buildList(),
    );
  }

  /// 列表主体: 首屏 Loading / 空态 / 卡片列表 + 底部加载中
  Widget _buildList() {
    if (firstLoad) return const Center(child: Loading(title: '加载中...'));
    if (list.isEmpty) {
      return Center(
        child: CommonEmpty(text: '暂无收藏的商品', imageWidth: 100.0),
      );
    }
    // 滚动条关掉(与项目其它列表一致,拖动时不会浮出一条灰色滚动条)
    return ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
        // 满一页时才挂尾部提示: 还有下一页显示加载中,没有则显示"已经到底了"
        itemCount: list.length + (list.length >= pageSize ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= list.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Center(
                child: hasMore
                    ? const Loading(title: '加载中...')
                    : const Text(
                        '已经到底了',
                        style: TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB)),
                      ),
              ),
            );
          }
          return _buildCard(list[index]);
        },
      ),
    );
  }

  /// 单条收藏: 左图 + 名称/价格 + 右侧「取消收藏」文字按钮
  Widget _buildCard(Map<String, dynamic> item) {
    final int goodsId = (item['goodsId'] as num?)?.toInt() ?? 0;
    final String image = '${item['image'] ?? ''}';
    final String title = '${item['title'] ?? ''}'.trim();
    final num price = (item['price'] as num?) ?? 0;
    final bool removing = removingId == goodsId;
    return GestureDetector(
      onTap: () => openDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10.0, offset: Offset(0, 3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: image.isEmpty
                  ? Container(
                      width: 88.0,
                      height: 88.0,
                      color: const Color(0xFFF5F5F5),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, size: 30.0, color: Color(0xFFDDDDDD)),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 88.0,
                      height: 88.0,
                      fit: BoxFit.cover,
                      placeholder: (BuildContext c, String u) => Container(
                        width: 88.0,
                        height: 88.0,
                        color: const Color(0xFFF5F5F5),
                      ),
                      errorWidget: (BuildContext c, String u, Object e) => Container(
                        width: 88.0,
                        height: 88.0,
                        color: const Color(0xFFF5F5F5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 30.0, color: Color(0xFFDDDDDD)),
                      ),
                    ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: SizedBox(
                height: 88.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title.isEmpty ? '商品' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.0, height: 1.35, color: Color(0xFF333333)),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // 价格: ¥ 小字 + 金额
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              const Text(
                                '¥',
                                style: TextStyle(fontSize: 11.0, color: Color(0xFFFF2C55), fontWeight: FontWeight.w600),
                              ),
                              Text(
                                price.toStringAsFixed(2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17.0,
                                  color: Color(0xFFFF2C55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 取消收藏: 文字按钮(替代原删除图标),请求中显示小菊花,避免连点
                        _buildCancelButton(item, removing),
                      ],
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

  /// 取消收藏文字按钮: 灰色描边胶囊,点击调用 [removeItem]
  Widget _buildCancelButton(Map<String, dynamic> item, bool removing) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: removing ? null : () => removeItem(item),
      child: Container(
        height: 28.0,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(14.0),
        ),
        alignment: Alignment.center,
        child: removing
            ? const SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: Color(0xFFBBBBBB)),
              )
            : const Text(
                '取消收藏',
                style: TextStyle(fontSize: 12.0, color: Color(0xFF666666)),
              ),
      ),
    );
  }
}
