/// 回到顶部悬浮按钮(首页 / 视频 / 商品详情等共用)
/// * 滚动超过 [distance] 才出现: 淡入 + 轻微放大,不再像之前那样硬闪一下
/// * 隐藏时忽略点击,避免透明状态下挡住下面的内容
/// * 质感: 白->浅粉渐变底 + 主色描边 + 双层柔和投影 + 按下回弹
library;

import 'package:flutter/material.dart';

class Backtop extends StatelessWidget {
  const Backtop({
  super.key,
  required this.controller,
  required this.offset,
  this.distance = 1000.0,
});

final ScrollController controller;
/// 滚动位置
final ValueNotifier<double> offset;
/// 距离顶部多远显示
final double distance;

  @override
  Widget build(BuildContext context){
    return ValueListenableBuilder<double>(
    valueListenable: offset,
    // 按钮作为 child 只构建一次: 滚动中每帧仅切换显示状态,不重复重建按钮
    child: _BacktopButton(controller: controller),
    builder: (BuildContext context, double value, Widget? child) {
      final bool show = value > distance;
      return AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: show ? 1.0 : 0.7,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !show,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    },
    );
  }
}

/// 按钮本体(按下有轻微回弹,手感更像实体按钮)
class _BacktopButton extends StatefulWidget {
  const _BacktopButton({required this.controller});

  final ScrollController controller;

  @override
  State<_BacktopButton> createState() => _BacktopButtonState();
}

class _BacktopButtonState extends State<_BacktopButton> {
  /// 按下态: 缩放回弹
  bool pressed = false;

  void onTap() {
    if(!widget.controller.hasClients) return;
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context){
    return GestureDetector(
      onTapDown: (TapDownDetails _) => setState(() => pressed = true),
      onTapUp: (TapUpDetails _) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 46.0,
          height: 46.0,
          decoration: BoxDecoration(
            // 半透明白圆底(带透明度,叠在内容上不显生硬) + 中性投影
            color: Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x26000000), blurRadius: 12.0, offset: Offset(0.0, 4.0)),
              BoxShadow(color: Color(0x0F000000), blurRadius: 3.0, offset: Offset(0.0, 1.0)),
            ],
          ),
          // * 必须显式居中: Container 不带 alignment 时 child 会贴左上,
          //   自绘图标不像 Icon(内部自带 Center)会自己居中
          alignment: Alignment.center,
          // 自绘图标: 上层圆角 chevron + 下层短基线,线条更纤细、比例更贴合圆形按钮
          // 按下时轻微上移,和按钮回弹一起强化"向上"的暗示
          child: AnimatedSlide(
            offset: pressed ? const Offset(0.0, -0.08) : Offset.zero,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: const _BacktopIcon(),
          ),
        ),
      ),
    );
  }
}

/// 回到顶部图标(自绘)
/// * Material 自带的 arrow_upward / vertical_align_top 笔画偏粗、留白偏大,
///   放在 46 的圆形按钮里显得笨重,这里自己画一个更纤细挺拔的
/// * 上层是圆角 chevron(圆头圆角交汇),下层一条更窄的基线表示"顶部"
class _BacktopIcon extends StatelessWidget {
  const _BacktopIcon();

  @override
  Widget build(BuildContext context){
    return const SizedBox(
      width: 22.0,
      height: 22.0,
      child: CustomPaint(painter: _BacktopIconPainter()),
    );
  }
}

class _BacktopIconPainter extends CustomPainter {
  const _BacktopIconPainter();

  /// 画布基准尺寸: 坐标按 22x22 设计,实际按 size 等比缩放,
  /// 这样即使外层约束把画布撑大,图标依然居中且比例不变
  static const double base = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / base;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // 近黑细线(对齐设计稿,不再用主色渐变)
      ..color = const Color(0xFF1F1F1F);

    final double cx = size.width / 2.0;

    // 顶部横线: 表示"顶"
    canvas.drawLine(
      Offset(cx - 5.4 * s, 4.6 * s),
      Offset(cx + 5.4 * s, 4.6 * s),
      paint,
    );

    // 箭头 chevron: 尖朝上, 与横线之间留一点空隙
    final Path arrow = Path()
      ..moveTo(cx - 4.8 * s, 10.8 * s)
      ..lineTo(cx, 6.4 * s)
      ..lineTo(cx + 4.8 * s, 10.8 * s);
    canvas.drawPath(arrow, paint);

    // 竖线: 从 chevron 尖端一直延伸到按钮下部
    canvas.drawLine(
      Offset(cx, 6.4 * s),
      Offset(cx, 17.4 * s),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BacktopIconPainter oldDelegate) => false;
}
