/// 直播签到 / 集章活动弹窗(对应H5 livepull.nvue)
/// * 签到: signDownPop(圆环倒计时 + 立即签到) → /live/api/shop/sign(查询) 与 signJoin(签到)
/// * 集章: stampDownPop(倒计时 + 收集奖章) → /live/api/shop/sendStampLog
///   集章成功 stampSuccPop / 集章信息 activeInfoPop(title + msg + imgs + award)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../api/live.dart';

/// 活动弹窗配色(与福袋弹窗一致: 淡粉底 + 抖音红, 见 popup_luckybag.dart)
abstract class _ActivityColor {
  static const Color panel = Color(0xFFFFF5F6);
  static const Color red = Color(0xFFFE2C55);
  static const Color text = Color(0xFF161823);
  static const Color grey = Color(0xFF999999);
  static const Color line = Color(0xFFE5E5E5);
}

/// 活动圆环倒计时(主色调, 与H5 luanqing-progressbar 一致): 中间显示 mm:ss
class ActivityRing extends StatefulWidget {
  const ActivityRing({super.key, required this.seconds, this.size = 150.0, this.lineWidth = 8.0});

  /// 剩余秒数(作为总数, 圆环按剩余比例收缩)
  final int seconds;
  final double size;
  final double lineWidth;

  @override
  State<ActivityRing> createState() => _ActivityRingState();
}

class _ActivityRingState extends State<ActivityRing> {
  late int left = widget.seconds;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant ActivityRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部刷新了剩余秒数(重新查询活动状态): 以新值为准重新起跑
    if (widget.seconds != oldWidget.seconds) {
      left = widget.seconds;
      _start();
    }
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
    final double total = widget.seconds <= 0 ? 1.0 : widget.seconds.toDouble();
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: CustomPaint(
        painter: _RingPainter(progress: second / total, lineWidth: widget.lineWidth),
        child: Center(
          child: Text(
            '$minute:$rest',
            style: const TextStyle(color: _ActivityColor.red, fontSize: 20.0, fontFamily: 'arial'),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.lineWidth});

  /// 剩余比例(0~1)
  final double progress;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - lineWidth) / 2;
    final Paint base = Paint()
      ..color = _ActivityColor.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    final Paint active = Paint()
      ..color = _ActivityColor.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    // 从 12 点方向开始, 按剩余比例画弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.lineWidth != lineWidth;
}

/// 签到弹窗(居中): 未签到(圆环倒计时+立即签到) / 已签到 / 签到成功 / 已结束
class PopupSign extends StatefulWidget {
  const PopupSign({super.key, required this.item});

  /// 签到活动数据(LiveApi.activityItem 归一化结果 + LiveApi.signDetail 的 title/notice/time)
  final Map<String, dynamic> item;

  @override
  State<PopupSign> createState() => _PopupSignState();
}

class _PopupSignState extends State<PopupSign> {
  // 当前状态: ing-nojoin 未签到 / ing-join 已签到 / award 签到成功 / end-* 已结束
  late String status = '${widget.item['status'] ?? widget.item['type'] ?? ''}'.trim();
  // 剩余秒数: 圆环跟着走, 归零后重新查一次状态(与H5 onFinishSign → showSignDetail 一致)
  late int left = LiveApi.intOf(widget.item['time']);
  // 圆环的秒数(只在重新查询状态后更新, 避免和圆环内部倒计时互相干扰)
  late int ringSeconds = left;
  bool loading = false;
  Timer? timer;

  String get gameId => '${widget.item['gameId'] ?? ''}';
  String get title => '${widget.item['title'] ?? ''}'.trim();
  String get notice => '${widget.item['notice'] ?? widget.item['msg'] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // 倒计时: 归零后自动刷新状态(活动可能刚刚结束/开奖)
  void _startCountdown() {
    timer?.cancel();
    if (left <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        left = left > 0 ? left - 1 : 0;
      });
      if (left <= 0) {
        t.cancel();
        _refresh();
      }
    });
  }

  // 重新查询签到状态(倒计时结束 / 签到后兜底刷新)
  Future<void> _refresh() async {
    final Map<String, dynamic>? res = await LiveApi.signDetail(gameId);
    if (!mounted || res == null) return;
    setState(() {
      status = '${res['type'] ?? status}'.trim();
      left = LiveApi.intOf(res['time'] ?? left);
      ringSeconds = left;
    });
    _startCountdown();
  }

  // 立即签到: 与H5 handleSignJoin 一致, 成功用返回的 type 更新状态
  Future<void> _join() async {
    if (loading) return;
    setState(() {
      loading = true;
    });
    final Map<String, dynamic>? res = await LiveApi.signJoin(gameId);
    if (!mounted) return;
    final String type = '${res?['type'] ?? ''}'.trim();
    setState(() {
      loading = false;
      if (type.isNotEmpty) status = type;
      error = type.isEmpty ? '签到失败，稍后再试' : '';
    });
  }

  String error = '';

  bool get ended => status.startsWith('end');

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280.0,
            padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 20.0),
            decoration: BoxDecoration(
              color: _ActivityColor.panel,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Text(
                      title.isEmpty ? '直播签到' : title,
                      style: const TextStyle(color: _ActivityColor.text, fontSize: 16.0, fontWeight: FontWeight.w600),
                    ),
                    if (notice.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(notice, textAlign: TextAlign.center, style: const TextStyle(color: _ActivityColor.grey, fontSize: 12.0)),
                    ],
                    const SizedBox(height: 14.0),
                    if (status == 'ing-nojoin' && left > 0)
                      // 未签到: 圆环倒计时
                      ActivityRing(seconds: ringSeconds <= 0 ? 1 : ringSeconds, size: 140.0)
                    else
                      // 已签到/签到成功/已结束: 图标(图标颜色随状态变淡)
                      Opacity(
                        opacity: ended ? 0.45 : 1.0,
                        child: Image.asset('assets/images/sign-icon.png', width: 100.0),
                      ),
                    const SizedBox(height: 16.0),
                    FilledButton(
                      style: ButtonStyle(
                        // 不可点(已签到/已结束): 灰底, 与福袋弹窗的禁用按钮一致
                        backgroundColor: WidgetStateProperty.all(
                          status == 'ing-nojoin' ? _ActivityColor.red : _ActivityColor.grey,
                        ),
                        minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                        ),
                      ),
                      onPressed: status == 'ing-nojoin' && !loading ? _join : null,
                      child: Text(
                        status == 'ing-nojoin'
                            ? (loading ? '签到中…' : '立即签到')
                            : (status == 'award' ? '签到成功' : (ended ? '已结束' : '已签到')),
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Text(error, style: const TextStyle(color: _ActivityColor.red, fontSize: 11.0)),
                    ],
                  ],
                ),
                // 关闭
                Positioned(
                  right: 0.0,
                  top: 0.0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _ActivityColor.grey, size: 20.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 集章弹窗(居中): 倒计时 + 「收集奖章」, 收集成功后原地切成「集章完成」
class PopupStamp extends StatefulWidget {
  const PopupStamp({super.key, required this.item, this.roomId = ''});

  /// 集章活动数据(activityItem 归一化结果, socket stamp_sign 的 data)
  final Map<String, dynamic> item;
  /// 直播间 sn(sendStampLog 需要)
  final String roomId;

  @override
  State<PopupStamp> createState() => _PopupStampState();
}

class _PopupStampState extends State<PopupStamp> {
  bool loading = false;
  // 收集成功: 弹窗内容切换成「集章完成」(与H5 stampDownPop → stampSuccPop 等效)
  bool done = false;
  String error = '';

  String get stampId => '${widget.item['gameId'] ?? ''}';
  String get title => '${widget.item['title'] ?? ''}'.trim();

  // 收集奖章: sendStampLog(room_id + stamp_id), 成功后展示集章完成
  Future<void> _join() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await LiveApi.stampLog(roomId: widget.roomId, stampId: stampId);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        loading = false;
        error = '收集失败，稍后再试';
      });
      return;
    }
    setState(() {
      loading = false;
      done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280.0,
            padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 20.0),
            decoration: BoxDecoration(
              color: _ActivityColor.panel,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: done ? _doneView() : _runningView(),
          ),
        ],
      ),
    );
  }

  // 进行中: 标题 + 圆环倒计时 + 收集奖章
  Widget _runningView() {
    final int time = LiveApi.intOf(widget.item['time']);
    return Stack(
      children: [
        Column(
          children: [
            Text(
              title.isEmpty ? '集章活动' : title,
              style: const TextStyle(color: _ActivityColor.text, fontSize: 16.0, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14.0),
            ActivityRing(seconds: time <= 0 ? 1 : time, size: 140.0),
            const SizedBox(height: 16.0),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(_ActivityColor.red),
                minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                ),
              ),
              onPressed: loading ? null : _join,
              child: Text(loading ? '收集中…' : '收集奖章', style: const TextStyle(color: Colors.white, fontSize: 14.0)),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(error, style: const TextStyle(color: _ActivityColor.red, fontSize: 11.0)),
            ],
          ],
        ),
        Positioned(
          right: 0.0,
          top: 0.0,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: _ActivityColor.grey, size: 20.0),
          ),
        ),
      ],
    );
  }

  // 集章完成(对应H5 stampSuccPop)
  Widget _doneView() {
    return Column(
      children: [
        const Text('集章完成！', style: TextStyle(color: _ActivityColor.text, fontSize: 16.0, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4.0),
        const Text('恭喜你成功集章', style: TextStyle(color: _ActivityColor.grey, fontSize: 12.0)),
        const SizedBox(height: 14.0),
        Image.asset('assets/images/icon-jizhang.png', width: 90.0),
        const SizedBox(height: 16.0),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(_ActivityColor.red),
            minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了', style: TextStyle(color: Colors.white, fontSize: 14.0)),
        ),
      ],
    );
  }
}

/// 集章信息弹窗(居中): stamp_award 推送或入口查询后展示 title + msg + 图片 + 奖励
class PopupStampInfo extends StatelessWidget {
  const PopupStampInfo({super.key, required this.item});

  /// LiveApi.stampInfoItem 归一化结果: {title, msg, award, imgs}
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String title = '${item['title'] ?? ''}'.trim();
    final String msg = '${item['msg'] ?? ''}'.trim();
    final String award = '${item['award'] ?? ''}'.trim();
    final String imgs = '${item['imgs'] ?? ''}'.trim();
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280.0,
            padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 20.0),
            decoration: BoxDecoration(
              color: _ActivityColor.panel,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        title.isEmpty ? '集章活动' : title,
                        style: const TextStyle(color: _ActivityColor.text, fontSize: 16.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    if (msg.isNotEmpty)
                      Text(msg, style: const TextStyle(color: _ActivityColor.grey, fontSize: 13.0, height: 1.5)),
                    if (imgs.isNotEmpty) ...[
                      const SizedBox(height: 10.0),
                      Center(child: Image.network(imgs, width: 110.0, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                    ],
                    if (award.isNotEmpty) ...[
                      const SizedBox(height: 10.0),
                      Text(award, style: const TextStyle(color: _ActivityColor.red, fontSize: 13.0)),
                    ],
                    const SizedBox(height: 16.0),
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(_ActivityColor.red),
                        minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('知道了', style: TextStyle(color: Colors.white, fontSize: 14.0)),
                    ),
                  ],
                ),
                Positioned(
                  right: 0.0,
                  top: 0.0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _ActivityColor.grey, size: 20.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
