/// 封装常用函数
library;

import 'dart:math';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class Utils {
  /// 随机字符串
  /// * [len] 字符串长度
 static String guid({int len = 32}) {
  String str = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  String chars = '';
  for(var i = 0; i < len; i++) {
    chars += str[Random().nextInt(str.length)];
  }
  return chars;
}

  /// 获取全局唯一标识符uuid
  /// * [type] uuid类型
  /// * [namespace] 生成指定内容uuid
  /// https://pub.dev/packages/uuid
 static dynamic uuid({String type = 'v1', String? namespace}) {
  var uuid = const Uuid();
  switch(type) {
    // Generate a v1 (time-based) id
   case 'v1':
      return uuid.v1(); // -> '6c84fb90-12c4-11e1-840d-7b25c5ee775a'
    // Generate a v4 (random) id
    case 'v4':
      return uuid.v4();
    // Generate a v5 (namespace-name-sha1-based) id
    case 'v5':
      return uuid.v5(Namespace.url.value, namespace);
    // Generate a v6 (time-based) id
    case 'v6':
      return uuid.v6();
    // Generate a v7 (time-based) id
    case 'v7':
      return uuid.v7();
    // Generate a v8 (time-random) id
    case 'v8':
      return uuid.v8();
 }
}

  /// 验证手机号是否正确
  /// * [tel] 手机号码
  static bool checkTel(dynamic tel) {
  return RegExp('^((13|14|15|17|18)[0-9]{1}\\d{8})\$').hasMatch(tel);
}

/// 是否为空
static bool isEmpty(dynamic val) {
 if(val == null) return true;
  if(val is bool && val == false) return true;
 if(val is String) return val.isEmpty;
  if(val is Iterable) return val.isEmpty;
 if(val is Map) return val.isEmpty;
  if(val is Set) return val.isEmpty;
 return false;
}

/// 网址正则
static bool isUrl(dynamic path) {
  // 网址正则
  String urlExpString = r"(http|ftp|https)://([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?";
  RegExp reg = RegExp(urlExpString);
  if(reg.hasMatch(path)) {
    return true;
  }
  return false;
 }

  /// 秒级时间戳转日期时间(对齐 H5 $util.timeStampTurnTime)
  /// * [timestamp] 秒级时间戳(毫秒级会自动按毫秒处理)
  /// * [withSecond] 是否带时分秒,false 只返回 yyyy-MM-dd
  static String timeStampTurnTime(dynamic timestamp, {bool withSecond = true}) {
    int time = int.tryParse('$timestamp') ?? 0;
    if (time <= 0) return '';
    // 毫秒级时间戳(13位)直接使用
    if ('$timestamp'.length <= 10) time = time * 1000;
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(time);
    String two(int value) => value.toString().padLeft(2, '0');
    final String ymd = '${date.year}-${two(date.month)}-${two(date.day)}';
    if (!withSecond) return ymd;
    return '$ymd ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  /// 秒数转换为时分秒
 static String secondsToHms(double seconds) {
    // String h = ((seconds / 3600) % 24).floor().toString().padLeft(2, '0');
 String m = (seconds % 3600 / 60).floor().toString().padLeft(2, '0');
  String s = (seconds % 3600 % 60).floor().toString().padLeft(2, '0');
  // return "$h:$m:$s";
  return "$m:$s";
}

/// 调用外部浏览器打开url
Future<void> launchStringUrl(String url) async {
 if (!await launchUrl(
   Uri.parse(url),
    // mode: LaunchMode.externalApplication,
    // mode: LaunchMode.inAppBrowserView,
    // browserConfiguration: const BrowserConfiguration(showTitle: true),
  )) {
   throw Exception('无法访问 $url');
  }
 }

  /// 统一跳转入口(广告/横幅/导航/推送等共用)
  /// [link] 约定(对应后端 adv_url / nav_url):
  ///   - 空字符串 -> 不跳转
  ///   - 普通字符串: 以 http(s) 开头 -> 系统浏览器; 以 / 开头 -> 内部路由(可带 query 参数)
  ///   - JSON 字符串(小程序约定) -> 按其中的 name 分发到对应 Flutter 路由:
  ///       LIVE_LIST            -> /live/list
  ///       SECKILL_PREFECTURE  -> /seckill
  ///       SIGN_IN             -> /my/signin
  ///       MEMBER_CENTER       -> /my/wallet
  ///       GOODS_CATEGORY_PAGE -> /goods?category_id=xx
  ///       CUSTOM_LINK         -> 取 wap_url(已是 Flutter 路径, 如 /goods/detail?id=80)
  ///     带参时参数会同时塞进 Get.arguments 与 Get.parameters, 兼容两种取参方式
  static Future<void> openAppLink(String link) async {
    final String raw = link.trim();
    if (raw.isEmpty) return;

    String target = raw;
    String? name;

    // 后端可能是 JSON 字符串(小程序约定): { name, wap_url, category_id?, ... }
    if (raw.startsWith('{')) {
      Map<String, dynamic>? info;
      try {
        info = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        info = null;
      }
      if (info == null) return;
      name = '${info['name'] ?? ''}';
      final String? wap = info['wap_url']?.toString();
      switch (name) {
        case 'LIVE_LIST':
          // 直播列表页(注意: /live 是直播间, 列表是 /live/list)
          target = '/live/list';
          break;
        case 'SECKILL_PREFECTURE':
          target = '/seckill';
          break;
        case 'SIGN_IN':
          target = '/my/signin';
          break;
        case 'MEMBER_CENTER':
          target = '/my/wallet';
          break;
        case 'GOODS_CATEGORY_PAGE':
          final String cid = '${info['category_id'] ?? ''}'.trim();
          target = cid.isEmpty ? '/goods' : '/goods?category_id=$cid';
          break;
        case 'CUSTOM_LINK':
        default:
          // 自定义链接: 用 wap_url(已是 Flutter 路径, 如 /goods/detail?id=80)
          target = (wap != null && wap.isNotEmpty) ? wap : '';
      }
    }

    // 小程序路径(/pages...)无法映射到 Flutter 路由, 视为未配置
    if (target.startsWith('/pages')) target = '';

    if (target.isEmpty) {
      if (name != null && name.isNotEmpty) {
        Get.snackbar('提示', '跳转:$name', snackPosition: SnackPosition.BOTTOM);
      }
      return;
    }

    if (target.startsWith('http')) {
      final Uri? uri = Uri.tryParse(target);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final Uri uri = Uri.parse(target);
    final String path = uri.path.isEmpty ? '/' : uri.path;
    final Map<String, String> params = uri.queryParameters;
    if (params.isEmpty) {
      Get.toNamed(path);
    } else {
      Get.toNamed(path, arguments: params, parameters: params);
    }
  }
}
