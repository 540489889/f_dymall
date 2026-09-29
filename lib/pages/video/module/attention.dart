/// 关注模块
library;

import 'package:flutter/material.dart';

class AttentionModule extends StatefulWidget {
  const AttentionModule({ super.key });

  @override
  State<AttentionModule> createState() => _AttentionModuleState();
}

class _AttentionModuleState extends State<AttentionModule> {
  @override
Widget build(BuildContext context) {
  return Container(
    color: Colors.cyan[200],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5.0,
      children: [
        Image.asset('assets/images/common-empty.png', width: 120.0),
        Text('暂无关注信息~', style: TextStyle(color: Colors.white60, fontSize: 14.0),),
      ],
    ),
    );
  }
}
