/// 底部评论框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PopupReply extends StatefulWidget {
const PopupReply({
  super.key,
  this.onChanged
});

// 输入框值改变
final ValueChanged? onChanged;

@override
State<PopupReply> createState() => _PopupReplyState();
}

class _PopupReplyState extends State<PopupReply> {
final TextEditingController controller = TextEditingController();

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  super.dispose();
  controller.dispose();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Column(
      children: [
      Expanded(
        child: GestureDetector(
      child: Container(
        color: Colors.transparent,
      ),
        onTap: () {
          Get.back();
        },
      ),
    ),
    Container(
      color: Colors.white,
      padding: EdgeInsets.all(10.0),
      child: Row(
      children: [
    Expanded(
    child: Container(
    margin: EdgeInsets.only(right: 10.0),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(20.0),
    ),
    child: TextField(
      decoration: InputDecoration(
        hintText: '说点什么...',
        isDense: true,
      hoverColor: Colors.transparent,
        contentPadding: EdgeInsets.all(10.0),
        border: OutlineInputBorder(borderSide: BorderSide.none),
      ),
      style: TextStyle(fontSize: 14.0,),
      textInputAction: TextInputAction.send,
      autofocus: true,
      maxLines: null,
        controller: controller,
        cursorColor: Color(0xFFFF2C55),
        onEditingComplete: () {
            widget.onChanged!(controller.text);
            Get.back();
          },
          onChanged: (value) {},
            ),
          ),
        ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(Size(60.0, 40.0)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0))
                )
              ),
              onPressed: () {
                widget.onChanged!(controller.text);
                Get.back();
              },
              child: Text('发送',),
            ),
          ],
        ),
        ),
      ],
      ),
    ),
    );
  }
}
