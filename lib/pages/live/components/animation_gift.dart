/// 送礼物动效
library;

import 'dart:async';
import 'package:flutter/material.dart';

class AnimationLiveGift extends StatefulWidget {
  const AnimationLiveGift({
    super.key,
    this.giftQueryList,
  });

  final List? giftQueryList;

  @override
  State<AnimationLiveGift> createState() => _AnimationLiveGiftState();
}

class _AnimationLiveGiftState extends State<AnimationLiveGift> with TickerProviderStateMixin {
  late AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300), // 第一个动画持续时间
  );
  late AnimationController controllerMix = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700), // 第二个动画持续时间
  );
  // 动画
  late Animation<Offset> animation = Tween(begin: const Offset(-2.5, 0), end: const Offset(0, 0)).animate(controller);
  late Animation<Offset> animationMix = Tween(begin: const Offset(0, 0), end: const Offset(-2.5, 0)).animate(controllerMix);

  Timer? timer;
  bool animationFirst = true;
  bool idle = true;
  // 送礼物数据列表
  List? giftList;

  @override
  void initState() {
    super.initState();

    giftList = widget.giftQueryList!.toList();

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
    if(giftList!.isNotEmpty) {
      giftList!.removeAt(0);
    }
    idle = true;
    // 执行下一个数据
    runAnimation();
    setState(() {});
    }
  });
}

void runAnimation() {
if(giftList!.isNotEmpty) {
// 空闲状态才能执行，防止添加数据播放状态混淆
if(idle == true) {
  if(controller.isCompleted || controller.isDismissed) {
    setState(() {});
    timer = Timer(const Duration(seconds: 1), () {
      controller.forward();
      debugPrint('第一个动画启动 ${giftList!.length}');
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
  child: giftList!.isNotEmpty ? Container(
  margin: const EdgeInsets.only(top: 7.0),
  child: Row(
  children: [
    Container(
    padding: const EdgeInsets.all(3.0),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(50.0),
  ),
  child: Row(
    children: [
      ClipOval(child: Image.asset('${giftList![0]['avatar']}', height: 35.0,),),
      const SizedBox(width: 3.0,),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${giftList![0]['user']}', style: const TextStyle(color: Colors.white, fontSize: 14.0),),
          Text('送${giftList![0]['label']}', style: const TextStyle(color: Colors.white70, fontSize: 10.0),),
        ],
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
          alignment: Alignment.center,
          child: Image.asset('${giftList![0]['gift']}', height: 30.0,)
        ),
          ],
        ),
      ),
      Text('x${giftList![0]['num']}', style: const TextStyle(color: Colors.white, fontSize: 20.0, fontStyle: FontStyle.italic),),
      ],
    ),
    )
    :
    Container()
    ,
  );
}
}
