/// 通用空状态组件(暂无数据)
library;

import 'package:flutter/material.dart';

class CommonEmpty extends StatelessWidget {
  /// 空状态文案(为 null 或空时不显示文字)
  final String? text;
  /// 插图宽度
  final double imageWidth;
  /// 文案颜色(深色背景可传白色系,如 Colors.white70)
  final Color textColor;

  const CommonEmpty({
    super.key,
    this.text,
    this.imageWidth = 120.0,
    this.textColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10.0,
      children: <Widget>[
        Image.asset('assets/images/common-empty.png', width: imageWidth),
        if (text != null && text!.isNotEmpty)
          Text(text!, style: TextStyle(color: textColor, fontSize: 13.0)),
      ],
    );
  }
}
