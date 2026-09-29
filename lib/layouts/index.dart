/// 布局模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/video_store.dart';
import '../components/keepalive_wrapper.dart';
// 引入pages页面
import '../pages/index/index.dart';
import '../pages/video/index.dart';
import '../pages/live/index.dart';
import '../pages/earn/index.dart';
import '../pages/my/index.dart';

class Layout extends StatefulWidget {
  const Layout({super.key});
  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
final videoStore = VideoStore.to;
  late PageController pageController;
  // page索引
 int pageCurrent = 0;
  // page页面
 late final List<Widget> pageModules = const [
   KeepAliveWrapper(child: IndexPage()),
    VideoPage(),
   KeepAliveWrapper(child: LivePage()),
  KeepAliveWrapper(child: EarnPage()),
   MyPage(),
 ];
  // tabs选项
  List<BottomNavigationBarItem> buildNavItems() {
    return [
     BottomNavigationBarItem(
      icon: Icon(Icons.local_mall),
      label: '商城'
    ),
    BottomNavigationBarItem(
      icon: Badge(
       isLabelVisible: true,
        backgroundColor: Colors.redAccent,
       alignment: Alignment(1.5, -1.0),
      smallSize: 8.0,
       child: Icon(Icons.play_circle_outline),
      ),
      label: '视频'
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.live_tv_rounded),
      label: '直播',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.card_giftcard_outlined),
     label: '赚钱'
    ),
    BottomNavigationBarItem(
     icon: Icon(Icons.person_pin),
      label: '我'
     )
    ];
  }

  @override
  void initState() {
   super.initState();
    pageController = PageController(initialPage: pageCurrent, viewportFraction: 1.0);
  }

  // 底部导航栏背景色
 Color bottomNavigationBgcolor() {
  int pageVideoTabIndex = videoStore.videoTabIndex.value;
   Color color = Colors.white;
    if(pageCurrent == 1) {
     if([0, 1, 3, 4, 5].contains(pageVideoTabIndex)) {
       color = Colors.white;
      }else {
      color = Colors.black;
     }
    }
   return color;
  }
  // 底部导航栏颜色
  Color bottomNavigationItemcolor({bool centerDocked = false}) {
    int pageVideoTabIndex = videoStore.videoTabIndex.value;
    Color color = Colors.black54;
    if(pageCurrent == 1) {
    if([0, 1, 3, 4, 5].contains(pageVideoTabIndex)) {
      color = Colors.black54;
    }else {
      color = Colors.white60;
    }
  }else if(pageCurrent == 2 && centerDocked) {
    color = Color(0xFFFF2C55);
    }
    return color;
  }

  void onNavTap(int index) {
    setState(() {
    pageCurrent = index;
  });
  videoStore.updateBottomNavigationIndex(index);
  pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: Colors.grey[50],
      body: PageView(
     controller: pageController,
      physics: NeverScrollableScrollPhysics(),
     children: pageModules,
    ),
    // 底部导航栏
    bottomNavigationBar: Theme(
     data: Theme.of(context).copyWith(
       splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
       hoverColor: Colors.transparent,
      ),
      child: Obx(() {
        return Stack(
          children: [
          Container(
            decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black45, width: .1)),
          ),
          child: BottomNavigationBar(
             backgroundColor: bottomNavigationBgcolor(),
              fixedColor: Color(0xFFFF2C55),
             unselectedItemColor: bottomNavigationItemcolor(),
              type: BottomNavigationBarType.fixed,
             elevation: 1.0,
              unselectedFontSize: 12.0,
            selectedFontSize: 12.0,
             currentIndex: pageCurrent,
             items: buildNavItems(),
              onTap: onNavTap,
             ),
             ),
         ],
        );
       }),
      ),
    );
  }
}
