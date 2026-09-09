/// 直播红包弹窗
library;

import 'package:flutter/material.dart';

class PopupRedpacket extends StatefulWidget {
  const PopupRedpacket({
    super.key,
});

@override
State<PopupRedpacket> createState() => _PopupRedpacketState();
}

class _PopupRedpacketState extends State<PopupRedpacket> with SingleTickerProviderStateMixin {
@override
Widget build(BuildContext context) {
  return Material(
    type: MaterialType.transparency,
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 10.0,
    children: [
      Text('”哇~被幸运选中啦~“', style: TextStyle(color: Color(0xFFFFFEBD), fontSize: 16.0),),
    Container(
      width: 200.0,
      decoration: const BoxDecoration(
        color: Color(0xFFFF2C55),
      borderRadius: BorderRadius.all(Radius.circular(30.0)),
    ),
  child: Column(
    spacing: 5.0,
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white30,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
      ),
      child: Text('直播惊喜红包', style: TextStyle(color: Colors.white, fontSize: 12.0),),
    ),
    Text.rich(
      TextSpan(
        style: TextStyle(color: Color(0xFFFFFEBD), fontFamily: 'arial'),
          children: [
          TextSpan(text: '5', style: TextStyle(fontSize: 45.0)),
          TextSpan(text: '元', style: TextStyle(fontSize: 16.0))
          ]
        )
      ),
      SizedBox(height: 50.0,),
        FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFFFFFEBD)),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(const Size(120.0, 40.0)),
        ),
        child: const Text('关注并领取', style: TextStyle(color: Color(0xFFF07604), fontSize: 13.0),),
        onPressed: () {},
      ),
      Text('30s后自动关闭', style: const TextStyle(color: Colors.white70, fontSize: 12.0),),
      SizedBox(height: 10.0,),
      ],
      ),
    ),
      GestureDetector(
        child: Container(
        margin: const EdgeInsets.only(top: 10.0),
        height: 30.0,
        width: 30.0,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1.0),
          borderRadius: BorderRadius.circular(50.0),
        ),
        child: const Icon(Icons.close_outlined, color: Colors.white, size: 18.0,),
      ),
      onTap: () {
        Navigator.of(context).pop();
      },
        )
      ],
      )
    );
  }
}
