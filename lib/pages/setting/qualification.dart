/// 平台资质
/// * 数据来自 /api/config/qualification
/// * 返回形态: data = { title, content(HTML, 内含 <img> 图片), ... }
///   -> 解析 content 中的 <img> 逐张展示, 点击可全屏预览
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/config.dart';

class QualificationPage extends StatefulWidget {
  const QualificationPage({super.key});

  @override
  State<QualificationPage> createState() => _QualificationPageState();
}

class _QualificationPageState extends State<QualificationPage> {
  bool _loading = true;
  String? _error;
  dynamic _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dynamic res = await ConfigApi.qualification();
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _loading = false;
        _error = '加载失败，请稍后重试';
      });
      return;
    }
    setState(() {
      _data = res;
      _loading = false;
    });
  }

  /// 标题: 优先用接口返回的 title
  String get _title {
    if (_data is Map && _data['title'] != null) {
      final String t = '${_data['title']}'.trim();
      if (t.isNotEmpty) return t;
    }
    return '平台资质';
  }

  /// 内容 HTML
  String get _content {
    if (_data is Map && _data['content'] is String) return _data['content'] as String;
    return '';
  }

  /// 从 content 中提取所有 <img src="..."> 的图片地址
  List<String> get _images {
    final String html = _content;
    if (html.isEmpty) return <String>[];
    final RegExp reg = RegExp(r'''<img[^>]*src=["']([^"']+)["']''', caseSensitive: false);
    return reg
        .allMatches(html)
        .map((RegExpMatch m) => m.group(1) ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  /// 去标签后的纯文本(无图片时降级展示)
  String get _plainText {
    final String html = _content;
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
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
        title: Text(
          _title,
          style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
            const SizedBox(height: 12.0),
            TextButton(onPressed: _load, child: const Text('重新加载')),
          ],
        ),
      );
    }

    final List<String> imgs = _images;
    if (imgs.isNotEmpty) return _buildImages(imgs);

    final String text = _plainText;
    if (text.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(text, style: const TextStyle(fontSize: 14.0, color: Color(0xFF333333), height: 1.6)),
        ),
      );
    }

    return const Center(
      child: Text('暂无平台资质信息', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
    );
  }

  /// 图片逐张卡片展示, 点击全屏预览
  Widget _buildImages(List<String> imgs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: imgs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16.0),
      itemBuilder: (BuildContext context, int index) {
        final String url = imgs[index];
        return GestureDetector(
          onTap: () => _previewImage(url),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12.0, offset: const Offset(0.0, 3.0)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200.0,
                  color: const Color(0xFFF2F2F2),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200.0,
                  color: const Color(0xFFF2F2F2),
                  child: const Icon(Icons.broken_image_outlined, size: 40.0, color: Color(0xFFCCCCCC)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 图片点击: 全屏预览
  void _previewImage(String url) {
    Get.dialog(
      GestureDetector(
        onTap: () => Get.back(),
        child: Scaffold(
          backgroundColor: Colors.black87,
          body: SafeArea(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48.0, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
