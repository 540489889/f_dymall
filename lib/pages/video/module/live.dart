/// 直播模块
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controller/auth_store.dart';

class LiveModule extends StatefulWidget {
  const LiveModule({ super.key });

  @override
  State<LiveModule> createState() => _LiveModuleState();
}

class _LiveModuleState extends State<LiveModule> {
  final authStore = AuthStore.to;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.network('https://lf-cdn-tos.bytescm.com/obj/static/webcast/douyin_live/media/empty.bcc258a60fd6da03.png', width: 100.0,),
    SizedBox(height: 10.0,),
    Text('你还没有登录', style: TextStyle(color: Colors.white, fontSize: 17.0),),
    SizedBox(height: 5.0,),
    Text('登录后为您提供更多精品内容~', style: TextStyle(color: Colors.white54, fontSize: 12.0)),
    SizedBox(height: 15.0,),
    FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size(120.0, 42.0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))
        )
      ),
      child: Text('立即登录', style: TextStyle(fontSize: 13.0),),
      onPressed: () {
        // 清除存储信息
        authStore.logout();
          Get.offAllNamed('/login');
        },
        ),
      ],
    ),
    );
  }
}
