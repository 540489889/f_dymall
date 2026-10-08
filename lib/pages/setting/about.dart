/// 关于我们
/// 对齐 H5: pages_tool/member/about.vue
/// * 头部: logo + 站点名称 + APP 版本号
/// * 公司信息: 联系电话(可拨号)
/// * 底部: 版权描述
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/index.dart';
import '../../controller/app_config.dart';

/// 品牌主色(与 App 主题一致)
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

  /// 读取 APP 版本号(对齐 H5 plus.runtime.getProperty)
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

  /// 拼接图片完整地址(与 H5 $util.img 一致: 绝对地址原样返回, 相对地址拼 imgDomain)
  String _imgUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${Config.imgDomain}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// 拨打电话
  Future<void> _callTel() async {
    final String tel = '${_site['site_tel'] ?? ''}';
    if (tel.isEmpty) return;
    final Uri uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final String logo = _imgUrl(_site['logo_square'] ?? _site['logo']);
    final String name = '${_site['site_name'] ?? ''}'.isNotEmpty
        ? '${_site['site_name']}'
        : '美膳官';
    final String copyrightDesc = '${_copyright['copyright_desc'] ?? ''}';
    final String tel = '${_site['site_tel'] ?? ''}';
    final String verText = version.isEmpty ? 'V—' : 'V$version';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            _appBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                children: [
                  // 头部: Logo + 名称 + 版本
                  _headerCard(logo, name, verText),
                  if (tel.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12.0),
                    _contactCard(tel),
                  ],
                  const SizedBox(height: 28.0),
                  if (copyrightDesc.isNotEmpty)
                    Center(
                      child: Text(copyrightDesc,
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
                          textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部标题栏
  Widget _appBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.chevron_left, size: 26.0, color: Colors.black87),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('关于我们',
                  style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 42.0),
        ],
      ),
    );
  }

  /// 头部卡片: logo + 名称 + 版本标签
  Widget _headerCard(String logo, String name, String verText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0D000000), blurRadius: 12.0, offset: Offset(0.0, 4.0)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          if (logo.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x1A000000), blurRadius: 10.0, offset: Offset(0.0, 3.0)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: CachedNetworkImage(
                  imageUrl: logo,
                  width: 84.0,
                  height: 84.0,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFFF5F5F5)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFFF5F5F5)),
                ),
              ),
            )
          else
            Container(
              width: 84.0,
              height: 84.0,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
          const SizedBox(height: 16.0),
          Text(name, style: const TextStyle(fontSize: 19.0, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(verText, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ),
        ],
      ),
    );
  }

  /// 联系电话卡片(可点击拨号)
  Widget _contactCard(String tel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0D000000), blurRadius: 12.0, offset: Offset(0.0, 4.0)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: _callTel,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Icon(Icons.phone, size: 18.0, color: _brandColor),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text('联系电话', style: TextStyle(fontSize: 15.0, color: Colors.black87)),
                ),
                Text(tel, style: const TextStyle(fontSize: 15.0, color: Color(0xFF666666))),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.chevron_right, size: 18.0, color: Colors.black26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
