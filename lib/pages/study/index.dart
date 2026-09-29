/// 学习课程 / 素材库 列表页(对应参考 trainingVideo/list.vue)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:get/get.dart';
import '../../api/materials.dart';

class StudyIndexPage extends StatefulWidget {
  const StudyIndexPage({super.key});
  @override
  State<StudyIndexPage> createState() => _StudyIndexPageState();
}

class _StudyIndexPageState extends State<StudyIndexPage> {
  static const Color primary = Color(0xFFFF2C55);

  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> categoryList = <Map<String, dynamic>>[];
  int currentCategoryId = 0;
  bool loading = true;

  List<Map<String, dynamic>> videoList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> articleList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> currentList = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadType();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadType() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> list = await MaterialsApi.typeList();
    setState(() {
      categoryList = list;
      // 默认选中全部(id=0); 若列表无 0 则取第一个
      final List<Map<String, dynamic>> all =
          list.where((Map<String, dynamic> e) => '${e['id']}' == '0').toList();
      currentCategoryId = all.isNotEmpty
          ? 0
          : (list.isNotEmpty ? (list[0]['id'] as int? ?? 0) : 0);
    });
    await _loadList();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadList() async {
    final bool isTop = currentCategoryId == 0;
    if (isTop) {
      List videos = <dynamic>[];
      List articles = <dynamic>[];
      // 优先 materialTop(首页精选); 若后端未返回数据, 退回 materialList 与「查看全部」同源
      final Map<String, dynamic> top = await MaterialsApi.materialTop();
      videos = top['videos'] as List? ?? <dynamic>[];
      articles = top['article'] as List? ?? <dynamic>[];
      if (videos.isEmpty && articles.isEmpty) {
        final Map<String, dynamic> vData =
            await MaterialsApi.materialList(type: 'video');
        final Map<String, dynamic> aData =
            await MaterialsApi.materialList(type: 'text');
        videos = vData['list'] as List? ?? <dynamic>[];
        articles = aData['list'] as List? ?? <dynamic>[];
      }
      setState(() {
        videoList = videos.map((dynamic e) => _mapVideo(e)).toList();
        articleList = articles.map((dynamic e) => _mapArticle(e)).toList();
        currentList = <Map<String, dynamic>>[];
      });
    } else {
      final Map<String, dynamic> data =
          await MaterialsApi.materialList(typeId: currentCategoryId);
      final List list = data['list'] as List? ?? <dynamic>[];
      setState(() {
        currentList = list.map((dynamic e) => _mapCategory(e)).toList();
        videoList = <Map<String, dynamic>>[];
        articleList = <Map<String, dynamic>>[];
      });
    }
  }

  Map<String, dynamic> _mapVideo(dynamic item) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    return <String, dynamic>{
      'id': m['id'] ?? 0,
      'cover': MaterialsApi.fixUrl(m['thumb'] ?? m['cover'] ?? m['image'] ?? m['pic']),
      'title': '${m['title'] ?? ''}',
      'learnCount': m['watch_num'] ?? m['learn_count'] ?? m['view_count'] ?? 0,
      'videoUrl': '${m['video_url'] ?? ''}',
      'time': _formatTime(m['create_time']),
    };
  }

  Map<String, dynamic> _mapArticle(dynamic item) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    return <String, dynamic>{
      'id': m['id'] ?? 0,
      'cover': MaterialsApi.fixUrl(m['thumb'] ?? m['cover'] ?? m['image'] ?? m['pic']),
      'title': '${m['title'] ?? ''}',
      'readCount': m['watch_num'] ?? m['read_count'] ?? m['view_count'] ?? 0,
      'time': _formatTime(m['create_time']),
    };
  }

  Map<String, dynamic> _mapCategory(dynamic item) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    final String t = '${m['type'] ?? ''}';
    return <String, dynamic>{
      'id': m['id'] ?? 0,
      'cover': MaterialsApi.fixUrl(m['thumb'] ?? m['cover'] ?? m['image'] ?? m['pic']),
      'title': '${m['title'] ?? ''}',
      'type': (t == 'video') ? '视频' : '图文',
      'watchCount': m['watch_num'] ?? 0,
      'videoUrl': '${m['video_url'] ?? ''}',
      'time': '${m['create_time'] ?? ''}',
    };
  }

  static String _formatTime(dynamic ts) {
    if (ts == null || '$ts'.isEmpty) return '';
    int? n = int.tryParse('$ts');
    if (n == null) return '$ts';
    if (n >= 1000000000000) {
      n = n ~/ 1000; // 毫秒
    } else if (n < 10000000000) {
      n = n * 1000; // 秒
    }
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(n);
    String pad(int v) => v < 10 ? '0$v' : '$v';
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }

  void _selectCategory(Map<String, dynamic> item) {
    final int id = item['id'] as int? ?? 0;
    if (id == currentCategoryId) return;
    setState(() => currentCategoryId = id);
    _loadList();
  }

  String _currentCategoryTitle() {
    for (final Map<String, dynamic> e in categoryList) {
      if ('${e['id']}' == '$currentCategoryId') return '${e['title'] ?? ''}';
    }
    return '全部内容';
  }

  void _handleSearch() {
    final String kw = _keywordController.text.trim();
    Get.toNamed('/study/more', arguments: <String, dynamic>{
      'keyword': kw,
      'title': '搜索课程、文章',
    });
  }

  void _viewMore(String type, String title) {
    Get.toNamed('/study/more', arguments: <String, dynamic>{
      'type': type,
      'title': title,
    });
  }

  void _goVideo(Map<String, dynamic> item) {
    Get.toNamed('/study/detail', arguments: <String, dynamic>{
      'id': item['id'],
      'title': item['title'],
      'videoUrl': item['videoUrl'],
    });
  }

  void _goArticle(Map<String, dynamic> item) {
    Get.toNamed('/study/article', arguments: <String, dynamic>{
      'id': item['id'],
      'title': item['title'],
    });
  }

  void _goCategoryItem(Map<String, dynamic> item) {
    if (item['type'] == '视频') {
      _goVideo(item);
    } else {
      _goArticle(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Column(
        children: <Widget>[
          // 顶部渐变 Hero
          Container(
            padding: EdgeInsets.only(
                top: statusTop + 12, bottom: 20, left: 14, right: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[primary, Color(0xFFFF5C7A)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Get.back(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    const Text('学习中心',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('海量课程 · 边学边赚',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                _searchBox(),
                const SizedBox(height: 14),
                _categoryBar(),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    children: <Widget>[
                      if (currentCategoryId == 0) ...<Widget>[
                        if (videoList.isNotEmpty) ...<Widget>[
                          _sectionCard(
                              _sectionHeader('视频课程',
                                  () => _viewMore('video', '视频课程')),
                              _videoGrid()),
                          const SizedBox(height: 14),
                        ],
                        if (articleList.isNotEmpty) ...<Widget>[
                          _sectionCard(
                              _sectionHeader('精选文章',
                                  () => _viewMore('text', '精选文章')),
                              _articleList()),
                          const SizedBox(height: 14),
                        ],
                        if (videoList.isEmpty && articleList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                                child: const CommonEmpty(text: '暂无内容')),
                          ),
                      ] else ...<Widget>[
                        _sectionCard(
                            Text(_currentCategoryTitle(),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            _categoryList()),
                      ],
                      const SizedBox(height: 20),
                      const Center(
                          child: Text('我也是有底线的哦~',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, color: primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _keywordController,
              onSubmitted: (_) => _handleSearch(),
              decoration: const InputDecoration.collapsed(
                  hintText: '搜索课程、文章',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          ),
          GestureDetector(
            onTap: _handleSearch,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[primary, Color(0xFFFF5C7A)],
                  ),
                  borderRadius: BorderRadius.circular(18)),
              child: const Center(
                  child: Text('搜索',
                      style: TextStyle(color: Colors.white, fontSize: 13))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    // 融合进顶部渐变区: 选中=实心白底+主题色字, 未选=半透明白底+白字
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categoryList.map((Map<String, dynamic> item) {
          final bool active = (item['id'] as int? ?? 0) == currentCategoryId;
          return GestureDetector(
            onTap: () => _selectCategory(item),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${item['title'] ?? ''}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? primary : Colors.white)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        GestureDetector(
          onTap: onMore,
          child: Row(
            children: const <Widget>[
              Text('查看全部',
                  style: TextStyle(fontSize: 13, color: primary)),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios, size: 12, color: primary),
            ],
          ),
        ),
      ],
    );
  }

  /// 白色圆角卡片容器(分组区块)
  Widget _sectionCard(Widget header, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _coverImg(String url) {
    if (url.isEmpty) return Container(color: const Color(0xFFF0F0F0));
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFFF0F0F0)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFFF0F0F0)),
    );
  }

  Widget _videoGrid() {
    if (videoList.isEmpty) {
      return const SizedBox(
          height: 40,
          child: Center(
              child: const CommonEmpty(text: '暂无视频')));
    }
    final double screenW = MediaQuery.of(context).size.width;
    final double cardW = (screenW - 68) / 2; // ListView(14*2)+sectionCard(14*2)+列间距12
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: videoList.map((Map<String, dynamic> item) {
        return GestureDetector(
          onTap: () => _goVideo(item),
          child: SizedBox(
            width: cardW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 横向 16:10 封面 + 居中播放键 + 阴影
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1.6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _coverImg(item['cover'] as String),
                          Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                shape: BoxShape.circle,
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1)),
                                ],
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: primary, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35)),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    const Icon(Icons.visibility, size: 13, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${item['learnCount']}人观看',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _articleList() {
    if (articleList.isEmpty) {
      return const SizedBox(
          height: 40,
          child: Center(
              child: const CommonEmpty(text: '暂无文章')));
    }
    return Column(
      children: List<Widget>.generate(articleList.length, (int i) {
        final Map<String, dynamic> item = articleList[i];
        final bool last = i == articleList.length - 1;
        return GestureDetector(
          onTap: () => _goArticle(item),
          child: Container(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 12),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                        width: 120,
                        height: 80,
                        child: _coverImg(item['cover'] as String))),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(item['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3)),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.article_outlined,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 3),
                            Text('${item['readCount']}人阅读',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
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
      }),
    );
  }

  Widget _categoryList() {
    if (currentList.isEmpty) {
      return const SizedBox(
          height: 60,
          child: Center(
              child: const CommonEmpty(text: '暂无内容')));
    }
    final double screenW = MediaQuery.of(context).size.width;
    final double cardW = (screenW - 68) / 2; // ListView(14*2)+sectionCard(14*2)+列间距12
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: currentList.map((Map<String, dynamic> item) {
        final bool isVideo = item['type'] == '视频';
        return GestureDetector(
          onTap: () => _goCategoryItem(item),
          child: SizedBox(
            width: cardW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 封面 + 阴影 + 类型标签
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1.3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _coverImg(item['cover'] as String),
                          // 左下角类型标签(视频橙/图文绿, 半透明)
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isVideo
                                        ? Colors.orange
                                        : Colors.green)
                                    .withOpacity(0.9),
                                borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(8)),
                              ),
                              child: Text(item['type'] as String,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35)),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Icon(
                        isVideo
                            ? Icons.play_circle_outline
                            : Icons.article_outlined,
                        size: 13,
                        color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                        '${item['watchCount']}${isVideo ? '人观看' : '人阅读'}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
