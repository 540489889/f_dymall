library;

import 'package:flutter/material.dart';

/// 表单错误提示: 内联展示在输入框下方 / 表单底部(替代 toast 弹窗)
/// * message 为空时不占位
/// * 颜色默认主色 #FF2C55,可外部覆盖
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key, this.color = const Color(0xFFFF2C55), this.top = 6.0});

  final String? message;
  final Color color;
  final double top;

  @override
  Widget build(BuildContext context) {
    final String? text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: 4.0, top: top),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(Icons.error_outline_rounded, size: 13.0, color: color),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.0, color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// 按消息内容猜测错误归属的输入框字段(服务端返回的错误用)
/// * 判断不了时返回 null -> 落到表单级提示(按钮上方)
/// * 注意顺序: "动态码/短信" 先于 "验证码",避免短信验证码被归到图形验证码
String? guessErrorField(String message) {
  final String text = message.toLowerCase();
  if (text.contains('动态码') || text.contains('短信')) return 'dynacode';
  if (text.contains('验证码') || text.contains('图形')) return 'vercode';
  if (text.contains('手机号') || text.contains('手机')) return 'mobile';
  if (text.contains('确认密码') || text.contains('两次密码')) return 'rePwd';
  if (text.contains('密码')) return 'pwd';
  if (text.contains('账号') || text.contains('用户名')) return 'account';
  return null;
}
