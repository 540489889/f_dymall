/// 送礼物动效
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimationLiveGift extends StatefulWidget {
  const AnimationLiveGift({
    super.key,
    this.giftQueryList,
    this.giftMessages,
  });

  // 初始送礼物数据(本地演示房间用)
  final List? giftQueryList;
  // socket gift 推送的送礼队列({user, avatar, label, gift, num}): 有新增时自动追加排队播放
  // * 与 AnimationLiveJoin.joinMessages 同一套消费逻辑: 只取新增部分, 忙时排队
  final ValueListenable<List<Map<String, dynamic>>>? giftMessages;

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
  // socket 送礼队列已消费条数: 只把新增部分追加进播放列表
  int giftConsumed = 0;

  @override
  void initState() {
    super.initState();

    giftList = widget.giftQueryList?.toList() ?? [];

    // socket 送礼消息: 记录已消费长度, 后续推送自动追加播放
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.giftMessages;
    if (queue != null) {
      giftConsumed = queue.value.length;
      queue.addListener(onGiftMessagesChanged);
    }

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

  // socket 送礼消息有新增: 追加进播放列表并启动动画(忙时排队, 播完自动接上)
  void onGiftMessagesChanged() {
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.giftMessages;
    if (queue == null) return;
    final List<Map<String, dynamic>> value = queue.value;
    if (value.length <= giftConsumed) {
      giftConsumed = value.length;
      return;
    }
    final List<Map<String, dynamic>> added = value.sublist(giftConsumed);
    giftConsumed = value.length;
    giftList ??= [];
    giftList!.addAll(added);
    runAnimation();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.giftMessages?.removeListener(onGiftMessagesChanged);
    controller.dispose();
    controllerMix.dispose();
    timer?.cancel();
    super.dispose();
  }

  // 礼物图片: 本地演示数据是 assets 路径, socket 推送是网络地址, 两者都要能显示
  Widget _img(dynamic path, double size, {BoxFit fit = BoxFit.cover}) {
    final String src = '${path ?? ''}'.trim();
    if (src.isEmpty) return SizedBox(width: size, height: size);
    if (src.startsWith('http')) {
      return Image.network(src, height: size, width: size, fit: fit,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size));
    }
    return Image.asset(src, height: size, width: size, fit: fit);
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
      ClipOval(child: _img(giftList![0]['avatar'], 35.0),),
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
          child: _img(giftList![0]['gift'], 30.0)
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
