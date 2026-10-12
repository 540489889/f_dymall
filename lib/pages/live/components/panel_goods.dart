/// 直播间商品面板
/// * 点商品不跳页: 面板从底部升起盖住下半屏,上方露出直播画面(就是直播间自己的 Video,一直在播)
/// * 抖音式升降: 初始占屏 80%, 三种方式都能改高度
///   * 拖顶部把手(最可靠): 直接改面板高度, 松手就近吸附到 80% / 全屏
///   * 内容在顶部时上滑: 自动撑到全屏(见下面的滚动兜底)
///   * 内容滚到顶继续往下拉: 越界量交回面板, 收回到 80%
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
  /// 顶部把手高度(拖动它改面板高度; 只占中间一小条, 不挡详情页左右按钮)
  static const double _kHandleHeight = 28.0;

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

  /// 把手拖动: 手指向上 -> 面板变高(delta.dy 为负, 取反后是正增量)
  void _onHandleDrag(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final double height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    final double delta = -details.delta.dy / height;
    _sheetController.jumpTo((_sheetController.size + delta).clamp(_kMinRatio, 1.0));
  }

  // 松手: 就近吸附到 80% 或全屏
  void _snapSheet() {
    if (!_sheetController.isAttached) return;
    final double size = _sheetController.size;
    final double target = (1.0 - size) < (size - _kMinRatio) ? 1.0 : _kMinRatio;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  // 滚动兜底: 详情页是 Stack + SliverAppBar 结构, 光靠 sheet 自己的越界机制未必触发,
  // 这里按滚动通知再补两条, 保证"上滑展开 / 到顶下拉收起"一定能用
  bool _onScroll(ScrollNotification notification) {
    if (!_sheetController.isAttached) return false;
    // 内容在顶部还继续上滑(想看下面的内容): 先撑满面板
    if (notification is ScrollUpdateNotification) {
      final double? delta = notification.scrollDelta;
      if (notification.metrics.pixels <= 2.0 && delta != null && delta > 0.0 && _sheetController.size < 1.0) {
        _sheetController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
      return false;
    }
    // 内容已到顶还往下拉(越界): 面板收回 80%
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0.0 && _sheetController.size > _kMinRatio) {
        _sheetController.animateTo(
          _kMinRatio,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
    return false;
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
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _kMinRatio,
                minChildSize: _kMinRatio,
                maxChildSize: 1.0,
                // 松手后吸到最近的档位(80% / 全屏), 不会停在中间高度
                snap: true,
                snapSizes: <double>[_kMinRatio, 1.0],
                builder: (BuildContext context, ScrollController scrollController) {
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(_size >= 0.995 ? 0.0 : _kRadius),
                        ),
                        child: Goods(
                          // 和外层 key 对应: 换商品时重建详情页,重新拉数据
                          key: ValueKey<int>(widget.goodsId),
                          goodsId: widget.goodsId,
                          liveRoomId: widget.roomSn,
                          onBack: widget.onClose,
                          // 用面板给的控制器: 面板没撑满时拖动先撑面板, 撑满后才滚内容
                          scrollController: scrollController,
                        ),
                      ),
                      // 顶部把手: 拖它直接改面板高度(不依赖内容滚动越界, 最好拖)
                      Positioned(
                        top: 0.0,
                        left: 0.0,
                        right: 0.0,
                        height: _kHandleHeight,
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: _onHandleDrag,
                            onVerticalDragEnd: (DragEndDetails details) => _snapSheet(),
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
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
