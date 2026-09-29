/// 协议详情(隐私协议 / 用户协议)
/// 对齐 H5: pages_tool/login/aggrement.vue
/// * 数据 /api/register/aggrement,type: PRIVACY 隐私协议 / SERVICE 用户协议
/// * content 为富文本 HTML, 用 flutter_html 渲染(与 H5 ns-mp-html 等价)
library;

import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import '../../api/member.dart';

class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key, this.type = 'SERVICE'});

  /// 默认协议类型(命名路由进入时以 arguments 为准)
  final String type;

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  String title = '';
  String content = '';
  bool loading = true;
  String errorMsg = '';

  /// 协议类型: 路由 arguments 为 Map({type:...}) 或字符串时优先
  String get type {
    final dynamic args = Get.arguments;
    if (args is Map) return '${args['type'] ?? widget.type}';
    if (args is String && args.isNotEmpty) return args;
    return widget.type;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 加载协议内容
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> res = await MemberApi.aggrement(type);
      if (!mounted) return;
      setState(() {
        title = '${res['title'] ?? ''}';
        content = '${res['content'] ?? ''}';
        loading = false;
        errorMsg = content.isEmpty ? '暂无协议内容' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = MemberApi.errorMsg(e, '协议加载失败');
      });
    }
  }

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
        title: Text(
          title.isNotEmpty ? title : (type == 'PRIVACY' ? '隐私协议' : '用户协议'),
          style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CommonEmpty(text: errorMsg.isEmpty ? '暂无协议内容' : errorMsg),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
      child: Html(data: content),
    );
  }
}
