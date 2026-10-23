/// 我的优惠券
/// 对齐 H5: pages_tool/member/coupon.vue
/// * 列表 /coupon/api/coupon/memberpage(state: 1未使用 2已使用 3已过期)
/// * 券卡: 左金额/折扣 + 门槛, 右名称/适用范围/有效期, 未使用可点击去使用
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/coupon.dart';
import '../../utils/index.dart';

class MyCouponPage extends StatefulWidget {
  const MyCouponPage({super.key});

  @override
  State<MyCouponPage> createState() => _MyCouponPageState();
}

class _MyCouponPageState extends State<MyCouponPage> {
  static const Color primary = Color(0xFFFF2C55);
  static const int pageSize = 10;

  final ScrollController controller = ScrollController();

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String errorMsg = '';
  int page = 1;
  int state = CouponApi.stateUnused;

  // 顶部tab: 未使用 / 已使用 / 已过期
  final List<Map<String, dynamic>> tabs = <Map<String, dynamic>>[
    <String, dynamic>{'label': '未使用', 'state': CouponApi.stateUnused},
    <String, dynamic>{'label': '已使用', 'state': CouponApi.stateUsed},
    <String, dynamic>{'label': '已过期', 'state': CouponApi.stateExpired},
  ];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
    loadList(refresh: true);
  }

  @override
  void dispose() {
    controller.removeListener(_onScroll);
    controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!controller.hasClients) return;
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) loadMore();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    page += 1;
    await loadList();
  }

  /// 切换tab
  void changeState(int value) {
    if (value == state) return;
    setState(() => state = value);
    loadList(refresh: true);
  }

  /// 券列表
  Future<void> loadList({bool refresh = false}) async {
    if (refresh) {
      page = 1;
      hasMore = true;
      setState(() {
        loading = true;
        errorMsg = '';
      });
    }
    try {
      final Map<String, dynamic> res = await CouponApi.memberPage(
        page: page,
        pageSize: pageSize,
        state: state,
      );
      final List<Map<String, dynamic>> data = CouponApi.listOf(res);
      if (!mounted) return;
      setState(() {
        list = refresh ? data : <Map<String, dynamic>>[...list, ...data];
        hasMore = data.length >= pageSize;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = '优惠券加载失败';
        loading = false;
        loadingMore = false;
      });
    }
  }

  /// 门槛文案
  String conditionText(Map<String, dynamic> item) {
    final double atLeast = double.tryParse('${item['at_least'] ?? ''}') ?? 0;
    return atLeast > 0 ? '满${_trim(atLeast)}元可用' : '无门槛优惠券';
  }

  /// 有效期
  String timeText(Map<String, dynamic> item) {
    final dynamic endTime = item['end_time'];
    final String date = Utils.timeStampTurnTime(endTime, withSecond: false);
    return date.isEmpty ? '有效期：长期有效' : '有效期：$date';
  }

  /// 适用范围(门店 / 最大优惠) — 商品类型、使用渠道单独成行展示
  List<String> scopeTexts(Map<String, dynamic> item) {
    final List<String> parts = <String>[];
    final String channelKey = '${item['use_channel'] ?? ''}';
    if (channelKey != 'online') {
      final String store = '${item['use_store'] ?? ''}';
      parts.add(store == 'all' ? '全部门店' : '${item['use_store_name'] ?? ''}'.trim());
    }
    final double limit = double.tryParse('${item['discount_limit'] ?? ''}') ?? 0;
    if (limit > 0) parts.add('最大优惠${_trim(limit)}元');
    return parts.where((String e) => e.isNotEmpty).toList();
  }

  /// 单条适用范围(单独一行: 标题 + 值, 无背景)
  Widget _scopeRow(String title, String value, bool disabled) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Text(
        '$title：$value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.0,
          color: disabled ? const Color(0xFF999999) : const Color(0xFF666666),
        ),
      ),
    );
  }

  /// 去掉多余小数(10.0 -> 10)
  String _trim(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// 去使用: 回商城首页选购
  void toUse(Map<String, dynamic> item) {
    Get.toNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('我的优惠券', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          _buildTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 顶部状态tab
  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          for (final Map<String, dynamic> item in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => changeState(item['state'] as int),
                child: Container(
                  height: 34.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    color: item['state'] == state ? const Color(0xFFFFF1F2) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(17.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${item['label']}',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: item['state'] == state ? primary : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/common-empty.png', width: 120.0),
            const SizedBox(height: 12.0),
            Text(
              errorMsg.isEmpty ? '暂无优惠券' : errorMsg,
              style: const TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => loadList(refresh: true),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 20.0),
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: loadingMore
                    ? const SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
                      )
                    : Text(hasMore ? '上拉加载更多' : '没有更多了', style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
              ),
            );
          }
          return _buildCouponCard(list[index]);
        },
      ),
    );
  }

  /// 券卡: 与领券中心一致的票券样式(左侧红渐变金额区 + 中间虚线 + 上下半圆缺口)
  Widget _buildCouponCard(Map<String, dynamic> item) {
    final int itemState = int.tryParse('${item['state'] ?? CouponApi.stateUnused}') ?? CouponApi.stateUnused;
    final bool disabled = itemState != CouponApi.stateUnused;
    final String goodsType = '${item['goods_type_name'] ?? ''}'.trim();
    final String channel = '${item['use_channel_name'] ?? ''}'.trim();
    final List<String> extra = scopeTexts(item);
    const double dividerX = 104.0; // 金额区宽度
    const double notchR = 7.0; // 半圆缺口半径
    const Color bg = Color(0xFFF5F5F5); // 与页面背景同色,模拟打孔
    final Color dashColor = disabled ? const Color(0xFFD8D8D8) : const Color(0xFFFFC2CB);
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      constraints: const BoxConstraints(minHeight: 112.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6.0, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 左侧金额区(不可用置灰)
                Container(
                  width: dividerX,
                  decoration: BoxDecoration(
                    gradient: disabled
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[Color(0xFFFF7A52), primary],
                          ),
                    color: disabled ? const Color(0xFFE0E0E0) : null,
                  ),
                  alignment: Alignment.center,
                  child: _buildAmount(item, disabled),
                ),
                // 右侧信息区
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: disabled ? const Color(0xFFF2F2F2) : Colors.white,
                    ),
                    padding: const EdgeInsets.fromLTRB(14.0, 12.0, 8.0, 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                '${item['coupon_name'] ?? '优惠券'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w600,
                                  color: disabled ? const Color(0xFF999999) : const Color(0xFF333333),
                                ),
                              ),
                              _scopeRow('适用商品', goodsType, disabled),
                              _scopeRow('使用渠道', channel, disabled),
                              if (extra.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 6.0),
                                Text(
                                  extra.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999)),
                                ),
                              ],
                              const SizedBox(height: 6.0),
                              Text(
                                timeText(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999)),
                              ),
                            ],
                          ),
                        ),
                        // 状态按钮区
                        SizedBox(
                          width: 64.0,
                          child: Center(child: _buildAction(itemState)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 中间虚线分隔(票根切口)
          Positioned(
            left: dividerX,
            top: notchR,
            bottom: notchR,
            child: _VerticalDashedLine(dashColor),
          ),
          // 上下半圆缺口
          Positioned(left: dividerX - notchR, top: -notchR, child: _CouponNotch(bg, notchR)),
          Positioned(left: dividerX - notchR, bottom: -notchR, child: _CouponNotch(bg, notchR)),
        ],
      ),
    );
  }

  /// 左侧金额区内容: ¥小字 + 大数字(满减) / 大数字 + 折(折扣),下方门槛文案
  Widget _buildAmount(Map<String, dynamic> item, bool disabled) {
    final String type = '${item['type'] ?? ''}';
    final double discount = double.tryParse('${item['discount'] ?? ''}') ?? 0;
    final double money = double.tryParse('${item['money'] ?? ''}') ?? 0;
    final Color big = disabled ? Colors.white70 : Colors.white;
    final Color small = disabled ? Colors.white70 : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (type == 'discount' && discount > 0)
          RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(text: _trim(discount), style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: big)),
                TextSpan(text: '折', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: small)),
              ],
            ),
          )
        else
          RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(text: '¥', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: small)),
                TextSpan(text: _trim(money), style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: big)),
              ],
            ),
          ),
        const SizedBox(height: 6.0),
        Text(
          conditionText(item),
          style: TextStyle(fontSize: 11.0, color: disabled ? Colors.white70 : Colors.white),
        ),
      ],
    );
  }

  /// 右侧按钮(去使用 / 已使用 / 已过期)
  Widget _buildAction(int itemState) {
    if (itemState == CouponApi.stateUnused) {
      return GestureDetector(
        onTap: () => toUse(<String, dynamic>{}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(14.0)),
          child: const Text('去使用', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      );
    }
    final String label = itemState == CouponApi.stateUsed ? '已使用' : '已过期';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(14.0)),
      child: Text(label, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: Color(0xFF999999))),
    );
  }
}

/// 票券中间竖向虚线(票根切口)
class _VerticalDashedLine extends StatelessWidget {
  final Color color;
  const _VerticalDashedLine(this.color);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => CustomPaint(
        size: Size(1.0, constraints.maxHeight),
        painter: _DashedPainter(color),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  const _DashedPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color..strokeWidth = 1.0;
    const double dash = 4.0;
    const double gap = 4.0;
    double y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0.0, y), Offset(0.0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}

/// 票券上下半圆缺口(与页面背景同色,模拟打孔)
class _CouponNotch extends StatelessWidget {
  final Color color;
  final double radius;
  const _CouponNotch(this.color, this.radius);

  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
