/// 看播记录(我的 -> 我的服务)
/// * 接口: /live/api/shop/getLiveLog(page / page_size / keyword), 与 H5 pages_tool/watching_record 同一接口
/// * 顶部: 搜索框(按直播标题搜索) + 清除 + 搜索按钮
/// * 列表: 封面(左上角完播/未完播标签) + 标题 + 主播头像昵称 + 起止时间,点击进直播间
/// * 状态: 首次加载 Loading / 无数据空态 / 滚到底部自动加载下一页
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/live.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/common_empty.dart';
import '../../components/loading.dart';

class WatchingRecordPage extends StatefulWidget {
  const WatchingRecordPage({super.key});

  @override
  State<WatchingRecordPage> createState() => _WatchingRecordPageState();
}

class _WatchingRecordPageState extends State<WatchingRecordPage> {
  /// 每页条数
  static const int pageSize = 10;

  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  /// 搜索关键词(直播标题)
  String keyword = '';
  List<Map<String, dynamic>> recordList = <Map<String, dynamic>>[];
  int page = 1;
  bool loading = false;
  /// 首次加载(用于 Loading 占位,避免先闪空态)
  bool firstLoad = true;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    // 输入变化只刷新搜索栏(用于显示/隐藏清除按钮),不触发列表重建
    inputController.addListener(() {
      if (mounted) setState(() {});
    });
    loadList(refresh: true);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    inputController.dispose();
    super.dispose();
  }

  /// 拉取记录(refresh: 换了搜索词后重新查;否则加载下一页)
  Future<void> loadList({bool refresh = false}) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final Map<String, dynamic> res = await LiveApi.liveLog(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
      );
      if (!mounted) return;
      final List<dynamic> rawList = (res['list'] ?? const <dynamic>[]) as List<dynamic>;
      final List<Map<String, dynamic>> list = rawList
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
          .toList();
      setState(() {
        hasMore = (res['hasMore'] ?? false) as bool;
        if (refresh) {
          recordList = list;
        } else {
          recordList.addAll(list);
        }
        page += 1;
        firstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => firstLoad = false);
        MyDialog.toast('记录加载失败,请重试');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 滚到底部加载更多
  void _onScroll() {
    if (loading || !hasMore) return;
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      loadList();
    }
  }

  /// 搜索(关键词为空时等同于恢复全部记录)
  void onSearch() {
    final String text = inputController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      keyword = text;
      recordList = <Map<String, dynamic>>[];
      page = 1;
      hasMore = true;
      firstLoad = true;
    });
    loadList(refresh: true);
  }

  /// 清空搜索词并恢复列表
  void onClear() {
    inputController.clear();
    onSearch();
  }

  /// 进看播详情: 整条记录带过去(与 H5 detail.vue 从列表带入的字段一致)
  void openDetail(Map<String, dynamic> item) {
    final String roomId = '${item['room_id'] ?? ''}'.trim();
    if (roomId.isEmpty) {
      MyDialog.toast('直播间信息缺失');
      return;
    }
    Get.toNamed('/my/watching_record/detail', arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Color(0xFF222222)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '看播记录',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
        ),
      ),
      body: Column(
        children: <Widget>[
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  /// 搜索栏: 圆角输入框(搜索图标 / 清除) + 右侧搜索按钮
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 10.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 36.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, size: 18.0, color: Color(0xFF999999)),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: TextField(
                      controller: inputController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (String _) => onSearch(),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '搜索直播标题',
                        hintStyle: TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
                    ),
                  ),
                  if (inputController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: const Icon(Icons.cancel, size: 16.0, color: Color(0xFFCCCCCC)),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearch,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Text(
                '搜索',
                style: TextStyle(fontSize: 14.0, color: Color(0xFFFF2C55), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 列表主体: 首屏 Loading / 空态 / 卡片列表 + 底部加载中
  Widget _buildList() {
    if (firstLoad) return const Center(child: Loading(title: '加载中...'));
    if (recordList.isEmpty) {
      return Center(
        child: CommonEmpty(
          text: keyword.isEmpty ? '暂无看播记录' : '未找到相关看播记录',
          imageWidth: 100.0,
        ),
      );
    }
    // 滚动条关掉(与项目其它列表一致,拖动时不会浮出一条灰色滚动条)
    return ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      // 满一页时才挂尾部提示: 还有下一页显示加载中,没有则显示"已经到底了"
      itemCount: recordList.length + (recordList.length >= pageSize ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= recordList.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Center(
              child: hasMore
                  ? const Loading(title: '加载中...')
                  : const Text(
                      '已经到底了',
                      style: TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB)),
                    ),
            ),
          );
        }
        return _buildCard(recordList[index]);
      },
      ),
    );
  }

  /// 单条记录卡片
  Widget _buildCard(Map<String, dynamic> item) {
    final bool finished = item['finished'] == true;
    final String cover = '${item['feeds_img'] ?? ''}';
    final String name = '${item['name'] ?? ''}'.trim();
    final String anchorName = '${item['anchor_name'] ?? ''}'.trim();
    final String anchorImg = '${item['anchor_img'] ?? ''}';
    final String timeText = LiveApi.recordTimeText(item);
    final String awardName = '${item['award_name'] ?? ''}'.trim();
    final String awardNum = '${item['award_num'] ?? ''}'.trim();
    // 完播奖励: 后台下发了才展示(与详情页头部同一份字段)
    String awardText = '';
    if (finished) {
      if (awardName.isNotEmpty && awardNum.isNotEmpty) {
        awardText = '奖励 $awardName$awardNum';
      } else if (awardName.isNotEmpty) {
        awardText = '奖励 $awardName';
      } else if (awardNum.isNotEmpty) {
        awardText = '奖励 $awardNum';
      }
    }
    return GestureDetector(
      onTap: () => openDetail(item),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10.0, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 封面: 满宽 16:9(横向小卡时信息被挤成一条,改成整幅封面更干净)
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                  child: AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: cover.isEmpty
                        ? Container(
                            color: const Color(0xFFF0F0F0),
                            alignment: Alignment.center,
                            child: const Icon(Icons.live_tv, size: 32.0, color: Color(0xFFDDDDDD)),
                          )
                        : CachedNetworkImage(
                            imageUrl: cover,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (BuildContext c, String u) => Container(color: const Color(0xFFF0F0F0)),
                            errorWidget: (BuildContext c, String u, Object e) => Container(
                              color: const Color(0xFFF0F0F0),
                              alignment: Alignment.center,
                              child: const Icon(Icons.live_tv, size: 32.0, color: Color(0xFFDDDDDD)),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  left: 8.0,
                  top: 8.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: finished ? const Color(0xFF07C160) : const Color(0x73000000),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      finished ? '完播' : '未完播',
                      style: const TextStyle(fontSize: 10.0, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // 信息区: 标题 / 主播 / 时间 / 完播奖励
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name.isEmpty ? '直播间' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                  ),
                  if (anchorName.isNotEmpty || anchorImg.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8.0),
                    Row(
                      children: <Widget>[
                        ClipOval(
                          child: anchorImg.isEmpty
                              ? Container(
                                  width: 20.0,
                                  height: 20.0,
                                  color: const Color(0xFFF0F0F0),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.person, size: 12.0, color: Color(0xFFCCCCCC)),
                                )
                              : CachedNetworkImage(
                                  imageUrl: anchorImg,
                                  width: 20.0,
                                  height: 20.0,
                                  fit: BoxFit.cover,
                                  errorWidget: (BuildContext c, String u, Object e) => Container(
                                    width: 20.0,
                                    height: 20.0,
                                    color: const Color(0xFFF0F0F0),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.person, size: 12.0, color: Color(0xFFCCCCCC)),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            anchorName.isEmpty ? '主播' : anchorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF666666)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (timeText.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 1.0),
                          child: Icon(Icons.access_time, size: 12.0, color: Color(0xFF999999)),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            timeText,
                            // 起止时间较长(10-10 10:00 ~ 10-10 12:00),宽度够,最多两行显示完整
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // 完播奖励: 单独做成小标签,不和时间抢一行
                  if (awardText.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        awardText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.0, color: Color(0xFFE6A23C), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
