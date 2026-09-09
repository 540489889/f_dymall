/// 直播首页模板
library;

import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';
import '../../components/backtop.dart';
import './mock/live_json.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with TickerProviderStateMixin {
  List<String> tabList = ['关注', '发现', '精选'];
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
// 瀑布流列表
List waterfallData = liveJson;
// 列表
List dataList = [];
// 是否加载中
bool isLoading = false;

late ScrollController scrollController = ScrollController();
late TabController tabController = TabController(initialIndex: 2, length: tabList.length, vsync: this);
late TabController cateController = TabController(initialIndex: 0, length: cateList.length, vsync: this);
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);

// 加载更多
Future<void> loadMoreData() async {
  if(isLoading) return;
  setState(() {
    isLoading = true;
  });
  // 模拟网络请求或数据获取延迟
  await Future.delayed(Duration(seconds: 1));
setState(() {
  dataList.addAll(waterfallData);
  isLoading = false;
});
}

// 下拉刷新
Future<void> handleRefresh() async {
setState(() {
  dataList.clear();
  // 随机打乱数据
  waterfallData = List.from(liveJson)..shuffle();
});
  loadMoreData();
}

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;

  if(scrollController.position.pixels == scrollController.position.maxScrollExtent) {
    debugPrint('[live]滚动到底部');
    if(!isLoading) {
      loadMoreData();
    }
    }
  });
  handleRefresh();
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
          hintText: "男卫衣纯棉100%",
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
        // 广告图
      SizedBox(
        height: 100.0,
        child: Swiper.children(
          autoplay: true,
          pagination: SwiperPagination(
        alignment: Alignment.bottomRight,
        builder: DotSwiperPaginationBuilder(
          color: Colors.white70,
          activeColor: Colors.white,
          size: 5.0,
          activeSize: 8.0
        )
      ),
        children: [
          CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281113/358423/2/10091/112897/691719cbFad563282/195e4f93971e0507.jpg', fit: BoxFit.fill),
          CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281029/343297/32/20029/96879/69032eb1F4e907c04/5998529abf168fb1.jpg', fit: BoxFit.fill),
        ],
      ),
      ),

      Container(
        color: Colors.white,
        margin: EdgeInsets.only(top: 10.0),
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
        dataList.isEmpty ? 
        // 初始loading提示
          Column(
          children: [
            RefreshProgressIndicator(
              backgroundColor: Colors.white,
              color: Color(0xFFFF2C55),
            ),
          ],
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
    imageUrl: '${item['poster']}',
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
          Text('直播中', style: TextStyle(color: Colors.white, fontSize: 10.0),)
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
        Text('${item['desc']}', style: TextStyle(fontSize: 14.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis,),
        Visibility(
        visible: item['topic'] != null,
        child: Wrap(
        spacing: 5.0,
        runSpacing: 5.0,
        children: item['topic']?.map<Widget>((item) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
            decoration: BoxDecoration(
                color: Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text('$item', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 10.0),),
            );
          }).toList() ?? [],
          ),
        ),
        Row(
      children: [
      Expanded(
      child: Row(
        spacing: 5.0,
      children: [
      ClipOval(
          child: Image.network('${item['logo']}', height: 20.0, width: 20.0, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.grey[50], height: 20.0, width: 20.0);
          }),
        ),
        Text('${item['name']}', style: TextStyle(color: Colors.grey, fontSize: 12.0), maxLines: 1, overflow: TextOverflow.ellipsis,),
      ],
      ),
      ),
      Icon(Icons.favorite, color: Colors.black54, size: 14.0,),
      Text(' ${item['likeNum']}', style: TextStyle(color: Colors.grey, fontSize: 11.0),),
      ],
        ),
        ],
        ),
      ),
    ],
    ),
  ),
  onTap: () {
    Get.toNamed('/live', arguments: item);
    }
  );
}
}
