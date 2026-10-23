/// 全屏礼物动效(socket gift 的 full_screen = 1)
/// * 播 gift_big_image(gif) + 送礼人昵称, 依次排队播放, 不叠加
/// * 与 AnimationLiveGift(左上角小横幅) 共用同一个 giftMessages 队列:
///   全屏礼物两者都播, 普通礼物只播小横幅
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimationFullScreenGift extends StatefulWidget {
  const AnimationFullScreenGift({
    super.key,
    this.giftMessages,
    this.holdDuration = defaultHoldDuration,
  });

  /// 默认停留时长: gif 入场后播多久再退场
  /// * 一次完整周期 = 入场 350ms + 停留 + 退场 350ms
  static const Duration defaultHoldDuration = Duration(seconds: 2);
  /// 单条停留时长的下限/上限: 防止后台配了 0(闪一下就没了)或 600(把屏幕占死)
  static const Duration _minHold = Duration(milliseconds: 500);
  static const Duration _maxHold = Duration(seconds: 15);

  // socket gift 推送的送礼队列(与 AnimationLiveGift 同一个)
  // * 只消费 full_screen == 1 且带 gift_big_image 的条目
  final ValueListenable<List<Map<String, dynamic>>>? giftMessages;

  /// 停留时长(默认 2s)
  /// * 单条礼物可在 socket 报文里带 `duration`(单位: 秒) 覆盖, 比如大件播久一点
  final Duration holdDuration;

  @override
  State<AnimationFullScreenGift> createState() => _AnimationFullScreenGiftState();
}

class _AnimationFullScreenGiftState extends State<AnimationFullScreenGift>
    with SingleTickerProviderStateMixin {
  // 入场时长
  static const Duration _inDuration = Duration(milliseconds: 350);

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: _inDuration,
  );
  late final Animation<double> anim = CurvedAnimation(parent: controller, curve: Curves.easeOutBack);

  // 队列已消费长度
  int consumed = 0;
  // 排队中的全屏礼物
  final List<Map<String, dynamic>> pending = <Map<String, dynamic>>[];
  // 正在播放的那条
  Map<String, dynamic>? current;
  Timer? holdTimer;

  @override
  void initState() {
    super.initState();
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.giftMessages;
    if (queue != null) {
      consumed = queue.value.length;
      queue.addListener(onChanged);
    }
    controller.addStatusListener(onStatus);
  }

  void onChanged() {
    final ValueListenable<List<Map<String, dynamic>>>? queue = widget.giftMessages;
    if (queue == null) return;
    final List<Map<String, dynamic>> value = queue.value;
    if (value.length <= consumed) {
      consumed = value.length;
      return;
    }
    // 只挑全屏礼物: 没有 big_image 的也跳过(没图可播)
    for (final Map<String, dynamic> item in value.sublist(consumed)) {
      if (item['fullScreen'] == true && '${item['bigImage'] ?? ''}'.isNotEmpty) {
        pending.add(item);
      }
    }
    consumed = value.length;
    playNext();
  }

  void playNext() {
    // 上一条还没退场时先排队, 不叠加播放
    if (current != null || pending.isEmpty) return;
    setState(() => current = pending.removeAt(0));
    controller.forward();
  }

  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      holdTimer?.cancel();
      holdTimer = Timer(_holdFor(current), () {
        if (mounted) controller.reverse();
      });
    } else if (status == AnimationStatus.dismissed) {
      if (!mounted) return;
      setState(() => current = null);
      playNext();
    }
  }

  /// 当前这条的停留时长
  /// * 优先用 socket 报文里的 duration(秒): 大件(嘉年华/私人飞机)可以比小礼物播得久
  /// * 没带就用组件默认值; 两者都夹在 [_minHold, _maxHold] 里, 避免配置离谱把屏幕占死
  Duration _holdFor(Map<String, dynamic>? item) {
    if (item != null) {
      final dynamic raw = item['duration'] ?? item['play_time'] ?? item['seconds'];
      final double? sec = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (sec != null && sec > 0) {
        return Duration(
          milliseconds: (sec * 1000).clamp(
            AnimationFullScreenGift._minHold.inMilliseconds.toDouble(),
            AnimationFullScreenGift._maxHold.inMilliseconds.toDouble(),
          ).toInt(),
        );
      }
    }
    return widget.holdDuration;
  }

  @override
  void dispose() {
    widget.giftMessages?.removeListener(onChanged);
    holdTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? item = current;
    // 没有全屏礼物时什么都不占(不拦截手势)
    if (item == null) return const SizedBox.shrink();

    return Positioned.fill(
      // 动效期间不吃手势: 底层直播间的点击(点赞/清屏)照常能用
      child: IgnorePointer(
        child: FadeTransition(
          opacity: anim,
          child: Center(
            // 只播 gif, 不放送礼文案: 文案会盖住画面, 且左上角小横幅已经在播同一条信息
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
              child: Image.network(
                '${item['bigImage']}',
                width: 260.0,
                height: 260.0,
                fit: BoxFit.contain,
                // 加载失败/地址为空: 留空即可, 不影响动效
                errorBuilder: (_, __, ___) => const SizedBox(width: 260.0, height: 260.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
