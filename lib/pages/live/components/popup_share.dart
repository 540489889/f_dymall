/// 直播间分享弹窗(底部弹出)
/// * 照 UI: 顶部「分享到」+ 右上「举报」/ 关闭, 下面微信好友 / 朋友圈两个入口
/// * 分享走 fluwx(微信开放平台 SDK): 分享网页(直播间 share_href), scene 区分会话 / 朋友圈
/// * 举报复用 popup_report, 与「更多」弹窗里的行为一致
library;

import 'dart:typed_data';
import 'dart:ui';

// 加前缀: get 也导出了 Response, 不带前缀两边会冲突
import 'package:dio/dio.dart' as dio;
import 'package:fluwx/fluwx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/index.dart';

class PopupShare extends StatefulWidget {
  const PopupShare({
    super.key,
    required this.roomId,
    this.title = '',
    this.shareUrl = '',
    this.desc = '',
    this.coverUrl = '',
  });

  /// 房间号 sn(举报入口移除后暂未使用, 保留字段方便后续加回)
  final String roomId;
  /// 分享标题(直播间标题)
  final String title;
  /// 分享链接(getRoomInfo 的 share_href)
  final String shareUrl;
  /// 分享描述(可为空)
  final String desc;
  /// 封面图(分享缩略图用: 微信网页分享必带缩略图, 否则 SDK 直接返回失败)
  final String coverUrl;

  @override
  State<PopupShare> createState() => _PopupShareState();
}

class _PopupShareState extends State<PopupShare> {
  bool sharing = false;

  /// 两个入口: 微信好友(会话) / 朋友圈
  /// * 微信好友是纯绿底 + 白微信图标; 朋友圈官方是彩色圆,这里用橙->红渐变 + 风车图标近似
  List<Map<String, dynamic>> get _items => <Map<String, dynamic>>[
        <String, dynamic>{
          'label': '微信好友',
          'scene': WeChatScene.session,
          'color': const Color(0xFF07C160),
          'icon': Image.asset(
            'assets/images/share-wx.png',
            width: 34.0,
            height: 34.0,
            // 强制白色: 不受素材自身颜色影响, 绿底上一定看得见
            color: Colors.white,
          ),
        },
        <String, dynamic>{
          'label': '朋友圈',
          'scene': WeChatScene.timeline,
          'gradient': const <Color>[Color(0xFFFFB300), Color(0xFFFF5252)],
          'icon': const Icon(Icons.filter_vintage, color: Colors.white, size: 30.0),
        },
      ];

  /// 分享到微信: [scene] 会话(微信好友) / 朋友圈
  Future<void> _shareTo(WeChatScene scene) async {
    if (sharing) return;
    final String url = widget.shareUrl.trim();
    if (url.isEmpty) {
      _toast('直播间信息还在加载');
      return;
    }
    setState(() => sharing = true);
    try {
      final Fluwx fluwx = Fluwx();
      final bool installed = await fluwx.isWeChatInstalled;
      if (!installed) {
        _toast('未安装微信');
        return;
      }
      // 重复注册无副作用: 分享前兜一次, 免得 app 起来还没注册过 SDK
      final bool registered = await fluwx.registerApi(
        appId: Config.wxAppId,
        universalLink: Config.wxUniversalLink,
      );
      debugPrint('[share]registerApi=$registered appId=${Config.wxAppId}');
      if (!registered) {
        _toast('微信注册失败，检查 AppID 与包名签名');
        return;
      }
      final Uint8List? thumb = await _makeThumb(widget.coverUrl);
      // 标题为空时微信也不收, 兜一个
      final bool ok = await fluwx.share(WeChatShareWebPageModel(
        url,
        title: widget.title.trim().isEmpty ? '直播分享' : widget.title.trim(),
        description: widget.desc,
        scene: scene,
        thumbData: thumb,
      ));
      debugPrint('[share]share=$ok scene=$scene url=$url thumb=${thumb?.length ?? 0}字节');
      if (!ok) _toast('分享失败');
    } catch (e) {
      debugPrint('[share]分享异常: $e');
      _toast('分享失败');
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  /// 分享缩略图: 网络图 -> 96x96 PNG 字节
  /// * 微信网页分享必须带缩略图(要求 ≤32KB), 不带的话 SDK 直接返回失败
  Future<Uint8List?> _makeThumb(String imageUrl) async {
    final String url = imageUrl.trim();
    if (url.isEmpty) return null;
    try {
      final dio.Response<List<int>> res = await dio.Dio().get<List<int>>(
        url,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final List<int>? bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      final Codec codec = await instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 96,
        targetHeight: 96,
      );
      final FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(format: ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[share]缩略图处理失败: $e');
      return null;
    }
  }

  void _toast(String message) {
    Get.snackbar('提示', message, snackPosition: SnackPosition.BOTTOM);
  }

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 标题行: 只有居中的「分享到」(举报/关闭已去掉, 点空白处关闭弹窗)
                    const SizedBox(
                      height: 40.0,
                      child: Center(
                        child: Text(
                          '分享到',
                          style: TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF161823),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _items
                          .map((Map<String, dynamic> item) => _buildItem(item))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个分享入口: 圆形图标 + 名称
  Widget _buildItem(Map<String, dynamic> item) {
    final List<Color>? gradient = item['gradient'] is List<Color> ? item['gradient'] as List<Color> : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _shareTo(item['scene'] as WeChatScene),
      child: Container(
        width: 88.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56.0,
              height: 56.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // color 与 gradient 不能同时给: 纯色(微信绿) / 渐变(朋友圈彩色)二选一
                color: gradient == null ? (item['color'] as Color? ?? const Color(0xFF07C160)) : null,
                gradient: gradient == null ? null : LinearGradient(colors: gradient),
                shape: BoxShape.circle,
              ),
              child: item['icon'] as Widget,
            ),
            const SizedBox(height: 8.0),
            Text(
              '${item['label']}',
              style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }
}
