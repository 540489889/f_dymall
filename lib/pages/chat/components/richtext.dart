/// 富文本emoj表情展示
/// 通过实现[Text.rich]展示文本、emoji、自定义表情、URL等
library;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class RichTextUtil {
  static Text getRichText(String text, {Color color = Colors.black}) {
    List<InlineSpan> textSpans= [];
  // 网址正则
  String urlExpString = r"(http|ftp|https)://([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?";
  // 表情正则
  String emojExpString = r"\[.{1,4}?\]";
  RegExp reg = RegExp('$urlExpString|$emojExpString');

  if(reg.hasMatch(text)) {
    Iterable<RegExpMatch> matches = reg.allMatches(text);

    int index = 0;
  int count = 0;
  for(var match in matches) {
    count++;
    String c = text.substring(match.start, match.end);
    // 匹配在首位
    if(index == match.start) {
      index = match.end;
    }
    // 匹配不在首位
    else if(index < match.start) {
    String leftStr = text.substring(index, match.start);
    index = match.end;
    textSpans.add(
      TextSpan(
        text: getSpaceText(leftStr),
      )
    );
  }

  // 匹配到表情...
    if(RegExp(emojExpString).hasMatch(c)) {
    // ...
  }
  // 匹配到网址
  else if(RegExp(urlExpString).hasMatch(c)) {
    textSpans.add(
      TextSpan(
      text: getSpaceText(c),
      style: const TextStyle(color: Colors.blue,),
      recognizer: TapGestureRecognizer()
      ..onTap = () async {
        // await launchUrl(Uri.parse('https://flutter.cn'));
        await launchUrl(Uri.parse(c));
      },
    )
    );
    }

    // 是否最后一个表情，且后面是否有字符串
    if(matches.length == count && text.length > index) {
    String rightStr = text.substring(index, text.length);
    textSpans.add(
      TextSpan(
        text: getSpaceText(rightStr),
      )
    );
    }
  }
}else {
  textSpans.add(
    TextSpan(
      text: getSpaceText(text),
    )
  );
}
// 生成富文本
return Text.rich(
  TextSpan(
      style: TextStyle(color: color),
      children: textSpans
    ),
  );
}

// 内容
static String getSpaceText(String text) {
  if(text.isEmpty) return text;
  String spaceWord = '';
  for(var elem in text.runes) {
    spaceWord += String.fromCharCode(elem);
    spaceWord += '\u200B';
  }
  return spaceWord;
  }
}
