/// 视频页面模板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controller/video_store.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/keepalive_wrapper.dart';
import './module/subscribe.dart';
import './module/browse.dart';
import './module/live.dart';
import './module/buying.dart';
import './module/drama.dart';
import './module/attention.dart';
import './module/local.dart';
import './module/recommend.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with SingleTickerProviderStateMixin {
GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

final videoStore = VideoStore.to;

late TabController tabController = TabController(initialIndex: videoStore.videoTabIndex.value, length: tabList.length, vsync: this);
late PageController pageController = PageController(initialPage: videoStore.videoTabIndex.value, viewportFraction: 1.0);

List<String> tabList = ['订阅', '逛逛', '直播', '团购', '短剧', '关注', '同城', '推荐'];
final tabModules = [
  KeepAliveWrapper(child: SubscribeModule()),
  KeepAliveWrapper(child: BrowseModule()),
  KeepAliveWrapper(child: LiveModule()),
KeepAliveWrapper(child: BuyingModule()),
KeepAliveWrapper(child: DramaModule()),
AttentionModule(),
LocalModule(),
RecommendModule()
];

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  tabController.dispose();
  super.dispose();
}

// tab文字颜色
Color tabColor() {
  int tabindex = videoStore.videoTabIndex.value;
  Color color = Colors.white;
  if([0, 1, 4, 5].contains(tabindex)) {
    color = Colors.black;
  }
  return color;
}
// tab未选中文字颜色
Color unselectedTabColor() {
  int tabindex = videoStore.videoTabIndex.value;
  Color color = Colors.white70;
  if([0, 1, 4, 5].contains(tabindex)) {
    color = Colors.black54;
  }
  return color;
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    key: scaffoldKey,
    extendBodyBehindAppBar: true,
    appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: Obx(() => AppBar(
      forceMaterialTransparency: true,
    systemOverlayStyle: SystemUiOverlayStyle(
    statusBarIconBrightness: [0, 1, 4, 5].contains(videoStore.videoTabIndex.value) ? Brightness.dark : Brightness.light,
  ),
  titleSpacing: 1.0,
  leading: IconButton(
    icon: Badge.count(
      backgroundColor: Colors.redAccent,
      count: 3,
      child: Icon(Icons.sort_rounded, color: tabColor(),),
    ),
    onPressed: () {
      // 自定义打开右侧drawer
      scaffoldKey.currentState?.openDrawer();
    },
  ),
    title: ScrollConfiguration(
    behavior: CustomScrollBehavior().copyWith(scrollbars: false),
    child: TabBar(
      controller: tabController,
      tabs: tabList.map((v) => Tab(text: v)).toList(),
      isScrollable: true,
      tabAlignment: TabAlignment.center,
     overlayColor: WidgetStateProperty.all(Colors.transparent),
    unselectedLabelColor: unselectedTabColor(),
    labelColor: tabColor(),
    indicatorColor: tabColor(),
     indicatorSize: TabBarIndicatorSize.tab,
    unselectedLabelStyle: const TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei'),
    labelStyle: const TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w600),
     dividerHeight: 0,
    labelPadding: const EdgeInsets.symmetric(horizontal: 10.0),
     indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 4.0),
     onTap: (index) {
      videoStore.updateVideoTabIndex(index);
      pageController.jumpToPage(index);
      },
    ),
  ),
    actions: [
    IconButton(icon: Icon(Icons.search_rounded, color: tabColor(),), onPressed: () {},),
  ],
  )),
),
body: ScrollConfiguration(
  behavior: CustomScrollBehavior().copyWith(scrollbars: false),
  child: PageView(
    controller: pageController,
    onPageChanged: (index) {
      videoStore.updateVideoTabIndex(index);
      tabController.animateTo(index, duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
    },
    children: tabModules,
  ),
),
  // 侧边栏
  drawer: Drawer(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(15.0))),
  clipBehavior: Clip.antiAlias,
  width: 300,
  child: Container(
    color: Colors.grey[50],
    child: Column(
      children: [
        SizedBox(height: 80.0,),
        Icon(Icons.list, color: Colors.grey, size: 30.0,),
        Text('自定义侧边栏', style: TextStyle(color: Colors.grey, fontSize: 12.0),)
      ],
        ),
      ),
    ),
    );
  }
}
