/// 邀请好友(对齐设计稿: 品牌区 + 邀请海报卡片 + 立即分享 / 保存海报)
/// * 邀请码: 后台 memberInfo.invite_code 优先, 缺省用 LH + 会员id(补零6位)
/// * 二维码: Config.downloadUrl + invite_code; 未配置落地页时直接放邀请码文本
/// * 立即分享: 微信好友 / 朋友圈 / 复制文案(fluwx), 未装微信自动降级为复制
/// * 保存海报: RepaintBoundary 截图 -> image_gallery_saver 保存到系统相册
library;

import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fluwx/fluwx.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../config/index.dart';
import '../../controller/auth_store.dart';
import '../../utils/wx_native.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  /// 页面主色(橙)
  static const Color orange = Color(0xFFFF8A3C);

  /// 橙色渐变(按钮 / 复制)
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFFFB05C), Color(0xFFFF8A3C)],
  );

  /// 页面背景(奶油橙渐变,与海报截图共用,保证保存的图片背景不透明)
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFF7EE), Color(0xFFFFE7CC)],
  );

  final GlobalKey _posterKey = GlobalKey();
  bool saving = false;

  AuthStore get auth => AuthStore.to;

  /// 邀请码: 后台下发 invite_code 优先, 缺省 LH + 会员id 补零 6 位
  String get _inviteCode {
    final String fromApi = '${auth.memberInfo['invite_code'] ?? ''}'.trim();
    if (fromApi.isNotEmpty) return fromApi;
    final int id = auth.memberId;
    return id > 0 ? 'LH${id.toString().padLeft(6, '0')}' : '';
  }

  /// 邀请落地链接(未配置 downloadUrl 时退化为邀请码文本)
  String get _inviteLink {
    final String base = Config.downloadUrl.trim();
    if (base.isEmpty) return _inviteCode;
    return '$base${base.contains('?') ? '&' : '?'}invite_code=$_inviteCode';
  }

  /// 分享文案
  String get _shareText {
    final StringBuffer sb = StringBuffer(
        '【乐惠新零售】邀请你一起来领金币、看直播、享优惠！\n邀请码：${_inviteCode.isEmpty ? '--------' : _inviteCode}');
    final String link = _inviteLink;
    if (link.isNotEmpty && link != _inviteCode) sb.write('\n下载链接：$link');
    return sb.toString();
  }

  /// 复制邀请码
  Future<void> _copyCode() async {
    if (_inviteCode.isEmpty) {
      MyDialog.toast('邀请码获取失败,请重新登录');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    MyDialog.toast('邀请码已复制');
  }

  /// 复制分享文案
  Future<void> _copyShareText() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    MyDialog.toast('邀请文案已复制,快去粘贴给好友吧');
  }

  /// 立即分享: 弹底部面板(微信好友 / 朋友圈 / 复制文案)
  Future<void> _showShareSheet() async {
    if (_inviteCode.isEmpty) {
      MyDialog.toast('邀请码获取失败,请重新登录');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14.0))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('分享到', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _shareItem('微信好友', Icons.chat_rounded, const Color(0xFF09BB07),
                        () => _shareToWeChat(WeChatScene.session)),
                    _shareItem('朋友圈', Icons.public_rounded, const Color(0xFF09BB07),
                        () => _shareToWeChat(WeChatScene.timeline)),
                    _shareItem('复制文案', Icons.copy_rounded, orange, _copyShareText),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 分享面板选项
  Widget _shareItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Get.back<void>();
        onTap();
      },
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14.0)),
              child: Icon(icon, color: color, size: 28.0),
            ),
            const SizedBox(height: 6.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  /// 微信分享文本(fluwx); 未装微信/拉起失败自动降级为复制文案
  Future<void> _shareToWeChat(WeChatScene scene) async {
    if (!WxAuth.supported) {
      await _copyShareText();
      return;
    }
    final bool installed = await WxAuth.isInstalled();
    if (!installed) {
      MyDialog.toast('未安装微信,已为你复制邀请文案');
      await _copyShareText();
      return;
    }
    await WxAuth.init();
    try {
      final bool sent = await Fluwx().share(WeChatShareTextModel(_shareText, scene: scene));
      if (!sent) await _copyShareText();
    } catch (e) {
      MyDialog.toast(WxAuth.errorMsg(e, '分享失败,请重试'));
    }
  }

  /// 保存海报: 截海报区 -> 系统相册
  Future<void> _savePoster() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final BuildContext? ctx = _posterKey.currentContext;
      if (ctx == null) throw '页面未就绪,请稍后重试';
      final RenderRepaintBoundary boundary =
          ctx.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw '生成海报失败';
      final Uint8List bytes = data.buffer.asUint8List();
      // Android 12 及以下需要存储权限(13+ 走系统相册 MediaStore, 无需授权)
      if (Platform.isAndroid) {
        try {
          await Permission.storage.request();
        } catch (_) {}
      }
      final dynamic res = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 95,
        name: 'lehui_invite_${DateTime.now().millisecondsSinceEpoch}',
      );
      final bool ok = res is Map && (res['isSuccess'] == true || '${res['isSuccess']}' == 'true');
      MyDialog.toast(ok ? '海报已保存到相册' : '保存失败,请检查相册权限');
    } catch (e) {
      MyDialog.toast('$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7EE),
        body: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
          child: Column(
            children: <Widget>[
              // 顶部导航固定在顶部, 不随内容滚动
              SizedBox(height: statusTop),
              _appBar(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // 海报区(品牌 + 邀请卡): 保存海报时整体截图
                    RepaintBoundary(
                      key: _posterKey,
                      child: Container(
                        decoration: const BoxDecoration(gradient: bgGradient),
                        padding: const EdgeInsets.fromLTRB(0.0, 4.0, 0.0, 10.0),
                        child: Column(
                          children: <Widget>[
                            _brand(),
                            _posterCard(),
                          ],
                        ),
                      ),
                    ),
                    _actions(),
                    _footer(),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 10.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部导航(返回 + 标题): 返回按钮与标题各自独立占位, 标题在剩余空间居中
  Widget _appBar() {
    return Container(
      height: 52.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40.0,
            height: 40.0,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20.0, color: Color(0xFF333333)),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('邀请好友',
                  style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
            ),
          ),
          // 与左侧返回按钮等宽, 保证标题真正居中
          const SizedBox(width: 40.0),
        ],
      ),
    );
  }

  /// 品牌区: logo + 名称 + slogan
  Widget _brand() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.asset(
                  'assets/images/mlogo.png',
                  width: 46.0,
                  height: 46.0,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(width: 46.0, height: 46.0),
                ),
              ),
              const SizedBox(width: 10.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Text('乐惠新零售',
                      style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFFFF7A21))),
                  SizedBox(height: 2.0),
                  Text('LeHuiNewRetail',
                      style: TextStyle(fontSize: 11.0, color: Color(0xFFC08A5A), letterSpacing: 1.0)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          const Text('— 邻里生活，惠享到家 —',
              style: TextStyle(fontSize: 13.0, color: Color(0xFFB27B4B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 邀请海报卡片: 头像昵称 + 二维码 + 邀请码/复制 + 文案
  Widget _posterCard() {
    final String code = _inviteCode.isEmpty ? '--------' : _inviteCode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x1AFF8A3C), blurRadius: 20.0, offset: Offset(0.0, 6.0)),
        ],
      ),
      child: Column(
        children: <Widget>[
          // 头像 + 昵称
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _avatar(),
              const SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  auth.nickname.isNotEmpty ? auth.nickname : '乐惠小伙伴',
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // 二维码
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E6),
              borderRadius: BorderRadius.circular(18.0),
            ),
            child: QrImageView(
              data: _inviteLink.isEmpty ? '-' : _inviteLink,
              size: 210.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF333333)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square, color: Color(0xFF333333)),
            ),
          ),
          const SizedBox(height: 16.0),
          // 邀请码 + 复制
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E0),
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: Text(
                    '邀请码：$code',
                    style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF9A5B1F)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 9.0),
                  decoration: BoxDecoration(
                    gradient: orangeGradient,
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: const Text('复制',
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Text('扫码下载APP，和我一起领金币、',
              style: TextStyle(fontSize: 14.0, color: Color(0xFF666666), height: 1.6)),
          const Text('看直播、享优惠！', style: TextStyle(fontSize: 14.0, color: Color(0xFF666666), height: 1.6)),
        ],
      ),
    );
  }

  /// 用户头像(无头像用橙色占位)
  Widget _avatar() {
    final String url = auth.headimg;
    return Container(
      width: 44.0,
      height: 44.0,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFE3C2)),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.person, color: orange, size: 28.0)
          : Image.network(
              url,
              width: 44.0,
              height: 44.0,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.person, color: orange, size: 28.0),
            ),
    );
  }

  /// 操作区: 立即分享 / 保存海报
  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 0.0),
      child: Column(
        children: <Widget>[
          GestureDetector(
            onTap: _showShareSheet,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 52.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: orangeGradient,
                borderRadius: BorderRadius.circular(26.0),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x33FF8A3C), blurRadius: 12.0, offset: Offset(0.0, 4.0)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.ios_share_rounded, color: Colors.white, size: 20.0),
                  SizedBox(width: 8.0),
                  Text('立即分享',
                      style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14.0),
          GestureDetector(
            onTap: saving ? null : _savePoster,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 52.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26.0),
                border: Border.all(color: orange, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  saving
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0, color: orange),
                        )
                      : const Icon(Icons.file_download_outlined, color: orange, size: 20.0),
                  const SizedBox(width: 8.0),
                  Text(
                    saving ? '正在保存...' : '保存海报，邀请好友',
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: orange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部奖励提示
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _line(),
          const SizedBox(width: 10.0),
          const Icon(Icons.redeem_rounded, color: orange, size: 15.0),
          const SizedBox(width: 4.0),
          const Text('每邀请1位好友，最高可得现金奖励',
              style: TextStyle(fontSize: 12.0, color: orange)),
          const SizedBox(width: 10.0),
          _line(),
        ],
      ),
    );
  }

  Widget _line() => Container(width: 28.0, height: 1.0, color: const Color(0xFFFFD5B0));
}
