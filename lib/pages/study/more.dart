/// 查看全部 / 搜索页(对应参考 trainingVideo/more.vue)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/materials.dart';

class StudyMorePage extends StatefulWidget {
  const StudyMorePage({super.key});
  @override
  State<StudyMorePage> createState() => _StudyMorePageState();
}

class _StudyMorePageState extends State<StudyMorePage> {
  String listType = '';
  String keyword = '';
  String title = '';
  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  int page = 1;
  int pageCount = 1;
  bool loading = false;
  bool noMore = false;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _kw = TextEditingController();

  @override
  void initState() {
    super.initState();
    final Map? args = Get.arguments as Map?;
    listType = '${args?['type'] ?? ''}';
    keyword = '${args?['keyword'] ?? ''}';
    title =
        '${args?['title'] ?? (keyword.isNotEmpty ? '搜索课程、文章' : '全部')}';
    _kw.text = keyword;
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 50 &&
          !loading &&
          !noMore) {
        _loadMore();
      }
    });
    _getList(true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _kw.dispose();
    super.dispose();
  }

  Future<void> _getList(bool reset) async {
    if (listType.isEmpty && keyword.isEmpty) return;
    if (reset) {
      page = 1;
      noMore = false;
      list = <Map<String, dynamic>>[];
    }
    setState(() => loading = true);
    final Map<String, dynamic> data = await MaterialsApi.materialList(
      type: listType,
      search: keyword,
      page: page,
      pageSize: 10,
    );
    if (!mounted) return;
    final List raw = data['list'] as List? ?? <dynamic>[];
    final List<Map<String, dynamic>> mapped =
        raw.map((dynamic e) => _mapItem(e)).toList();
    setState(() {
      list = reset ? mapped : <Map<String, dynamic>>[...list, ...mapped];
      pageCount = data['page_count'] as int? ?? 1;
      if (page >= pageCount || mapped.length < 10) noMore = true;
      loading = false;
      page++;
    });
  }

  Future<void> _loadMore() => _getList(false);

  void _handleSearch() {
    keyword = _kw.text.trim();
    _getList(true);
  }

  Map<String, dynamic> _mapItem(dynamic item) {
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

  void _goDetail(Map<String, dynamic> item) {
    if (item['type'] == '视频') {
      Get.toNamed('/study/detail', arguments: <String, dynamic>{
        'id': item['id'],
        'title': item['title'],
        'videoUrl': item['videoUrl'],
      });
    } else {
      Get.toNamed('/study/article', arguments: <String, dynamic>{
        'id': item['id'],
        'title': item['title'],
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? '全部' : title,
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          // 搜索框
          Container(
            margin: const EdgeInsets.all(14),
            height: 40,
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFF2C55), width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search, color: Color(0xFFFF2C55), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _kw,
                    onSubmitted: (_) => _handleSearch(),
                    decoration: const InputDecoration.collapsed(
                        hintText: '搜索课程、文章',
                        hintStyle:
                            TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                ),
                GestureDetector(
                  onTap: _handleSearch,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF2C55),
                        borderRadius: BorderRadius.circular(18)),
                    child: const Center(
                        child: Text('搜索',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13))),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty && !loading
                ? const Center(
                    child: Text('暂无数据', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: list.length + 1,
                    itemBuilder: (BuildContext ctx, int i) {
                      if (i == list.length) {
                        if (noMore) {
                          return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                  child: Text('我也是有底线的哦~',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12))));
                        }
                        return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)));
                      }
                      final Map<String, dynamic> item = list[i];
                      final bool isVideo = item['type'] == '视频';
                      return GestureDetector(
                        onTap: () => _goDetail(item),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: <Widget>[
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                      width: 140,
                                      height: 92,
                                      child: _coverImg(item['cover'] as String))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 92,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(item['title'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14, height: 1.3)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                              '${item['watchCount']}${isVideo ? '人观看' : '人阅读'}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: isVideo
                                                    ? Colors.orange
                                                    : Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(3)),
                                            child: Text(item['type'] as String,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10)),
                                          ),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
