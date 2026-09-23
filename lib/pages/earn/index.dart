/// 赚钱页(推广中心): 收益概览 + 签到 + 立即提现 + 日常任务
/// * 界面参考用户提供的截图: 顶部红色收益卡 / 签到 / 提现 / 任务列表
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
  static const Color primary = Color(0xFFFF2C55);
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

  // 日常任务
  final List<Map<String, dynamic>> tasks = const <Map<String, dynamic>>[
    {
      'icon': Icons.live_tv_rounded,
      'bg': Color(0xFFEBF5FF),
      'iconColor': Color(0xFF4A90FF),
      'title': '看视频获取金币',
      'top': '最高共',
      'topValue': 160,
      'unit': '金币',
      'desc': '看视频可得丰厚金币奖励',
      'progress': '',
      'btn': '去领取',
      // 看视频 -> 激励视频, 看完才发金币
      'adType': 'reward',
      'done': false,
    },
    {
      'icon': Icons.ramen_dining_rounded,
      'bg': Color(0xFFFFF1F2),
      'iconColor': Color(0xFFFF2C55),
      'title': '吃饭领金币',
      'top': '最高共',
      'topValue': 210,
      'unit': '金币',
      'desc': '午餐补贴发放中·每日 11:30-13:30',
      'progress': '',
      'btn': '去领取',
      // 其他任务 -> 插屏广告
      'adType': 'interstitial',
      'done': false,
    },
    {
      'icon': Icons.local_florist_rounded,
      'bg': Color(0xFFFFF7F7),
      'iconColor': Color(0xFFFF6B8A),
      'title': '逛乐惠圈赚金币',
      'top': '最高共',
      'topValue': 100,
      'unit': '金币',
      'desc': '发布动态、点赞、评论均可获得',
      'progress': '',
      'btn': '去逛逛',
      'adType': 'interstitial',
      'done': false,
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSignIn()),
          SliverToBoxAdapter(child: _buildWithdraw()),
          SliverToBoxAdapter(child: _buildDailyTasks()),
          // Banner 广告位(未配置广告位时不展示)
          if (AdsConfig.enabled && AdsConfig.bannerId.isNotEmpty)
            SliverToBoxAdapter(child: _buildBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
        ],
      ),
    );
  }

  // 顶部红色收益卡
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF4D5F), Color(0xFFFF2C55)],
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 我的金币 / 可提现 / 去领取
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 我的金币
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text('我的金币', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
                            const SizedBox(width: 2.0),
                            Icon(Icons.help_outline, color: Colors.white.withAlpha(180), size: 12.0),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          _fmtCoin(goldCoin),
                          style: const TextStyle(color: coinGold, fontSize: 28.0, fontWeight: FontWeight.w900, fontFamily: 'Arial'),
                        ),
                      ],
                    ),
                  ),
                  // 可提现
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('可提现（元）', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
                        const SizedBox(height: 4.0),
                        Text(
                          balance.toStringAsFixed(2),
                          style: const TextStyle(color: Colors.white, fontSize: 28.0, fontWeight: FontWeight.w900, fontFamily: 'Arial'),
                        ),
                      ],
                    ),
                  ),
                  // 去领取
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.check, color: primary, size: 14.0),
                        SizedBox(width: 2.0),
                        Text('去领取', style: TextStyle(color: primary, fontSize: 13.0, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              // 昨日待结算
              Row(
                children: <Widget>[
                  const Text('昨日待结算：', style: TextStyle(color: Colors.white70, fontSize: 11.0)),
                  Text('¥${yesterdayPending.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8.0),
              // 底部说明
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Text(
                  '现金余额可提现至微信账户',
                  style: TextStyle(color: Colors.white70, fontSize: 11.0),
                ),
              ),
            ],
          ),
        ),
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
          const SizedBox(height: 12.0),
          // 7 天签到
          Row(
            children: List<Widget>.generate(signRewards.length, (int i) {
              final DateTime day = now.add(Duration(days: i));
              final String dateText = i == 0 ? '今天' : '${day.month}/${day.day}';
              final bool isToday = i == 0;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == signRewards.length - 1 ? 0.0 : 6.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFFFFF1F2) : const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isToday)
                        const Icon(Icons.monetization_on, color: primary, size: 16.0)
                      else
                        const Icon(Icons.monetization_on, color: Color(0xFFFFD6A0), size: 16.0),
                      const SizedBox(height: 2.0),
                      Text('+${signRewards[i]}', style: TextStyle(color: isToday ? primary : const Color(0xFFFFA500), fontSize: 11.0, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4.0),
                      Text(dateText, style: const TextStyle(color: Colors.black54, fontSize: 10.0)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12.0),
          // 领取按钮
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.check, color: Colors.white, size: 16.0),
                const SizedBox(width: 4.0),
                // 两段文案都可伸缩: 小屏窄卡片上也不会把按钮撑爆(原来会右溢出)
                Flexible(
                  child: const Text(
                    '已领取 120 金币',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w700),
                  ),
                ),
                const Text('·', style: TextStyle(color: Colors.white70, fontSize: 14.0)),
                Flexible(
                  child: const Text(
                    '明天再来领 +30',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w700),
                  ),
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
            width: 46.0,
            height: 46.0,
            decoration: BoxDecoration(
              color: primary.withAlpha(18),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: const Icon(Icons.card_giftcard, color: primary, size: 24.0),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text('+${todayWithdraw.toStringAsFixed(1)}', style: const TextStyle(color: primary, fontSize: 10.0, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('天天赚', style: TextStyle(color: Colors.white, fontSize: 10.0)),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                const Text('福利用户专属，每日可提', style: TextStyle(color: Colors.black45, fontSize: 11.0)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: const Text('去提现', style: TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 日常任务
  Widget _buildDailyTasks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0.0),
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.redeem, color: primary, size: 20.0),
              const SizedBox(width: 6.0),
              const Text('日常任务', style: TextStyle(color: Colors.black87, fontSize: 16.0, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6.0),
          Column(
            children: tasks.map((Map<String, dynamic> task) {
              final bool done = task['done'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: task['bg'] as Color,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(task['icon'] as IconData, color: task['iconColor'] as Color, size: 22.0),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              // 标题可伸缩: 任务名过长时省略, 不会把右侧的"最高共xxx金币"挤出边界
                              Flexible(
                                child: Text(
                                  '${task['title']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black87, fontSize: 14.0, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                '${task['top']}',
                                style: const TextStyle(color: Colors.black45, fontSize: 11.0),
                              ),
                              Text(
                                '${task['topValue']}',
                                style: const TextStyle(color: Color(0xFFFFA500), fontSize: 11.0, fontWeight: FontWeight.w700),
                              ),
                              const Text(' 金币', style: TextStyle(color: Colors.black45, fontSize: 11.0)),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            // 看视频任务显示真实进度(0/20)
                            '${task['desc']}${task['adType'] == 'reward' ? ' ($videoWatched/$videoTotal)' : '${task['progress']}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black45, fontSize: 11.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      onTap: () => _onTaskTap(task),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: done ? const Color(0xFFF5F5F5) : primary,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          done ? '已完成' : '${task['btn']}',
                          style: TextStyle(
                            color: done ? Colors.black38 : Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  // 任务按钮: 激励视频看完才发金币, 其他任务走插屏
  Future<void> _onTaskTap(Map<String, dynamic> task) async {
    if (adPlaying) return;
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
