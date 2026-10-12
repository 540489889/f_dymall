/// 赚钱页(推广中心): 收益概览 + 签到 + 立即提现 + 热门任务
/// * 界面参考用户提供的 UI 图
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../api/member.dart';
import '../../api/member_account.dart';
import '../../api/member_point.dart';
import '../../api/member_signin.dart';
import '../../api/member_withdraw.dart';
import '../../controller/auth_store.dart';
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

  // 收益数据(接口):
  // * 可提现 = 「我的余额」的现金余额(/api/memberaccount/info 的 balance_money)
  // * 金币位 = 会员积分(/api/memberaccount/point 的 point)
  double balanceMoney = 0.0;
  int point = 0;
  // 看视频任务加的金币(仅本地累计,暂不展示)
  int goldCoin = 12700;
  // 看视频任务: 今日已看次数 / 上限
  int videoWatched = 0;
  static const int videoTotal = 20;
  // 广告播放中: 防止连点重复拉广告
  bool adPlaying = false;

  // 签到: 走「每日签到」同一套规则(/api/membersignin/*), 不再用写死的演示奖励
  int signState = 0; // 签到开关(1 开启)
  int hasSign = 0; // 今日是否已签到
  int signDaysSeries = 0; // 连续签到天数
  int cycle = 0; // 周期天数
  List<Map<String, dynamic>> signRule = <Map<String, dynamic>>[]; // [{ day, point, growth }]
  bool signSubmitting = false;

  // 默认提现账户的收款授权(/api/memberbankaccount/defaultinfo)
  bool withdrawLoaded = false; // 是否已拉到账户信息
  bool withdrawAccountBound = false; // 是否已绑定提现账户
  bool withdrawIsWechat = false; // 默认账户是否微信
  bool withdrawAuthed = false; // 是否已微信免确认收款授权(auth_status != '0')

  /// 授权是否 OK: 已绑定账户,且微信账户已完成收款授权(与提现账户页 auth_status 同口径)
  bool get withdrawAuthOk => withdrawAccountBound && (!withdrawIsWechat || withdrawAuthed);

  /// 授权状态文案
  String get withdrawAuthText {
    if (!withdrawAccountBound) return '未绑定提现账户，绑定后才能提现';
    if (withdrawIsWechat && !withdrawAuthed) return '提现账户未微信免确认收款授权';
    return '提现账户已收款授权，提现免确认';
  }

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

  @override
  void initState() {
    super.initState();
    load();
    loadSignin();
    loadWithdrawAccount();
  }

  /// 现金余额 + 积分(并发拉取;失败静默,顶部保持 0,不影响其它板块)
  Future<void> load() async {
    try {
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberAccountApi.info(),
        MemberPointApi.point(),
      ]);
      if (!mounted) return;
      final Map<String, dynamic> account =
          res[0] is Map ? (res[0] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final Map<String, dynamic> pointInfo =
          res[1] is Map ? (res[1] as Map).cast<String, dynamic>() : <String, dynamic>{};
      setState(() {
        balanceMoney = double.tryParse('${account['balance_money'] ?? 0}') ?? 0;
        point = int.tryParse('${pointInfo['point'] ?? 0}') ?? 0;
      });
    } catch (_) {
      // 静默: 未登录/接口异常时保持 0
    }
  }

  /// 每日默认积分(规则里 day == 1 那条)
  int get signDefaultPoint {
    for (final Map<String, dynamic> item in signRule) {
      if ('${item['day']}' == '1') return int.tryParse('${item['point'] ?? 0}') ?? 0;
    }
    return signRule.isEmpty ? 0 : (int.tryParse('${signRule.first['point'] ?? 0}') ?? 0);
  }

  /// 今日/明日可领积分(每日奖励 + 命中连签额外奖励)
  int get signPointTomorrow {
    final int next = signDaysSeries + 1;
    int point = signDefaultPoint;
    for (final Map<String, dynamic> item in signRule) {
      if ('${item['day']}' == '$next') point += int.tryParse('${item['point'] ?? 0}') ?? 0;
    }
    return point;
  }

  /// 展示的天数窗口(与「每日签到」页 showSignDays 同逻辑: 最多 7 天,末位为周期大奖)
  List<Map<String, dynamic>> get signDays {
    int defaultPoint = 0;
    final Map<int, int> reward = <int, int>{};
    final List<int> rewardRuleDay = <int>[];
    for (final Map<String, dynamic> item in signRule) {
      final int day = int.tryParse('${item['day'] ?? 0}') ?? 0;
      final int point = int.tryParse('${item['point'] ?? 0}') ?? 0;
      if (day == 1) {
        defaultPoint = point;
      } else {
        rewardRuleDay.add(day);
        reward[day] = point;
      }
    }
    final int totalDay = cycle;
    int startDay = 1;
    int endDay = 7;
    if (signDaysSeries > 5) startDay = signDaysSeries - 5;
    if (totalDay >= signDaysSeries + 1) endDay = signDaysSeries + 1;
    if (signDaysSeries <= 5) endDay = 8 - startDay;
    if ((endDay - startDay) < 7 && totalDay >= startDay + 6) endDay = startDay + 6;
    if (totalDay == signDaysSeries && signDaysSeries > 0) {
      startDay = signDaysSeries - 6;
      endDay = signDaysSeries;
    }
    final List<Map<String, dynamic>> days = <Map<String, dynamic>>[];
    for (int i = 1; i <= totalDay; i++) {
      if (i >= startDay && i <= endDay) {
        days.add(<String, dynamic>{'day': i, 'is_last': 0, 'point': defaultPoint});
      }
    }
    if (days.isNotEmpty) days.last['is_last'] = 1;
    for (final Map<String, dynamic> item in days) {
      final int day = item['day'] as int;
      // 连签额外奖励 = 额外奖励 + 每日默认奖励
      if (rewardRuleDay.contains(day)) item['point'] = (reward[day] ?? 0) + defaultPoint;
    }
    return days;
  }

  /// 签到信息(开关 + 是否已签 + 周期奖励);商家未开启签到时整块不展示
  Future<void> loadSignin() async {
    try {
      final int state = await MemberSigninApi.status();
      if (!mounted || state != 1) return;
      // 逐个兜底,不能用裸的 Future.wait:
      // /api/member/info 需要登录,游客进页面时它一定会失败,一个失败会让整块签到卡都不显示
      // (游客看到的就是"没有签到板块"); 连续天数拿不到就按 0 处理,规则照常展示
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberApi.info().catchError((_) => null),
        MemberSigninApi.isSign().catchError((_) => 0),
        MemberSigninApi.award().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final dynamic info = res[0];
      final Map<String, dynamic> award =
          res[2] is Map ? (res[2] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final dynamic reward = award['reward'];
      setState(() {
        signState = state;
        if (info is Map) signDaysSeries = int.tryParse('${info['sign_days_series'] ?? 0}') ?? 0;
        hasSign = int.tryParse('${res[1]}') ?? 0;
        cycle = int.tryParse('${award['cycle'] ?? 0}') ?? 0;
        signRule = reward is List
            ? reward.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[];
      });
      if (kDebugMode) {
        debugPrint('[earn]签到: state=$state cycle=$cycle 规则${signRule.length}条 连签=$signDaysSeries 今日已签=$hasSign 有会员信息=${info is Map}');
      }
    } catch (_) {
      // 静默: 接口异常时不展示签到卡
    }
  }

  /// 默认提现账户 + 收款授权状态(/api/memberbankaccount/defaultinfo)
  /// * auth_status == '0' 为未授权(与提现账户页同口径),其它值视为已授权
  Future<void> loadWithdrawAccount() async {
    try {
      final Map<String, dynamic> info = await MemberWithdrawApi.accountDefaultInfo();
      if (!mounted) return;
      final int id = int.tryParse('${info['id'] ?? 0}') ?? 0;
      setState(() {
        withdrawLoaded = true;
        withdrawAccountBound = id > 0;
        withdrawIsWechat = '${info['withdraw_type'] ?? ''}' == 'wechatpay';
        withdrawAuthed = '${info['auth_status'] ?? ''}' != '0';
      });
    } catch (_) {
      // 静默: 未登录/接口异常时保持原说明文案
    }
  }

  /// 执行签到(/api/membersignin/signin)
  Future<void> _signin() async {
    if (signState != 1 || hasSign == 1 || signSubmitting) return;
    // 游客: 签到接口要求登录, 点了只会报错; 先去登录, 回来再刷一次签到状态
    if (!AuthStore.to.isLogin) {
      await Get.toNamed('/login');
      if (!mounted) return;
      await loadSignin();
      await load();
      return;
    }
    setState(() => signSubmitting = true);
    try {
      final Map<String, dynamic> tip = await MemberSigninApi.signin();
      if (!mounted) return;
      final int point = int.tryParse('${tip['point'] ?? 0}') ?? 0;
      MyDialog.toast(point > 0 ? '签到成功，获得${point}积分' : '签到成功');
      // 先本地置为已签(接口返回可能有延迟), 再拉最新规则
      if (mounted) {
        setState(() {
          hasSign = 1;
          signDaysSeries += 1;
        });
      }
      await loadSignin();
      await load();
    } catch (e) {
      if (mounted) MyDialog.toast(MemberSigninApi.errorMsg(e, '签到失败'));
    } finally {
      if (mounted) setState(() => signSubmitting = false);
    }
  }

  String _fmtCoin(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7EE),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSignIn()),
          // 立即提现: 暂时隐藏(板块代码仍在 _buildWithdraw, 要恢复就注掉下面这行前面的注释)
          // SliverToBoxAdapter(child: _buildWithdraw()),
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
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/make/qianyin_header_bg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24.0),
          bottomRight: Radius.circular(24.0),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: statusTop),
          // 标题(左右边距同卡片,和下面各板块左边缘对齐)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
          // 收益概览（整块统一橙色盒子）
          // * 左右边距与其它卡片(签到/热门任务)一致用 12, 否则盒子会比下面的卡片窄一截
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 6.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFE7A4E),
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    // 三列都垂直居中: 「去领取」是矮按钮, 顶部对齐会显得贴着上边
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(child: _headerCoinColumn()),
                      const SizedBox(width: 8.0),
                      Expanded(child: _headerWithdrawColumn()),
                      const SizedBox(width: 8.0),
                      // 第三列: 去掉「昨日待结算」, 换成从右上角移下来的「去领取」
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _headerClaimButton(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  // 底部说明（盒内：半透明白底 + 提现账户收款授权状态;未拉到数据时先显示原说明）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (!withdrawLoaded) ...<Widget>[
                          const Icon(Icons.verified_user, color: Colors.white, size: 14.0),
                          const SizedBox(width: 4.0),
                          const Text(
                            '现金余额可提现至微信账户',
                            style: TextStyle(color: Colors.white, fontSize: 11.0),
                          ),
                        ] else ...<Widget>[
                          Icon(
                            withdrawAuthOk ? Icons.verified_user : Icons.error_outline,
                            color: withdrawAuthOk ? Colors.white : coinGold,
                            size: 14.0,
                          ),
                          const SizedBox(width: 4.0),
                          Flexible(
                            child: Text(
                              withdrawAuthText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11.0),
                            ),
                          ),
                          if (!withdrawAuthOk) ...<Widget>[
                            const SizedBox(width: 6.0),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Get.toNamed('/my/withdraw_account'),
                              child: Text(
                                withdrawAccountBound ? '去授权' : '去绑定',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
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
              child: Text('我的积分', style: const TextStyle(color: Colors.white70, fontSize: 10.0), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                _fmtCoin(point),
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
                balanceMoney.toStringAsFixed(2),
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

  /// 「去领取」: 进申请提现页(/my/withdraw)
  Widget _headerClaimButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed('/my/withdraw'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/make/money_icon_sign_2.png', width: 16.0, height: 16.0, fit: BoxFit.contain),
            const SizedBox(width: 2.0),
            const Text('去领取', style: TextStyle(color: primary, fontSize: 12.0, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // 签到卡(规则取 /api/membersignin/award;商家未开启签到时整块不展示)
  Widget _buildSignIn() {
    final List<Map<String, dynamic>> days = signDays;
    if (signState != 1 || days.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 0.0),
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
              Text('$signPointTomorrow', style: const TextStyle(color: primary, fontSize: 16.0, fontWeight: FontWeight.w800)),
              const Text(' 积分', style: TextStyle(color: Colors.black87, fontSize: 16.0, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text('已连续签到$signDaysSeries天', style: const TextStyle(color: primary, fontSize: 10.0)),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          // 周期奖励窗口(第N天 + 可得积分, 已签到的高亮)
          Row(
            children: days.map((Map<String, dynamic> item) {
              final int day = item['day'] as int;
              final int point = item['point'] as int;
              final bool isLast = '${item['is_last']}' == '1';
              final bool signed = day <= signDaysSeries;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0.0 : 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        decoration: BoxDecoration(
                          color: signed ? primary : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            isLast
                                ? Icon(Icons.card_giftcard, size: 22.0, color: signed ? Colors.white : const Color(0xFFCCCCCC))
                                : Image.asset('assets/images/sign-icon.png', width: 22.0, height: 22.0, fit: BoxFit.contain),
                            const SizedBox(height: 4.0),
                            Text('+$point', style: TextStyle(color: signed ? Colors.white : const Color(0xFFFFA500), fontSize: 11.0, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text('第$day天', style: const TextStyle(color: Colors.black54, fontSize: 10.0)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14.0),
          // 签到按钮
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (hasSign == 1 || signSubmitting) ? null : _signin,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                gradient: hasSign == 1 ? null : const LinearGradient(colors: <Color>[Color(0xFFFF9A70), primary]),
                color: hasSign == 1 ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(hasSign == 1 ? Icons.check_circle_outline : Icons.calendar_today, color: Colors.white, size: 16.0),
                  const SizedBox(width: 4.0),
                  Text(
                    hasSign == 1 ? '今日已签到' : '签到领$signPointTomorrow积分',
                    style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 立即提现卡(暂时不展示: 见 build 里的注释, 恢复时把 build 那行注回来)
  // ignore: unused_element
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
