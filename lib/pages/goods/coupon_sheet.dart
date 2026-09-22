/// 优惠券弹窗(商品详情"领券"入口)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/coupon.dart';
import '../../controller/auth_store.dart';
import '../../behavior/custom_scroll_behavior.dart';

/* -------------------- 券文案工具(详情页 chip 与弹窗共用) -------------------- */

/// 金额去尾零: 10.00 -> 10, 9.50 -> 9.5
String trimNum(num value) => value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// 券字段转数字
num couponNum(dynamic value) {
  if (value == null || '$value'.isEmpty) return 0;
  return num.tryParse('$value') ?? 0;
}

/// 券名
String couponName(Map item) => '${item['coupon_name'] ?? '优惠券'}';

/// 券面主文案: ¥10 / 9.5折 / 券名
String couponAmountText(Map item) {
  final String type = '${item['type'] ?? ''}';
  final num couponMoney = couponNum(item['money']);
  final num discount = couponNum(item['discount']);
  if (type == 'reward' && couponMoney > 0) return '¥${trimNum(couponMoney)}';
  if (type == 'discount' && discount > 0) return '${trimNum(discount)}折';
  return couponName(item);
}

/// 使用门槛(short 用于详情页 chip: 满100, 否则用于弹窗: 满100.00可用)
String couponConditionText(Map item, {bool short = false}) {
  final num atLeast = couponNum(item['at_least']);
  if (atLeast <= 0) return '无门槛';
  return short ? '满${trimNum(atLeast)}' : '满${atLeast.toStringAsFixed(2)}可用';
}

/// 有效期: 领取后N天 / 固定期限 / 长期有效
String couponValidityText(Map item) {
  final int validityType = couponNum(item['validity_type']).toInt();
  final num endTime = couponNum(item['end_time']);
  final num fixedTerm = couponNum(item['fixed_term']);
  if (validityType == 2 && fixedTerm > 0) return '领取后${trimNum(fixedTerm)}天内有效';
  if (endTime > 0) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(endTime.toInt() * 1000);
    String two(int value) => value.toString().padLeft(2, '0');
    return '有效期至 ${date.year}.${two(date.month)}.${two(date.day)}';
  }
  if (fixedTerm > 0) return '领取后${trimNum(fixedTerm)}天内有效';
  return '长期有效';
}

/// 券唯一标识(用于记录已领取状态)
int couponKey(Map item) {
  final int id = couponNum(item['coupon_type_id']).toInt();
  return id != 0 ? id : identityHashCode(item);
}

/// 打开优惠券弹窗, 返回"已领取"的券标识集合
Future<Set<int>> showCouponSheet(
  BuildContext context, {
  required List<Map> coupons,
  required Set<int> fetched,
}) async {
  final Set<int>? result = await showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => CouponSheet(coupons: coupons, fetched: fetched),
  );
  return result ?? fetched;
}

/* ------------------------------ 弹窗 ------------------------------ */

class CouponSheet extends StatefulWidget {
  const CouponSheet({ super.key, required this.coupons, required this.fetched });

  /// 接口 coupon_list
  final List<Map> coupons;

  /// 已领取的券标识
  final Set<int> fetched;

  @override
  State<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<CouponSheet> {
  late final Set<int> fetched = <int>{...widget.fetched};
  // 领取中的券(避免重复提交)
  final Set<int> fetching = <int>{};

  void _close() => Navigator.of(context).pop(fetched);

  /// 领取优惠券(/coupon/api/coupon/receive),成功后标记已领取并同步券数量
  Future<void> _fetch(Map item) async {
    final int key = couponKey(item);
    final int couponTypeId = couponNum(item['coupon_type_id']).toInt();
    if (couponTypeId == 0 || fetching.contains(key)) return;
    setState(() => fetching.add(key));
    try {
      await CouponApi.receive(couponTypeId: couponTypeId);
      if (!mounted) return;
      setState(() {
        fetched.add(key);
        fetching.remove(key);
      });
      // 「我的」页可用券数量同步
      if (Get.isRegistered<AuthStore>()) AuthStore.to.loadCouponNum();
    } catch (e) {
      if (!mounted) return;
      setState(() => fetching.remove(key));
      String message = '$e';
      final int index = message.indexOf('message: ');
      if (index >= 0) message = message.substring(index + 9);
      Get.snackbar('提示', message.isEmpty ? '领取失败' : message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.66,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(child: _buildList()),
            _buildConfirm(),
          ],
        ),
      ),
    );
  }

  /// 标题栏(标题居中 + 关闭)
  Widget _buildHeader() {
    return SizedBox(
      height: 48.0,
      child: Stack(
        children: <Widget>[
          const Center(
            child: Text('优惠券', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600)),
          ),
          Positioned(
            right: 5.0,
            top: 0.0,
            bottom: 0.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.close, size: 20.0, color: Colors.black45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 券列表
  Widget _buildList() {
    final List<Map> coupons = widget.coupons;
    if (coupons.isEmpty) {
      return const Center(
        child: Text('暂无可用优惠券', style: TextStyle(color: Colors.grey, fontSize: 13.0)),
      );
    }
    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 5.0),
        itemCount: coupons.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12.0),
        itemBuilder: (BuildContext context, int index) {
          final Map item = coupons[index];
          final int key = couponKey(item);
          return _CouponTicket(
            item: item,
            fetched: fetched.contains(key),
            loading: fetching.contains(key),
            onFetch: () => _fetch(item),
          );
        },
      ),
    );
  }

  /// 底部确定
  Widget _buildConfirm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 10.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Container(
          height: 44.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF2C55),
            borderRadius: BorderRadius.circular(22.0),
          ),
          child: const Text('确定', style: TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/* ------------------------------ 单张券 ------------------------------ */

class _CouponTicket extends StatelessWidget {
  const _CouponTicket({ required this.item, required this.fetched, required this.onFetch, this.loading = false });

  final Map item;
  final bool fetched;
  final VoidCallback onFetch;
  /// 领取中(显示转圈, 禁用点击)
  final bool loading;

  static const double ticketHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ticketHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: <Widget>[
          _buildAmountBlock(),
          Expanded(child: _buildInfoBlock()),
        ],
      ),
    );
  }

  /// 左侧红色票面(右缘锯齿 + 左中齿孔)
  Widget _buildAmountBlock() {
    final String amount = couponAmountText(item);
    final bool isMoney = amount.startsWith('¥');
    return SizedBox(
      width: 106.0,
      height: double.infinity,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipPath(
              clipper: const _TicketClipper(),
              child: Container(
                color: const Color(0xFFFF2C55),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 2.0,
                  children: <Widget>[
                    if (isMoney)
                      Text.rich(
                        TextSpan(children: <InlineSpan>[
                          const TextSpan(text: '¥', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
                          TextSpan(text: amount.substring(1), style: const TextStyle(fontSize: 26.0, fontWeight: FontWeight.w800)),
                        ]),
                        style: const TextStyle(color: Colors.white, height: 1.1),
                      )
                    else
                      Text(amount, style: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.w700)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        couponConditionText(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 左中齿孔(超出左边缘的部分会被外层圆角裁掉, 只留半圆缺口)
          Positioned(
            left: -5.0,
            top: ticketHeight / 2 - 5.0,
            child: Container(
              width: 10.0,
              height: 10.0,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧券信息(券名 / 虚线 / 有效期 / 领取)
  Widget _buildInfoBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 10.0, 12.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 7.0,
              children: <Widget>[
                Text(
                  couponName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 1.0, child: CustomPaint(painter: _DashedLinePainter())),
                Text(
                  '有效期: ${couponValidityText(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          _buildFetchButton(),
        ],
      ),
    );
  }

  Widget _buildFetchButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (fetched || loading) ? null : onFetch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: fetched || loading ? Colors.grey.shade300 : const Color(0xFFFF2C55),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: loading
            ? const SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(strokeWidth: 1.6, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(
                fetched ? '已领取' : '领取',
                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

/// 票面右缘锯齿
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  @override
  Path getClip(Size size) {
    const double tooth = 5.0;
    const double step = 7.0;
    final Path path = Path()..moveTo(0.0, 0.0);
    path.lineTo(size.width - tooth, 0.0);
    double y = 0.0;
    bool peak = true;
    while (y < size.height) {
      y = math.min(y + step, size.height);
      path.lineTo(peak ? size.width : size.width - tooth, y);
      peak = !peak;
    }
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 横向虚线
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFE8CFCF)
      ..strokeWidth = size.height;
    const double dash = 4.0;
    const double gap = 3.0;
    double x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + dash, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
