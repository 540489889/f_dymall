/// 限时秒杀(场次列表 + 商品列表)
/// 对齐 H5: pages_promotion/seckill/list.vue
/// * 顶部渐变头 + 深色倒计时条(本场还剩 时:分:秒 结束)
/// * 左侧竖向场次时间轴(点选切换场次, 选中态高亮), 右侧当前场次商品
/// * 商品卡片: 秒杀价 / 划线原价 / 仅剩N件(或已抢xx%) / 马上抢
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/seckill.dart';
import '../../components/loading.dart';

class SeckillListPage extends StatefulWidget {
  const SeckillListPage({super.key});

  @override
  State<SeckillListPage> createState() => _SeckillListPageState();
}

class _SeckillListPageState extends State<SeckillListPage> {
  /// 秒杀价红
  static const Color primary = Color(0xFFF83530);
  /// 辅助橙(徽标/选中态)
  static const Color aux = Color(0xFFF08300);
  /// 按钮渐变(马上抢)
  static const Color orangeFrom = Color(0xFFFF8A2B);
  static const Color orangeTo = Color(0xFFFFA62E);
  /// 顶部渐变背景
  static const Color headFrom = Color(0xFFFF7C3D);
  static const Color headTo = Color(0xFFFFB256);
  /// 倒计时深色条
  static const Color countdownBar = Color(0xFF35324A);
  /// 页面底色(米白)
  static const Color bgColor = Color(0xFFFFF8F1);
  /// 时间轴未选中灰
  static const Color railGray = Color(0xFFCFC9C1);
  static const Color textGray = Color(0xFF9A948E);

  Timer? timer;

  bool loading = true;
  bool goodsLoading = false;
  String errorMsg = '';

  /// 场次列表
  List<SeckillTime> timeList = <SeckillTime>[];
  int timeIndex = 0;
  /// 商品列表
  List<Map<String, dynamic>> goodsList = <Map<String, dynamic>>[];

  /// 服务器时间戳(秒)与同步时的本机秒数, 用于无漂移倒计时
  int serverSeconds = 0;
  int syncedAt = 0;

  /// 当前"当日秒数"(服务器时间 + 本地走过的时间)
  int get nowSeconds {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return serverSeconds + (now - syncedAt);
  }

  SeckillTime? get currentTime => timeList.isEmpty ? null : timeList[timeIndex];

  @override
  void initState() {
    super.initState();
    loadTimeList();
    // 每秒刷新倒计时
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  /// 场次列表(/seckill/api/seckill/lists)
  Future<void> loadTimeList() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> res = await SeckillApi.timeList();
      final List<SeckillTime> list = (res['list'] as List? ?? const []).cast<SeckillTime>();
      final int timestamp = int.tryParse('${res['timestamp'] ?? 0}') ?? 0;
      final DateTime serverTime = timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          : DateTime.now();
      serverSeconds = serverTime.hour * 3600 + serverTime.minute * 60 + serverTime.second;
      syncedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (!mounted) return;
      setState(() {
        timeList = list;
        timeIndex = 0;
        loading = false;
        errorMsg = list.isEmpty ? '商家未开启秒杀' : '';
      });
      if (list.isNotEmpty) await loadGoods();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = _errText(e);
      });
    }
  }

  /// 当前场次商品(不分页, /seckill/api/seckillgoods/lists)
  /// * 注意: 不用 /seckillgoods/page —— 该接口会漏商品且 goods_stock 返回负值
  Future<void> loadGoods() async {
    final SeckillTime? time = currentTime;
    if (time == null) return;
    setState(() => goodsLoading = true);
    try {
      final List<Map<String, dynamic>> data = await SeckillApi.goodsList(
        seckillTimeId: time.id,
        type: time.type,
      );
      if (!mounted) return;
      setState(() {
        goodsList = data;
        goodsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => goodsLoading = false);
    }
  }

  /// 切换场次
  Future<void> onTapTime(int index) async {
    if (index == timeIndex) return;
    setState(() {
      timeIndex = index;
      goodsList = <Map<String, dynamic>>[];
    });
    await loadGoods();
  }

  /// 跳秒杀详情
  void toDetail(Map<String, dynamic> item) {
    Get.toNamed('/seckill/detail', arguments: <String, dynamic>{'seckillId': item['id']});
  }

  String _errText(Object e) => '$e'.replaceAll(RegExp(r'^DioException.*message: '), '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 13.0, color: Color(0xFFFFE3A8)),
            SizedBox(width: 5.0),
            Text('限时秒杀', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600)),
            SizedBox(width: 5.0),
            Icon(Icons.auto_awesome, size: 13.0, color: Color(0xFFFFE3A8)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)))
          : errorMsg.isNotEmpty
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(errorMsg, style: const TextStyle(color: Color(0xFF999999), fontSize: 14.0)),
          const SizedBox(height: 12.0),
          OutlinedButton(onPressed: loadTimeList, child: const Text('重新加载')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: <Widget>[
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 左侧: 场次时间轴(点选切换场次)
              _buildTimeRail(),
              // 右侧: 当前场次商品列表
              Expanded(child: _buildGoodsList()),
            ],
          ),
        ),
      ],
    );
  }

  /// 秒杀顶部头部：渐变背景向上延伸到状态栏/标题栏，标题栏透明叠加，整体不分层
  Widget _buildHeader() {
    // 顶部留白 = 状态栏高度 + 标题栏高度，让渐变从屏幕最顶端开始
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: <Color>[headFrom, headTo], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.0),
          bottomRight: Radius.circular(20.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildCountDown(),
        ],
      ),
    );
  }

  /// 倒计时条：深色横条(时钟 + 本场还剩 + 时分秒 + 结束)
  Widget _buildCountDown() {
    final SeckillTime? time = currentTime;
    if (time == null) return const SizedBox.shrink();
    final int status = time.statusOf(nowSeconds);
    final int remain = time.remainSeconds(nowSeconds);
    final String tip = status == 1 ? '本场还剩' : (status == 0 ? '本场已结束' : '距开始还剩');
    final String tail = status == 1 ? '结束' : (status == 0 ? '' : '开始');
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 14.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
      decoration: BoxDecoration(
        color: countdownBar,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10.0, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.alarm, color: Color(0xFFFFC24B), size: 16.0),
          const SizedBox(width: 6.0),
          Text(tip, style: const TextStyle(color: Colors.white, fontSize: 12.0)),
          const SizedBox(width: 8.0),
          if (status != 0) ..._buildTimeBlocks(remain),
          if (status != 0) const SizedBox(width: 2.0),
          Text(tail, style: const TextStyle(color: Colors.white, fontSize: 12.0)),
        ],
      ),
    );
  }

  /// 左侧场次时间轴(原横向 tab 改为竖向时间轴)
  Widget _buildTimeRail() {
    return SizedBox(
      width: 90.0,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
        itemCount: timeList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12.0),
        itemBuilder: (BuildContext context, int index) => _buildRailItem(timeList[index], index),
      ),
    );
  }

  /// 时间轴节点: 圆点 + 竖线 + 场次时间/状态, 选中场次高亮
  /// * 选中项: 白底圆角卡片 + 淡橙投影, 时间加粗放大
  /// * 「抢购中」: 橙色实心胶囊(最醒目); 未选中的进行中场次时间/状态也用橙色加粗
  Widget _buildRailItem(SeckillTime item, int index) {
    final bool active = index == timeIndex;
    final bool isLast = index == timeList.length - 1;
    final int status = item.statusOf(nowSeconds);
    final bool inProgress = status == 1;
    // 选中 或 正在进行 -> 视为需要强调
    final bool emphasize = active || inProgress;
    final String statusText =
        status == 1 ? '抢购中' : (status == 2 ? '即将开始' : (status == 3 ? '明日预告' : '已结束'));

    // 状态文案: 选中且抢购中 -> 橙色渐变胶囊; 其余普通文字(进行中/选中为橙色加粗)
    final Widget statusWidget = (active && inProgress)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: <Color>[orangeFrom, orangeTo]),
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: const Text(
              '抢购中',
              style: TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w700),
            ),
          )
        : Text(
            statusText,
            style: TextStyle(
              color: emphasize ? aux : textGray,
              fontSize: 11.0,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal,
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapTime(index),
      child: Container(
        height: 52.0,
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(color: const Color(0xFFFF9A3C).withValues(alpha: 0.14), blurRadius: 8.0, offset: const Offset(0, 2)),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 14.0,
              child: Column(
                children: <Widget>[
                  Container(
                    width: active ? 12.0 : 9.0,
                    height: active ? 12.0 : 9.0,
                    margin: const EdgeInsets.only(top: 3.0),
                    decoration: BoxDecoration(
                      color: emphasize ? aux : Colors.transparent,
                      shape: BoxShape.circle,
                      border: active
                          ? Border.all(color: const Color(0xFFFFD79A), width: 3.0)
                          : Border.all(color: emphasize ? aux.withValues(alpha: 0.45) : railGray, width: 1.5),
                    ),
                  ),
                  // 末节点不画竖线
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 3.0),
                        color: railGray.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.startTimeText,
                    style: TextStyle(
                      color: active ? const Color(0xFF3A352F) : (inProgress ? aux : textGray),
                      fontSize: active ? 16.0 : 15.0,
                      fontWeight: active ? FontWeight.w700 : (inProgress ? FontWeight.w600 : FontWeight.w500),
                      fontFamily: 'Arial',
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  statusWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧商品列表(当前场次)
  Widget _buildGoodsList() {
    return RefreshIndicator(
      color: primary,
      onRefresh: () async => loadTimeList(),
      child: ListView(
        // 内容不满一屏也可下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 12.0, 12.0, 16.0),
        children: <Widget>[
          if (goodsLoading)
            const Padding(padding: EdgeInsets.all(30.0), child: Center(child: Loading()))
          else if (goodsList.isEmpty)
            _buildEmpty()
          else
            ...goodsList.map(_buildGoodsItem),
        ],
      ),
    );
  }

  List<Widget> _buildTimeBlocks(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    return <Widget>[
      _buildBlock(_pad(h)),
      const Text(' : ', style: TextStyle(color: Color(0xFFFFC24B), fontSize: 12.0, fontWeight: FontWeight.w700)),
      _buildBlock(_pad(m)),
      const Text(' : ', style: TextStyle(color: Color(0xFFFFC24B), fontSize: 12.0, fontWeight: FontWeight.w700)),
      _buildBlock(_pad(s)),
    ];
  }

  Widget _buildBlock(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: const TextStyle(color: countdownBar, fontSize: 13.0, fontWeight: FontWeight.w700, fontFamily: 'Arial'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60.0),
      alignment: Alignment.center,
      child: const Text('暂时没有商品哦！去别处看看吧~', style: TextStyle(color: Color(0xFF999999), fontSize: 13.0)),
    );
  }

  /// 商品卡片: 图 + 标题 + 秒杀价/划线原价 + 仅剩/已抢徽标 + 马上抢
  Widget _buildGoodsItem(Map<String, dynamic> item) {
    final String image = '${item['image'] ?? ''}';
    final num price = item['seckillPrice'] as num? ?? 0;
    final num origin = item['price'] as num? ?? 0;
    final int stock = (item['stock'] as num? ?? 0).toInt();
    final int saleNum = (item['saleNum'] as num? ?? 0).toInt();
    final int total = stock + saleNum;
    final double progress = total <= 0 ? 0 : (saleNum / total).clamp(0.0, 1.0);
    final int status = currentTime?.statusOf(nowSeconds) ?? 0;
    final bool canBuy = status == 1 && stock != 0;
    // 有库存显示"仅剩N件", 抢完显示"已抢xx%"
    final String badgeText = stock > 0 ? '仅剩$stock件' : '已抢${(progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0xFFFF9A3C).withValues(alpha: 0.08), blurRadius: 10.0, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () => toDetail(item),
        borderRadius: BorderRadius.circular(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildGoodsImage(image),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${item['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333), height: 1.3),
                  ),
                  const SizedBox(height: 10.0),
                  // 秒杀价 + 划线原价
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      const Text('¥', style: TextStyle(color: primary, fontSize: 12.0, fontWeight: FontWeight.w600)),
                      Text(
                        _money(price),
                        style: const TextStyle(
                          color: primary,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Arial',
                        ),
                      ),
                      if (origin > price) ...<Widget>[
                        const SizedBox(width: 6.0),
                        Text(
                          '¥${_money(origin)}',
                          style: const TextStyle(
                            color: textGray,
                            fontSize: 11.0,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  // 库存/进度徽标
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0DE),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(color: aux, fontSize: 10.0),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // 马上抢: 单独放一排右对齐(不再和价格挤同一行, 避免右侧溢出)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildBuyButton(item, canBuy, stock),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 商品图(空图/失败兜底): 统一裁 8px 圆角
  Widget _buildGoodsImage(String image) {
    const double size = 100.0;
    final Widget child = image.isEmpty
        ? Container(
            width: size,
            height: size,
            color: const Color(0xFFF5F5F5),
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 28.0),
          )
        : CachedNetworkImage(
            imageUrl: image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: size, height: size, color: const Color(0xFFF5F5F5)),
            errorWidget: (_, __, ___) => Container(
              width: size,
              height: size,
              color: const Color(0xFFF5F5F5),
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 28.0),
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: child,
    );
  }

  /// 「马上抢」按钮: 可抢为橙色渐变胶囊, 不可抢为灰色
  Widget _buildBuyButton(Map<String, dynamic> item, bool canBuy, int stock) {
    final String text = canBuy ? '马上抢' : (stock == 0 ? '已抢完' : '即将开始');
    return GestureDetector(
      onTap: canBuy ? () => toDetail(item) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 7.0),
        decoration: BoxDecoration(
          gradient: canBuy
              ? const LinearGradient(colors: <Color>[orangeFrom, orangeTo])
              : null,
          color: canBuy ? null : const Color(0xFFE6E1DA),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: canBuy
              ? <BoxShadow>[
                  BoxShadow(color: orangeTo.withValues(alpha: 0.35), blurRadius: 8.0, offset: const Offset(0, 3)),
                ]
              : null,
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _money(num v) => v.toStringAsFixed(2);

  String _pad(int v) => v < 10 ? '0$v' : '$v';
}
