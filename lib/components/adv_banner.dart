/// 广告轮播组件
/// * 多张: 自动轮播(6 秒) + 底部指示点, 可手动左右滑
/// * 单张: 静态展示, 不启动定时器也不显示指示点
/// * 点击按广告的 link 跳转(http 外链用系统浏览器, 其它按内部路由)
library;

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/index.dart';

class AdvBanner extends StatefulWidget {
  const AdvBanner({
    super.key,
    required this.list,
    this.height = 95.0,
    this.radius = 0.0,
    this.margin,
    this.interval = const Duration(seconds: 6),
  });

  /// 广告列表(元素: {image, link, title}); 为空时组件不占高度
  final List<Map<String, dynamic>> list;
  /// 轮播高度: 多张图必须统一高度, 否则切换时页面会整体跳动
  final double height;
  /// 圆角(0 为直角)
  final double radius;
  final EdgeInsetsGeometry? margin;
  /// 自动轮播间隔
  final Duration interval;

  @override
  State<AdvBanner> createState() => _AdvBannerState();
}

class _AdvBannerState extends State<AdvBanner> {
  late PageController pageController;
  Timer? timer;
  int index = 0;
  /// 每张图的宽高比(下标 -> 宽/高): 高度按当前这张图算, 不写死不裁剪
  final Map<int, double> _ratios = <int, double>{};
  /// 正在取尺寸的下标(去重, 避免每次 build 都重新 resolve)
  final Set<int> _resolving = <int>{};

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant AdvBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 广告列表变化(接口回来/刷新): 回到第一张并重置定时器
    if (oldWidget.list.length != widget.list.length ||
        '${oldWidget.list.isEmpty ? '' : oldWidget.list.first['image']}' !=
            '${widget.list.isEmpty ? '' : widget.list.first['image']}') {
      index = 0;
      _ratios.clear();
      _resolving.clear();
      if (pageController.hasClients && pageController.page != 0) {
        pageController.jumpToPage(0);
      }
      _startAutoPlay();
    }
  }

  /// 取第 [i] 张图的宽高比(CachedNetworkImageProvider 命中缓存时同步返回)
  void _resolveRatio(int i, String url) {
    if (url.isEmpty || _resolving.contains(i)) return;
    _resolving.add(i);
    final ImageStream stream = CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        stream.removeListener(listener);
        _resolving.remove(i);
        if (!mounted) return;
        final int w = info.image.width;
        final int h = info.image.height;
        if (w <= 0 || h <= 0) return;
        final double ratio = w / h;
        if ((_ratios[i] ?? 0) == ratio) return;
        setState(() => _ratios[i] = ratio);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        _resolving.remove(i);
      },
    );
    stream.addListener(listener);
  }

  /// 自动轮播: 只有多张时才起定时器
  void _startAutoPlay() {
    timer?.cancel();
    timer = null;
    if (widget.list.length < 2) return;
    timer = Timer.periodic(widget.interval, (Timer t) {
      if (!mounted || !pageController.hasClients) return;
      final int next = (index + 1) % widget.list.length;
      pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  /// 点击广告: 统一走 App 跳转入口(外链浏览器 / 内部路由带参)
  Future<void> onTap(String link) async {
    await Utils.openAppLink(link);
  }

  /// 单条广告图
  /// * 高度由外层容器按这张图的宽高比定(见 build), 这里填满即可, 不裁不拉
  /// * 加载中占位沿用 [AdvBanner.height](默认 95): 与页面上的等高占位一致, 图回来后基本不跳
  Widget _buildItem(Map<String, dynamic> item) {
    final String url = '${item['image'] ?? ''}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap('${item['link'] ?? ''}'),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (BuildContext c, String u) => SizedBox(
          height: widget.height,
          child: const ColoredBox(color: Color(0xFFF5F5F5)),
        ),
        errorWidget: (BuildContext c, String u, Object e) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> list = widget.list;
    if (list.isEmpty) return const SizedBox.shrink();
    final double radius = widget.radius;
    // 高度不限制: 容器高度 = 宽 / 当前这张图的宽高比, 图完完整整显示
    // * 图尺寸还没回来时先用 height 兜底, 免得塌成 0
    // * 多张比例不一致时切页会带着下方内容动一下 —— 产品要求不限制高度, 接受
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double? ratio = _ratios[index];
        final double height = (ratio != null && ratio > 0) ? width / ratio : widget.height;
        final Widget pageView = PageView.builder(
          controller: pageController,
          itemCount: list.length,
          onPageChanged: (int i) {
            if (!mounted) return;
            setState(() => index = i);
          },
          itemBuilder: (BuildContext context, int i) {
            _resolveRatio(i, '${list[i]['image'] ?? ''}');
            return _buildItem(list[i]);
          },
        );
        return Container(
          margin: widget.margin,
          height: height,
          clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
          decoration: radius > 0 ? BoxDecoration(borderRadius: BorderRadius.circular(radius)) : null,
          child: list.length > 1
              ? Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    pageView,
                    // 指示点: 只有多张时显示
                    Positioned(
                      bottom: 6.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(list.length, (int i) {
                          final bool active = i == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                            width: active ? 12.0 : 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFFFF2C55) : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                )
              : pageView,
        );
      },
    );
  }
}
