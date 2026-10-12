/// 直播间商品面板
/// * 点商品不跳页: 面板从底部升起盖住下半屏,上方露出直播画面(就是直播间自己的 Video,一直在播)
/// * 抖音式升降: 初始占屏 80%
///   * 内容停在顶部时手指上滑 -> 位移先给面板, 面板撑大到全屏, 内容不动
///   * 面板全屏后继续上滑 -> 内容才开始滚
///   * 内容滚回顶部继续往下拉 -> 面板收回到 80%(到 80% 后不再变小)
///   * 另外顶部有把手, 按住它也能直接拖高度
/// * 内容直接复用商品详情页 Goods: 轮播 / 价格 / 促销 / 评价 / 属性 / 优惠券 /
///   图文详情 / 加购购买都在,商城详情页和直播间共用一套逻辑
library;

import 'package:flutter/material.dart';

import '../../goods/detail.dart';

/// 面板专用滚动物理: 内容停在顶部时, 把手指位移先交给面板改高度, 内容不动
/// * 面板没到边界(80% / 全屏) -> 位移吃给面板, 返回 0 让内容不动(抖音那种手感)
/// * 面板已到边界 -> 放行, 内容正常滚
/// * 为什么不用 DraggableScrollableSheet 自带的越界机制: 它依赖内部列表刚好停在
///   pixels == 0 且方向判定全部命中, 详情页是 Stack + SliverAppBar 结构, 实测不触发
class _PanelScrollPhysics extends ClampingScrollPhysics {
  const _PanelScrollPhysics({super.parent, required this.onDelta});

  /// [dy] > 0 表示手指上滑(面板应变高), < 0 表示手指下滑(面板应变矮)
  /// * 返回 true: 这段位移被面板吃掉, 内容不滚
  final bool Function(double dy) onDelta;

  @override
  _PanelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _PanelScrollPhysics(parent: buildParent(ancestor), onDelta: onDelta);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 只在内容停在顶部时接管(内容已经滚起来了就让它正常滚)
    // * offset < 0 = 手指上滑(要看下面的内容) -> 转成正的 dy 让面板变高
    if (position.pixels <= 0.0 && offset != 0.0 && onDelta(-offset)) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

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
  late final _PanelScrollPhysics _physics = _PanelScrollPhysics(onDelta: _onDragDelta);

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

  /// 把滚动位移转成面板高度(内容滚动 / 拖把手都走这里)
  /// * [dy] > 0 面板变高; 返回 false 表示面板已到边界, 位移该还给内容
  bool _onDragDelta(double dy) {
    if (!_sheetController.isAttached) return false;
    final double height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return false;
    final double current = _sheetController.size;
    final double next = (current + dy / height).clamp(_kMinRatio, 1.0);
    if (next == current) return false;
    _sheetController.jumpTo(next);
    return true;
  }

  /// 把手拖动: 手指向上(delta.dy 为负) -> 面板变高
  void _onHandleDrag(DragUpdateDetails details) {
    _onDragDelta(-details.delta.dy);
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
                        scrollController: scrollController,
                        // 关键: 面板没撑满时, 滚动位移先改面板高度(内容不动)
                        physics: _physics,
                      ),
                    ),
                    // 顶部把手: 按住它直接拖面板高度(只占中间一小条, 不挡详情页按钮)
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
      ],
    );
  }
}
