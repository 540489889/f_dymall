/// 直播首页模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';
import '../../components/backtop.dart';
import '../../api/live.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with TickerProviderStateMixin {
  // 直播列表(接口 /live/api/shop/roomPage)
  List dataList = [];
  // 分页: 当前页码 / 是否还有下一页; 列表筛选状态(接口 roomPage 的 status): 1 直播中 / 2 直播预告
  // * 用可空字段 + getter 兜底: hot reload 会保留旧的 State 实例, 新增字段在旧实例上还是 null,
  //   直接声明成非空 int/bool 再读取会抛 "Null is not a subtype of type int"
  int? pageValue;
  bool? hasMoreValue;
  int? roomStatusValue;
  int get page => pageValue ?? 1;
  bool get hasMore => hasMoreValue ?? true;
  int get roomStatus => roomStatusValue ?? 1;
  // 是否加载中
  bool isLoading = false;
  // 搜索关键字(接口 roomPage 的 keywords: 直播间标题/主播昵称)
  // * 只记值不发请求,点"搜索"/回车才带关键字重新拉列表
  String keywords = '';
  final TextEditingController searchController = TextEditingController();

  late ScrollController scrollController = ScrollController();
  // 记录滚动位置
  final ValueNotifier<double> scrollOffset = ValueNotifier(0);

  // 加载直播列表(/live/api/shop/roomPage)
  // * [refresh] 下拉刷新: 回到第一页并清空列表; 否则按当前页码追加下一页
  Future<void> loadRoomPage({bool refresh = false}) async {
    if (isLoading) return;
    if (refresh) {
      pageValue = 1;
      hasMoreValue = true;
      setState(() {
        dataList.clear();
      });
    }
    if (!hasMore) return;
    setState(() {
      isLoading = true;
    });
    final Map<String, dynamic> res = await LiveApi.roomPage(page: page, pageSize: 10, status: roomStatus, keywords: keywords);
    if (!mounted) return;
    final List<dynamic> list = res['list'] is List ? res['list'] as List<dynamic> : <dynamic>[];
    setState(() {
      isLoading = false;
      dataList.addAll(list);
      hasMoreValue = res['hasMore'] == true;
      // 本次确实拿到数据才翻页,避免失败时空翻
      if (list.isNotEmpty) pageValue = page + 1;
    });
  }

  // 下拉刷新
  Future<void> handleRefresh() async {
    await loadRoomPage(refresh: true);
  }

  // 搜索(点"搜索"按钮 / 键盘回车): 带 keywords 重新拉第一页
  Future<void> handleSearch() async {
    keywords = searchController.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    await loadRoomPage(refresh: true);
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      scrollOffset.value = scrollController.offset;

      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        debugPrint('[live]滚动到底部');
        if (!isLoading && hasMore) {
          loadRoomPage();
        }
      }
    });
    loadRoomPage();
  }

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        toolbarHeight: 70.0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leadingWidth: 60.0,
        leading: const Center(
          child: _PlayIcon(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds);
              },
              child: const Text(
                '乐惠直播',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Row(
              children: [
                const Text('好物·邻里·一起看', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                const SizedBox(width: 3.0),
                Icon(Icons.favorite, size: 10.0, color: Colors.pink[300]),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            // 扫码图标(自定义 png)
            icon: Image.asset('assets/images/icon_sm.png', width: 22.0, height: 22.0, fit: BoxFit.contain, isAntiAlias: true),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
            child: Row(
              children: [
                _statusChip('直播中', 1),
                const SizedBox(width: 14.0),
                _statusChip('直播预约', 2),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Container(
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10.0),
                        const Icon(Icons.search, color: Color(0xFF999999), size: 18.0),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '直播间标题/主播昵称',
                              hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.0),
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 13.0),
                            cursorColor: const Color(0xFFFF2C55),
                            onSubmitted: (_) => handleSearch(),
                          ),
                        ),
                        GestureDetector(
                          onTap: handleSearch,
                          child: Container(
                            margin: const EdgeInsets.all(3.0),
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            child: const Text('搜索', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior().copyWith(scrollbars: false),
        child: RefreshIndicator(
          backgroundColor: const Color(0xFFFCF7EE),
          color: const Color(0xFFFF2C55),
          displacement: 10.0,
          onRefresh: handleRefresh,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            children: [
              // 空态
              if (dataList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset('assets/images/common-empty.png', width: 120.0),
                      const SizedBox(height: 12.0),
                      Text(roomStatus == 2 ? '暂无预约直播' : '暂无直播', style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                    ],
                  ),
                )
              else
                ...dataList.map<Widget>((dynamic item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: CardItem(item: item),
                    )),
              // 加载更多
              Opacity(
                opacity: dataList.isNotEmpty && isLoading ? 1 : 0,
                child: const Loading(title: '加载中...'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
    );
  }

  // 状态筛选按钮: [value] 与接口 status 一致(1 直播中 / 2 直播预告)
  Widget _statusChip(String label, int value) {
    final bool active = roomStatus == value;
    return GestureDetector(
      onTap: () {
        // 加载中不切换: 避免上一页数据回填到新的筛选下
        if (isLoading || roomStatus == value) return;
        setState(() {
          roomStatusValue = value;
        });
        loadRoomPage(refresh: true);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: active ? 14.0 : 0.0, vertical: active ? 4.0 : 0.0),
        decoration: active
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16.0)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF999999),
            fontSize: 13.0,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// 顶部播放图标
class _PlayIcon extends StatelessWidget {
  const _PlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24.0),
    );
  }
}

// 卡片组件
class CardItem extends StatelessWidget {
  final dynamic item;
  const CardItem({super.key, required this.item});

  // 在线人数格式化(>=1万 显示 x.x万)
  String get _viewers {
    final int online = LiveApi.intOf(item['online']);
    if (online >= 10000) {
      final String w = (online / 10000).toStringAsFixed(1);
      return w.endsWith('.0') ? '${w.substring(0, w.length - 2)}万' : '${w}万';
    }
    return '$online';
  }

  // 标签列表(最多 3 个)
  List<String> get _tags {
    final dynamic t = item['tags'];
    if (t is List) {
      return t.map((dynamic e) => '$e').where((String s) => s.isNotEmpty).take(3).cast<String>().toList();
    }
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> room = item is Map ? (item as Map).cast<String, dynamic>() : <String, dynamic>{};
    final String cover = LiveApi.imageOf(room['feeds_img']);
    final String avatar = LiveApi.imageOf(room['anchor_img']);
    final String name = '${room['anchor_name'] ?? ''}'.trim();
    final String title = '${room['name'] ?? ''}'.trim();
    final String desc = '${room['desc'] ?? ''}'.trim();
    final String community = '${room['community'] ?? ''}'.trim();
    final bool isLive = LiveApi.statusOf(room) == 1;
    final bool verified = room['is_verified'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: () {
        Get.toNamed('/live', arguments: <String, dynamic>{
          'sn': '${room['sn'] ?? ''}',
          'name': room['name'] ?? '',
          'src': '${room['push_link'] ?? ''}',
          'type': '${room['type'] ?? ''}',
          'cover': cover,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: cover,
                    width: 120.0,
                    height: 150.0,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) => Container(width: 120.0, height: 150.0, color: Colors.grey[200]),
                    errorWidget: (BuildContext context, String url, Object error) => Container(
                      width: 120.0,
                      height: 150.0,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  // 直播中/预告 badge
                  Positioned(
                    left: 8.0,
                    top: 8.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8A75), Color(0xFFFF5A4D)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_tethering, color: Colors.white, size: 10.0),
                          const SizedBox(width: 3.0),
                          Text(
                            LiveApi.statusName(room),
                            style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 在线人数
                  if (isLive)
                    Positioned(
                      right: 8.0,
                      top: 8.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, color: Colors.white, size: 10.0),
                            const SizedBox(width: 2.0),
                            Text(_viewers, style: const TextStyle(color: Colors.white, fontSize: 10.0)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            // 右侧信息
            Expanded(
              child: SizedBox(
                height: 150.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          desc,
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 10.0),
                    // 主播行(头像/名字/认证/直播中/小区专享)
                    Row(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar,
                            width: 20.0,
                            height: 20.0,
                            fit: BoxFit.cover,
                            errorWidget: (BuildContext context, String url, Object error) => Container(color: Colors.grey[200], width: 20.0, height: 20.0),
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF666666)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verified)
                          Padding(
                            padding: const EdgeInsets.only(left: 2.0),
                            child: Icon(Icons.verified, size: 13.0, color: Colors.orange[400]),
                          ),
                        if (isLive)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 11.0, color: Colors.green[400]),
                                const SizedBox(width: 2.0),
                                const Text('直播中', style: TextStyle(fontSize: 11.0, color: Color(0xFF999999))),
                              ],
                            ),
                          ),
                        if (community.isNotEmpty)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.home_filled, size: 10.0, color: Colors.orange[400]),
                                  const SizedBox(width: 2.0),
                                  Flexible(
                                    child: Text(
                                      '$community小区专享',
                                      style: TextStyle(fontSize: 11.0, color: Colors.orange[400]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    // 标签
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: _tags.map((String tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0ED),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(fontSize: 11.0, color: Color(0xFFFF5A4D)),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
