/// 视频页面 - 短剧频道
library;

import 'package:flutter/material.dart';
import './module/drama.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  @override
  Widget build(BuildContext context) {
    // 直接展示「热门短剧」内容, 不再使用顶部频道切换 Tab 栏
    return const DramaModule();
  }
}
