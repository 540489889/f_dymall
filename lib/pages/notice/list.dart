/// 公告列表(/api/notice/page)
/// * 置顶(is_top == 1)排在前面并显示「置顶」标签
/// * 点条目进公告详情(/notice/detail),内容直接用列表返回的 content,不额外请求
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/notice.dart';
import '../../components/common_empty.dart';
import '../../utils/index.dart';

class NoticeListPage extends StatefulWidget {
  const NoticeListPage({super.key});

  @override
  State<NoticeListPage> createState() => _NoticeListPageState();
}

class _NoticeListPageState extends State<NoticeListPage> {
  final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  final ScrollController scrollController = ScrollController();

  static const int _pageSize = 10;
  static const Color _primary = Color(0xFFFF2C55);

  bool loading = true; // 首屏加载
  bool loadingMore = false; // 加载更多
  bool hasMore = true;
  String errorMsg = '';
  int page = 1;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    load(refresh: true);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// 滚到底部自动加载下一页
  void _onScroll() {
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels < scrollController.position.maxScrollExtent - 200) return;
    load();
  }

  /// 拉取公告
  /// * [refresh] true 为下拉刷新 / 首屏,重置分页
  Future<void> load({bool refresh = false}) async {
    if (loadingMore) return;
    if (refresh) {
      page = 1;
      hasMore = true;
      errorMsg = '';
      if (mounted) setState(() => loading = true);
    } else {
      if (!hasMore || loading) return;
      if (mounted) setState(() => loadingMore = true);
    }
    try {
      final Map<String, dynamic> res = await NoticeApi.page(page: page, pageSize: _pageSize);
      if (!mounted) return;
      final List<Map<String, dynamic>> items = (res['list'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
          .toList();
      final int pageCount = (res['page_count'] as int?) ?? 1;
      if (refresh) list.clear();
      list.addAll(items);
      // 置顶优先,其次按时间倒序(先排好再 setState,避免界面上出现排序前后的跳动)
      list.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final int top = _intOf(b['is_top']).compareTo(_intOf(a['is_top']));
        if (top != 0) return top;
        return _intOf(b['create_time']).compareTo(_intOf(a['create_time']));
      });
      setState(() {
        hasMore = page < pageCount;
        if (hasMore) page++;
        loading = false;
        loadingMore = false;
        errorMsg = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingMore = false;
        errorMsg = list.isEmpty ? '公告加载失败,请稍后重试' : '';
      });
    }
  }

  int _intOf(dynamic value) => int.tryParse('$value') ?? 0;

  String _timeOf(Map<String, dynamic> item) {
    return Utils.timeStampTurnTime(item['create_time'], withSecond: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '公告',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      // 失败 / 空数据都用空态,失败时给个重试入口
      return Center(
        child: GestureDetector(
          onTap: () => load(refresh: true),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: CommonEmpty(text: errorMsg.isNotEmpty ? errorMsg : '暂无公告'),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => load(refresh: true),
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 24.0),
        itemCount: list.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10.0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= list.length) return _buildFooter();
          return _buildItem(list[index]);
        },
      ),
    );
  }

  /// 底部: 加载中 / 没有更多 / 加载失败重试
  Widget _buildFooter() {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: SizedBox(width: 20.0, height: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0))),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: GestureDetector(
            onTap: () => load(),
            child: Text(
              errorMsg.isNotEmpty ? '加载失败,点击重试' : '上拉加载更多',
              style: TextStyle(fontSize: 12.0, color: errorMsg.isNotEmpty ? _primary : const Color(0xFF999999)),
            ),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Center(child: Text('没有更多了', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999)))),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final bool top = '${item['is_top'] ?? 0}' == '1';
    final String title = '${item['title'] ?? ''}'.trim();
    final String time = _timeOf(item);
    return GestureDetector(
      onTap: () => Get.toNamed('/notice/detail', arguments: item),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 12.0, 14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (top) ...<Widget>[
                        Container(
                          margin: const EdgeInsets.only(top: 2.0, right: 6.0),
                          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                          child: const Text('置顶',
                              style: TextStyle(fontSize: 10.0, color: _primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          title.isEmpty ? '公告' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: <Widget>[
                      if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                      const Spacer(),
                      const Text('查看详情', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                      const Icon(Icons.chevron_right, size: 16.0, color: Color(0xFF999999)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
