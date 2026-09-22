/// 商品评价列表
/// 对齐 H5: pages_tool/goods/evaluate.vue
/// * 入参 goods_id(Get.arguments: { goods_id: 1 })
/// * /api/goodsevaluate/getgoodsevaluate 各类型数量
/// * /api/goodsevaluate/page 评价列表(按 explain_type 筛选,滚动加载更多)
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../api/goods_evaluate.dart';
import '../../components/loading.dart';
import '../../styles/index.dart';

/// 评分星级(5 分制)
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.score,
    this.size = 14.0,
    this.color = const Color(0xFFFA9A02),
  });

  final num score;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double value = score.toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final double fill = (value - index).clamp(0.0, 1.0);
        final IconData icon = fill >= 1
            ? Icons.star_rounded
            : (fill > 0 ? Icons.star_half_rounded : Icons.star_border_rounded);
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

class GoodsEvaluatePage extends StatefulWidget {
  const GoodsEvaluatePage({super.key, this.goodsId = 0});

  /// 商品id(命名路由进入时以 arguments 为准)
  final int goodsId;

  @override
  State<GoodsEvaluatePage> createState() => _GoodsEvaluatePageState();
}

class _GoodsEvaluatePageState extends State<GoodsEvaluatePage> {
  static const Color primary = Color(0xFFFF2C55);
  static const int pageSize = 10;

  final ScrollController controller = ScrollController();

  /// 各类型数量: 全部 / 好评 / 中评 / 差评(下标即 explain_type)
  List<int> counts = <int>[0, 0, 0, 0];
  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  int tabIndex = 0;
  int page = 1;
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.position.pixels >= controller.position.maxScrollExtent - 200 && hasMore && !loadingMore) {
        loadMore();
      }
    });
    loadCount();
    loadList();
  }

  /// 商品id: 路由传 Map / 数字 / 字符串,缺省用构造参数
  int get goodsId {
    final dynamic own = widget.goodsId;
    final int ownId = own is int ? own : int.tryParse('$own') ?? 0;
    final dynamic args = Get.arguments;
    if (args is Map) return int.tryParse('${args['goods_id'] ?? args['goodsId'] ?? args['id'] ?? ''}') ?? ownId;
    return int.tryParse('$args') ?? ownId;
  }

  /// 各类型评价数量
  Future<void> loadCount() async {
    try {
      final Map<String, dynamic> data = await GoodsEvaluateApi.count(goodsId);
      if (!mounted) return;
      setState(() {
        counts = <int>[
          int.tryParse('${data['total'] ?? 0}') ?? 0,
          int.tryParse('${data['haoping'] ?? 0}') ?? 0,
          int.tryParse('${data['zhongping'] ?? 0}') ?? 0,
          int.tryParse('${data['chaping'] ?? 0}') ?? 0,
        ];
      });
    } catch (_) {}
  }

  /// 评价列表
  Future<void> loadList({bool refresh = true}) async {
    if (refresh) {
      page = 1;
      hasMore = true;
      loading = true;
    } else {
      loadingMore = true;
    }
    if (mounted) setState(() {});
    try {
      final Map<String, dynamic> data = await GoodsEvaluateApi.page(
        goodsId: goodsId,
        page: page,
        pageSize: pageSize,
        explainType: tabIndex,
      );
      final List<Map<String, dynamic>> newList = GoodsEvaluateApi.listOf(data);
      final int count = int.tryParse('${data['count'] ?? 0}') ?? 0;
      if (!mounted) return;
      setState(() {
        list = refresh ? newList : <Map<String, dynamic>>[...list, ...newList];
        hasMore = list.length < count;
        loading = false;
        loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  Future<void> loadMore() async {
    page += 1;
    await loadList(refresh: false);
  }

  /// 切换筛选
  void onTab(int index) {
    if (index == tabIndex) return;
    setState(() => tabIndex = index);
    loadList();
  }

  /// 图片预览
  void preview(List<String> urls, int index) {
    if (urls.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: <Widget>[
              PageView.builder(
                controller: PageController(initialPage: index),
                itemCount: urls.length,
                itemBuilder: (BuildContext context, int i) => Center(
                  child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: 16.0,
                top: MediaQuery.of(context).padding.top + 8.0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26.0),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('商品评价', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          _buildTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 筛选: 全部 / 好评 / 中评 / 差评
  Widget _buildTabs() {
    const List<String> names = <String>['全部', '好评', '中评', '差评'];
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        children: List<Widget>.generate(names.length, (int index) {
          final bool active = index == tabIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTab(index),
              child: Container(
                margin: EdgeInsets.only(right: index == names.length - 1 ? 0.0 : 8.0),
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                decoration: BoxDecoration(
                  color: active ? primary : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(15.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${names[index]}(${counts[index]})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.0, color: active ? Colors.white : Colors.black87),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: Loading(title: '加载中...'));
    if (list.isEmpty) {
      return const Center(
        child: Text('暂无商品评价', style: TextStyle(fontSize: 13.0, color: FStyle.c999)),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(10.0),
      itemCount: list.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10.0),
      itemBuilder: (BuildContext context, int index) {
        if (index == list.length) {
          return hasMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(child: Loading(title: '加载中...')),
                )
              : const SizedBox(height: 12.0);
        }
        return _buildItem(list[index]);
      },
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final List<String> images = GoodsEvaluateApi.imagesOf(item);
    final List<String> againImages = GoodsEvaluateApi.imagesOf(item, field: 'again_images');
    final String headimg = GoodsEvaluateApi.headimgOf(item);
    final String time = GoodsEvaluateApi.timeOf(item);
    final String explain = '${item['explain_first'] ?? ''}';
    final String againContent = '${item['again_content'] ?? ''}';
    final String againExplain = '${item['again_explain'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipOval(
                child: headimg.isEmpty
                    ? Container(
                        width: 36.0,
                        height: 36.0,
                        color: const Color(0xFFF0F0F0),
                        child: const Icon(Icons.person_outline, size: 20.0, color: Colors.grey),
                      )
                    : CachedNetworkImage(
                        imageUrl: headimg,
                        width: 36.0,
                        height: 36.0,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 36.0,
                          height: 36.0,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.person_outline, size: 20.0, color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  GoodsEvaluateApi.memberNameOf(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.0, color: Colors.black87),
                ),
              ),
              StarRating(score: item['scores'] as num? ?? 0),
            ],
          ),
          if (time.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6.0),
            Text(time, style: const TextStyle(fontSize: 11.0, color: FStyle.c999)),
          ],
          if ('${item['content'] ?? ''}'.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            Text('${item['content']}', style: const TextStyle(fontSize: 13.0, color: Colors.black87, height: 1.5)),
          ],
          if (images.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            _buildImages(images),
          ],
          // 商家回复
          if (explain.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            _buildReply('商家回复：$explain'),
          ],
          // 追评
          if (againContent.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10.0),
            const Text('追加评价', style: TextStyle(fontSize: 13.0, color: primary)),
            const SizedBox(height: 6.0),
            Text(againContent, style: const TextStyle(fontSize: 13.0, color: Colors.black87, height: 1.5)),
            if (againImages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8.0),
              _buildImages(againImages),
            ],
            if (againExplain.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8.0),
              _buildReply('商家回复：$againExplain'),
            ],
          ],
        ],
      ),
    );
  }

  /// 评价图片(九宫格)
  Widget _buildImages(List<String> urls) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: List<Widget>.generate(urls.length, (int index) {
        return GestureDetector(
          onTap: () => preview(urls, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: CachedNetworkImage(
              imageUrl: urls[index],
              width: 76.0,
              height: 76.0,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 76.0,
                height: 76.0,
                color: const Color(0xFFF0F0F0),
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20.0),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 商家回复(灰底块)
  Widget _buildReply(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(6.0)),
      child: Text(text, style: const TextStyle(fontSize: 12.0, color: Colors.black87, height: 1.5)),
    );
  }
}
