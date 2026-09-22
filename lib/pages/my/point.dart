/// 我的积分
/// 对齐 H5: pages_tool/member/point.vue
/// * 积分汇总 /api/memberaccount/point(point 当前 / point_all 累计 / point_use 累计消费 / point_today 今日)
/// * 积分规则 /api/config/getPointRuleConfig(底部弹窗展示富文本)
/// * 菜单: 积分明细;积分商城(插件页,Flutter 端提示待接入)
/// * 任务: 每日签到(signin);购买商品(去首页)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_point.dart';
import '../../styles/index.dart';

class PointPage extends StatefulWidget {
  const PointPage({super.key});

  @override
  State<PointPage> createState() => _PointPageState();
}

class _PointPageState extends State<PointPage> {
  static const Color primary = Color(0xFFF16914);
  /// 顶部渐变(橙黄,与签到页一致)
  static const LinearGradient topGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF16914), Color(0xFFFEAA4C)],
  );

  Map<String, dynamic> pointInfo = <String, dynamic>{};
  String rule = '';
  bool loading = true;
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 当前积分
  int get point => int.tryParse('${pointInfo['point'] ?? 0}') ?? 0;

  /// 累计积分(point_all)
  int get totalPoint => int.tryParse('${pointInfo['point_all'] ?? 0}') ?? 0;

  /// 累计消费(point_use)
  int get totalConsume => int.tryParse('${pointInfo['point_use'] ?? 0}') ?? 0;

  /// 今日获得(point_today)
  int get todayPoint => int.tryParse('${pointInfo['point_today'] ?? 0}') ?? 0;

  /// 积分汇总 + 积分规则(规则失败不影响积分展示)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        MemberPointApi.point(),
        MemberPointApi.ruleConfig(),
      ]);
      if (!mounted) return;
      setState(() {
        pointInfo = res[0] is Map ? (res[0] as Map).cast<String, dynamic>() : <String, dynamic>{};
        rule = res[1] is String ? res[1] as String : '';
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberPointApi.errorMsg(e, '积分加载失败');
        loading = false;
      });
    }
  }

  /// 积分规则弹窗(H5 uni-popup 底部弹出)
  Future<void> openRule() async {
    if (rule.isEmpty) {
      MyDialog.toast('暂无积分说明');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: const Text('积分说明', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(15.0),
                  child: Html(data: rule, shrinkWrap: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // 渐变延伸到状态栏 + 标题栏,AppBar 透明浮在上面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        title: const Text('我的积分', style: TextStyle(fontSize: 17.0, color: Colors.white)),
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
        const CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (pointInfo.isEmpty && errorMsg.isNotEmpty) return _buildPlain(_buildError());
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12.0),
          _buildMenus(),
          const SizedBox(height: 12.0),
          _buildTasks(),
        ],
      ),
    );
  }

  /// 非内容态(加载/失败)顶部补一段渐变,避免透明 AppBar 下露出灰底
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

  /// 加载失败(接口报错)
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

  /// 顶部积分卡(H5 head-wrap: 橙黄渐变 + 当前积分 + 累计/消费/今日)
  Widget _buildHeader() {
    final double top = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.0, top + 20.0, 16.0, 24.0),
      decoration: const BoxDecoration(
        gradient: topGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$point',
            style: const TextStyle(color: Colors.white, fontSize: 40.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              const Text('当前积分', style: TextStyle(color: Colors.white70, fontSize: 13.0)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: openRule,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('积分规则', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                      Icon(Icons.chevron_right, color: Colors.white, size: 16.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Row(
            children: <Widget>[
              _buildSubItem('累计积分', totalPoint),
              Container(width: 0.5, height: 24.0, color: Colors.white30),
              _buildSubItem('累计消费', totalConsume),
              Container(width: 0.5, height: 24.0, color: Colors.white30),
              _buildSubItem('今日获得', todayPoint),
            ],
          ),
        ],
      ),
    );
  }

  /// 累计 / 消费 / 今日分项
  Widget _buildSubItem(String label, int value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontSize: 17.0, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
          ),
          const SizedBox(height: 4.0),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.0)),
        ],
      ),
    );
  }

  /// 菜单卡(H5 menu-wrap: 积分明细 / 积分商城)
  Widget _buildMenus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          _buildMenu(
            Icons.receipt_long,
            '积分明细',
            () => Get.toNamed('/my/point_detail'),
            showDivider: true,
          ),
          _buildMenu(
            Icons.storefront_outlined,
            '积分商城',
            () => Get.toNamed('/point/shop'),
          ),
        ],
      ),
    );
  }

  /// 任务卡(H5 task-wrap: 每日签到 / 购买商品)
  Widget _buildTasks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 6.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('做任务赚积分', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6.0),
          _buildTask(
            Icons.edit_calendar_outlined,
            '每日签到',
            '连续签到可获得更多积分',
            '去签到',
            () => Get.toNamed('/my/signin'),
          ),
          _buildTask(
            Icons.shopping_bag_outlined,
            '购买商品',
            '购买商品可获得积分',
            '去下单',
            () => Get.toNamed('/'),
          ),
        ],
      ),
    );
  }

  Widget _buildTask(IconData icon, String title, String desc, String btn, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: <Widget>[
          Container(
            width: 36.0,
            height: 36.0,
            decoration: const BoxDecoration(color: Color(0xFFFFF3E6), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: primary, size: 18.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3.0),
                Text(desc, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14.0),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Text(btn, style: const TextStyle(color: Colors.white, fontSize: 12.0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 菜单项
  Widget _buildMenu(IconData icon, String title, VoidCallback onTap, {bool showDivider = false}) {
    return Column(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20.0, color: primary),
                  const SizedBox(width: 12.0),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500))),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18.0),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 46.0),
      ],
    );
  }
}
