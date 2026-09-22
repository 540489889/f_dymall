/// 直播福袋活动弹窗(参考抖音福袋弹窗)
/// * 与参照项目 H5 livepull.nvue 的福袋弹窗一一对应:
///   未参与 bagPopNo / 已参与 bagPopParticipated / 中奖 bagPopSucc1
///   / 未中奖 bagPopSucc2 / 幸运观众 winnerList
/// * 数据来自 socket activity 下发 + /live/api/shop/luckybag(状态) 与 luckybagWinlist(名单)
/// * 参与/已参与用底部面板, 中奖/未中奖用居中卡片, 共用淡粉底 + 白卡 + 抖音红按钮
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/live.dart';

/// 面板配色(淡粉底 + 白卡 + 抖音红)
abstract class _LuckyBagColor {
  static const Color panel = Color(0xFFFFF5F6);
  static const Color card = Colors.white;
  static const Color red = Color(0xFFFE2C55);
  static const Color redBg = Color(0xFFFFE6EB);
  static const Color green = Color(0xFF07C160);
  static const Color greenBg = Color(0xFFE8F8EE);
  static const Color text = Color(0xFF161823);
  static const Color grey = Color(0xFF999999);
  static const Color line = Color(0xFFE5E5E5);
}

/// 福袋倒计时(mm:ss): 与服务端下发的剩余秒数同步, 每秒本地递减
class LuckyBagCountdown extends StatefulWidget {
  const LuckyBagCountdown({super.key, required this.seconds, this.style});

  /// 剩余秒数(打开弹窗时的快照, 取自 activity / luckybag 下发的 time)
  final int seconds;
  final TextStyle? style;

  @override
  State<LuckyBagCountdown> createState() => _LuckyBagCountdownState();
}

class _LuckyBagCountdownState extends State<LuckyBagCountdown> {
  late int left = widget.seconds;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start() {
    timer?.cancel();
    if (left <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        left = left > 0 ? left - 1 : 0;
      });
      if (left <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int second = left < 0 ? 0 : left;
    final String minute = '${second ~/ 60}'.padLeft(2, '0');
    final String rest = '${second % 60}'.padLeft(2, '0');
    return Text('$minute:$rest', style: widget.style ?? const TextStyle(color: _LuckyBagColor.grey, fontSize: 12.0));
  }
}

/// 福袋参与弹窗(未参与): 底部面板, 点遮罩关闭
class PopupLuckyBagJoin extends StatefulWidget {
  const PopupLuckyBagJoin({
    super.key,
    required this.item,
    this.closeTick,
    this.onJoin,
  });

  /// 活动数据(LiveApi.activityItem 归一化结果)
  final Map<String, dynamic> item;
  /// 参与成功(服务端 luckybag_join)时自增, 弹窗收到后自行关闭(不盲目退栈)
  final ValueNotifier<int>? closeTick;
  /// 去发表评论: 由页面打开评论输入框并预填参与口令
  final VoidCallback? onJoin;

  @override
  State<PopupLuckyBagJoin> createState() => _PopupLuckyBagJoinState();
}

class _PopupLuckyBagJoinState extends State<PopupLuckyBagJoin> {
  @override
  void initState() {
    super.initState();
    widget.closeTick?.addListener(_close);
  }

  @override
  void dispose() {
    widget.closeTick?.removeListener(_close);
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> item = widget.item;
    final String title = '${item['title'] ?? ''}'.trim();
    final int joinNum = LiveApi.intOf(item['joinNum']);

    return _LuckyBagSheet(
      onClose: _close,
      children: [
        _SheetHeader(
          title: title.isEmpty ? '福袋' : title,
          subtitle: joinNum > 0 ? '$joinNum人已参加' : '',
          onClose: _close,
        ),
        _CountdownAwardCard(item: item),
        _JoinConditionCard(item: item, done: false),
        _SheetButton(
          text: '去发表评论',
          onTap: () {
            _close();
            widget.onJoin?.call();
          },
        ),
      ],
    );
  }
}

/// 福袋结果弹窗: 已参与(底部面板) / 中奖 / 未中奖(居中卡片)
class PopupLuckyBagResult extends StatefulWidget {
  const PopupLuckyBagResult({
    super.key,
    required this.status,
    required this.item,
    this.awardNum,
    this.awardTypeName,
    this.onLookWinner,
    this.closeTick,
  });

  /// joined 已参与 / award 已中奖 / noaward 未中奖(由页面按接口 type 映射)
  final String status;
  /// 活动数据(展示奖励/参与人数/倒计时)
  final Map<String, dynamic> item;
  /// 中奖数量与单位: 接口开奖结果(end-award 的 award)优先, 没有再回落到活动数据
  final String? awardNum;
  final String? awardTypeName;
  /// 查看幸运观众
  final VoidCallback? onLookWinner;
  /// 开奖推送(luckybag_end)时自增: 已参与弹窗收到后自动关闭(不再需要用户手动关)
  final ValueNotifier<int>? closeTick;

  @override
  State<PopupLuckyBagResult> createState() => _PopupLuckyBagResultState();
}

class _PopupLuckyBagResultState extends State<PopupLuckyBagResult> {
  @override
  void initState() {
    super.initState();
    // 只有「已参与」是等待开奖的常驻弹窗, 开奖时自动收掉; 结果弹窗本身不监听
    if (widget.status == 'joined') widget.closeTick?.addListener(_close);
  }

  @override
  void dispose() {
    if (widget.status == 'joined') widget.closeTick?.removeListener(_close);
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool awarded = widget.status == 'award';
    final bool joined = widget.status == 'joined';
    final Map<String, dynamic> item = widget.item;
    final int joinNum = LiveApi.intOf(item['joinNum']);
    final String num = (widget.awardNum ?? '').trim().isEmpty ? '${item['awardNum'] ?? ''}'.trim() : widget.awardNum!.trim();
    final String name =
        (widget.awardTypeName ?? '').trim().isEmpty ? '${item['awardTypeName'] ?? ''}'.trim() : widget.awardTypeName!.trim();

    final String msg = '${item['msg'] ?? ''}'.trim();
    final String title = joined ? '已参与福袋' : (awarded ? '恭喜中奖！' : '没抽中福袋');
    // 已参与: 接口 msg 优先(如"您已参与本次福袋活动，请勿离开直播间"), 没有才用本地兜底文案
    final String subTitle = joined
        ? (msg.isEmpty ? '开奖后将自动通知你' : msg)
        : (awarded ? '运气爆棚，福气满满' : '送你一个好运气~');
    // 开奖结果只留情绪文案; 已参与(等开奖)才带参与人数; 接口 msg 已把话说全时也不再追加
    final String subtitle = joined && msg.isEmpty && joinNum > 0 ? '$subTitle · $joinNum人已参加' : subTitle;

    final List<Widget> children = <Widget>[
      // 开奖结果: 顶部给个福袋图标, 一眼看出是福袋开奖
      // * 中奖时图标跟着奖励文字排(见 _AwardWinCard), 这里只给未中奖用, 免得一张卡上出现两个福袋
      if (!joined && !awarded) const _LuckyBagIcon(),
      _SheetHeader(
        title: title,
        subtitle: subtitle,
        onClose: _close,
        // 居中卡片里标题跟着居中(底部面板保持左对齐)
        center: !joined,
      ),
      // 中奖: 突出展示"获得 X 单位"; 未中奖: 展示本场福袋奖励; 已参与: 倒计时 + 奖励
      if (awarded)
        _AwardWinCard(num: num, name: name, bagNum: '${item['bagNum'] ?? '1'}'.trim())
      else
        _CountdownAwardCard(item: item, awardNum: num, awardTypeName: name, showCountdown: joined),
      // 已参与: 展示参与条件达成情况; 开奖后(中奖/未中奖)不再展示
      if (joined) _JoinConditionCard(item: item, done: true),
      if (!joined && widget.onLookWinner != null) _WinnerEntry(onTap: widget.onLookWinner!, center: true),
      _SheetButton(
        text: joined ? '已参与' : (awarded ? '开心收下' : '知道啦'),
        onTap: joined ? null : _close,
      ),
    ];

    // 已参与: 底部面板; 中奖/未中奖: 居中卡片
    if (joined) return _LuckyBagSheet(onClose: _close, children: children);
    return _LuckyBagDialog(onClose: _close, children: children);
  }
}

// ==================== 面板与私有组件 ====================

/// 福袋底部面板外壳: 半透明遮罩 + 淡粉圆角面板 + 拖动条, 点遮罩关闭
class _LuckyBagSheet extends StatelessWidget {
  const _LuckyBagSheet({required this.onClose, required this.children});

  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          alignment: Alignment.bottomCenter,
          color: Colors.black.withAlpha(100),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: _LuckyBagColor.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36.0,
                        height: 4.0,
                        margin: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                        decoration: BoxDecoration(
                          color: _LuckyBagColor.line,
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 20.0,
                        children: children,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 福袋居中弹窗外壳: 半透明遮罩 + 淡粉圆角卡片, 点遮罩关闭
class _LuckyBagDialog extends StatelessWidget {
  const _LuckyBagDialog({required this.onClose, required this.children});

  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          alignment: Alignment.center,
          color: Colors.black.withAlpha(100),
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 340.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: _LuckyBagColor.panel,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16.0,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板标题: 标题 + 右上关闭 + 说明文案([center] 为居中卡片用: 标题与说明居中)
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.center = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 左侧留出与关闭图标等宽的空位, 让标题在视觉上真正居中
            if (center) const SizedBox(width: 20.0),
            Expanded(
              child: Text(
                title,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: _LuckyBagColor.text,
                  // 居中卡片是"结果展示", 标题给大一点(底部面板保持 18)
                  fontSize: center ? 21.0 : 18.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 20.0, color: _LuckyBagColor.grey),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4.0),
          Text(
            subtitle,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: _LuckyBagColor.grey, fontSize: 13.0),
          ),
        ],
      ],
    );
  }
}

/// 福袋图标(与左上角活动入口同一张图): 淡红光晕圆底, 用于开奖结果弹窗顶部
class _LuckyBagIcon extends StatelessWidget {
  const _LuckyBagIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 84.0,
        height: 84.0,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [_LuckyBagColor.redBg, Color(0x00FFE6EB)],
          ),
        ),
        child: Image.asset(
          'assets/images/icon-fudai.png',
          width: 64.0,
          height: 64.0,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 中奖奖励卡: 突出展示"恭喜获得 X 单位"(拿不到中奖明细时回落成本场福袋数量)
class _AwardWinCard extends StatelessWidget {
  const _AwardWinCard({required this.num, required this.name, required this.bagNum});

  final String num;
  final String name;
  final String bagNum;

  @override
  Widget build(BuildContext context) {
    // 数量与单位分开渲染: 单位单独拿小一号字体(拿不到中奖明细时主体回落成福袋数量)
    final String unit = name.isEmpty ? '' : name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        // 上下淡红渐变 + 淡红描边: 比纯白卡片更像"中奖喜报"
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1F4), Colors.white],
        ),
        border: Border.all(color: _LuckyBagColor.redBg),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Column(
        children: [
          const Text('恭喜获得', style: TextStyle(color: _LuckyBagColor.grey, fontSize: 12.0)),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 福袋图放在奖励文字左侧(中奖弹窗顶部不再单独放大图, 免得重复)
              Image.asset(
                'assets/images/icon-fudai.png',
                width: 28.0,
                height: 28.0,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6.0),
              // 数量与单位分开排: 数量更大, 单位小一号, 避免"10积分"一坨
              Text(
                num.isEmpty ? '$bagNum个福袋' : num,
                style: const TextStyle(
                  color: _LuckyBagColor.red,
                  fontSize: 30.0,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (num.isNotEmpty && unit.isNotEmpty) ...[
                const SizedBox(width: 4.0),
                Text(
                  unit,
                  style: const TextStyle(
                    color: _LuckyBagColor.red,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

        ],
      ),
    );
  }
}

/// 倒计时 + 奖励白卡(开奖结果由 [awardNum]/[awardTypeName] 覆盖活动数据)
/// * [showCountdown] 为 false 时只展示奖励信息(中奖/未中奖弹窗不再显示倒计时)
class _CountdownAwardCard extends StatelessWidget {
  const _CountdownAwardCard({
    required this.item,
    this.awardNum,
    this.awardTypeName,
    this.showCountdown = true,
  });

  final Map<String, dynamic> item;
  final String? awardNum;
  final String? awardTypeName;
  final bool showCountdown;

  @override
  Widget build(BuildContext context) {
    final String num = (awardNum ?? '').trim().isEmpty ? '${item['awardNum'] ?? ''}'.trim() : awardNum!.trim();
    final String name = (awardTypeName ?? '').trim().isEmpty ? '${item['awardTypeName'] ?? ''}'.trim() : awardTypeName!.trim();
    final String bagNum = '${item['bagNum'] ?? '1'}'.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: _LuckyBagColor.card,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          if (showCountdown) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LuckyBagCountdown(
                    seconds: LiveApi.intOf(item['time']),
                    style: const TextStyle(
                      color: _LuckyBagColor.red,
                      // 倒计时与右侧奖励文字整体收小一号, 面板里不再那么抢视线
                      fontSize: 28.0,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'arial',
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  const Text('倒计时', style: TextStyle(color: _LuckyBagColor.grey, fontSize: 12.0)),
                ],
              ),
            ),
            Container(width: 1.0, height: 40.0, color: _LuckyBagColor.line),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: showCountdown ? 20.0 : 0.0),
              child: Column(
                crossAxisAlignment: showCountdown ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(
                    num.isEmpty ? '' : '总$num$name',
                    style: const TextStyle(
                      color: _LuckyBagColor.text,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text('$bagNum个福袋', style: const TextStyle(color: _LuckyBagColor.grey, fontSize: 12.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 参与条件白卡: 左侧口令, 右侧 未达成 / 已达成 标签
class _JoinConditionCard extends StatelessWidget {
  const _JoinConditionCard({required this.item, required this.done});

  final Map<String, dynamic> item;
  /// 是否已完成参与条件(未参与弹窗 false / 已参与弹窗 true)
  final bool done;

  @override
  Widget build(BuildContext context) {
    final String joinContent = '${item['joinContent'] ?? ''}'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '参与条件',
          style: TextStyle(color: _LuckyBagColor.text, fontSize: 16.0, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: _LuckyBagColor.card,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  joinContent.isEmpty ? '发送任意评论即可参与' : '发送评论：$joinContent',
                  style: const TextStyle(color: _LuckyBagColor.text, fontSize: 14.0),
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: done ? _LuckyBagColor.greenBg : _LuckyBagColor.redBg,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  done ? '已达成' : '未达成',
                  style: TextStyle(
                    color: done ? _LuckyBagColor.green : _LuckyBagColor.red,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 查看幸运观众入口([center] 为居中卡片用: 红色文字链接, 不再是白卡行)
class _WinnerEntry extends StatelessWidget {
  const _WinnerEntry({required this.onTap, this.center = false});

  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    if (center) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('查看幸运观众', style: TextStyle(color: _LuckyBagColor.red, fontSize: 14.0)),
              Icon(Icons.chevron_right, size: 18.0, color: _LuckyBagColor.red),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: _LuckyBagColor.card,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Row(
          children: [
            Text('查看幸运观众', style: TextStyle(color: _LuckyBagColor.text, fontSize: 14.0)),
            Spacer(),
            Icon(Icons.chevron_right, size: 18.0, color: _LuckyBagColor.grey),
          ],
        ),
      ),
    );
  }
}

/// 面板按钮: 红底主操作, onTap 为空时灰底不可点
class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? _LuckyBagColor.red : _LuckyBagColor.line,
          borderRadius: BorderRadius.circular(23.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: enabled ? Colors.white : _LuckyBagColor.grey,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
