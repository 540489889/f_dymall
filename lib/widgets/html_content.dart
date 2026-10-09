/// 富文本正文(flutter_html 统一排版)
/// * 去掉 flutter_html 默认块级间距,统一字号 / 行高,避免正文出现大段空白
/// * 清洗后台富文本里的空段落(<p><br></p> 等)与连续换行
/// * 剥掉编辑器写死的行内间距(margin / padding / line-height / text-indent),
///   否则这些值会覆盖统一样式,导致个别位置间距特别大
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

  /// 块级元素底部间距(统一收紧,原来 8,块嵌套时会叠加成大空白)
  static const double _blockGap = 6.0;

  @override
  Widget build(BuildContext context) {
    return Html(
      data: clean(html),
      shrinkWrap: true,
      style: <String, Style>{
        // 根容器: flutter_html 默认会给 html / body 留外边距,先归零
        'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(fontSize),
          lineHeight: LineHeight(lineHeightValue),
          color: Colors.black87,
        ),
        // div / section 只是布局容器,不给间距(否则和内部 p 的间距叠加)
        'div': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          lineHeight: LineHeight(lineHeightValue),
        ),
        'section': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'p': Style(
          margin: Margins.only(bottom: _blockGap),
          fontSize: FontSize(fontSize),
          lineHeight: LineHeight(lineHeightValue),
        ),
        'h1': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize + 3.0), lineHeight: LineHeight(1.4)),
        'h2': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize + 2.0), lineHeight: LineHeight(1.4)),
        'h3': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize + 1.0), lineHeight: LineHeight(1.4)),
        'h4': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize), lineHeight: LineHeight(1.4)),
        'h5': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize), lineHeight: LineHeight(1.4)),
        'h6': Style(margin: Margins.only(bottom: _blockGap), fontSize: FontSize(fontSize), lineHeight: LineHeight(1.4)),
        'ul': Style(margin: Margins.only(bottom: _blockGap), padding: HtmlPaddings.only(left: 20.0)),
        'ol': Style(margin: Margins.only(bottom: _blockGap), padding: HtmlPaddings.only(left: 20.0)),
        'li': Style(margin: Margins.only(bottom: 2.0), lineHeight: LineHeight(lineHeightValue)),
        'blockquote': Style(margin: Margins.only(bottom: _blockGap, left: 12.0)),
        'table': Style(margin: Margins.only(bottom: _blockGap)),
        'img': Style(
          width: Width(MediaQuery.of(context).size.width - horizontalPadding * 2),
          margin: Margins.only(bottom: _blockGap),
        ),
      },
    );
  }

  /// 富文本清理: 去掉编辑器产生的空段落 / 连续换行 / 写死的行内间距
  static String clean(String html) {
    if (html.trim().isEmpty) return html;
    String result = html;

    // 1. 剥掉行内样式里的间距声明(后台编辑器常写 margin:30px 0 / line-height:3 / text-indent),
    //    flutter_html 里 style 属性优先级高于我们传的 style map, 不剥就会出现"局部间距特别大"
    result = result.replaceAllMapped(
      RegExp(r'style\s*=\s*"([^"]*)"', caseSensitive: false),
      (Match m) {
        final String value = m.group(1) ?? '';
        final String kept = value
            .split(';')
            .where((String decl) {
              final String key = decl.split(':').first.trim().toLowerCase();
              return !(key.startsWith('margin') || key.startsWith('padding') || key == 'line-height');
            })
            .join(';');
        return kept.trim().isEmpty ? '' : 'style="$kept"';
      },
    );

    // 2. 空块整体删除: <p><br></p> / <div>&nbsp;</div> 在浏览器里不占位,
    //    flutter_html 却照样按块渲染, 跑两遍处理嵌套的空块
    final RegExp blockReg = RegExp(r'<(p|div|section)([^>]*)>([\s\S]*?)</\1>', caseSensitive: false);
    for (int i = 0; i < 2; i++) {
      result = result.replaceAllMapped(blockReg, (Match m) {
        final String inner = (m.group(3) ?? '')
            .replaceAll(RegExp(r'<br\s*/?>|&nbsp;|\s|<span[^>]*>|</span>|<font[^>]*>|</font>', caseSensitive: false), '');
        return inner.isEmpty ? '' : m.group(0)!;
      });
    }

    // 3. 段落首尾多余的 <br> 去掉(否则段前 / 段后各空出一行)
    result = result.replaceAllMapped(
      RegExp(r'<(p|div|section)([^>]*)>\s*(?:<br\s*/?>\s*)+', caseSensitive: false),
      (Match m) => '<${m.group(1)}${m.group(2)}>',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?:\s*<br\s*/?>\s*)+\s*</(p|div|section)>', caseSensitive: false),
      (Match m) => '</${m.group(1)}>',
    );

    // 4. 连续 3 个及以上 <br> 收敛为 2 个(最多留一个空行)
    result = result.replaceAll(RegExp(r'(?:\s*<br\s*/?>\s*){3,}', caseSensitive: false), '<br><br>');
    return result;
  }
}
