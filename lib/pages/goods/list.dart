/// 商品列表(搜索结果 / 分类列表)
/// * 入参(arguments): {'keyword': 'xxx', 'categoryId': 1}
///   - keyword: 搜索关键词(搜索页跳过来)
///   - categoryId: 指定一级分类(分类入口跳过来)
/// * 顶部: 居中标题 + 搜索框(框内右侧搜索图标,框外右侧列表样式切换)
/// * 排序栏: 综合 / 销量 / 价格 / 筛选(筛选抽屉: 一级分类 + 价格区间)
/// * 列表: /api/goodssku/page,支持 category_id / keyword / order / sort / min_price / max_price
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/goods.dart';
import '../../components/common_empty.dart';
import '../../components/loading.dart';
import '../../components/skeleton.dart';
// 商品卡片复用首页的 CardItem(视觉与首页瀑布流保持一致)
import '../index/index.dart' show CardItem;

class GoodsListPage extends StatefulWidget {
  const GoodsListPage({super.key});

  @override
  State<GoodsListPage> createState() => _GoodsListPageState();
}

class _GoodsListPageState extends State<GoodsListPage> {
  /// 每页条数
  static const int pageSize = 12;

  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  /// 搜索关键词
  String keyword = '';
  /// 当前一级分类(0 = 全部)
  int categoryId = 0;
  /// 一级分类列表 [{category_id, category_name, ...}]
  List<Map<String, dynamic>> categoryList = <Map<String, dynamic>>[];
  /// 排序字段: 空=综合, sale_num=销量, discount_price=价格
  String order = '';
  /// 排序方向: desc / asc
  String sort = 'desc';

  List<dynamic> goodsList = <dynamic>[];
  int page = 1;
  int pageCount = 1;
  /// 是否双列(瀑布流),false = 单列大卡
  bool isDoubleColumn = true;
  bool loading = false;
  /// 首次加载(用于骨架屏占位,避免先闪空态)
  bool firstLoad = true;
  /// 总条数(用于"共N件商品")
  int count = 0;

  /// 筛选: 最低价 / 最高价
  num? minPrice;
  num? maxPrice;

  /// 筛选是否生效(选了分类或填了价格区间)
  bool get screenActive => categoryId > 0 || minPrice != null || maxPrice != null;

  bool get hasMore => page <= pageCount;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      keyword = '${args['keyword'] ?? ''}';
      final dynamic id = args['categoryId'];
      categoryId = id is int ? id : int.tryParse('$id') ?? 0;
    }
    inputController.text = keyword;
    scrollController.addListener(_onScroll);
    loadCategory();
    loadList(refresh: true);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    inputController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  /// 一级分类(用于顶部分类 tab 和筛选抽屉)
  Future<void> loadCategory() async {
    try {
      final List<Map<String, dynamic>> list = await GoodsApi.categoryTree();
      if (!mounted || list.isEmpty) return;
      setState(() => categoryList = list);
    } catch (e) {
      debugPrint('[goodsList]分类加载失败: $e');
    }
  }

  /// 拉取列表(refresh: 换了搜索词/分类/排序/筛选后重新查;否则加载下一页)
  Future<void> loadList({bool refresh = false}) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> res = await GoodsApi.pageList(
        page: page,
        pageSize: pageSize,
        categoryId: categoryId,
        keyword: keyword,
        order: order,
        sort: sort,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
      if (!mounted) return;
      final List<dynamic> list = GoodsApi.toCardList((res['list'] ?? const []) as List);
      setState(() {
        pageCount = (res['page_count'] ?? 1) as int;
        count = (res['count'] ?? 0) as int;
        if (refresh) {
          goodsList = list;
        } else {
          goodsList.addAll(list);
        }
        page += 1;
        firstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => firstLoad = false);
        MyDialog.toast('商品加载失败,请重试');
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

  /// 重新搜索(顶部搜索框改词后)
  void onSearch() {
    final String text = inputController.text.trim();
    if (text.isEmpty) {
      MyDialog.toast('请输入搜索关键词');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      keyword = text;
      goodsList = <dynamic>[];
      page = 1;
      pageCount = 1;
      firstLoad = true;
    });
    loadList(refresh: true);
  }

  /// 切换排序: 综合 / 销量 / 价格(点价格切换 asc <-> desc)
  void onSelectOrder(String value) {
    String nextSort = 'desc';
    if (value == 'discount_price' && order == 'discount_price') {
      nextSort = sort == 'desc' ? 'asc' : 'desc';
    }
    setState(() {
      order = value;
      sort = nextSort;
      goodsList = <dynamic>[];
      page = 1;
      pageCount = 1;
      firstLoad = true;
    });
    loadList(refresh: true);
  }

  /// 打开筛选抽屉(一级分类 + 价格区间)
  void openScreen() {
    // 打开时把当前已生效的价格回写到输入框
    minPriceController.text = minPrice == null ? '' : '$minPrice';
    maxPriceController.text = maxPrice == null ? '' : '$maxPrice';
    scaffoldKey.currentState?.openEndDrawer();
  }

  /// 筛选-确定: 按当前选中的分类 + 价格区间重新查
  void confirmScreen() {
    final String minText = minPriceController.text.trim();
    final String maxText = maxPriceController.text.trim();
    if (minText.isNotEmpty) {
      final num? p = num.tryParse(minText);
      if (p == null || p < 0) {
        MyDialog.toast('最低价不能小于0');
        return;
      }
      minPrice = p;
    } else {
      minPrice = null;
    }
    if (maxText.isNotEmpty) {
      final num? p = num.tryParse(maxText);
      if (p == null || p < 0) {
        MyDialog.toast('最高价不能小于0');
        return;
      }
      maxPrice = p;
    } else {
      maxPrice = null;
    }
    if (minPrice != null && maxPrice != null && minPrice! > maxPrice!) {
      MyDialog.toast('最低价不能大于最高价');
      return;
    }
    Navigator.of(context).pop();
    setState(() {
      goodsList = <dynamic>[];
      page = 1;
      pageCount = 1;
      firstLoad = true;
    });
    loadList(refresh: true);
  }

  /// 筛选-重置: 分类回到"全部",清空价格区间
  void resetScreen() {
    setState(() {
      categoryId = 0;
      minPrice = null;
      maxPrice = null;
      minPriceController.clear();
      maxPriceController.clear();
      goodsList = <dynamic>[];
      page = 1;
      pageCount = 1;
      firstLoad = true;
    });
    Navigator.of(context).pop();
    loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        // AppBar 只放居中标题,搜索框放到页面内容顶部(与标题分开)
        centerTitle: true,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Color(0xFF222222)),
          onPressed: () => Get.back(),
        ),
        actions: const <Widget>[SizedBox(width: 48.0)],
        title: const Text(
          '商品列表',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17.0,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
      ),
      endDrawer: _buildScreenDrawer(),
      body: Column(
        children: <Widget>[
          _buildSearchBar(),
          _buildSortBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  /// 搜索栏(页面内容顶部,与标题栏分开)
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12.0, 2.0, 12.0, 10.0),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildInput()),
          // 列表样式切换图标(放在搜索框外右侧)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => isDoubleColumn = !isDoubleColumn),
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Icon(
                isDoubleColumn ? Icons.grid_view_rounded : Icons.list_rounded,
                size: 22.0,
                color: const Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索框(带当前关键词,右侧搜索图标 + 列表样式切换)
  Widget _buildInput() {
    return Container(
      height: 34.0,
      padding: const EdgeInsets.only(left: 12.0, right: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(17.0),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: inputController,
              textInputAction: TextInputAction.search,
              onSubmitted: (String value) => onSearch(),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '请输入您要搜索的商品',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14.0),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14.0),
              cursorColor: const Color(0xFFFF2C55),
            ),
          ),
          // 搜索图标
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearch,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(Icons.search, color: Color(0xFF999999), size: 20.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类 chip(筛选抽屉内使用)
  Widget _buildChip(String text, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 只用 padding 撑出胶囊高度,不用 alignment(在有界宽度下会把标签拉满一行)
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEBEE) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.0,
            color: selected ? const Color(0xFFFF2C55) : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  /// 排序栏: 综合 / 销量 / 价格 / 筛选,四栏均分
  Widget _buildSortBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 6.0, 0, 10.0),
      child: Row(
        children: <Widget>[
          _buildSortItem(
            '综合',
            active: order.isEmpty,
            onTap: () => onSelectOrder(''),
          ),
          _buildSortItem(
            '销量',
            active: order == 'sale_num',
            onTap: () => onSelectOrder('sale_num'),
          ),
          _buildSortItem(
            '价格',
            active: order == 'discount_price',
            onTap: () => onSelectOrder('discount_price'),
            suffix: SizedBox(
              width: 14.0,
              height: 20.0,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    top: -2.0,
                    child: Icon(
                      Icons.arrow_drop_up,
                      size: 14.0,
                      color: order == 'discount_price' && sort == 'asc'
                          ? const Color(0xFFFF2C55)
                          : const Color(0xFFBBBBBB),
                    ),
                  ),
                  Positioned(
                    bottom: -2.0,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 14.0,
                      color: order == 'discount_price' && sort == 'desc'
                          ? const Color(0xFFFF2C55)
                          : const Color(0xFFBBBBBB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSortItem(
            '筛选',
            // 选了分类或价格时高亮,提醒当前列表是筛过的
            active: screenActive,
            onTap: openScreen,
            suffix: _buildFilterIcon(active: screenActive),
          ),
        ],
      ),
    );
  }

  /// 单个排序项(Expanded 均分,文字居中)
  Widget _buildSortItem(String text, {required bool active, required VoidCallback onTap, Widget? suffix}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              text,
              style: TextStyle(
                fontSize: 14.0,
                color: active ? const Color(0xFFFF2C55) : const Color(0xFF666666),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (suffix != null) const SizedBox(width: 3.0),
            ?suffix,
          ],
        ),
      ),
    );
  }

  /// 筛选图标(漏斗 svg,不生效灰色、生效变红;换形状只改 assets/images/svg/shaixuan.svg)
  Widget _buildFilterIcon({required bool active}) {
    final Color color = active ? const Color(0xFFFF2C55) : const Color(0xFF666666);
    return SvgPicture.asset(
      'assets/images/svg/shaixuan.svg',
      width: 14.0,
      height: 14.0,
      // svg 里是纯黑路径,用 srcIn 染成当前颜色
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// 筛选抽屉(右侧)
  Widget _buildScreenDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // 头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  const Text(
                    '筛选',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 20.0, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 一级分类
                    _buildScreenTitle('全部分类'),
                    const SizedBox(height: 12.0),
                    if (categoryList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '暂无分类',
                          style: TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: [
                          _buildChip('全部', selected: categoryId == 0, onTap: () => setState(() => categoryId = 0)),
                          ...categoryList.map((Map<String, dynamic> item) {
                            final int id = item['category_id'] as int? ?? 0;
                            return _buildChip(
                              '${item['category_name'] ?? ''}',
                              selected: categoryId == id,
                              onTap: () => setState(() => categoryId = id),
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 24.0),
                    // 价格区间
                    _buildScreenTitle('价格区间(元)'),
                    const SizedBox(height: 12.0),
                    Row(
                      children: <Widget>[
                        Expanded(child: _buildPriceField(minPriceController, '最低价')),
                        Container(
                          width: 16.0,
                          height: 1.0,
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          color: const Color(0xFFDDDDDD),
                        ),
                        Expanded(child: _buildPriceField(maxPriceController, '最高价')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: resetScreen,
                      child: Container(
                        height: 40.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: const Text(
                          '重置',
                          style: TextStyle(fontSize: 14.0, color: Color(0xFF666666)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: confirmScreen,
                      child: Container(
                        height: 40.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2C55),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(fontSize: 14.0, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
    );
  }

  /// 筛选价格输入框
  Widget _buildPriceField(TextEditingController controller, String hint) {
    return Container(
      height: 36.0,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.0),
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
      ),
    );
  }

  /// 商品列表
  Widget _buildList() {
    // 首屏用骨架屏占位(与首页一致),避免先闪一下空态
    if (firstLoad) {
      return MasonryGridView.count(
        padding: const EdgeInsets.all(10.0),
        crossAxisCount: isDoubleColumn ? 2 : 1,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        itemCount: 4,
        itemBuilder: (BuildContext context, int index) =>
            SkeletonGoodsCard(horizontal: !isDoubleColumn),
      );
    }
    if (goodsList.isEmpty) return _buildEmpty();
    return isDoubleColumn ? _buildGrid() : _buildSingle();
  }

  /// 空态
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6.0,
        children: <Widget>[
          const CommonEmpty(text: '暂无相关商品', imageWidth: 110.0),
          Text(
            keyword.isEmpty ? '换个分类看看吧' : '换个关键词试试',
            style: const TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }

  /// 双列瀑布流
  Widget _buildGrid() {
    return MasonryGridView.count(
      controller: scrollController,
      padding: const EdgeInsets.all(10.0),
      crossAxisCount: 2,
      mainAxisSpacing: 10.0,
      crossAxisSpacing: 10.0,
      // 还有下一页时末尾补一个 loading
      itemCount: goodsList.length + (hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= goodsList.length) return _buildLoadingMore();
        return CardItem(item: goodsList[index]);
      },
    );
  }

  /// 单列大卡
  Widget _buildSingle() {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(10.0),
      itemCount: goodsList.length + (hasMore ? 1 : 0),
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10.0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= goodsList.length) return _buildLoadingMore();
        return SizedBox(width: double.infinity, child: CardItem(item: goodsList[index], horizontal: true));
      },
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Center(child: Loading()),
    );
  }
}
