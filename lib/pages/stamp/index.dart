/// 看播集章 - 集章记录列表(对应参考 stamp/index.vue)
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/stamp.dart';

class StampIndexPage extends StatefulWidget {
  const StampIndexPage({super.key});
  @override
  State<StampIndexPage> createState() => _StampIndexPageState();
}

class _StampIndexPageState extends State<StampIndexPage> {
  final List<Map<String, dynamic>> stampList = <Map<String, dynamic>>[];
  int page = 1;
  final int pageSize = 10;
  bool noMore = false;
  bool loading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 40) {
      _load();
    }
  }

  Future<void> _load() async {
    if (loading || noMore) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> res =
          await StampApi.getStampList(page: page, pageSize: pageSize);
      final List list = res['list'] is List ? res['list'] as List : const [];
      if (page == 1) stampList.clear();
      stampList.addAll(list.cast<Map<String, dynamic>>());
      if (list.length < pageSize) noMore = true;
      if (list.isNotEmpty) page++;
    } catch (_) {
      if (page == 1) stampList.clear();
      noMore = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _goDetail(Map<String, dynamic> item) {
    final int id = int.tryParse('${item['stamp_id'] ?? ''}') ?? 0;
    Get.toNamed('/stamp/detail',
        arguments: <String, dynamic>{'stamp_id': id});
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: Column(
        children: <Widget>[
          // 导航栏
          Container(
            padding: EdgeInsets.only(top: statusTop, bottom: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF7A52)],
              ),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Get.back(),
                ),
                Expanded(
                  child: Center(
                    child: const Text('集章记录',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: stampList.isEmpty && !loading
                ? _empty()
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      for (final Map<String, dynamic> item in stampList)
                        _card(item),
                      if (!noMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text('加载中...',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12))),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text('— 没有更多了 —',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12))),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final bool done = (int.tryParse('${item['award_num'] ?? 0}') ?? 0) > 0;
    final int num = int.tryParse('${item['num'] ?? 0}') ?? 0;
    final int times = int.tryParse('${item['times'] ?? 0}') ?? 0;
    final double ratio =
        times > 0 ? (num / times).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => _goDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('${item['title'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333))),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0x1A07C160)
                        : const Color(0x1AFF2C55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(done ? '已完成' : '进行中',
                      style: TextStyle(
                          fontSize: 11,
                          color: done
                              ? const Color(0xFF07C160)
                              : const Color(0xFFFF2C55))),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('集章进度',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                          text: '$num',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF2C55))),
                      TextSpan(
                          text: '/$times',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFBBBBBB))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF2C55),
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            if ('${item['send_time'] ?? ''}'.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF07C160), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('完成时间：${item['send_time']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset('assets/images/common-empty.png', width: 120.0),
          SizedBox(height: 12),
          Text('暂无集章记录', style: TextStyle(fontSize: 15, color: Colors.grey)),
          SizedBox(height: 6),
          Text('快去直播间参与活动收集印章吧～',
              style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
        ],
      ),
    );
  }
}
