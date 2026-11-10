/// 视频页面 - 短剧频道
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './module/drama.dart';
import '../../components/task_countdown.dart';
import '../../utils/content.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  @override
  Widget build(BuildContext context) {
    // 状态栏图标(时间/电量)颜色跟随内容SDK就绪状态:
    // * 就绪 -> 黑底短剧, 用白色图标(SystemUiOverlayStyle.light)
    // * 未就绪 -> 米色兜底页, 用深色图标(SystemUiOverlayStyle.dark)
    // 用 ValueListenableBuilder 监听 Content.ready, 隐私同意后延迟初始化完成会自动切换。
    // 放在 VideoPage 这一层: AnnotatedRegion 随 tab 切换自动还原, 不会污染其它页面状态栏。
    return ValueListenableBuilder<bool>(
      valueListenable: Content.readyNotifier,
      builder: (BuildContext context, bool ready, Widget? child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: ready ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Stack(
            children: <Widget>[
              const Positioned.fill(child: DramaModule()),
              // 赚钱页 type=3「观看短剧」任务: 右上角圆形倒计时,只有从任务入口进来才显示
              // SafeArea 避开状态栏;再下移约一行(48dp)避开短剧顶部频道 Tab
              const Positioned(
                top: 48.0,
                right: 12.0,
                child: SafeArea(
                  bottom: false,
                  child: TaskCountdownCircle(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
