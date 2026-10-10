/// 关于我们
/// 顶部 logo + 名称 + 标语 + 版本号，下方备案号 + 查询链接
/// * 二维码已去掉(按需求不再展示下载二维码)
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

  String _imgUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${Config.imgDomain}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String get _logo => _imgUrl(_site['logo_square'] ?? _site['logo']);

  String get _name => '${_site['site_name'] ?? ''}'.isNotEmpty
      ? '${_site['site_name']}'
      : '乐惠';

  String get _slogan => '${_site['site_slogan'] ?? ''}'.isNotEmpty
      ? '${_site['site_slogan']}'
      : '正品拼团更便宜！';

  String get _icpNo => '${_copyright['icp'] ?? _copyright['copyright_desc'] ?? ''}';

  String get _icpLink => '${_copyright['icp_link'] ?? 'https://beian.miit.gov.cn/'}';

  String get _titleText => '关于$_name';

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('提示', '无法打开该链接');
    }
  }

  // 给我评分吧(入口已隐藏,保留方法待后台配 app_store_url 后启用)
  // ignore: unused_element
  Future<void> _rate() async {
    final String storeUrl = '${_site['app_store_url'] ?? ''}';
    if (storeUrl.isNotEmpty) {
      await _openUrl(storeUrl);
      return;
    }
    Get.snackbar('提示', '评分链接暂未配置');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // 状态栏用白色背景 + 深色图标(顶栏是白底,透明会让状态栏露出页面灰底)
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            // 状态栏区域也铺白,和下面的标题栏连成一体
            Container(
              height: MediaQuery.of(context).padding.top,
              color: Colors.white,
            ),
            _appBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 顶部信息区
                          _headerCard(),
                          // 底部备案 + 入口
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 24.0),
                            child: Column(
                              children: [
                                _icpSection(),
                                // 证照信息 / 给我评分吧 先隐藏(后台未配置,暂不展示)
                                // _entryRow(
                                //   label: '证照信息',
                                //   icon: Icons.verified_user_outlined,
                                //   onTap: () => Get.toNamed('/license_info'),
                                // ),
                                // _entryRow(
                                //   label: '给我评分吧',
                                //   trailing: const Icon(Icons.chevron_right, size: 18.0, color: Color(0xFFCCCCCC)),
                                //   onTap: _rate,
                                // ),
                              ],
                            ),
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
              child: Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(_titleText,
                  style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 34.0),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo + 名称 + 标语
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(width: 10.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_name,
                      style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4.0),
                  Text(_slogan,
                      style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28.0),
          // 版本号
          Text(
            version.isEmpty ? '版本：—' : '版本：$version',
            style: const TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    if (_logo.isEmpty) {
      return Container(
        width: 54.0,
        height: 54.0,
        decoration: BoxDecoration(color: _brandColor, borderRadius: BorderRadius.circular(14.0)),
        child: const Icon(Icons.shopping_bag, size: 30.0, color: Colors.white),
      );
    }
    return CachedNetworkImage(
      imageUrl: _logo,
      width: 54.0,
      height: 54.0,
      fit: BoxFit.cover,
      imageBuilder: (BuildContext context, ImageProvider imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.0),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (_, __) => Container(
        width: 54.0,
        height: 54.0,
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14.0)),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 54.0,
        height: 54.0,
        decoration: BoxDecoration(color: _brandColor, borderRadius: BorderRadius.circular(14.0)),
        child: const Icon(Icons.shopping_bag, size: 30.0, color: Colors.white),
      ),
    );
  }

  Widget _icpSection() {
    if (_icpNo.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'APP备案号：$_icpNo',
          style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 6.0),
        GestureDetector(
          onTap: () => _openUrl(_icpLink),
          child: RichText(
            text: TextSpan(
              text: '查询链接：',
              style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
              children: <TextSpan>[
                TextSpan(
                  text: _icpLink,
                  style: const TextStyle(fontSize: 12.0, color: Color(0xFF2C8DFA)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 入口行(证照信息 / 给我评分吧 暂时隐藏,保留方法备用)
  // ignore: unused_element
  Widget _entryRow({
    required String label,
    IconData? icon,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15.0, color: Color(0xFF333333))),
              ),
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Icon(icon, size: 18.0, color: const Color(0xFF999999)),
                ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
