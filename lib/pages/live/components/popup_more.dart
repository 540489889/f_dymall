/// 底部更多框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../behavior/custom_scroll_behavior.dart';

class PopupMore extends StatefulWidget {
  const PopupMore({
  super.key,
});

@override
State<PopupMore> createState() => _PopupMoreState();
}

class _PopupMoreState extends State<PopupMore> {
List circleList = [
  {'icon': const Icon(Icons.share), 'label': '分享'},
  {'icon': const Icon(Icons.message), 'label': '聊天设置'},
  {'icon': const Icon(Icons.import_export_sharp), 'label': '转发'},
  {'icon': const Icon(Icons.card_giftcard), 'label': '送礼特效'},
  {'icon': const Icon(Icons.clear_all), 'label': '清屏'},
  {'icon': const Icon(Icons.desktop_windows), 'label': '添加到桌面'},
  {'icon': const Icon(Icons.local_mall), 'label': '电商组件'},
];
List moreList = [
  {'icon': const Icon(Icons.settings_outlined), 'label': '直播设置'},
  {'icon': const Icon(Icons.merge_rounded), 'label': '举报'},
  {'icon': const Icon(Icons.settings_accessibility_sharp), 'label': '未成年监督'},
  {'icon': const Icon(Icons.favorite_border), 'label': '优化推荐'},
];

@override
void initState() {
  super.initState();
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
              height: 80.0,
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
                    return Container(
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
                      );
                      },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 100.0,
              width: double.infinity,
              child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(5.0),
                itemCount: moreList.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        children: [
                          Container(
                            height: 45.0,
                            width: 45.0,
                            margin: const EdgeInsets.only(bottom: 5.0),
                            child: UnconstrainedBox(
                              child: moreList[index]['icon'],
                            ),
                          ),
                          Text('${moreList[index]['label']}', style: const TextStyle(color: Colors.black54, fontSize: 12.0),)
                        ],
                      ),
                        );
                      },
                    ),
                  ),
                    ],
                  ),
                ),
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
