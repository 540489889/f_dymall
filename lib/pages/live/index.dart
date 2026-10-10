/// 直播首页模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';
import '../../components/backtop.dart';
import '../../components/live_playing_bars.dart';
import '../../api/live.dart';
import './scan.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key, this.fromHome = false});

  /// 是否从首页直播板块的"全部"进来
  /// * 只有这种来源才显示右下角"回到首页"入口: 底部"直播"tab 进来时本来就在站内,
  ///   再给一个回首页按钮既多余又和 tab 栏语义冲突
  final bool fromHome;

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
  // 是否正在拉第一页(下拉刷新 / 搜索 / 切筛选): 用于区分顶部刷新指示器与底部"加载中"
  // * 同样用可空字段 + getter 兜底,原因同 pageValue
  bool? isRefreshingValue;
  bool get isRefreshing => isRefreshingValue ?? false;
  // 搜索关键字(接口 roomPage 的 keywords: 直播间标题/主播昵称)
  // * 只记值不发请求,点"搜索"/回车才带关键字重新拉列表
  String keywords = '';
  final TextEditingController searchController = TextEditingController();

  late ScrollController scrollController = ScrollController();
  // 记录滚动位置
  final ValueNotifier<double> scrollOffset = ValueNotifier(0);

  // 加载直播列表(/live/api/shop/roomPage)
  // * [refresh] 重新拉第一页: 默认先清空列表(搜索 / 切筛选), keepOld = true 时保留旧列表(下拉刷新)
  // * [keepOld] 下拉刷新用: 旧数据继续占位,拿到新列表后整体覆盖,避免中间闪一下空白
  Future<void> loadRoomPage({bool refresh = false, bool keepOld = false}) async {
    if (isLoading) return;
    if (refresh) {
      pageValue = 1;
      hasMoreValue = true;
      isRefreshingValue = true;
      if (!keepOld) {
        setState(() {
          dataList = [];
        });
      }
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
      isRefreshingValue = false;
      if (refresh) {
        // 覆盖式刷新: 只有明确拿到 list 才替换,请求失败时保留旧列表不误清空
        if (res['list'] is List) dataList = List<dynamic>.from(list);
      } else {
        dataList.addAll(list);
      }
      hasMoreValue = res['hasMore'] == true;
      // 本次确实拿到数据才翻页,避免失败时空翻
      if (list.isNotEmpty) pageValue = page + 1;
    });
  }

  // 下拉刷新: 保留旧列表占位,新数据回来后整体覆盖(不清空,避免一闪而过)
  Future<void> handleRefresh() async {
    await loadRoomPage(refresh: true, keepOld: true);
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

      // 滚到底部附近(留 30px 余量)才加载下一页; maxScrollExtent>0 防止短列表误触发持续翻页
      if (scrollController.position.maxScrollExtent > 0 &&
          scrollController.position.pixels >= scrollController.position.maxScrollExtent - 30) {
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
        toolbarHeight: 56.0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leadingWidth: 0.0,
        title: Image.asset(
          'assets/images/leuhui_logo_live.png',
          height: 50.0,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            // 扫码图标(自定义 png): 进入扫码/直播码入口页,不再直接拉起相机
            icon: Image.asset('assets/images/icon_sm.png', width: 22.0, height: 22.0, fit: BoxFit.contain, isAntiAlias: true),
            onPressed: () => Get.to(() => const LiveScanPage()),
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
            // 即便列表为空/很短也保持可滚动, 保证下拉刷新始终可用
            physics: const AlwaysScrollableScrollPhysics(),
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
              // 加载更多(下拉刷新时已经有顶部指示器,底部不再重复显示)
              Opacity(
                opacity: dataList.isNotEmpty && isLoading && !isRefreshing ? 1 : 0,
                child: const Loading(title: '加载中...'),
              ),
            ],
          ),
        ),
      ),
      // 右下角悬浮组: 回到首页在上(仅从首页"全部"进来时显示),返回顶部在下(滚动超过阈值才出现)
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (widget.fromHome) _buildHomeFab(),
          if (widget.fromHome) const SizedBox(height: 12.0),
          Backtop(controller: scrollController, offset: scrollOffset),
        ],
      ),
    );
  }

  /// 回到首页悬浮按钮
  /// * 质感与 Backtop 保持一致(白粉渐变 + 主色描边 + 双层投影),视觉上是一组
  /// * offAllNamed('/'): 与商品详情页底部"首页"入口一致,清空栈后落在底部导航的首页
  Widget _buildHomeFab() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.offAllNamed('/'),
      child: Container(
        width: 46.0,
        height: 46.0,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF1F4)],
          ),
          borderRadius: BorderRadius.circular(23.0),
          border: Border.all(color: const Color(0x33FF2C55), width: 1.0),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x2EFF2C55), blurRadius: 14.0, offset: Offset(0.0, 4.0)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 4.0, offset: Offset(0.0, 1.0)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.home_outlined, size: 22.0, color: Color(0xFFFF2C55)),
      ),
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

  // 模拟数据兜底: 接口缺少标签时, 用固定文案撑出 UI 图效果
  List<String> _mockTags(String title) {
    if (title.contains('草莓')) return ['新鲜草莓', '农家直发', '现摘现发'];
    if (title.contains('蟹') || title.contains('海鲜')) return ['品质蟹', '个大肥美', '现货速发'];
    if (title.contains('水果')) return ['芒果', '蓝莓', '阳光玫瑰'];
    if (title.contains('四件套') || title.contains('床品')) return ['纯棉四件套', '柔软舒适', '限时特惠'];
    if (title.contains('坚果')) return ['坚果礼盒', '营养健康', '全家适用'];
    return ['精选好物', '限时优惠', '品质保证'];
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> room = item is Map ? (item as Map).cast<String, dynamic>() : <String, dynamic>{};
    final String cover = LiveApi.imageOf(room['feeds_img']);
    final String avatar = LiveApi.imageOf(room['anchor_img']);
    final String name = '${room['anchor_name'] ?? ''}'.trim();
    final String title = '${room['name'] ?? ''}'.trim().isEmpty ? '精选好物直播专场' : '${room['name'] ?? ''}'.trim();
    final bool isLive = LiveApi.statusOf(room) == 1;

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
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: cover,
                    width: 130.0,
                    height: 90.0,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) => Container(width: 130.0, height: 100.0, color: Colors.grey[200]),
                    errorWidget: (BuildContext context, String url, Object error) => Container(
                      width: 130.0,
                      height: 90.0,
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
                        color: const Color(0xFFFDEDDF),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 直播中: 用跳动均衡器条代替静态图标(与首页直播卡片一致); 预告状态保留原图标
                          isLive
                              ? LivePlayingBars(color: const Color(0xFFFF5A4D), height: 10.0)
                              : const Icon(Icons.wifi_tethering, color: Color(0xFFFF5A4D), size: 10.0),
                          const SizedBox(width: 3.0),
                          Text(
                            LiveApi.statusName(room),
                            style: const TextStyle(color: Color(0xFFFF5A4D), fontSize: 10.0, fontWeight: FontWeight.w600),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: Color(0xFF222222), height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0),
                  // 主播行(头像/名字+认证/直播中)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32.0,
                        height: 32.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!, width: 1.0),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar,
                            width: 32.0,
                            height: 32.0,
                            fit: BoxFit.cover,
                            errorWidget: (BuildContext context, String url, Object error) => Container(color: Colors.grey[200], width: 32.0, height: 32.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.verified, size: 14.0, color: Colors.orange[400]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  // 标签(最多2个, 单行)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6.0,
                    children: (_tags.isNotEmpty ? _tags : _mockTags(title)).take(2).map((String tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F6),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 10.0, color: Color(0xFFFF5A4D)),
                      ),
                    )).toList(),
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
