/// 弹幕/聊天字体大小设置弹窗(对应 H5 liveFooter 的 zoom 选择)
/// * 三档: 标(1.0) / 中(1.3) / 大(1.6), 选中即写本地缓存并即时生效
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/danmu_zoom.dart';

class PopupFontSize extends StatefulWidget {
  const PopupFontSize({super.key});

  @override
  State<PopupFontSize> createState() => _PopupFontSizeState();
}

class _PopupFontSizeState extends State<PopupFontSize> {
  late double current = danmuZoom.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Get.back(),
              child: const SizedBox.expand(),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    height: 40.0,
                    child: Center(
                      child: Text(
                        '弹幕字体大小',
                        style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF161823)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Row(
                    children: danmuZoomOptions
                        .map((double zoom) => Expanded(child: _zoomItem(zoom)))
                        .toList(),
                  ),
                  const SizedBox(height: 14.0),
                  // 预览: 用当前档位渲染一条聊天文本
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text: '观众：',
                            style: TextStyle(color: const Color(0xFF8CE7FF), fontSize: 13.0 * current),
                          ),
                          TextSpan(
                            text: '这是弹幕字体预览',
                            style: TextStyle(color: Colors.white, fontSize: 13.0 * current),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个档位: 主色描边表示当前选中, 中间的字按该档位放大(直观看到大小差别)
  Widget _zoomItem(double zoom) {
    final bool selected = current == zoom;
    return GestureDetector(
      onTap: () {
        setState(() => current = zoom);
        setDanmuZoom(zoom);
        // 选完即关(H5 setZoom 也是选完收起)
        Get.back();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1E8) : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: selected ? const Color(0xFFFE6000) : const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              danmuZoomText(zoom),
              style: TextStyle(
                fontSize: 13.0 * zoom,
                fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFFFE6000) : const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 12.0 * zoom,
                color: selected ? const Color(0xFFFE6000) : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
