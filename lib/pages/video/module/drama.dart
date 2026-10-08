import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/loading.dart';
import '../../../components/backtop.dart';
import '../../../utils/content.dart';

class DramaModule extends StatefulWidget {
  const DramaModule({super.key});
  @override
  State<DramaModule> createState() => _DramaModuleState();
}

class _DramaModuleState extends State<DramaModule> {
  // 模拟数据：与 UI 图对应字段
  List fetchData = [
    {
      'image': 'https://i0.hdslb.com/bfs/bangumi/image/5c1622f50bf3845432a5b321f7a7d3d098e057dd.png',
      'title': '闪婚后，老公竟是豪门继承人',
      'tags': '都市 · 甜宠',
      'view': '356.8万',
      'like': '12.6万',
      'duration': '16:32',
      'badge': '热播',
    },
    {
      'image': 'https://i0.hdslb.com/bfs/archive/855e52477cdb85fcaacbcfb9d37aa6957b777b0c.png',
      'title': '重生后我在乡村做美食',
      'tags': '乡村 · 励志',
      'view': '248.7万',
      'like': '9.8万',
      'duration': '12:45',
      'badge': '上新',
    },
    {
      'image': 'https://s2-10623.kwimgs.com/kimg/bs2/zt-image-host/ChgwOGQyZmFlMGNjMDIxMGFkZTI5YWYwMDYQ3svXLw.jpg',
      'title': '逆袭：从废柴到商界大佬',
      'tags': '逆袭 · 都市',
      'view': '321.3万',
      'like': '18.5万',
      'duration': '15:20',
      'badge': '热播',
    },
    {
      'image': 'https://i0.hdslb.com/bfs/archive/4657b6a60a0eae61f0d1f57da2af4a7b00b99104.png',
      'title': '我的猫系男友太会撩了',
      'tags': '甜宠 · 校园',
      'view': '312.6万',
      'like': '14.2万',
      'duration': '10:36',
      'badge': '上新',
    },
    {
      'image': 'https://i0.hdslb.com/bfs/bangumi/image/6c1ca4159442a6de3577bbee5e583be72b00499f.jpg',
      'title': '乡村喜事：我家有个傻媳妇',
      'tags': '搞笑 · 乡村',
      'view': '289.4万',
      'like': '11.7万',
      'duration': '13:08',
      'badge': '热播',
    },
    {
      'image': 'https://i0.hdslb.com/bfs/bangumi/image/cde0f6de97c5beac7358d3a89a68aa9b37b4c059.png',
      'title': '穿越后我成了王妃',
      'tags': '古装 · 甜宠',
      'view': '376.2万',
      'like': '16.9万',
      'duration': '14:52',
      'badge': '上新',
    },
  ];

  // 分类标签
  final List<String> categories = ['推荐', '都市', '甜宠', '逆袭', '搞笑', '乡村', '古装', '悬疑'];
  int selectedCategory = 0;

  // 列表
  List dataList = [];
  // 是否加载中
  bool isLoading = false;

  late ScrollController scrollController = ScrollController();
  // 记录滚动位置
  final ValueNotifier<double> scrollOffset = ValueNotifier(0);

  // 主色
  static const Color primary = Color(0xFFFF5C33);

  // 加载更多
  Future<void> loadMoreData() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });
    // 模拟网络请求或数据获取延迟
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      dataList.addAll(fetchData);
      isLoading = false;
    });
  }

  // 下拉刷新
  Future<void> handleRefresh() async {
    setState(() {
      dataList.clear();
    });
    loadMoreData();
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      scrollOffset.value = scrollController.offset;

      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        debugPrint('[drama]滚动到底部');
        if (!isLoading) {
          loadMoreData();
        }
      }
    });

    handleRefresh();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 内容SDK已就绪: 直接渲染穿山甲短剧聚合页
    if (Content.ready) {
      return const Scaffold(
        backgroundColor: const Color(0xFFFCF7EE),
        body: SafeArea(
          child: DramaHomeNativeView(
            config: DramaHomeConfig(
              showBackBtn: false,
              freeEpisodesCount: 3,
              unlockEpisodesCountUsingAd: 2,
            ),
          ),
        ),
      );
    }
    // 兜底: 没开通内容合作/H5/初始化失败时, 仍是本地演示列表
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7EE),
      appBar: AppBar(
        toolbarHeight: 0,
        forceMaterialTransparency: true,
      ),
      body: Column(
        children: [
          // 固定在顶部的头部 / 搜索 / 分类
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              children: [
                const SizedBox(height: 8.0),
                _buildHeader(),
                const SizedBox(height: 12.0),
                _buildSearchBar(),
                const SizedBox(height: 12.0),
                _buildCategories(),
                const SizedBox(height: 12.0),
              ],
            ),
          ),
          // 可滚动的短剧列表
          Expanded(
            child: RefreshIndicator(
              backgroundColor: Colors.white,
              color: primary,
              displacement: 10.0,
              onRefresh: handleRefresh,
              child: ListView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                children: [
                  dataList.isEmpty
                      ? const Center(
                          child: RefreshProgressIndicator(
                            backgroundColor: Colors.white,
                            color: primary,
                          ),
                        )
                      : MasonryGridView.count(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12.0,
                          crossAxisSpacing: 12.0,
                          itemCount: dataList.length,
                          itemBuilder: (BuildContext context, int index) => DramaCard(item: dataList[index]),
                        ),
                  dataList.isNotEmpty && isLoading
                      ? const Padding(
                          padding: EdgeInsets.only(top: 16.0, bottom: 20.0),
                          child: Loading(title: '加载中...'),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
      // 返回顶部
      floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
    );
  }

  // 顶部标题区
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左侧标题: 直接用 drama_logo.png 代替整个标题板块(高度与直播页顶 logo 统一为 50)
        Expanded(
          child:         Image.asset(
            'assets/images/newico/drama_logo.png',
            height: 50.0,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
        // 右侧装饰: drama_sticker.png
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Image.asset(
            'assets/images/newico/drama_sticker.png',
            height: 40.0,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // 搜索栏
  Widget _buildSearchBar() {
    return Container(
      height: 42.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21.0),
        border: Border.all(color: const Color(0xFFFFE0D6), width: 1.0),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: Colors.black38, size: 20.0),
          SizedBox(width: 8.0),
          Expanded(
            child: Text(
              '搜索你想看的短剧、剧名、演员...',
              style: TextStyle(color: Colors.black38, fontSize: 13.0),
            ),
          ),
        ],
      ),
    );
  }

  // 分类标签
  Widget _buildCategories() {
    return SizedBox(
      height: 28.0,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final bool selected = index == selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: index == categories.length - 1 ? 0.0 : 12.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: selected
                        ? BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFFF7A45), Color(0xFFF5412C)],
                            ),
                            borderRadius: BorderRadius.circular(14.0),
                          )
                        : null,
                    child: Text(
                      categories[index],
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF5A4A46),
                        fontSize: 13.0,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 固定在最右侧的向下箭头
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 24.0,
              alignment: Alignment.center,
              child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF5A4A46), size: 20.0),
            ),
          ),
        ],
      ),
    );
  }
}

// 卡片组件
class DramaCard extends StatelessWidget {
  final dynamic item;
  const DramaCard({super.key, required this.item});

  static const Color primary = Color(0xFFFF5C33);

  @override
  Widget build(BuildContext context) {
    final bool isHot = item['badge'] == '热播';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0.0, 2.0),
            blurRadius: 4.0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // 封面图
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: AspectRatio(
            aspectRatio: 16 / 10.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: '${item['image']}',
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  // 加载/解码失败(如 web 端跨域 CORS 拦截)时显示占位, 不再抛出 "source image cannot be decoded"
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFF0F0F0),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28.0),
                    ),
                  ),
                  fit: BoxFit.cover,
                ),
                // 左上角标签
                Positioned(
                  top: 6.0,
                  left: 6.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: isHot ? primary : const Color(0xFF3B9DFF),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isHot)
                          const Icon(Icons.local_fire_department, color: Colors.white, size: 10.0),
                        if (isHot) const SizedBox(width: 2.0),
                        Text(
                          '${item['badge']}',
                          style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                // 右下角时长
                Positioned(
                  right: 6.0,
                  bottom: 6.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 10.0),
                        const SizedBox(width: 1.0),
                        Text(
                          '${item['duration']}',
                          style: const TextStyle(color: Colors.white, fontSize: 10.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        // 标题
        Text(
          '${item['title']}',
          style: const TextStyle(color: Color(0xFF3A2E2B), fontSize: 14.0, fontWeight: FontWeight.w700, height: 1.3),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6.0),
        // 分类标签
        Text(
          '${item['tags']}',
          style: const TextStyle(color: primary, fontSize: 11.0, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6.0),
        // 观看 / 点赞
        Row(
          children: [
            const Icon(Icons.remove_red_eye, color: Colors.black38, size: 12.0),
            const SizedBox(width: 3.0),
            Text(
              '${item['view']}',
              style: const TextStyle(color: Colors.black45, fontSize: 11.0),
            ),
            const SizedBox(width: 10.0),
            const Icon(Icons.favorite, color: Color(0xFFFF4D5F), size: 12.0),
            const SizedBox(width: 3.0),
            Text(
              '${item['like']}',
              style: const TextStyle(color: Colors.black45, fontSize: 11.0),
            ),
          ],
        ),
      ],
      ),
    );
  }
}
