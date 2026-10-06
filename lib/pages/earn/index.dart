/// 赚钱页(推广中心): 收益概览 + 签到 + 立即提现 + 热门任务
/// * 界面参考用户提供的 UI 图
library;

import 'package:flutter/material.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../utils/ads.dart';
import '../../utils/ads_config.dart';

class EarnPage extends StatefulWidget {
  const EarnPage({super.key});

  @override
  State<EarnPage> createState() => _EarnPageState();
}

class _EarnPageState extends State<EarnPage> {
  // 主色
  static const Color primary = Color(0xFFFF5C33);
  static const Color coinGold = Color(0xFFFFE08A);

  // 收益数据: 接接口后替换
  // * /api/member/info 的 balance_money 是可提现余额, 金币/累计收益接口待补
  int goldCoin = 12700; // 可变: 看完激励视频要加金币
  final double balance = 27.10;
  final double yesterdayPending = 0.30;
  // 看视频任务: 今日已看次数 / 上限
  int videoWatched = 0;
  static const int videoTotal = 20;
  // 广告播放中: 防止连点重复拉广告
  bool adPlaying = false;

  // 签到数据(演示): 今天已领, 明天起递增
  final int signBase = 120;
  final List<int> signRewards = const <int>[120, 30, 40, 50, 60, 80];

  // 立即提现
  final double todayWithdraw = 0.30;

  // 热门任务
  final List<Map<String, dynamic>> tasks = const <Map<String, dynamic>>[
    {
      'icon': 'assets/images/make/money_task_redpacket.png',
      'title': '签到领红包',
      'desc': '连续签到7天，最高可得10元红包',
      'reward': '+1.00 ~ 10.00 元',
      'btn': '去完成',
      'done': false,
      'adType': 'interstitial',
    },
    {
      'icon': 'assets/images/make/money_task_invite.png',
      'title': '邀请好友得佣金',
      'desc': '好友首次下载并注册，双方都得奖励',
      'reward': '+3.00 ~ 20.00 元',
      'btn': '去完成',
      'done': false,
      'adType': 'interstitial',
    },
    {
      'icon': 'assets/images/make/money_task_browse.png',
      'title': '浏览商品赚金币',
      'desc': '浏览商品30秒，轻松赚金币',
      'reward': '+50 ~ 200 金币',
      'btn': '去完成',
      'done': false,
      'adType': 'interstitial',
    },
    {
      'icon': 'assets/images/make/money_task_share.png',
      'title': '分享直播间',
      'desc': '分享直播间到社交平台，获得奖励',
      'reward': '+0.50 ~ 5.00 元',
      'btn': '去完成',
      'done': false,
      'adType': 'interstitial',
    },
    {
      'icon': 'assets/images/make/money_task_order.png',
      'title': '完成订单返积分',
      'desc': '下单并确认收货，获得积分奖励',
      'reward': '+100 ~ 500 积分',
      'btn': '去完成',
      'done': false,
      'adType': 'interstitial',
    },
  ];

  String _fmtCoin(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSignIn()),
          SliverToBoxAdapter(child: _buildWithdraw()),
          SliverToBoxAdapter(child: _buildHotTasks()),
          // Banner 广告位(未配置广告位时不展示)
          if (AdsConfig.enabled && AdsConfig.bannerId.isNotEmpty)
            SliverToBoxAdapter(child: _buildBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
        ],
      ),
    );
  }

  // 顶部橙色区域：标题 + 收益概览 + 去领取
  Widget _buildHeader() {
    final double statusTop = MediaQuery.of(context).padding.top;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF7A50), Color(0xFFFF5C33)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24.0),
          bottomRight: Radius.circular(24.0),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: const HeaderPatternPainter()),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: statusTop),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                const Text(
                  '赚钱',
                  style: TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4.0),
                Icon(Icons.sync, color: Colors.white.withAlpha(230), size: 16.0),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          // 收益概览
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _headerCoinColumn()),
                  const SizedBox(width: 8.0),
                  Expanded(child: _headerWithdrawColumn()),
                  const SizedBox(width: 8.0),
                  Expanded(child: _headerPendingColumn()),
                  const SizedBox(width: 10.0),
                  _headerClaimButton(),
                ],
              ),
            ),
          ),
          // 底部说明
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const Text(
                '现金余额可提现至微信账户',
                style: TextStyle(color: Colors.white70, fontSize: 11.0),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
  }

  Widget _headerCoinColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text('我的金币', style: const TextStyle(color: Colors.white70, fontSize: 10.0), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 2.0),
            Icon(Icons.help_outline, color: Colors.white.withAlpha(180), size: 11.0),
          ],
        ),
        const SizedBox(height: 6.0),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _fmtCoin(goldCoin),
                style: const TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w900, fontFamily: 'Arial'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerWithdrawColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text('可提现（元）', style: const TextStyle(color: Colors.white70, fontSize: 10.0), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 2.0),
            Icon(Icons.help_outline, color: Colors.white.withAlpha(180), size: 11.0),
          ],
        ),
        const SizedBox(height: 6.0),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                balance.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w900, fontFamily: 'Arial'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerPendingColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('昨日待结算', style: TextStyle(color: Colors.white70, fontSize: 10.0)),
        const SizedBox(height: 6.0),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${yesterdayPending.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.w900, fontFamily: 'Arial'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerClaimButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.monetization_on, color: primary, size: 12.0),
          SizedBox(width: 2.0),
          Text('去领取', style: TextStyle(color: primary, fontSize: 12.0, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // 签到卡
  Widget _buildSignIn() {
    final DateTime now = DateTime.now();
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标题行
          Row(
            children: <Widget>[
              const Icon(Icons.calendar_today, color: primary, size: 20.0),
              const SizedBox(width: 6.0),
              const Text('签到领 ', style: TextStyle(color: Colors.black87, fontSize: 16.0, fontWeight: FontWeight.w800)),
              Text('$signBase', style: const TextStyle(color: primary, fontSize: 16.0, fontWeight: FontWeight.w800)),
              const Text(' 金币', style: TextStyle(color: Colors.black87, fontSize: 16.0, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Text('最多领120金币', style: TextStyle(color: primary, fontSize: 10.0)),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          // 6 天签到
          Row(
            children: List<Widget>.generate(signRewards.length, (int i) {
              final DateTime day = now.add(Duration(days: i));
              final String dateText = i == 0 ? '今天' : '${day.month}/${day.day}';
              final bool isToday = i == 0;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == signRewards.length - 1 ? 0.0 : 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        decoration: BoxDecoration(
                          color: isToday ? primary : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Image.asset(
                              isToday
                                  ? 'assets/images/make/money_icon_sign_1.png'
                                  : 'assets/images/make/money_icon_sign_${i + 1}.png',
                              width: isToday ? 28.0 : 22.0,
                              height: isToday ? 28.0 : 22.0,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 4.0),
                            Text('+${signRewards[i]}', style: TextStyle(color: isToday ? Colors.white : const Color(0xFFFFA500), fontSize: 11.0, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(dateText, style: const TextStyle(color: Colors.black54, fontSize: 10.0)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14.0),
          // 签到按钮
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFF9A70), primary],
              ),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                Icon(Icons.calendar_today, color: Colors.white, size: 16.0),
                SizedBox(width: 4.0),
                Text(
                  '签到领120金币',
                  style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 立即提现卡
  Widget _buildWithdraw() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0.0),
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: primary.withAlpha(18),
              borderRadius: BorderRadius.circular(28.0),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/make/money_icon_gift.png',
                width: 44.0,
                height: 44.0,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('立即提现', style: TextStyle(color: Colors.black87, fontSize: 15.0, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6.0),
                    Text(
                      todayWithdraw.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.black87, fontSize: 15.0, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('天天提', style: TextStyle(color: primary, fontSize: 10.0, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6.0),
                    const Text('福利用户专属，每日可提', style: TextStyle(color: Colors.black45, fontSize: 11.0)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: const Text('去提现', style: TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 热门任务
  Widget _buildHotTasks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: const <Widget>[
                      Icon(Icons.local_fire_department, color: primary, size: 20.0),
                      SizedBox(width: 6.0),
                      Text('热门任务', style: TextStyle(color: Colors.black87, fontSize: 16.0, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Column(
                    children: tasks.map((Map<String, dynamic> task) {
                      final bool done = task['done'] == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 56.0,
                              height: 56.0,
                              decoration: BoxDecoration(
                                color: primary.withAlpha(18),
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                              child: Center(
                                child: Image.asset(
                                  '${task['icon']}',
                                  width: 44.0,
                                  height: 44.0,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    '${task['title']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black87, fontSize: 14.0, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '${task['desc']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black45, fontSize: 11.0),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '${task['reward']}',
                                    style: const TextStyle(color: Color(0xFFFFA500), fontSize: 12.0, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            GestureDetector(
                              onTap: () => _onTaskTap(task),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                decoration: BoxDecoration(
                                  color: done ? const Color(0xFFF5F5F5) : primary,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      done ? '已完成' : '${task['btn']}',
                                      style: TextStyle(
                                        color: done ? Colors.black38 : Colors.white,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (!done) ...[
                                      const SizedBox(width: 2.0),
                                      const Icon(Icons.chevron_right, color: Colors.white, size: 12.0),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 任务按钮: 激励视频看完才发金币, 其他任务走插屏
  Future<void> _onTaskTap(Map<String, dynamic> task) async {
    if (adPlaying) return;
    // H5 没有广告实现: 直接提示, 不进广告流程(否则报 MissingPluginException)
    if (!Ads.supported) {
      MyDialog.toast('当前环境暂不支持广告');
      return;
    }
    final String adType = '${task['adType'] ?? ''}';
    setState(() => adPlaying = true);
    try {
      if (adType == 'reward') {
        final bool rewarded = await Ads.showRewardVideo(customData: 'earn_video', userId: '$goldCoin');
        if (!mounted) return;
        if (!rewarded) {
          // 区分三种 false: 没配广告位 / 广告没拉起来(有 errCode) / 视频没看完
          final String msg = AdsConfig.rewardVideoId.isEmpty
              ? '激励视频广告位未配置'
              : (Ads.lastErrorCode == 0 && Ads.lastErrorMessage.isEmpty
                  ? '看完视频才能领取金币'
                  : '广告加载失败，请稍后再试');
          MyDialog.toast(msg);
          return;
        }
        setState(() {
          if (videoWatched < videoTotal) videoWatched += 1;
          goldCoin += 60;
        });
        MyDialog.toast('已领取 60 金币');
      } else {
        await Ads.showInterstitial();
        if (!mounted) return;
        if (AdsConfig.interstitialId.isEmpty) MyDialog.toast('插屏广告位未配置');
      }
    } finally {
      if (mounted) setState(() => adPlaying = false);
    }
  }

  // 底部 Banner 广告位
  Widget _buildBanner() {
    // H5 不支持广告: 整块不渲染(否则只剩一个空白白卡)
    if (!Ads.supported) return const SizedBox.shrink();
    // 模板按 600x150 创建, 高度同比例换算, 避免广告被拉伸
    final double width = MediaQuery.of(context).size.width - 24.0 - 12.0;
    final double height = width * 150 / 600;
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0.0),
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: AdsBanner(
        posId: AdsConfig.bannerId,
        width: width,
        height: height,
        refreshSeconds: 30,
      ),
    );
  }
}

/// 赚钱页顶部背景装饰花纹：右上角大弧形光斑 + 底部波浪 + 小圆点
class HeaderPatternPainter extends CustomPainter {
  const HeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 顶部右侧大弧形光斑
    final Paint highlight = Paint()
      ..color = const Color(0xFFFFF8F5).withAlpha(35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.width * 0.45,
      highlight,
    );

    // 底部波浪纹理
    final Paint wave = Paint()
      ..color = const Color(0xFFFFF8F5).withAlpha(22)
      ..style = PaintingStyle.fill;

    final Path wavePath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.68,
        size.width * 0.55,
        size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.92,
        size.width,
        size.height * 0.74,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(wavePath, wave);

    // 小装饰圆点
    final Paint dot = Paint()
      ..color = const Color(0xFFFFF8F5).withAlpha(40)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.35),
      size.width * 0.08,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
