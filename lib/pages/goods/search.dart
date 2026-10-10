/// 商品搜索
/// * 入口: 首页顶部搜索框 -> Get.toNamed('/search')
/// * 对齐 H5 pages_tool/goods/search.vue: 历史搜索 + 热门搜索,搜索后跳商品列表页 /goods/list
/// * 历史搜索存本地(GetStorage,最多 10 条,新搜的排最前)
/// * 热门搜索 /api/goods/hotSearchWords,默认搜索词 /api/goods/defaultSearchWords(作 placeholder)
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/goods.dart';
import '../../components/common_empty.dart';
import '../../utils/storage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  /// 历史搜索缓存key
  static const String historyKey = 'search_history';
  /// 历史搜索最多保留条数
  static const int historyMax = 10;

  final TextEditingController inputController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  /// 历史搜索(新搜的排最前)
  List<String> history = <String>[];
  /// 热门搜索
  List<String> hotList = <String>[];
  /// 默认搜索词(placeholder)
  String defaultWord = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    final dynamic args = Get.arguments;
    if (args is Map) {
      final String word = '${args['keyword'] ?? ''}';
      if (word.isNotEmpty) inputController.text = word;
    }
    _loadHotWords();
    // 进页面即可输入
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
  }

  @override
  void dispose() {
    focusNode.dispose();
    inputController.dispose();
    super.dispose();
  }

  /// 本地历史搜索
  void _loadHistory() {
    final dynamic raw = Storage.read(historyKey);
    if (raw is List) {
      history = raw.map((dynamic e) => '$e').where((String e) => e.trim().isNotEmpty).toList();
    }
  }

  /// 记一条历史搜索(去重 + 置顶 + 截断)
  void _saveHistory(String word) {
    history.remove(word);
    history.insert(0, word);
    if (history.length > historyMax) history = history.sublist(0, historyMax);
    Storage.write(historyKey, history);
  }

  void _clearHistory() {
    setState(() => history = <String>[]);
    Storage.write(historyKey, history);
  }

  /// 热门搜索 + 默认搜索词
  Future<void> _loadHotWords() async {
    final String word = await GoodsApi.defaultSearchWords();
    final List<String> hot = await GoodsApi.hotSearchWords();
    if (!mounted) return;
    setState(() {
      defaultWord = word;
      hotList = hot;
    });
  }

  /// 搜索(回车 / 点搜索按钮 / 点历史词或热词)
  void search(String word) {
    String text = word.trim();
    if (text.isEmpty) {
      // 没输入就搜索时,用默认搜索词(与 H5 一致)
      if (defaultWord.isEmpty) {
        MyDialog.toast('请输入搜索关键词');
        return;
      }
      text = defaultWord;
    }
    focusNode.unfocus();
    _saveHistory(text);
    Get.toNamed('/goods/list', arguments: <String, String>{'keyword': text});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Get.back(),
        ),
        title: _buildInput(),
        actions: <Widget>[
          TextButton(
            onPressed: () => search(inputController.text),
            child: const Text('搜索', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 14.0)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (history.isNotEmpty) _buildSection('历史搜索', history, clearable: true),
            if (hotList.isNotEmpty) _buildSection('热门搜索', hotList),
            if (history.isEmpty && hotList.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80.0),
                child: Center(child: CommonEmpty(text: '暂无搜索记录', imageWidth: 100.0)),
              ),
          ],
        ),
      ),
    );
  }

  /// 搜索输入框
  Widget _buildInput() {
    return Container(
      height: 34.0,
      margin: const EdgeInsets.only(right: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(17.0),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, color: Color(0xFF999999), size: 18.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: TextField(
              controller: inputController,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: search,
              decoration: InputDecoration(
                isDense: true,
                // 后端配了默认搜索词就用它,否则用兜底文案
                hintText: defaultWord.isNotEmpty ? defaultWord : '请输入关键字搜索',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14.0),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14.0),
              cursorColor: const Color(0xFFFF2C55),
            ),
          ),
          // 有输入内容时才显示清除按钮
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: inputController,
            builder: (BuildContext context, TextEditingValue value, Widget? child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => inputController.clear(),
                child: const Icon(Icons.cancel, color: Color(0xFFCCCCCC), size: 16.0),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 一块搜索词区域(历史 / 热门)
  Widget _buildSection(String title, List<String> words, {bool clearable = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const Spacer(),
              if (clearable)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clearHistory,
                  child: const Icon(Icons.delete_outline, size: 18.0, color: Color(0xFF999999)),
                ),
            ],
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: words.map(_buildWordChip).toList(),
          ),
        ],
      ),
    );
  }

  /// 单个搜索词
  Widget _buildWordChip(String word) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => search(word),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Text(word, style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
      ),
    );
  }
}
