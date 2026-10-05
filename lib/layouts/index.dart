/// 布局模板
library;

import 'package:flutter/material.dart';
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
  // tabs选项(图标使用 newico 目录下的 png)
  Widget _tabIcon(String name, {bool selected = false}) {
    return Opacity(
      opacity: selected ? 1.0 : 0.5,
      child: Image.asset('assets/images/newico/$name', width: 26.0, height: 26.0, fit: BoxFit.contain),
    );
  }

  List<BottomNavigationBarItem> buildNavItems() {
    return [
      BottomNavigationBarItem(
        icon: _tabIcon('tab_shop_selected.png'),
        activeIcon: _tabIcon('tab_shop_selected.png', selected: true),
        label: '商城',
      ),
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: true,
          backgroundColor: Colors.redAccent,
          alignment: const Alignment(1.5, -1.0),
          smallSize: 8.0,
          child: _tabIcon('tab_video.png'),
        ),
        activeIcon: Badge(
          isLabelVisible: true,
          backgroundColor: Colors.redAccent,
          alignment: const Alignment(1.5, -1.0),
          smallSize: 8.0,
          child: _tabIcon('tab_video.png', selected: true),
        ),
        label: '视频',
      ),
      BottomNavigationBarItem(
        icon: _tabIcon('tab_live.png'),
        activeIcon: _tabIcon('tab_live.png', selected: true),
        label: '直播',
      ),
      BottomNavigationBarItem(
        icon: _tabIcon('tab_money.png'),
        activeIcon: _tabIcon('tab_money.png', selected: true),
        label: '赚钱',
      ),
      BottomNavigationBarItem(
        icon: _tabIcon('tab_mine.png'),
        activeIcon: _tabIcon('tab_mine.png', selected: true),
        label: '我',
      ),
    ];
  }

  @override
  void initState() {
   super.initState();
    pageController = PageController(initialPage: pageCurrent, viewportFraction: 1.0);
  }

  // 底部导航栏背景色
 Color bottomNavigationBgcolor() {
   Color color = const Color(0xFFFDFAF7);
    if(pageCurrent == 1) {
      color = const Color(0xFFFDFAF7);
    }
   return color;
  }
  // 底部导航栏颜色
  Color bottomNavigationItemcolor({bool centerDocked = false}) {
    Color color = Colors.black54;
    if(pageCurrent == 1) {
      color = Colors.black54;
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
      child: Stack(
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
        ),
      ),
    );
  }
}
