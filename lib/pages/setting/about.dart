/// 关于我们
/// 排版对齐 UI 设计稿: 橙色渐变顶栏 + 暖色背景
/// * 上: 居中 Logo / 名称 / 标语
/// * 中: 白色圆角信息卡(版本号 / 联系方式 / 运营主体 / 平台官网 / 平台资质 / ICP备案号)
/// * 下: 版权文案贴底
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/index.dart';
import '../../controller/app_config.dart';

/// 品牌主色
const Color _brandColor = Color(0xFFFF4D5F);

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => version = info.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => version = '');
    }
  }

  /// 站点信息(后端 /api/config/init 的 site_info / siteInfo)
  Map<String, dynamic> get _site {
    dynamic raw = AppConfig.to.get('site_info');
    raw ??= AppConfig.to.get('siteInfo');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// 版权 / 备案信息(后端 copyright)
  Map<String, dynamic> get _copyright {
    final dynamic raw = AppConfig.to.get('copyright');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// 动态字符串兜底: 空值/空串返回 fallback
  String _str(dynamic value, String fallback) {
    final String s = value == null ? '' : '$value'.trim();
    return s.isEmpty ? fallback : s;
  }

  String _imgUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${Config.imgDomain}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String get _logo => _imgUrl(_site['logo_square'] ?? _site['logo']);

  String get _name => _str(_site['site_name'], '乐惠新零售');

  String get _slogan => _str(_site['site_slogan'], '邻里生活，惠享到家');

  /// 联系方式(优先后台配置, 未配置用默认邮箱)
  String get _contact =>
      _str(_site['contact_email'] ?? _site['email'] ?? _copyright['email'], 'lehuishop@163.com');

  /// 运营主体
  String get _company =>
      _str(_copyright['company_name'] ?? _site['company_name'], '重楼数字科技重庆有限公司');

  /// 平台官网(未配置时点击提示)
  String get _officialUrl =>
      _str(_site['site_url'] ?? _site['website'] ?? _copyright['site_url'], '');

  /// ICP 备案号
  String get _icpNo => _str(_copyright['icp'] ?? _copyright['copyright_desc'], '—');

  /// ICP 查询链接
  String get _icpLink => _str(_copyright['icp_link'], 'https://beian.miit.gov.cn/');

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) {
      Get.snackbar('提示', '链接暂未配置');
      return;
    }
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('提示', '无法打开该链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 顶栏与页面同色(暖色), 状态栏图标用深色
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF6EE),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶栏(仅占位, 无单独背景色, 与页面暖色背景融为一体)
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: SizedBox(
                height: kToolbarHeight,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Get.back<void>(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Color(0xFF3A2E24)),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        '关于我们',
                        style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Color(0xFF3A2E24)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        // 用 spaceBetween 把版权推到底部, 不能用 Spacer(弹性子组件在无限高度的
                        // 滚动视图里会导致布局异常、整页空白)
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 顶部内容组: 品牌区 + 信息卡
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 40.0),
                              _header(),
                              const SizedBox(height: 36.0),
                              _infoCard(),
                            ],
                          ),
                          // 底部版权(贴底, 预留底部安全区/手势条间距)
                          Padding(
                            padding: EdgeInsets.only(
                              top: 24.0,
                              bottom: MediaQuery.of(context).padding.bottom + 12.0,
                            ),
                            child: _copyrightText(),
                          ),
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
    );
  }

  /// 顶部品牌区: Logo / 名称 / 标语
  Widget _header() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 18.0),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: Color(0xFF3A2E24)),
        ),
        const SizedBox(height: 8.0),
        Text(
          _slogan,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.0, color: Color(0xFF9A8C7E)),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    const double size = 88.0;
    final BorderRadius radius = BorderRadius.circular(20.0);
    if (_logo.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _brandColor, borderRadius: radius),
        child: const Icon(Icons.shopping_bag, size: 42.0, color: Colors.white),
      );
    }
    return CachedNetworkImage(
      imageUrl: _logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
      imageBuilder: (BuildContext context, ImageProvider imageProvider) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (_, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFFF5EAE0), borderRadius: radius),
      ),
      errorWidget: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _brandColor, borderRadius: radius),
        child: const Icon(Icons.shopping_bag, size: 42.0, color: Colors.white),
      ),
    );
  }

  /// 信息卡: 版本号 / 联系方式 / 运营主体 / 平台官网 / 平台资质 / ICP备案号
  Widget _infoCard() {
    final TextStyle valueStyle = const TextStyle(fontSize: 14.0, color: Color(0xFF666666));
    const TextStyle linkStyle = TextStyle(fontSize: 14.0, color: Color(0xFF666666));

    // 可点击行右侧: 文案 + 小箭头
    Widget linkValue(String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: linkStyle),
            const SizedBox(width: 2.0),
            const Icon(Icons.chevron_right, size: 18.0, color: Color(0xFFBBBBBB)),
          ],
        );

    final List<Widget> rows = <Widget>[
      _row('版本号', Text(version.isEmpty ? '—' : version, style: valueStyle)),
      _divider(),
      _row('联系方式', Text(_contact, style: valueStyle)),
      _divider(),
      _row('运营主体', Text(_company, style: valueStyle)),
      _divider(),
      _row('平台官网', linkValue('访问官网'), onTap: () => _openUrl(_officialUrl)),
      _divider(),
      _row('平台资质', linkValue('查看资质'), onTap: () => Get.toNamed('/qualification')),
      _divider(),
      _row('ICP备案号', Text(_icpNo, style: valueStyle), onTap: () => _openUrl(_icpLink)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16.0, offset: const Offset(0.0, 4.0)),
        ],
      ),
      child: Column(children: rows),
    );
  }

  /// 信息卡单行: 左标签 + 右值(整行可点)
  Widget _row(String label, Widget value, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 15.0, color: Color(0xFF333333))),
              const Spacer(),
              value,
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1.0, thickness: 0.5, color: Color(0xFFF2EDE8), indent: 16.0, endIndent: 16.0);
  }

  /// 底部版权: Copyright © 2023-<当前年份> 名称. All Rights Reserved.
  Widget _copyrightText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'Copyright © 2023-${DateTime.now().year} $_name. All Rights Reserved.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.0, color: Color(0xFFB8AA9C)),
      ),
    );
  }
}
