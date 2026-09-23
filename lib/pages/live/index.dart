/// 直播首页模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
  List<String> tabList = ['关注', '精选'];
  List cateList = [
  {'name': "直播推荐", 'badge': 1},
  {'name': "上新"},
  {'name': "关注"},
  {'name': "男装"},
  {'name': "食品饮料"},
  {'name': "玩具"},
  {'name': "家电"},
  {'name': "美妆护肤"},
  {'name': "生鲜"},
  {'name': "数码办公"},
];
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
// 分类栏暂时不用: 置为 false 隐藏,后续要分类时改回 true 即可
static const bool showCateTab = false;

late ScrollController scrollController = ScrollController();
// initialIndex 必须小于 tabList.length(现在只有 2 个 tab), 越界会直接在 tab_controller.dart 触发断言报错
late TabController tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);
late TabController cateController = TabController(initialIndex: 0, length: cateList.length, vsync: this);
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);

// 加载直播列表(/live/api/shop/roomPage)
// * [refresh] 下拉刷新: 回到第一页并清空列表; 否则按当前页码追加下一页
Future<void> loadRoomPage({bool refresh = false}) async {
  if(isLoading) return;
  if(refresh) {
    pageValue = 1;
    hasMoreValue = true;
    setState(() {
      dataList.clear();
    });
  }
  if(!hasMore) return;
  setState(() {
    isLoading = true;
  });
  final Map<String, dynamic> res = await LiveApi.roomPage(page: page, pageSize: 10, status: roomStatus);
  if(!mounted) return;
  final List<dynamic> list = res['list'] is List ? res['list'] as List<dynamic> : <dynamic>[];
  setState(() {
    isLoading = false;
    dataList.addAll(list);
    hasMoreValue = res['hasMore'] == true;
    // 本次确实拿到数据才翻页,避免失败时空翻
    if(list.isNotEmpty) pageValue = page + 1;
  });
}

// 下拉刷新
Future<void> handleRefresh() async {
  await loadRoomPage(refresh: true);
}

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;

  if(scrollController.position.pixels == scrollController.position.maxScrollExtent) {
    debugPrint('[live]滚动到底部');
    if(!isLoading && hasMore) {
      loadRoomPage();
    }
    }
  });
  loadRoomPage();
}

@override
void dispose() {
  scrollController.dispose();
  tabController.dispose();
  cateController.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
  backgroundColor: Colors.grey[50],
  appBar: AppBar(
    forceMaterialTransparency: true,
    leading: UnconstrainedBox(
      child: Image.asset('assets/images/live.png', height: 30.0, width: 30.0, isAntiAlias: true, fit: BoxFit.contain,),
    ),
    titleSpacing: 1.0,
    title: TabBar(
    controller: tabController,
    tabs: tabList.map((v) => Tab(text: v)).toList(),
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    unselectedLabelColor: Colors.black87,
    labelColor: Color(0xFFFF2C55),
    indicator: UnderlineTabIndicator(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: Color(0xFFFF2C55), width: 2.0),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    unselectedLabelStyle: TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei'),
    labelStyle: TextStyle(fontSize: 18.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
    dividerHeight: 0,
    labelPadding: EdgeInsets.symmetric(horizontal: 7.5),
    indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 4.0),
  ),
  actions: [
    IconButton(icon: Icon(Icons.add_a_photo_outlined, size: 20.0,), onPressed: () {},),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(45.0),
        child: Container(
        margin: EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
        height: 35.0,
        decoration: BoxDecoration(
          color: Colors.white,
        border: Border.all(color: Color(0xFFFF2C55), width: 2.0),
        borderRadius: BorderRadius.circular(30.0),
      ),
        child: TextField(
          decoration: InputDecoration(
          isDense: true,
          hintText: "直播间标题/主播昵称",
          prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20.0,),
        suffixIcon: Padding(
          padding: EdgeInsetsGeometry.all(2.0),
          child: FilledButton(
            style: ButtonStyle(
              elevation: WidgetStateProperty.all(0.0),
            backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
            padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 15.0)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))
            )
          ),
          onPressed: () {},
            child: Text('搜索', style: TextStyle(fontSize: 13.0),),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0))
      ),
      style: TextStyle(fontSize: 14.0),
      cursorColor: Colors.black,
        onChanged: (val) {
          debugPrint(val);
        },
        ),
      ),
    ),
    flexibleSpace: Container(
      decoration: BoxDecoration(
      color: Color(0xFFFFF5F5),
    image: DecorationImage(
        image: AssetImage('assets/images/livebg.png'),
        fit: BoxFit.fill,
      ),
    ),
  ),
),
body: ScrollConfiguration(
  behavior: CustomScrollBehavior().copyWith(scrollbars: false),
  child: RefreshIndicator(
    backgroundColor: Colors.white,
    color: Color(0xFFFF2C55),
    displacement: 10.0,
    onRefresh: handleRefresh,
    child: ListView(
      controller: scrollController,
      children: [
      // 分类栏: 暂时隐藏(showCateTab),数据全部取自 roomPage 接口
      if (showCateTab)
      Container(
        color: Colors.white,
        child: TabBar(
          controller: cateController,
            tabs: cateList.map((item) => Container(
        alignment: Alignment.center,
        height: 45.0,
        child: Badge.count(
          backgroundColor: Colors.red,
          count: item['badge'] ?? 0,
          isLabelVisible: item['badge'] != null ? true : false,
          child: Text(item['name'])
        ),
      )).toList(),
      isScrollable: true,
          tabAlignment: TabAlignment.start,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          unselectedLabelColor: Colors.black87,
          labelColor: Color(0xFFFF2C55),
          indicatorColor: Color(0xFFFF2C55),
            indicatorSize: TabBarIndicatorSize.tab,
          unselectedLabelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei'),
          labelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
          dividerHeight: 0,
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          labelPadding: EdgeInsets.symmetric(horizontal: 10.0),
          indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        ),
          ),
        Container(
          color: Color(0xFFFAFAFA),
        padding: EdgeInsets.all(10.0),
        child: Column(
        spacing: 10.0,
        children: [
        // 状态筛选: 直播中(1) / 直播预告(2),切换后按新 status 重新拉列表
        Row(
          spacing: 8.0,
          children: [
            _statusChip('直播中', 1),
            _statusChip('直播预告', 2),
          ],
        ),
        dataList.isEmpty ? 
        // 首次加载转圈;加载完仍为空显示空态
          Padding(
          padding: EdgeInsets.symmetric(vertical: 60.0),
          child: isLoading ?
            RefreshProgressIndicator(
              backgroundColor: Colors.white,
              color: Color(0xFFFF2C55),
            )
            : Text('暂无直播', style: TextStyle(color: Colors.grey, fontSize: 13.0),),
        )
          :
          MasonryGridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            itemCount: dataList.length,
            itemBuilder: (BuildContext context, int index) => CardItem(item: dataList[index]),
          ),
          Opacity(
            opacity: dataList.isNotEmpty && isLoading ? 1 : 0,
            child: Loading(title: '加载中...')
          ),
          ],
        ),
        ),
      ],
      ),
    ),
  ),
  // 返回顶部
  floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}

// 状态筛选按钮: [value] 与接口 status 一致(1 直播中 / 2 直播预告)
Widget _statusChip(String label, int value) {
  final bool active = roomStatus == value;
  return GestureDetector(
    onTap: () {
      // 加载中不切换: 避免上一页数据回填到新的筛选下
      if(isLoading || roomStatus == value) return;
      setState(() {
        roomStatusValue = value;
      });
      loadRoomPage(refresh: true);
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: active ? Color(0xFFFF2C55) : Colors.white,
        border: Border.all(color: active ? Color(0xFFFF2C55) : Colors.black12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black87, fontSize: 13.0),),
    ),
  );
}
}

// 卡片组件
class CardItem extends StatelessWidget {
  final dynamic item;
  const CardItem({super.key, required this.item});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          offset: Offset(0.0, 1.0),
          blurRadius: 1.0,
          spreadRadius: 0.0,
        ),
      ]
    ),
    child: Column(
      children: [
    Stack(
      children: [
    CachedNetworkImage(
    // 接口封面字段 feeds_img(兼容本地 mock 的 poster)
    imageUrl: LiveApi.imageOf(item['feeds_img'] ?? item['poster']),
    placeholder: (context, url) => Container(
      height: 200.0,
    ),
    height: 200,
    width: double.infinity,
      fit: BoxFit.cover,
    ),
    Positioned(
      left: 5.0,
      top: 5.0,
      child: Container(
        padding: EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: Colors.black38,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
        spacing: 5.0,
        children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFFF2C55),
            borderRadius: BorderRadius.circular(20.0),
          ),
          height: 20.0,
          width: 20.0,
          child: UnconstrainedBox(
              child: Image.asset('assets/images/wave.png', width: 15.0),
            )
          ),
          // 状态用接口 status_name(直播中/直播预告/已结束...)
          Text(LiveApi.statusName(item is Map ? item.cast<String, dynamic>() : null), style: TextStyle(color: Colors.white, fontSize: 10.0),)
        ],
          ),
        ),
          ),
        ],
      ),
      Container(
        padding: EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5.0,
      children: [
        Text('${item['name'] ?? item['desc'] ?? ''}', style: TextStyle(fontSize: 14.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis,),
        Row(
      children: [
      Expanded(
      child: Row(
        spacing: 5.0,
      children: [
      ClipOval(
          // 主播头像(接口 anchor_img,兼容本地 mock 的 logo)
          child: Image.network(LiveApi.imageOf(item['anchor_img'] ?? item['logo']), height: 20.0, width: 20.0, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.grey[50], height: 20.0, width: 20.0);
          }),
        ),
        Text('${item['anchor_name'] ?? ''}', style: TextStyle(color: Colors.grey, fontSize: 12.0), maxLines: 1, overflow: TextOverflow.ellipsis,),
      ],
      ),
      ),
      Icon(Icons.remove_red_eye_outlined, color: Colors.black54, size: 14.0,),
      Text(' ${item['online'] ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 11.0),),
      ],
        ),
        ],
        ),
      ),
    ],
    ),
  ),
  onTap: () {
    // 带上直播间页需要的参数: sn 房间号 / src 拉流地址 / type 横竖屏 / cover 封面(与首页入口一致)
    Get.toNamed('/live', arguments: <String, dynamic>{
      'sn': '${item['sn'] ?? ''}',
      'name': item['name'] ?? '',
      'src': '${item['push_link'] ?? ''}',
      'type': '${item['type'] ?? ''}',
      'cover': LiveApi.imageOf(item['feeds_img'] ?? item['poster']),
    });
    }
  );
}
}
