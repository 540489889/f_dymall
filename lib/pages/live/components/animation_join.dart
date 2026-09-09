/// 加入直播间动效
library;

import 'dart:async';
import 'package:flutter/material.dart';

class AnimationLiveJoin extends StatefulWidget {
  const AnimationLiveJoin({
  super.key,
  this.joinQueryList,
});

final List? joinQueryList;

@override
State<AnimationLiveJoin> createState() => _AnimationLiveJoinState();
}

class _AnimationLiveJoinState extends State<AnimationLiveJoin> with TickerProviderStateMixin {
late AnimationController controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 500), // 第一个动画持续时间
);
late AnimationController controllerMix = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1000), // 第二个动画持续时间
);
// 动画
late Animation<Offset> animation = Tween(begin: const Offset(2.5, 0), end: const Offset(0, 0)).animate(controller);
late Animation<Offset> animationMix = Tween(begin: const Offset(0, 0), end: const Offset(-2.5, 0)).animate(controllerMix);

Timer? timer;
// 是否第一个动画
bool animationFirst = true;
// 是否空闲
bool idle = true;
// 加入直播间数据列表
List? joinList;

  @override
  void initState() {
  super.initState();

  joinList = widget.joinQueryList!.toList();

  runAnimation();
  // 监听第一个动画
  animation.addListener(() {
    if(animation.status == AnimationStatus.forward) {
      idle = false;
      setState(() {});
    }else if(animation.status == AnimationStatus.completed) {
      animationFirst = false;
      if(controllerMix.isCompleted || controllerMix.isDismissed) {
        timer = Timer(const Duration(seconds: 2), () {
          controllerMix.forward();
        });
      }
      setState(() {});
      }
    });
    // 监听第二个动画
    animationMix.addListener(() {
      if(animationMix.status == AnimationStatus.forward) {
      setState(() {});
    }else if(animationMix.status == AnimationStatus.completed) {
      animationFirst = true;
      controller.reset();
      controllerMix.reset();
      // 移除第一个数据
      if(joinList!.isNotEmpty) {
        joinList!.removeAt(0);
      }
      idle = true;
      // 执行下一个数据
      runAnimation();
      setState(() {});
    }
  });
}

void runAnimation() {
  if(joinList!.isNotEmpty) {
  // 空闲状态才能执行，防止添加数据播放状态混淆
  if(idle == true) {
    if(controller.isCompleted || controller.isDismissed) {
      setState(() {});
      timer = Timer(Duration.zero, () {
        controller.forward();
      });
      }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
  controllerMix.dispose();
  timer?.cancel();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return SlideTransition(
    position: animationFirst ? animation : animationMix,
  child: Container(
    alignment: Alignment.centerLeft,
    margin: const EdgeInsets.only(top: 7.0),
    padding: const EdgeInsets.symmetric(horizontal: 7.0,),
    height: 23.0,
    width: 250,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF9901FF), Colors.transparent
        ],
      ),
      borderRadius: BorderRadius.horizontal(left: Radius.circular(20.0)),
    ),
    child: joinList!.isNotEmpty ? 
      Text('欢迎 ${joinList![0]['name']} 加入了直播间', style: const TextStyle(color: Colors.white, fontSize: 14.0,),)
      :
      Container()
      ,
    ),
    );
  }
}
