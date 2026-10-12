/// 直播间商品面板
/// * 点商品不跳页: 面板从底部升起盖住下半屏,上方露出直播画面(就是直播间自己的 Video,一直在播)
/// * 抖音式升降(DraggableScrollableSheet): 初始占屏 80%
///   * 往上拖 -> 面板先撑大到全屏(这时内容不滚,滚动量被面板吃掉)
///   * 全屏后继续拖 -> 内容才开始滚动
///   * 内容滚到顶继续往下拉 -> 面板收回到 80%(再点上方空白/关闭按钮才关面板)
/// * 内容直接复用商品详情页 Goods: 轮播 / 价格 / 促销 / 评价 / 属性 / 优惠券 /
///   图文详情 / 加购购买都在,商城详情页和直播间共用一套逻辑
library;

import 'package:flutter/material.dart';

import '../../goods/detail.dart';

/// 直播间商品面板: 可拖拽升降(80% <-> 全屏), 上方留白露出直播画面
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
  /// 面板收起时占屏幕高度的比例(上方剩下的就是直播画面)
  static const double _kMinRatio = 0.8;
  static const Duration _kDuration = Duration(milliseconds: 260);
  /// 收起状态的顶部圆角(撑到全屏时抹平, 看起来就是一张独立页面)
  static const double _kRadius = 14.0;

  bool _entered = false;
  double _size = _kMinRatio;

  late final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetResize);
    // 下一帧再改 offset: 同一帧内改的话起始位置就是终点,看不到升起动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetResize);
    _sheetController.dispose();
    super.dispose();
  }

  // 面板尺寸变化(拖拽过程中实时回调): 撑到全屏时去掉顶部圆角
  void _onSheetResize() {
    if (!_sheetController.isAttached) return;
    final double size = _sheetController.size;
    if ((size - _size).abs() < 0.005) return;
    setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // 上方留白区: 面板全屏时会被盖住(点不到), 收起时点它就关面板
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: const SizedBox.expand(),
          ),
        ),
        // 面板本体: 入场从底部升起, 之后可拖拽升降(80% <-> 全屏)
        AnimatedSlide(
          offset: _entered ? Offset.zero : const Offset(0.0, 1.0),
          duration: _kDuration,
          curve: Curves.easeOutCubic,
          child: SizedBox.expand(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _kMinRatio,
              minChildSize: _kMinRatio,
              maxChildSize: 1.0,
              // 松手后吸到最近的档位(80% / 全屏), 不会停在中间高度
              snap: true,
              snapSizes: <double>[_kMinRatio, 1.0],
              builder: (BuildContext context, ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_size >= 0.995 ? 0.0 : _kRadius),
                  ),
                  child: Goods(
                    // 和外层 key 对应: 换商品时重建详情页,重新拉数据
                    key: ValueKey<int>(widget.goodsId),
                    goodsId: widget.goodsId,
                    liveRoomId: widget.roomSn,
                    onBack: widget.onClose,
                    // 关键: 用面板给的控制器, 面板没撑满时拖动先撑面板, 撑满后才滚内容
                    scrollController: scrollController,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
