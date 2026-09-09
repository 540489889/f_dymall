/// 关注模块
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        SvgPicture.asset('assets/images/svg/empty.svg', colorFilter: ColorFilter.mode(Colors.white60, BlendMode.srcIn), width: 40.0,),
        Text('暂无关注信息~', style: TextStyle(color: Colors.white60, fontSize: 14.0),),
      ],
    ),
    );
  }
}
