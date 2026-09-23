/// 底部更多框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../behavior/custom_scroll_behavior.dart';
import '../../../router/fade_route.dart';
import 'popup_font_size.dart';
import 'popup_report.dart';

class PopupMore extends StatefulWidget {
  const PopupMore({
  super.key,
  required this.roomId,
  this.onShare,
});

  /// 直播间房间号 sn(举报接口 no 参数)
  final String roomId;

  /// 点"分享"回调(分享由外层处理)
  final VoidCallback? onShare;

@override
State<PopupMore> createState() => _PopupMoreState();
}

class _PopupMoreState extends State<PopupMore> {
// 只保留"分享"和"举报"(同一排展示), 其余功能暂未实现先隐藏
List circleList = [
  {'icon': const Icon(Icons.share), 'label': '分享'},
  {'icon': const Icon(Icons.merge_rounded), 'label': '举报'},
  {'icon': const Icon(Icons.text_fields), 'label': '字体大小'},
];

@override
void initState() {
  super.initState();
}

  /// 点击功能项: 先收起更多弹窗, 再打开对应弹窗
  void onItemTap(String label) {
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    if (label == '举报') {
      nav.push(FadeRoute(effect: 'bottom', child: PopupReport(roomId: widget.roomId)));
      return;
    }
    if (label == '字体大小') {
      nav.push(FadeRoute(effect: 'bottom', child: const PopupFontSize()));
      return;
    }
    if (label == '分享') {
      widget.onShare?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
   body: ScrollConfiguration(
    behavior: CustomScrollBehavior().copyWith(scrollbars: false),
    child: SafeArea(
    child: Column(
      children: [
        Expanded(
          child: GestureDetector(
          child: Container(
            color: Colors.transparent,
          ),
          onTap: () {
            Get.back();
          },
        ),
      ),
      Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
        child: Column(
          children: [
            Container(
              height: 95.0,
              width: double.infinity,
            margin: const EdgeInsets.only(top: 15.0),
            child: Row(
              children: [
                Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(5.0),
                  itemCount: circleList.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onItemTap('${circleList[index]['label']}'),
                      child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      children: [
                        Container(
                          height: 45.0,
                          width: 45.0,
                          margin: const EdgeInsets.only(bottom: 5.0),
                          decoration: BoxDecoration(
                          color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(50.0),
                          ),
                          child: UnconstrainedBox(
                            child: circleList[index]['icon'],
                          ),
                        ),
                        Text('${circleList[index]['label']}', style: const TextStyle(color: Colors.black54, fontSize: 12.0),)
                      ],
                        ),
                      ),
                      );
                      },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25.0),
              ],
            ),
          ),
        ],
        ),
      ),
    ),
  );
  }
}
