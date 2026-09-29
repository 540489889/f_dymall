/// 同城附近模块
library;

import 'package:flutter/material.dart';

class LocalModule extends StatefulWidget {
  const LocalModule({ super.key });

  @override
  State<LocalModule> createState() => _LocalModuleState();
}

class _LocalModuleState extends State<LocalModule> {
  @override
  Widget build(BuildContext context) {
  return Container(
    color: Colors.pink[200],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5.0,
      children: [
        Image.asset('assets/images/common-empty.png', width: 120.0),
        Text('暂无同城信息~', style: TextStyle(color: Colors.white60, fontSize: 14.0),),
      ],
    ),
  );
  }
}
