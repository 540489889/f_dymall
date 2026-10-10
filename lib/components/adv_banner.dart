/// 广告轮播组件
/// * 多张: 自动轮播(4 秒) + 底部指示点, 可手动左右滑
/// * 单张: 静态展示, 不启动定时器也不显示指示点
/// * 点击按广告的 link 跳转(http 外链用系统浏览器, 其它按内部路由)
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvBanner extends StatefulWidget {
  const AdvBanner({
    super.key,
    required this.list,
    this.height = 95.0,
    this.radius = 0.0,
    this.margin,
    this.interval = const Duration(seconds: 4),
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
    if (oldWidget.list.length != widget.list.length) {
      index = 0;
      if (pageController.hasClients && pageController.page != 0) {
        pageController.jumpToPage(0);
      }
      _startAutoPlay();
    }
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

  /// 点击广告: 外链用系统浏览器, 其它按内部路由跳
  Future<void> onTap(String link) async {
    final String url = link.trim();
    if (url.isEmpty) return;
    if (url.startsWith('http')) {
      final Uri uri = Uri.tryParse(url) ?? Uri();
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    Get.toNamed(url);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> list = widget.list;
    if (list.isEmpty) return const SizedBox.shrink();
    final double radius = widget.radius;
    return Container(
      margin: widget.margin,
      height: widget.height,
      clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
      decoration: radius > 0 ? BoxDecoration(borderRadius: BorderRadius.circular(radius)) : null,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          PageView.builder(
            controller: pageController,
            itemCount: list.length,
            onPageChanged: (int i) {
              if (!mounted) return;
              setState(() => index = i);
            },
            itemBuilder: (BuildContext context, int i) {
              final Map<String, dynamic> item = list[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap('${item['link'] ?? ''}'),
                child: CachedNetworkImage(
                  imageUrl: '${item['image'] ?? ''}',
                  width: double.infinity,
                  height: widget.height,
                  fit: BoxFit.cover,
                  placeholder: (BuildContext c, String u) => const ColoredBox(color: Color(0xFFF5F5F5)),
                  errorWidget: (BuildContext c, String u, Object e) => const SizedBox.shrink(),
                ),
              );
            },
          ),
          // 指示点: 只有多张时显示
          if (list.length > 1)
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
      ),
    );
  }
}
