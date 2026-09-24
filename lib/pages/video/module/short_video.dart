/// 小视频模块(穿山甲内容SDK VideoNativeView 沉浸式)
/// * 内容SDK没就绪(未开通内容合作 / 初始化失败 / H5)时展示占位, 不渲染原生View
library;

import 'package:flutter/material.dart';

import '../../../utils/content.dart';

class ShortVideoModule extends StatelessWidget {
  const ShortVideoModule({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Content.ready) {
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
  }
}
