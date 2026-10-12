/// 直播间商品面板(smooth_sheets)
/// * 点商品不跳页: 面板占屏 80%, 上方露出直播画面(就是直播间自己的 Video, 一直在播)
/// * 抖音式升降, 由 smooth_sheets 的 scrollConfiguration 负责:
///   * 内容停在顶部时上滑 -> 滚动手势先归面板, 面板撑到全屏, 内容不动
///   * 面板全屏后继续上滑 -> 内容才开始滚
///   * 内容滚回顶部再往下拉 -> 面板收回到 80%
/// * 为什么换成 smooth_sheets: 官方 DraggableScrollableSheet 的越界联动依赖
///   "内部列表刚好停在 pixels == 0" 这类判定, 详情页是 Stack + SliverAppBar 结构实测不触发;
///   smooth_sheets 把物理(physics)和吸附(snapGrid)拆开配置, 并且明确提供
///   SheetScrollHandlingBehavior.onlyFromTop 这种"只在顶部接管滚动"的模式
/// * 内容直接复用商品详情页 Goods: 轮播 / 价格 / 促销 / 评价 / 属性 / 优惠券 /
///   图文详情 / 加购购买都在,商城详情页和直播间共用一套逻辑
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../goods/detail.dart';

/// 直播间商品面板: 可升降(80% <-> 全屏), 上方留白露出直播画面
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
  /// 面板顶部圆角
  static const double _kRadius = 14.0;
  /// 顶部把手高度(按住它也能拖面板高度; 只占中间一小条, 不挡详情页左右按钮)
  static const double _kHandleHeight = 28.0;
  /// 把手拖动判定阈值(像素): 位移太小就当作误触, 不改变档位
  static const double _kDragThreshold = 24.0;

  bool _entered = false;
  double _handleDy = 0.0;

  late final SheetController _sheetController = SheetController();

  @override
  void initState() {
    super.initState();
    // 下一帧再改 offset: 同一帧内改的话起始位置就是终点,看不到升起动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// 切到指定档位(0.8 / 1.0)
  Future<void> _animateToRatio(double ratio) {
    return _sheetController.animateTo(
      SheetOffset.proportionalToViewport(ratio),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  // 把手: 拖动过程中只累积位移, 松手时按方向切换档位(避免和面板自己的拖动打架)
  void _onHandleDragUpdate(DragUpdateDetails details) {
    _handleDy += details.delta.dy;
  }

  void _onHandleDragEnd(DragEndDetails details) {
    final double dy = _handleDy;
    _handleDy = 0.0;
    if (dy.abs() < _kDragThreshold) return;
    // 手指向上(dy 为负) -> 撑到全屏; 向下 -> 回到 80%
    unawaited(_animateToRatio(dy < 0 ? 1.0 : _kMinRatio));
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
        // 面板本体: 入场从底部升起, 之后可升降(80% <-> 全屏)
        AnimatedSlide(
          offset: _entered ? Offset.zero : const Offset(0.0, 1.0),
          duration: _kDuration,
          curve: Curves.easeOutCubic,
          child: SizedBox.expand(
            child: SheetViewport(
              child: Sheet(
                controller: _sheetController,
                initialOffset: SheetOffset.proportionalToViewport(_kMinRatio),
                // 松手后吸到最近的档位(80% / 全屏), 不会停在中间高度
                snapGrid: SheetSnapGrid(
                  snaps: <SheetOffset>[
                    SheetOffset.proportionalToViewport(_kMinRatio),
                    SheetOffset.proportionalToViewport(1.0),
                  ],
                ),
                // 关键: 内容停在顶部时, 滚动手势先归面板(先撑开面板, 再滚内容)
                scrollConfiguration: const SheetScrollConfiguration(
                  scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
                  delegateUnhandledOverscrollToChild: true,
                ),
                child: Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(_kRadius)),
                      child: Goods(
                        // 和外层 key 对应: 换商品时重建详情页,重新拉数据
                        key: ValueKey<int>(widget.goodsId),
                        goodsId: widget.goodsId,
                        liveRoomId: widget.roomSn,
                        onBack: widget.onClose,
                        // 滚动由 smooth_sheets 通过 scrollConfiguration 接管, 不用传控制器/物理
                      ),
                    ),
                    // 顶部把手: 拖它切换档位(只占中间一小条, 不挡详情页按钮)
                    Positioned(
                      top: 0.0,
                      left: 0.0,
                      right: 0.0,
                      height: _kHandleHeight,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: _onHandleDragUpdate,
                          onVerticalDragEnd: _onHandleDragEnd,
                          child: const SizedBox(
                            width: 64.0,
                            height: _kHandleHeight,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x33000000),
                                  borderRadius: BorderRadius.all(Radius.circular(2.0)),
                                ),
                                child: SizedBox(width: 36.0, height: 4.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
