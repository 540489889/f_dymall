/// 底部更多框
library;

import 'package:flutter/material.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';

import '../../../behavior/custom_scroll_behavior.dart';
import '../../../router/fade_route.dart';
import 'popup_font_size.dart';
import 'popup_report.dart';
import 'popup_share.dart'; // shareToWeChat / WeChatScene
import '../link_mic.dart'; // 申请连麦页 LinkMicPage

class PopupMore extends StatefulWidget {
  const PopupMore({
    super.key,
    required this.roomId,
    this.shareTitle = '',
    this.shareUrl = '',
    this.shareCover = '',
  });

  /// 直播间房间号 sn(举报接口 no 参数)
  final String roomId;

  /// 分享所需信息(更多框第一排直接拉起微信分享, 不再进分享弹窗)
  final String shareTitle;
  final String shareUrl;
  final String shareCover;

  @override
  State<PopupMore> createState() => _PopupMoreState();
}

class _PopupMoreState extends State<PopupMore> {
  @override
  void initState() {
    super.initState();
  }

  /// 第一排: 分享微信好友 / 朋友圈(彩色圆, 与分享弹窗一致)
  List<Map<String, dynamic>> get _shareItems => <Map<String, dynamic>>[
        <String, dynamic>{
          'label': '微信好友',
          'scene': WeChatScene.session,
          'color': const Color(0xFF07C160),
          'icon': Image.asset(
            'assets/images/share-wx.png',
            width: 40.0,
            height: 40.0,
          ),
        },
        <String, dynamic>{
          'label': '朋友圈',
          'scene': WeChatScene.timeline,
          'gradient': const <Color>[Color(0xFFFFB300), Color(0xFFFF5252)],
          'icon': Image.asset(
            'assets/images/share-pyq.png',
            width: 40.0,
            height: 40.0,
          ),
        },
      ];

  /// 第二排: 举报 / 字体大小(灰底圆)
  List<Map<String, dynamic>> get _moreItems => <Map<String, dynamic>>[
        <String, dynamic>{'icon': Image.asset('assets/images/jb-ico.png', width: 24.0, height: 24.0), 'label': '举报'},
        <String, dynamic>{'icon': const Icon(Icons.text_fields), 'label': '字体大小'},
        <String, dynamic>{'icon': Image.asset('assets/images/mic-ico.png', width: 24.0, height: 24.0), 'label': '申请连麦'},
      ];

  /// 第一排点击: 收起更多框后直接拉起微信分享
  void _onShare(WeChatScene scene) {
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    shareToWeChat(
      title: widget.shareTitle,
      url: widget.shareUrl,
      coverUrl: widget.shareCover,
      scene: scene,
    );
  }

  /// 第二排点击: 收起更多框后打开对应弹窗
  void _onMoreTap(String label) {
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
    if (label == '申请连麦') {
      // 连麦页内部自己走「输入连麦码 -> 申请 -> 等待主播同意」流程
      nav.push(FadeRoute(effect: 'bottom', child: const LinkMicPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior().copyWith(scrollbars: false),
        child: Column(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                child: Container(color: Colors.transparent),
                onTap: () => Get.back(),
              ),
            ),
            Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 顶部标题栏: 左「分享给」, 右圆角关闭按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            '分享给',
                            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Color(0xFF161823)),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Get.back(),
                            child: Container(
                              width: 30.0,
                              height: 30.0,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              child: const Icon(Icons.close, size: 18.0, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      // 第一排: 分享微信好友 / 朋友圈
                      _buildRow(
                        _shareItems.map((Map<String, dynamic> e) => _buildShareItem(e)).toList(),
                      ),
                      const SizedBox(height: 18.0),
                      // 第二排: 举报 / 字体大小
                      _buildRow(
                        _moreItems.map((Map<String, dynamic> e) => _buildMoreItem(e)).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 一行左对齐排列
  Widget _buildRow(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: children,
    );
  }

  /// 分享入口: 直接使用图标(无背景圆)
  Widget _buildShareItem(Map<String, dynamic> item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onShare(item['scene'] as WeChatScene),
      child: Container(
        width: 88.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 45.0,
              height: 45.0,
              child: Align(
                alignment: Alignment.center,
                child: item['icon'] as Widget,
              ),
            ),
            const SizedBox(height: 8.0),
            Text('${item['label']}',
                style: const TextStyle(fontSize: 12.0, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  /// 普通入口(灰底圆): 举报 / 字体大小
  Widget _buildMoreItem(Map<String, dynamic> e) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onMoreTap('${e['label']}'),
      child: Container(
        width: 88.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 45.0,
              height: 45.0,
              margin: const EdgeInsets.only(bottom: 5.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: UnconstrainedBox(child: e['icon'] as Widget),
            ),
            Text('${e['label']}',
                style: const TextStyle(color: Colors.black54, fontSize: 12.0)),
          ],
        ),
      ),
    );
  }
}
