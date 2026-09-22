/// 限时秒杀(场次列表 + 商品列表)
/// 对齐 H5: pages_promotion/seckill/list.vue
/// * 顶部场次横向 tab(今日/明日预告), 选中场次展示倒计时
/// * 商品列表: 秒杀价 / 原价 / 抢购进度 / 仅剩N件 / 马上抢
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
  /// 活动主色(H5 style_color: seckill_promotion_color / aux_color)
  static const Color primary = Color(0xFFF83530);
  static const Color aux = Color(0xFFFD9A01);

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
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('限时秒杀', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600)),
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
    return RefreshIndicator(
      color: primary,
      onRefresh: () async => loadTimeList(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16.0),
        children: <Widget>[
          _buildHeader(),
          if (goodsLoading)
            const Padding(padding: EdgeInsets.all(30.0), child: Center(child: Loading()))
          else if (goodsList.isEmpty)
            _buildEmpty(),
          ...goodsList.map(_buildGoodsItem),
        ],
      ),
    );
  }

  /// 秒杀顶部头部：渐变背景向上延伸到状态栏/标题栏，标题栏透明叠加，整体不分层
  Widget _buildHeader() {
    // 顶部留白 = 状态栏高度 + 标题栏高度，让渐变从屏幕最顶端开始
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: <Color>[primary, aux], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildCountDown(),
          _buildTimeBar(),
        ],
      ),
    );
  }

  /// 倒计时条：浮在渐变上的半透明胶囊，避免黑色断层
  Widget _buildCountDown() {
    final SeckillTime? time = currentTime;
    if (time == null) return const SizedBox.shrink();
    final int status = time.statusOf(nowSeconds);
    final int remain = time.remainSeconds(nowSeconds);
    final String tip = status == 1 ? '本场还剩' : (status == 0 ? '本场已结束' : '距开始还剩');
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.alarm, color: Colors.white, size: 14.0),
            const SizedBox(width: 6.0),
            Text(tip, style: const TextStyle(color: Colors.white, fontSize: 12.0)),
            const SizedBox(width: 6.0),
            if (status != 0) ..._buildTimeBlocks(remain),
            const SizedBox(width: 4.0),
            Text(status == 1 ? '结束' : (status == 0 ? '' : '开始'),
                style: const TextStyle(color: Colors.white, fontSize: 12.0)),
          ],
        ),
      ),
    );
  }

  /// 场次横向 tab(H5 time-wrap)
  Widget _buildTimeBar() {
    return Container(
      height: 76.0,
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        itemCount: timeList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8.0),
        itemBuilder: (BuildContext context, int index) {
          final SeckillTime item = timeList[index];
          final bool active = index == timeIndex;
          final int status = item.statusOf(nowSeconds);
          final String statusText = status == 1
              ? '抢购中'
              : (status == 2 ? '即将开始' : (status == 3 ? '明日预告' : '已结束'));
          return GestureDetector(
            onTap: () => onTapTime(index),
            child: Container(
              width: 74.0,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10.0),
                border: active
                    ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.startTimeText,
                    style: TextStyle(
                      color: active ? primary : Colors.white,
                      fontSize: 17.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: active ? primary : Colors.white.withValues(alpha: 0.9),
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTimeBlocks(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    return <Widget>[
      _buildBlock(_pad(h)),
      const Text(':', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600)),
      _buildBlock(_pad(m)),
      const Text(':', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600)),
      _buildBlock(_pad(s)),
    ];
  }

  Widget _buildBlock(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF2B2B2B), fontSize: 12.0, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
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

  /// 商品行(H5 goods-list .item)
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

    return Container(
      margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () => toDetail(item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: image.isEmpty
                  ? Container(
                      width: 110.0,
                      height: 110.0,
                      color: const Color(0xFFF5F5F5),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 28.0),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 110.0,
                      height: 110.0,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 110.0, height: 110.0, color: const Color(0xFFF5F5F5)),
                      errorWidget: (_, __, ___) => Container(
                        width: 110.0,
                        height: 110.0,
                        color: const Color(0xFFF5F5F5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: Color(0xFFDDDDDD), size: 28.0),
                      ),
                    ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: SizedBox(
                height: 110.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${item['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333), height: 1.3),
                    ),
                    // 抢购进度
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6.0),
                          child: SizedBox(
                            height: 10.0,
                            width: double.infinity,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFF0F0F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(aux),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          stock > 0 ? '仅剩$stock件' : '已抢完',
                          style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  const Text('¥', style: TextStyle(color: primary, fontSize: 11.0)),
                                  Text(
                                    _money(price),
                                    style: const TextStyle(
                                      color: primary,
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Arial',
                                    ),
                                  ),
                                ],
                              ),
                              if (origin > price)
                                Text(
                                  '原价 ¥${_money(origin)}',
                                  style: const TextStyle(
                                    color: Color(0xFF999999),
                                    fontSize: 11.0,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: canBuy ? () => toDetail(item) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                            decoration: BoxDecoration(
                              color: canBuy ? primary : const Color(0xFFDDDDDD),
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                            child: Text(
                              canBuy ? '马上抢' : (stock == 0 ? '已抢完' : '即将开始'),
                              style: const TextStyle(color: Colors.white, fontSize: 12.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(num v) => v.toStringAsFixed(2);

  String _pad(int v) => v < 10 ? '0$v' : '$v';
}
