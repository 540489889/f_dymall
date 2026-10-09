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

  /// diy 网络图标: 只显示接口返回的两态图片
  /// * 不用本地静态图标兜底: BottomNavigationBar 选中态用 activeIcon 插槽、未选中用 icon 插槽,
  ///   切 tab 时图片控件在两个插槽间重新挂载, placeholder 会先闪一下本地图标再变接口图标
  /// * 加载中 / 失败 / 地址为空一律用同尺寸空白占位, 图标区域高度不变
  Widget _diyIcon(Map<String, dynamic> item, bool selected) {
    final String url = selected
        ? '${item['selectedIconPath'] ?? ''}'
        : '${item['iconPath'] ?? ''}';
    // diy 图标统一尺寸: 缺失 imgWidth 时按 40 兜底(与首页/我的显式值一致), 保证全部 tab 大小统一
    double size = 40.0;
    final double? w = double.tryParse('${item['imgWidth'] ?? ''}');
    if (w != null && w > 0) size = w;
    if (url.isEmpty) return SizedBox(width: size, height: size);
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      placeholder: (BuildContext c, String u) => SizedBox(width: size, height: size),
      errorWidget: (BuildContext c, String u, Object e) => SizedBox(width: size, height: size),
    );
  }

  /// 默认静态导航(与历史 5 个 tab 一致, 配置未就绪时兜底, 仅展示文字无图标)
  List<BottomNavigationBarItem> _defaultNavItems() {
    return const [
      BottomNavigationBarItem(icon: SizedBox.shrink(), activeIcon: SizedBox.shrink(), label: '商城'),
      BottomNavigationBarItem(icon: SizedBox.shrink(), activeIcon: SizedBox.shrink(), label: '视频'),
      BottomNavigationBarItem(icon: SizedBox.shrink(), activeIcon: SizedBox.shrink(), label: '直播'),
      BottomNavigationBarItem(icon: SizedBox.shrink(), activeIcon: SizedBox.shrink(), label: '赚钱'),
      BottomNavigationBarItem(icon: SizedBox.shrink(), activeIcon: SizedBox.shrink(), label: '我'),
    ];
  }

  /// 构建底部导航 items(diy 用接口图标 / 默认无图标)
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
        backgroundColor: const Color(0xFFFCF7EE),
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
                  // tab 文字加粗(选中/未选中均加粗,字号保持 12)
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
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
