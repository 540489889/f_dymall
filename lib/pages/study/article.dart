/// 图文详情页(对应参考 trainingVideo/article.vue)
library;

import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import '../../api/materials.dart';

class StudyArticlePage extends StatefulWidget {
  const StudyArticlePage({super.key});
  @override
  State<StudyArticlePage> createState() => _StudyArticlePageState();
}

class _StudyArticlePageState extends State<StudyArticlePage> {
  int articleId = 0;
  String title = '';
  Map<String, dynamic> detail = <String, dynamic>{};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final Map? args = Get.arguments as Map?;
    articleId = int.tryParse('${args?['id'] ?? 0}') ?? 0;
    title = '${args?['title'] ?? ''}';
    _load();
  }

  Future<void> _load() async {
    if (articleId == 0) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final Map<String, dynamic> d = await MaterialsApi.materialDetail(articleId);
    if (!mounted) return;
    setState(() {
      detail = d;
      if ('${d['title']}'.isNotEmpty) title = '${d['title']}';
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? '文章详情' : title,
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : detail.isEmpty
              ? const Center(
                  child: const CommonEmpty(text: '暂无内容'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Text(detail['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.4)),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        if ('${detail['author'] ?? ''}'.isNotEmpty)
                          Expanded(
                              child: Text('${detail['author']}',
                                  style: const TextStyle(
                                      color: Color(0xFFFF2C55), fontSize: 12))),
                        if ('${detail['create_time'] ?? ''}'.isNotEmpty)
                          Text('${detail['create_time']}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        const Spacer(),
                        Text('${detail['watch_num'] ?? 0}人阅读',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 20),
                    Html(
                      data: '${detail['content'] ?? ''}',
                      style: <String, Style>{
                        'body': Style(
                          fontSize: FontSize(14),
                          color: Colors.black87,
                          lineHeight: LineHeight(1.6),
                        ),
                      },
                    ),
                  ],
                ),
    );
  }
}
