/// 图形验证码图片解析(接口返回 base64 字符串)
library;

import 'dart:convert';
import 'dart:typed_data';

class CaptchaImg {
  /// 把接口返回的 img 转成图片字节
  /// * 兼容 `data:image/png;base64,xxxx` 与纯 base64 两种格式
  /// * 接口带换行符(\r\n),统一先去掉
  static Uint8List? decode(String img) {
    final String raw = img.replaceAll(RegExp(r'\s'), '');
    if (raw.isEmpty) return null;
    String base64Str = raw;
    final int flagIndex = raw.indexOf('base64,');
    if (flagIndex >= 0) base64Str = raw.substring(flagIndex + 7);
    // base64 长度必须是 4 的倍数,缺位补 '='
    final int pad = base64Str.length % 4;
    if (pad != 0) base64Str = base64Str.padRight(base64Str.length + (4 - pad), '=');
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }
}
