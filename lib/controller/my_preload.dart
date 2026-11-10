/// 「我的」页首屏数据预拉: 广告(MEMBER_M) + 我的服务 nav + 门店支付开关
/// * 启动时 main 调 MyPreload.start() 预拉一次, 进「我的」页首帧就有内容 —— 不再「先没有, 过一会才冒出来」
/// * 页面自己进页面时也会再拉一次(见 my/index.dart 的 loadAdv / loadServiceNav / loadMemberPageConfig),
///   结果写回这里的缓存, 内容没变就不 setState(避免重建把轮播/网格重刷一遍)
/// * 全部失败静默: 拉不到就按「没数据」处理, 页面走骨架占位后撤掉
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../api/adv.dart';
import '../api/member.dart';

class MyPreload {
  /// 广告图(/api/adv/detail keyword=MEMBER_M)
  static List<Map<String, dynamic>> adv = <Map<String, dynamic>>[];

  /// 我的服务(/api/Member/serviceNav, 已自动补看播记录入口)
  static List<Map<String, dynamic>> service = <Map<String, dynamic>>[];

  /// 门店支付开关(/api/member/memberPageConfig 的 is_pay_code == '1')
  /// * null = 还没拿到结果; true/false = 后台配置结果
  static bool? payCodeEnabled;
  static bool payCodeLoaded = false;
  static DateTime? payCodeAt;

  /// 是否已拿到过结果(true 表示结果已确定, 空列表就是后台没配, 页面不再占位)
  static bool advLoaded = false;
  static bool serviceLoaded = false;

  static bool _started = false;

  /// 启动预拉(幂等, 内部 unawaited, 不阻塞首帧)
  static void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  static Future<void> _run() async {
    await Future.wait<dynamic>(<Future<dynamic>>[
      loadAdv(),
      loadService(),
      loadPayCodeConfig(),
    ]);
  }

  /// 拉广告并写缓存(失败保留旧缓存, 返回值交给页面渲染)
  static Future<List<Map<String, dynamic>>> loadAdv() async {
    try {
      final List<Map<String, dynamic>> list = await AdvApi.list('MEMBER_M');
      adv = list;
      advLoaded = true;
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[preload] 广告(MEMBER_M)拉取失败: $e');
      return adv;
    }
  }

  /// 拉门店支付配置并写缓存(启动预拉与页面刷新共用, 只有这一处解析 is_pay_code)
  /// * 返回 null = 没拿到新信息(空响应 / 请求失败), 调用方保留上次结果
  static Future<bool?> loadPayCodeConfig() async {
    try {
      final Map<String, dynamic> res = await MemberApi.memberPageConfig();
      if (kDebugMode) {
        debugPrint('[preload][memberPageConfig] code=${res['code']} message=${res['message']}');
        debugPrint('[preload][memberPageConfig] data=${res['data']}');
      }
      final dynamic data = res['data'];
      if (data is! Map) return null;
      final bool showPay = '${data['is_pay_code'] ?? ''}' == '1';
      payCodeEnabled = showPay;
      payCodeLoaded = true;
      payCodeAt = DateTime.now();
      return showPay;
    } catch (e) {
      if (kDebugMode) debugPrint('[preload][memberPageConfig] 请求失败: $e');
      return null;
    }
  }

  /// 拉「我的服务」并写缓存
  /// * 看播记录是内置入口: 后台没配 WATCH_RECORD 时自动补一项,保证入口一定可达
  static Future<List<Map<String, dynamic>>> loadService() async {
    try {
      final List<Map<String, dynamic>> list = await MemberApi.serviceNav();
      if (list.isNotEmpty && !_hasWatchRecord(list)) {
        list.add(<String, dynamic>{
          'nav_name': '看播记录',
          'nav_image': 'assets/images/me/mine_icon_svc_livemic.png',
          'nav_url': jsonEncode(<String, String>{'name': 'WATCH_RECORD'}),
        });
      }
      service = list;
      serviceLoaded = true;
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[preload] 我的服务拉取失败: $e');
      return service;
    }
  }

  static bool _hasWatchRecord(List<Map<String, dynamic>> list) {
    return list.any((Map<String, dynamic> e) => actionName(e) == 'WATCH_RECORD');
  }

  /// 服务项动作码: nav_url 可能是 Map,也可能是 JSON 字符串(与首页金刚区同一套约定)
  static String actionName(Map<String, dynamic> item) {
    final dynamic rawUrl = item['nav_url'];
    if (rawUrl is Map) return '${rawUrl['name'] ?? ''}';
    final String text = '${rawUrl ?? ''}'.trim();
    if (text.isEmpty) return '';
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is Map) return '${decoded['name'] ?? ''}';
    } catch (_) {
      return '';
    }
    return '';
  }
}
