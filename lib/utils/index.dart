/// 封装常用函数
library;

import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
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
}
