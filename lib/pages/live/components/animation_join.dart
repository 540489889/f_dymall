/// 加入直播间动效
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimationLiveJoin extends StatefulWidget {
  const AnimationLiveJoin({
    super.key,
    this.joinQueryList,
    this.joinMessages,
  });

  // 初始进场数据(本地演示房间用)
  final List? joinQueryList;
  // socket join 推送的进场队列({name, msg}): 有新增时自动追加排队播放
  final ValueListenable<List<Map<String, dynamic>>>? joinMessages;

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
  // socket 进场队列已消费条数: 只把新增部分追加进播放列表
  int joinConsumed = 0;

  @override
  void initState() {
    super.initState();

    joinList = widget.joinQueryList?.toList() ?? [];
    // socket 进场消息: 记录已消费长度, 后续推送自动追加播放
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.joinMessages;
    if (queue != null) {
      joinConsumed = queue.value.length;
      queue.addListener(onJoinMessagesChanged);
    }

    runAnimation();
    // 监听第一个动画
    animation.addListener(() {
      if (animation.status == AnimationStatus.forward) {
        idle = false;
        setState(() {});
      } else if (animation.status == AnimationStatus.completed) {
        animationFirst = false;
        if (controllerMix.isCompleted || controllerMix.isDismissed) {
          timer = Timer(const Duration(seconds: 2), () {
            controllerMix.forward();
          });
        }
        setState(() {});
      }
    });
    // 监听第二个动画
    animationMix.addListener(() {
      if (animationMix.status == AnimationStatus.forward) {
        setState(() {});
      } else if (animationMix.status == AnimationStatus.completed) {
        animationFirst = true;
        controller.reset();
        controllerMix.reset();
        // 移除第一个数据
        if (joinList!.isNotEmpty) {
          joinList!.removeAt(0);
        }
        idle = true;
        // 执行下一个数据
        runAnimation();
        setState(() {});
      }
    });
  }

  // socket 进场消息有新增: 追加进播放列表并启动动画(忙时排队, 播完自动接上)
  void onJoinMessagesChanged() {
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.joinMessages;
    if (queue == null) return;
    final List<Map<String, dynamic>> value = queue.value;
    if (value.length <= joinConsumed) {
      joinConsumed = value.length;
      return;
    }
    final List<Map<String, dynamic>> added = value.sublist(joinConsumed);
    joinConsumed = value.length;
    joinList ??= [];
    joinList!.addAll(added);
    runAnimation();
    if (mounted) setState(() {});
  }

  void runAnimation() {
    if (joinList!.isNotEmpty) {
      // 空闲状态才能执行，防止添加数据播放状态混淆
      if (idle == true) {
        if (controller.isCompleted || controller.isDismissed) {
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
    widget.joinMessages?.removeListener(onJoinMessagesChanged);
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
        padding: const EdgeInsets.symmetric(horizontal: 7.0),
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
        // 进场文案沿用原样式, 只更换数据来源: socket join 队列 / 本地演示数据
        child: joinList!.isNotEmpty ?
          Text('欢迎 ${joinList![0]['name']} 加入了直播间', style: const TextStyle(color: Colors.white, fontSize: 14.0,),)
          :
          Container(),
      ),
    );
  }
}
