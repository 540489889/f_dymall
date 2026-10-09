/// 证照信息（备案 / 企业信息）
/// * 数据来自 /api/config/init 的 copyright 节点
/// * 字段不固定，兼容展示 icp / company_name / address / copyright_desc 等
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controller/app_config.dart';

class LicenseInfoPage extends StatelessWidget {
  const LicenseInfoPage({super.key});

  Map<String, dynamic> get _copyright {
    final dynamic raw = AppConfig.to.get('copyright');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// 要展示的信息项：key -> 中文标签
  static const Map<String, String> _labels = <String, String>{
    'company_name': '企业名称',
    'icp': 'APP备案号',
    'icp_link': '备案查询',
    'company_address': '企业地址',
    'copyright_desc': '版权说明',
    'business_license': '营业执照',
  };

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, String>> entries = _labels.entries
        .where((MapEntry<String, String> e) => '${_copyright[e.key] ?? ''}'.trim().isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '证照信息',
          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('暂无证照信息', style: TextStyle(fontSize: 13.0, color: Color(0xFF999999))),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1.0, indent: 16.0, endIndent: 16.0),
              itemBuilder: (BuildContext context, int index) {
                final MapEntry<String, String> entry = entries[index];
                final String value = '${_copyright[entry.key]}'.trim();
                final bool link = entry.key == 'icp_link' || value.startsWith('http');
                return InkWell(
                  onTap: link ? () => _openUrl(value) : null,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 90.0,
                          child: Text(entry.value,
                              style: const TextStyle(fontSize: 14.0, color: Color(0xFF666666))),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: link ? const Color(0xFF2C8DFA) : const Color(0xFF333333),
                            ),
                          ),
                        ),
                        if (link)
                          const Icon(Icons.open_in_new, size: 14.0, color: Color(0xFF2C8DFA)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('提示', '无法打开该链接');
    }
  }
}
