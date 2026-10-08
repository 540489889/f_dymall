/// 布局模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controller/video_store.dart';
import '../controller/app_config.dart';
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

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: pageCurrent, viewportFraction: 1.0);
  }

  /// 把 diy 的 link.type 映射到对应页面(未知类型回退首页)
  Widget _pageForType(String type) {
    switch (type) {
      case 'home':
        return const KeepAliveWrapper(child: IndexPage());
      case 'video':
        return const VideoPage();
      case 'live':
        return const KeepAliveWrapper(child: LivePage());
      case 'earn':
        return const KeepAliveWrapper(child: EarnPage());
      case 'mine':
        return const MyPage();
      default:
        return const KeepAliveWrapper(child: IndexPage());
    }
  }

  /// 底部自定义导航配置(来自 /api/config/init 的 diy_bottom_nav),未加载/异常时返回 null
  Map<String, dynamic>? get _diy {
    final dynamic raw = AppConfig.to.get('diy_bottom_nav');
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  /// diy 的 tab 列表(空表示使用默认静态导航)
  List<dynamic> get _diyList {
    final Map<String, dynamic>? d = _diy;
    if (d != null && d['list'] is List) return d['list'] as List<dynamic>;
    return const [];
  }

  bool get _useDiy => _diyList.isNotEmpty;

  /// 根据当前配置构建页面列表(顺序与 tab 列表一致)
  List<Widget> get _pages {
    if (!_useDiy) {
      return const [
        KeepAliveWrapper(child: IndexPage()),
        VideoPage(),
        KeepAliveWrapper(child: LivePage()),
        KeepAliveWrapper(child: EarnPage()),
        MyPage(),
      ];
    }
    return _diyList.map<Widget>((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      final Map<String, dynamic> link =
          item['link'] is Map ? item['link'] as Map<String, dynamic> : <String, dynamic>{};
      final String type = '${link['type'] ?? ''}';
      return _pageForType(type);
    }).toList();
  }

  /// #RRGGBB / #RGB / 不带# 的颜色解析,失败返回 fallback
  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String h = hex.trim();
    if (!h.startsWith('#')) h = '#$h';
    if (h.length == 4) {
      h = '#${h[1]}${h[1]}${h[2]}${h[2]}${h[3]}${h[3]}';
    }
    if (h.length == 7) {
      final int? v = int.tryParse(h.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return fallback;
  }

  /// 本地兜底图标(无网络图标 / 加载失败时用), 尺寸与 diy 图标保持一致
  Widget _localIcon(String type, bool selected, [double size = 26.0]) {
    String asset;
    switch (type) {
      case 'home':
        asset = 'tab_shop_selected.png';
        break;
      case 'video':
        asset = 'tab_video.png';
        break;
      case 'live':
        asset = 'tab_live.png';
        break;
      case 'earn':
        asset = 'tab_money.png';
        break;
      case 'mine':
        asset = 'tab_mine.png';
        break;
      default:
        asset = 'tab_shop_selected.png';
    }
    return Opacity(
      opacity: selected ? 1.0 : 0.5,
      child: Image.asset('assets/images/newico/$asset', width: size, height: size, fit: BoxFit.contain),
    );
  }

  /// diy 网络图标: 取选中/未选中两态图片(失败回退本地)
  Widget _diyIcon(Map<String, dynamic> item, bool selected) {
    final Map<String, dynamic> link =
        item['link'] is Map ? item['link'] as Map<String, dynamic> : <String, dynamic>{};
    final String type = '${link['type'] ?? ''}';
    final String url = selected
        ? '${item['selectedIconPath'] ?? ''}'
        : '${item['iconPath'] ?? ''}';
    // diy 图标统一尺寸: 缺失 imgWidth 时按 40 兜底(与首页/我的显式值一致), 保证全部 tab 大小统一
    double size = 40.0;
    final double? w = double.tryParse('${item['imgWidth'] ?? ''}');
    if (w != null && w > 0) size = w;
    if (url.isEmpty) return _localIcon(type, selected, size);
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      placeholder: (BuildContext c, String u) => _localIcon(type, selected, size),
      errorWidget: (BuildContext c, String u, Object e) => _localIcon(type, selected, size),
    );
  }

  /// 默认静态导航(与历史 5 个 tab 一致, 配置未就绪时兜底)
  List<BottomNavigationBarItem> _defaultNavItems() {
    Widget tabIcon(String name, {bool selected = false}) => Opacity(
          opacity: selected ? 1.0 : 0.5,
          child: Image.asset('assets/images/newico/$name', width: 26.0, height: 26.0, fit: BoxFit.contain),
        );
    return [
      BottomNavigationBarItem(
        icon: tabIcon('tab_shop_selected.png'),
        activeIcon: tabIcon('tab_shop_selected.png', selected: true),
        label: '商城',
      ),
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: true,
          backgroundColor: Colors.redAccent,
          alignment: const Alignment(1.5, -1.0),
          smallSize: 8.0,
          child: tabIcon('tab_video.png'),
        ),
        activeIcon: Badge(
          isLabelVisible: true,
          backgroundColor: Colors.redAccent,
          alignment: const Alignment(1.5, -1.0),
          smallSize: 8.0,
          child: tabIcon('tab_video.png', selected: true),
        ),
        label: '视频',
      ),
      BottomNavigationBarItem(
        icon: tabIcon('tab_live.png'),
        activeIcon: tabIcon('tab_live.png', selected: true),
        label: '直播',
      ),
      BottomNavigationBarItem(
        icon: tabIcon('tab_money.png'),
        activeIcon: tabIcon('tab_money.png', selected: true),
        label: '赚钱',
      ),
      BottomNavigationBarItem(
        icon: tabIcon('tab_mine.png'),
        activeIcon: tabIcon('tab_mine.png', selected: true),
        label: '我',
      ),
    ];
  }

  /// 构建底部导航 items(diy / 默认)
  List<BottomNavigationBarItem> _navItems() {
    if (!_useDiy) return _defaultNavItems();
    return _diyList.map<BottomNavigationBarItem>((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      final String text = '${item['text'] ?? ''}';
      return BottomNavigationBarItem(
        icon: _diyIcon(item, false),
        activeIcon: _diyIcon(item, true),
        label: text,
      );
    }).toList();
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
    // 配置动态: 用 Obx 包裹, /api/config/init 拉取完成后自动切换为 diy 导航
    return Obx(() {
      final List<Widget> pages = _pages;
      final List<BottomNavigationBarItem> items = _navItems();
      final Color barBg = _useDiy
          ? _parseColor(_diy?['backgroundColor'], const Color(0xFFFDFAF7))
          : const Color(0xFFFDFAF7);
      final Color selColor = _useDiy
          ? _parseColor(_diy?['textHoverColor'], const Color(0xFFFF2C55))
          : const Color(0xFFFF2C55);
      final Color unselColor = _useDiy
          ? _parseColor(_diy?['textColor'], Colors.black54)
          : Colors.black54;

      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: PageView(
          controller: pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: pages,
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
                  backgroundColor: barBg,
                  fixedColor: selColor,
                  unselectedItemColor: unselColor,
                  type: BottomNavigationBarType.fixed,
                  elevation: 1.0,
                  unselectedFontSize: 12.0,
                  selectedFontSize: 12.0,
                  currentIndex: pageCurrent,
                  items: items,
                  onTap: onNavTap,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
