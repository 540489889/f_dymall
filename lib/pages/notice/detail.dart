/// 公告详情
/// * 内容直接用列表项带过来的 content(富文本 HTML),不再单独请求详情接口
/// * 入参: Get.arguments 为公告 Map({title, content, create_time, is_top, ...})
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../components/common_empty.dart';
import '../../utils/index.dart';
import '../../widgets/html_content.dart';

class NoticeDetailPage extends StatefulWidget {
  const NoticeDetailPage({super.key});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  late final Map<String, dynamic> item;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    item = args is Map ? args.cast<String, dynamic>() : <String, dynamic>{};
  }

  String get title => '${item['title'] ?? ''}'.trim();

  String get content => '${item['content'] ?? ''}'.trim();

  String get time => Utils.timeStampTurnTime(item['create_time']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          '公告详情',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (title.isEmpty && content.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CommonEmpty(text: '公告内容不存在'),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: Color(0xFF202020), height: 1.4),
            ),
          const SizedBox(height: 10.0),
          if (time.isNotEmpty)
            Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          const SizedBox(height: 16.0),
          const Divider(height: 1.0, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14.0),
          if (content.isNotEmpty)
            HtmlContent(content)
          else
            const Center(child: CommonEmpty(text: '暂无内容')),
        ],
      ),
    );
  }
}
