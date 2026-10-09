/// 富文本正文(flutter_html 统一排版)
/// * 去掉 flutter_html 默认块级间距,统一字号 / 行高,避免正文出现大段空白
/// * 清洗后台富文本里的空段落(<p><br></p> 等)与连续换行
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class HtmlContent extends StatelessWidget {
  const HtmlContent(
    this.html, {
    super.key,
    this.fontSize = 14.0,
    this.lineHeightValue = 1.6,
    this.horizontalPadding = 16.0,
  });

  final String html;
  final double fontSize;
  final double lineHeightValue;
  /// 外层左右内边距: 用于计算图片最大宽度
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Html(
      data: clean(html),
      shrinkWrap: true,
      style: <String, Style>{
        'body': Style(
          margin: Margins.zero,
          fontSize: FontSize(fontSize),
          lineHeight: LineHeight(lineHeightValue),
          color: Colors.black87,
        ),
        'p': Style(
          margin: Margins.only(bottom: 8.0),
          fontSize: FontSize(fontSize),
          lineHeight: LineHeight(lineHeightValue),
        ),
        'div': Style(margin: Margins.only(bottom: 8.0), lineHeight: LineHeight(lineHeightValue)),
        'h1': Style(margin: Margins.only(bottom: 8.0), fontSize: FontSize(fontSize + 3.0)),
        'h2': Style(margin: Margins.only(bottom: 8.0), fontSize: FontSize(fontSize + 2.0)),
        'h3': Style(margin: Margins.only(bottom: 8.0), fontSize: FontSize(fontSize + 1.0)),
        'li': Style(margin: Margins.only(bottom: 4.0)),
        'img': Style(width: Width(MediaQuery.of(context).size.width - horizontalPadding * 2)),
      },
    );
  }

  /// 富文本清理: 去掉编辑器产生的空段落与连续换行
  /// * 空段落形如 <p><br></p> / <p>&nbsp;</p>,浏览器里不占位但 flutter_html 会撑出块间距
  static String clean(String html) {
    if (html.trim().isEmpty) return html;
    // 1. 内容为空(仅 br / &nbsp; / 空白)的段落整体删除
    String result = html.replaceAllMapped(
      RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false),
      (Match m) {
        final String inner = (m.group(1) ?? '').replaceAll(RegExp(r'<br\s*/?>|&nbsp;|\s', caseSensitive: false), '');
        return inner.isEmpty ? '' : m.group(0)!;
      },
    );
    // 2. 连续 3 个及以上 <br> 收敛为 2 个
    result = result.replaceAll(RegExp(r'(?:\s*<br\s*/?>\s*){3,}', caseSensitive: false), '<br><br>');
    return result;
  }
}
