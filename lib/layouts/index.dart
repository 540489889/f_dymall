/// 布局模板
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controller/video_store.dart';
import '../controller/app_config.dart';
import '../controller/auth_store.dart';
import '../controller/main_tab.dart';
import '../components/keepalive_wrapper.dart';
import '../utils/player_config.dart';
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
    // 进首页时配置还是空的(首启那次请求被系统网络弹窗打断了), 再补拉一次:
    // 拿不到 diy 配置就只能显示默认导航(只有文字没有图标)
    AppConfig.to.fetchIfEmpty();
    _syncHomeTabActive();
    // 把「按 type 切 tab」的方法注册给主框架控制器, 供推送/深链(如任务中心)调用
    MainTabController.register(_switchToType);
  }

  @override
  void dispose() {
    // 解注册, 避免切 tab 回调指向已销毁的 State
    MainTabController.unregister(_switchToType);
    super.dispose();
  }

  /// 外部(推送/深链)按 type 切底部 tab('home'/'video'/'live'/'earn'/'mine'/diy type)
  /// * 复用 onNavTap: 切 tab 时一并触发视频暂停、各 tab 刷新等原有逻辑
  void _switchToType(String type) {
    final List<String> types = _pageTypes;
    final int idx = types.indexOf(type);
    debugPrint('[nav] switchToType: type=$type idx=$idx useDiy=$_useDiy types=$types');
    if (idx < 0 || idx >= _pages.length) return;
    onNavTap(idx);
  }

  /// 首页 tab 是否正在展示(切到其它 tab 为 false)
  /// * 首页被保活不销毁, 直播轮询要等这个信号才停, 否则离开首页后还在后台请求
  void _syncHomeTabActive() {
    final bool isHome = pageCurrent < _pageTypes.length && _pageTypes[pageCurrent] == 'home';
    if (homeTabActive.value != isHome) homeTabActive.value = isHome;
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
        // 与其它 tab 一致保活: 否则每次切回「我的」都会重建,
        // 门店支付等板块要重新请求一次配置才会出现(看起来就是闪一下)
        return const KeepAliveWrapper(child: MyPage());
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
        KeepAliveWrapper(child: MyPage()),
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
    final Widget icon = CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      placeholder: (BuildContext c, String u) => SizedBox(width: size, height: size),
      errorWidget: (BuildContext c, String u, Object e) {
        if (kDebugMode) debugPrint('[nav]tab 图标加载失败: $u $e');
        return SizedBox(width: size, height: size);
      },
    );
    if (!selected) return icon;
    // 选中态: 播放一次"轻微放大弹入 + 上浮"的动画
    // * BottomNavigationBar 的 icon / activeIcon 是两个插槽,切 tab 时直接替换、没有过渡,
    //   选中的图标每切换一次就是新挂载,这里用 TweenAnimationBuilder 从 0.9 跑到 1.0(带回弹),
    //   配合 -1.5 的上浮,有"弹一下"的反馈又不夸张
    // * 常态重建(如配置刷新)不会重播: tween 未变且 element 复用
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.translate(
          offset: const Offset(0.0, -1.5),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: icon,
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

  /// 每个 tab 对应的页面类型(与 _pages 顺序一致)
  /// * 默认 5 个 tab 写死顺序; diy 配置时取每条 link.type
  List<String> get _pageTypes {
    if (!_useDiy) {
      return const <String>['home', 'video', 'live', 'earn', 'mine'];
    }
    return _diyList.map<String>((dynamic e) {
      final Map<String, dynamic> item = e as Map<String, dynamic>;
      final Map<String, dynamic> link =
          item['link'] is Map ? item['link'] as Map<String, dynamic> : <String, dynamic>{};
      return '${link['type'] ?? ''}';
    }).toList();
  }

  /// 切 tab 时让 PageView 跳到对应页
  /// * 后台被通知点击拉起时 PageController 可能还没 attach 到视图, 直接 jump 会抛异常;
  ///   未 attach 时等下一帧(应用 resume 后)重试, 直到 attach 成功, 保证最终落到正确页
  void _jumpSafely(int index) {
    if (pageController.hasClients) {
      pageController.jumpToPage(index);
      return;
    }
    int tries = 0;
    void retry() {
      if (pageController.hasClients) {
        pageController.jumpToPage(index);
      } else if (tries++ < 30) {
        WidgetsBinding.instance.addPostFrameCallback((_) => retry());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => retry());
  }

  void onNavTap(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      pageCurrent = index;
    });
    _syncHomeTabActive();
    videoStore.updateBottomNavigationIndex(index);
    _jumpSafely(index);
    // 切到直播 tab(包括重复点当前 tab)时让直播列表重新拉一次:
    // * 直播页被 KeepAliveWrapper 保活, 不主动刷新的话列表一直停在首次进 tab 时的数据
    if (index < _pageTypes.length && _pageTypes[index] == 'live') {
      liveTabRefreshTick.value++;
    }
    // 同理: 每次切到赚钱 tab(含重复点当前 tab)都重新拉任务列表
    if (index < _pageTypes.length && _pageTypes[index] == 'earn') {
      earnTabRefreshTick.value++;
    }
    // 切换「我的」tab(含重复点当前 tab): 刷新 memberPageConfig
    if (index < _pageTypes.length && _pageTypes[index] == 'mine') {
      mineTabRefreshTick.value++;
    }
  }

  /// 未登录横幅: 悬浮在底部导航栏上方(黑底圆角条 + 金币图标 + 红色渐变「立即登录」按钮)
  /// * 整条可点,统一起去 /login
  Widget _loginBanner() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed('/login'),
      child: Container(
        height: 44.0,
        padding: const EdgeInsets.only(left: 12.0, right: 5.0),
        decoration: BoxDecoration(
          color: const Color(0xD91A1A1A),
          borderRadius: BorderRadius.circular(22.0),
        ),
        child: Row(
          children: [
            // 金币图标(自绘: 金色渐变圆 + ¥)
            Container(
              width: 26.0,
              height: 26.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: <Color>[Color(0xFFFFE082), Color(0xFFFFB300)]),
              ),
              alignment: Alignment.center,
              child: const Text(
                '¥',
                style: TextStyle(color: Color(0xFF8C5A00), fontSize: 15.0, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8.0),
            const Expanded(
              child: Text(
                '登录享更多福利！',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                gradient: const LinearGradient(colors: <Color>[Color(0xFFFF6A3D), Color(0xFFFA2C19)]),
              ),
              child: const Text(
                '立即登录',
                style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 配置动态: 用 Obx 包裹, /api/config/init 拉取完成后自动切换为 diy 导航
    return Obx(() {
      final List<Widget> pages = _pages;
      final List<BottomNavigationBarItem> items = _navItems();
      // 切到「短剧/视频」tab 时, 底部导航栏整体转黑, 与全屏短剧页融为一体
      final bool isVideo =
          pageCurrent < _pageTypes.length && _pageTypes[pageCurrent] == 'video';
      final Color barBg = isVideo
          ? Colors.black
          : (_useDiy
              ? _parseColor(_diy?['backgroundColor'], const Color(0xFFFDFAF7))
              : const Color(0xFFFDFAF7));
      final Color selColor = isVideo
          ? Colors.white
          : (_useDiy
              ? _parseColor(_diy?['textHoverColor'], const Color(0xFFFF2C55))
              : const Color(0xFFFF2C55));
      final Color unselColor = isVideo
          ? Colors.white70
          : (_useDiy
              ? _parseColor(_diy?['textColor'], Colors.black54)
              : Colors.black54);
      // diy 导航配置是异步来的: tab 类型可能随之后到而变化(首页也可能不在 0 位), 每次布局都同步一次
      _syncHomeTabActive();
      // 未登录: 在底部导航栏上方悬浮「立即登录」横幅
      // 读 authorization.value 让外层 Obx 订阅登录态, 登录/退出自动显隐
      final bool notLogin = AuthStore.to.authorization.value.isEmpty;
      // 只在「首页」tab 显示(默认列表/diy 配置里 type == 'home' 的页面)
      final bool isHome =
          pageCurrent < _pageTypes.length && _pageTypes[pageCurrent] == 'home';
      // 仅未登录 + 当前在首页时才显示
      final bool showLoginBanner = notLogin && isHome;

      return Scaffold(
        backgroundColor: const Color(0xFFFCF7EE),
        body: PageView(
          controller: pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: pages,
        ),
        // 底部导航栏(未登录时上方悬浮「立即登录」横幅)
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: Stack(
            children: [
              // 未登录时给悬浮横幅预留顶部空间
              Container(
                padding: EdgeInsets.only(top: showLoginBanner ? 60.0 : 0.0),
                child: Container(
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
              ),
              if (showLoginBanner)
                Positioned(
                  left: 10.0,
                  right: 10.0,
                  top: 8.0,
                  child: _loginBanner(),
                ),
            ],
          ),
        ),
      );
    });
  }
}
