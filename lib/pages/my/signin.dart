/// 每日签到
/// 对齐 H5: pages_tool/member/signin.vue + public/js/signin.js
/// * 签到开关 /api/membersignin/getSignStatus,未开启提示并返回
/// * 今日是否签到 /api/membersignin/issign;连续天数 sign_days_series 取自 /api/member/info
/// * 周期奖励 /api/membersignin/award(cycle + reward),按连续天数展示 7 天窗口
/// * 签到 /api/membersignin/signin;累计积分/成长值 /api/memberaccount/sum
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member.dart';
import '../../api/member_signin.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  static const Color primary = Color(0xFFF16914);
  static const LinearGradient topGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF16914), Color(0xFFFEAA4C)],
  );

  bool loading = true;
  String errorMsg = '';
  bool submitting = false;

  /// 签到开关(1 开启)
  int signState = 0;
  /// 今日是否已签到
  int hasSign = 0;
  /// 连续签到天数
  int signDaysSeries = 0;
  /// 周期天数
  int cycle = 0;
  /// 奖励规则 [{ day, point, growth }]
  List<Map<String, dynamic>> rule = <Map<String, dynamic>>[];
  /// 签到累计积分 / 成长值
  num signPoint = 0;
  num signGrowth = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 明日(未签到则今日)可获得的积分(H5 pointTomorrow)
  int get pointTomorrow {
    final int next = signDaysSeries + 1;
    int point = rule.isNotEmpty ? (int.tryParse('${rule.first['point'] ?? 0}') ?? 0) : 0;
    for (final Map<String, dynamic> item in rule) {
      if ('${item['day']}' == '$next') point += int.tryParse('${item['point'] ?? 0}') ?? 0;
    }
    return point;
  }

  /// 展示的天数窗口(H5 getRule 里的 showSignDays: 最多 7 天,末位为周期大奖)
  List<Map<String, dynamic>> get showSignDays {
    int defaultPoint = 0;
    final Map<int, int> reward = <int, int>{};
    final List<int> rewardRuleDay = <int>[];
    for (final Map<String, dynamic> item in rule) {
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

  /// 签到信息(H5 onShow: 开关 + 是否签到 + 规则 + 累计)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final int state = await MemberSigninApi.status();
      if (!mounted) return;
      if (state != 1) {
        MyDialog.toast('商家未开启会员签到');
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (mounted) Get.back();
        return;
      }
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberApi.info(),
        MemberSigninApi.isSign(),
        MemberSigninApi.award(),
        MemberSigninApi.sum(accountType: 'point'),
        MemberSigninApi.sum(accountType: 'growth'),
      ]);
      if (!mounted) return;
      final dynamic info = res[0];
      final Map<String, dynamic> award = res[2] is Map ? (res[2] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final dynamic reward = award['reward'];
      setState(() {
        signState = state;
        if (info is Map) signDaysSeries = int.tryParse('${info['sign_days_series'] ?? 0}') ?? 0;
        hasSign = int.tryParse('${res[1]}') ?? 0;
        cycle = int.tryParse('${award['cycle'] ?? 0}') ?? 0;
        rule = reward is List
            ? reward.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[];
        signPoint = res[3] is num ? res[3] as num : 0;
        signGrowth = res[4] is num ? res[4] as num : 0;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberSigninApi.errorMsg(e, '签到信息加载失败');
        loading = false;
      });
    }
  }

  /// 签到(H5 sign)
  Future<void> sign() async {
    if (signState != 1) {
      MyDialog.toast('签到未开启');
      return;
    }
    if (hasSign == 1 || submitting) return;
    setState(() => submitting = true);
    try {
      final Map<String, dynamic> tip = await MemberSigninApi.signin();
      if (!mounted) return;
      setState(() {
        hasSign = 1;
        signDaysSeries += 1;
        submitting = false;
      });
      await showRewardDialog(tip);
      // 刷新累计积分 / 成长值
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberSigninApi.sum(accountType: 'point'),
        MemberSigninApi.sum(accountType: 'growth'),
        MemberSigninApi.award(),
      ]);
      if (!mounted) return;
      setState(() {
        signPoint = res[0] is num ? res[0] as num : 0;
        signGrowth = res[1] is num ? res[1] as num : 0;
        if (res[2] is Map) {
          final Map<String, dynamic> award = (res[2] as Map).cast<String, dynamic>();
          cycle = int.tryParse('${award['cycle'] ?? 0}') ?? 0;
          final dynamic reward = award['reward'];
          if (reward is List) {
            rule = reward.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      MyDialog.toast(MemberSigninApi.errorMsg(e, '签到失败'));
    }
  }

  /// 签到成功弹窗(H5 uni-popup: 恭喜您获得 X 积分 / X 成长值)
  Future<void> showRewardDialog(Map<String, dynamic> tip) async {
    final int point = int.tryParse('${tip['point'] ?? 0}') ?? 0;
    final int growth = int.tryParse('${tip['growth'] ?? 0}') ?? 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20.0, 26.0, 20.0, 22.0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.card_giftcard, color: primary, size: 44.0),
                const SizedBox(height: 12.0),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15.0, color: Color(0xFF333333)),
                    children: <TextSpan>[
                      const TextSpan(text: '恭喜您获得 '),
                      if (point > 0)
                        TextSpan(
                          text: '$point',
                          style: const TextStyle(color: primary, fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                      if (point > 0) const TextSpan(text: ' 积分'),
                      if (point > 0 && growth > 0) const TextSpan(text: ' '),
                      if (growth > 0)
                        TextSpan(
                          text: '$growth',
                          style: const TextStyle(color: primary, fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                      if (growth > 0) const TextSpan(text: ' 成长值'),
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text('连续签到可获得更多奖励！', style: TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                const SizedBox(height: 18.0),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(primary),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('知道啦', style: TextStyle(fontSize: 15.0)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        title: const Text('每日签到', style: TextStyle(fontSize: 17.0, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return _buildPlain(
        const CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
      );
    }
    if (errorMsg.isNotEmpty) return _buildPlain(_buildError());
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(),
          if (showSignDays.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12.0),
            _buildDays(),
          ],
          const SizedBox(height: 12.0),
          _buildSummary(),
          if (rule.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12.0),
            _buildRule(),
          ],
          const SizedBox(height: 20.0),
        ],
      ),
    );
  }

  /// 顶部: 左侧头像 + 连续签到天数 + 可获积分,右侧签到按钮(对齐 H5 member-info)
  Widget _buildHeader() {
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    final bool signed = hasSign == 1;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.0, top + 22.0, 16.0, 30.0),
      decoration: const BoxDecoration(
        gradient: topGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(220.0, 30.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 50.0,
            height: 50.0,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.person, color: primary.withAlpha(220), size: 28.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                    children: <TextSpan>[
                      const TextSpan(text: '已连续签到 '),
                      TextSpan(
                        text: '$signDaysSeries',
                        style: const TextStyle(fontSize: 19.0),
                      ),
                      const TextSpan(text: ' 天'),
                    ],
                  ),
                ),
                const SizedBox(height: 9.0),
                Text(
                  signed ? '今日已签到，明日再来' : '今日签到可获得 $pointTomorrow 积分',
                  style: const TextStyle(fontSize: 12.0, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          _buildSignButton(),
        ],
      ),
    );
  }

  /// 签到按钮(H5 point-box: 未签到白底橙字,已签到半透明白底弱化)
  Widget _buildSignButton() {
    final bool signed = hasSign == 1;
    return GestureDetector(
      onTap: sign,
      child: Container(
        height: 36.0,
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        decoration: BoxDecoration(
          color: signed ? Colors.white.withAlpha(60) : Colors.white,
          borderRadius: BorderRadius.circular(18.0),
          boxShadow: signed
              ? null
              : <BoxShadow>[
                  BoxShadow(color: Colors.black.withAlpha(35), blurRadius: 8.0, offset: const Offset(0, 3)),
                ],
        ),
        alignment: Alignment.center,
        child: submitting
            ? SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(signed ? Colors.white : primary),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    signed ? Icons.check_circle_outline : Icons.edit_calendar_outlined,
                    size: 16.0,
                    color: signed ? Colors.white : primary,
                  ),
                  const SizedBox(width: 5.0),
                  Text(
                    signed ? '已签到' : '签到',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: signed ? Colors.white : primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 连续签到天数窗口(H5 signin-day-list)
  Widget _buildDays() {
    final List<Map<String, dynamic>> days = showSignDays;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 14.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('连续签到领好礼', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14.0),
          Row(
            children: days.map((Map<String, dynamic> item) {
              final int day = item['day'] as int;
              final int point = item['point'] as int;
              final bool isLast = '${item['is_last']}' == '1';
              final bool signed = day <= signDaysSeries;
              return Expanded(child: _buildDay(day, point, signed: signed, isLast: isLast));
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 单天(非末位: 天数 + 图标 + 积分;末位: 宝箱)
  Widget _buildDay(int day, int point, {required bool signed, required bool isLast}) {
    final Color textColor = signed ? primary : const Color(0xFF999999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '第$day天',
          style: TextStyle(fontSize: 11.0, color: signed ? const Color(0xFF333333) : const Color(0xFF999999)),
        ),
        const SizedBox(height: 6.0),
        Container(
          width: 38.0,
          height: 38.0,
          decoration: BoxDecoration(
            color: signed ? const Color(0xFFFFF3E6) : const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isLast
              ? Icon(Icons.card_giftcard, size: 20.0, color: signed ? primary : const Color(0xFFCCCCCC))
              : Image.asset('assets/images/sign-icon.png', width: 22.0, height: 22.0),
        ),
        const SizedBox(height: 6.0),
        Text('$point积分', style: TextStyle(fontSize: 11.0, color: textColor)),
      ],
    );
  }

  /// 我的签到(累计积分 / 累计成长值)
  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('我的签到', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12.0),
          Row(
            children: <Widget>[
              _buildSummaryItem('积分：$signPoint', '累计获得积分', const Color(0xFFFFF7E6)),
              const SizedBox(width: 10.0),
              _buildSummaryItem('成长值：$signGrowth', '累计获得成长值', const Color(0xFFFFEEF2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8.0)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 4.0),
            Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  /// 签到规则(H5 signin-rule)
  Widget _buildRule() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('签到规则', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10.0),
          for (int i = 0; i < rule.length; i++) _buildRuleItem(_ruleText(i)),
          _buildRuleItem('${rule.length + 1}.连续签到$cycle天为一个周期，连续签到天数签满一个周期或者签到中断，将清空连签天数重新计算签到天数'),
          _buildRuleItem('${rule.length + 2}. 用户可在签到页每日签到一次，签到后可获得每日签到奖励；连续签到天数达到连签奖励的当天，可额外获得连签奖励'),
        ],
      ),
    );
  }

  /// 规则文案(第一条为每日签到奖励,其余为连签额外奖励)
  String _ruleText(int index) {
    final Map<String, dynamic> item = rule[index];
    final int point = int.tryParse('${item['point'] ?? 0}') ?? 0;
    final int growth = int.tryParse('${item['growth'] ?? 0}') ?? 0;
    final StringBuffer buffer = StringBuffer();
    if (index == 0) {
      buffer.write('1. 每日签到奖励：');
    } else {
      buffer.write('${index + 1}. 连续签到${item['day']}天额外奖励：');
    }
    if (point > 0) buffer.write('${point}积分 ');
    if (growth > 0) buffer.write('${growth}成长值');
    return buffer.toString();
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888), height: 1.5)),
    );
  }

  /// 非内容态(加载/失败)顶部补一段渐变
  Widget _buildPlain(Widget child) {
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          height: top + 24.0,
          decoration: const BoxDecoration(gradient: topGradient),
        ),
        Expanded(child: Center(child: child)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
        const SizedBox(height: 12.0),
        OutlinedButton(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(primary),
            side: WidgetStateProperty.all(const BorderSide(color: primary)),
          ),
          onPressed: load,
          child: const Text('重新加载', style: TextStyle(fontSize: 14.0)),
        ),
      ],
    );
  }
}
