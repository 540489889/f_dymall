/// 直播间商品面板
/// * 点商品不跳页: 面板从底部升起盖住下半屏,上方露出直播画面(就是直播间自己的 Video,一直在播)
/// * 为什么不跳 /goods 页面: 跳页后直播间被盖住,还得再起一路 Player 挂悬浮小窗
///   (多一路拉流 + 多一份解码,海思这类芯片上第二路硬解开不出来)。面板方案下直播间的
///   Video 尺寸全程不变,不会触发 SetSurfaceSize -> 内部 seek -> 直播流被打断
/// * 面板内容直接复用商品详情页 Goods: 轮播 / 价格 / 促销 / 评价 / 属性 / 优惠券 /
///   图文详情 / 加购购买都在,商城详情页和直播间共用一套逻辑
library;

import 'package:flutter/material.dart';

import '../../goods/detail.dart';

/// 直播间商品面板: 底部升起,上方留白露出直播画面
/// * 外层换商品时要带 key(ValueKey(goodsId)): 否则 widget 被复用,详情页不会重新加载
class PanelGoods extends StatefulWidget {
  const PanelGoods({
    super.key,
    required this.goodsId,
    required this.roomSn,
    required this.onClose,
  });

  /// 商品 id
  final int goodsId;
  /// 直播间房间号 sn: 面板里加购/下单同样要回传 live_roomid
  final String roomSn;
  /// 关闭面板(点上方空白 / 详情页自带的关闭按钮)
  final VoidCallback onClose;

  @override
  State<PanelGoods> createState() => _PanelGoodsState();
}

class _PanelGoodsState extends State<PanelGoods> {
  /// 面板占屏幕高度的比例(上方剩下的就是直播画面)
  static const double _kPanelRatio = 0.8;
  static const Duration _kDuration = Duration(milliseconds: 260);

  bool _entered = false;

  @override
  void initState() {
    super.initState();
    // 下一帧再改 offset: 同一帧内改的话起始位置就是终点,看不到升起动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double panelHeight = screenHeight * _kPanelRatio;
    return Stack(
      children: <Widget>[
        // 上方留白: 露出直播间画面,点它关闭面板
        Positioned(
          top: 0.0,
          left: 0.0,
          right: 0.0,
          height: screenHeight - panelHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: const SizedBox.expand(),
          ),
        ),
        // 面板本体: 从底部升起
        Positioned(
          left: 0.0,
          right: 0.0,
          bottom: 0.0,
          height: panelHeight,
          child: AnimatedSlide(
            offset: _entered ? Offset.zero : const Offset(0.0, 1.0),
            duration: _kDuration,
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14.0)),
              child: Goods(
                // 和外层 key 对应: 换商品时重建详情页,重新拉数据
                key: ValueKey<int>(widget.goodsId),
                goodsId: widget.goodsId,
                liveRoomId: widget.roomSn,
                onBack: widget.onClose,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
