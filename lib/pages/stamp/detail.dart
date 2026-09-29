/// 看播集章 - 集章详情(日志列表,对应参考 stamp/detail.vue)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/stamp.dart';

class StampDetailPage extends StatefulWidget {
  const StampDetailPage({super.key});
  @override
  State<StampDetailPage> createState() => _StampDetailPageState();
}

class _StampDetailPageState extends State<StampDetailPage> {
  int stampId = 0;
  String stampTitle = '';
  String roomName = '';
  String anchorName = '';
  bool hasAward = false;
  int awardCount = 0;
  int totalLogCount = 0;
  final List<Map<String, dynamic>> logList = <Map<String, dynamic>>[];
  int page = 1;
  final int pageSize = 10;
  bool noMore = false;
  bool loading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final dynamic arg = Get.arguments;
    if (arg is Map && arg['stamp_id'] != null) {
      stampId = int.tryParse('${arg['stamp_id']}') ?? 0;
    }
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
    if (loading || noMore || stampId == 0) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> res = await StampApi.stampLogDetail(
          stampId: stampId, page: page, pageSize: pageSize);
      final List list = res['list'] is List ? res['list'] as List : const [];
      if (page == 1) {
        logList.clear();
        stampTitle = '';
        roomName = '';
        anchorName = '';
        awardCount = 0;
        totalLogCount = 0;
        hasAward = false;
        if (list.isNotEmpty) {
          final Map<String, dynamic> first =
              list[0] as Map<String, dynamic>;
          stampTitle = '${first['title'] ?? ''}';
          roomName = '${first['room_name'] ?? ''}';
          anchorName = '${first['anchor_name'] ?? ''}';
        }
      }
      logList.addAll(list.cast<Map<String, dynamic>>());
      totalLogCount += list.length;
      final int got = list.where((dynamic e) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        return (int.tryParse('${m['award_num'] ?? 0}') ?? 0) > 0;
      }).length;
      if (got > 0) {
        hasAward = true;
        awardCount += got;
      }
      if (list.length < pageSize) noMore = true;
      if (list.isNotEmpty) page++;
    } catch (_) {
      noMore = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: Column(
        children: <Widget>[
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
                    child: const Text('集章详情',
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
            child: logList.isEmpty && !loading
                ? _empty()
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      if (stampTitle.isNotEmpty) _summary(),
                      for (final Map<String, dynamic> item in logList)
                        _logCard(item),
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

  Widget _summary() {
    return Container(
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
                child: Text(stampTitle,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasAward
                      ? const Color(0x1A07C160)
                      : const Color(0x1AFF2C55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(hasAward ? '已领奖' : '进行中',
                    style: TextStyle(
                        fontSize: 11,
                        color: hasAward
                            ? const Color(0xFF07C160)
                            : const Color(0xFFFF2C55))),
              ),
            ],
          ),
          if (roomName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('直播间：$roomName',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
          if (anchorName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('主播：$anchorName',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _stat('$totalLogCount', '集章次数'),
              Container(width: 1, height: 28, color: const Color(0xFFEEEEEE)),
              _stat('$awardCount', '已领奖励'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF2C55))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> item) {
    final int times =
        int.tryParse('${item['num'] ?? item['award_num'] ?? 1}') ?? 1;
    final int awardNum = int.tryParse('${item['award_num'] ?? 0}') ?? 0;
    final String awardName = item['award_data'] is Map
        ? '${item['award_data']['name'] ?? ''}'
        : '';
    final String cover = StampApi.fixUrl(item['feeds_img']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: cover.isEmpty
                ? Container(
                    width: 90,
                    height: 90,
                    color: const Color(0xFFF5F5F5),
                    child: const Icon(Icons.image, color: Colors.grey),
                  )
                : CachedNetworkImage(
                    imageUrl: cover,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                    Text('集章 $times 次',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF2C55))),
                  ],
                ),
                if ('${item['anchor_name'] ?? ''}'.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('主播：${item['anchor_name']}',
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ],
                if ('${item['room_name'] ?? ''}'.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text('直播间：${item['room_name']}',
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ],
                if (awardNum > 0) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Color(0xFF07C160), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('获得 $awardNum$awardName',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF07C160))),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text('集章时间：${item['create_time'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
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
          Text('暂无详情', style: TextStyle(fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
