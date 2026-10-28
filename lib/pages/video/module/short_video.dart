/// 小视频模块(穿山甲内容SDK VideoNativeView 沉浸式)
/// * 内容SDK没就绪(未开通内容合作 / 初始化失败 / H5)时展示占位, 不渲染原生View
library;

import 'package:flutter/material.dart';

import '../../../utils/content.dart';

class ShortVideoModule extends StatelessWidget {
  const ShortVideoModule({super.key});

  @override
  Widget build(BuildContext context) {
    // 用 ValueListenableBuilder 监听 Content.ready: 隐私同意后延迟初始化完成时自动切到原生小视频
    return ValueListenableBuilder<bool>(
      valueListenable: Content.readyNotifier,
      builder: (BuildContext context, bool ready, Widget? child) {
        if (!ready) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('小视频暂未开通', style: TextStyle(color: Colors.white70, fontSize: 14.0)),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Colors.black,
          body: VideoNativeView(
            channelType: 1, // 1 推荐 / 2 关注 / 3 推荐+关注
            autoPlay: true,
          ),
        );
      },
    );
  }
}
