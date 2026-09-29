/// 提现详情
/// 对齐 H5: pages_tool/member/withdrawal_detail.vue
/// * /api/memberwithdraw/detail  data: { id }
/// * 状态 status: 0 待审核 / 1 待转账 / 2 已转账 / 3 收款中 / -1 拒绝(refuse_reason) / -2 失败(fail_reason)
/// * 入参 Get.arguments: { id, item }(item 为列表项,接口不可用/字段名有出入时用于兜底展示)
/// * H5 的「收款」按钮依赖微信商家转账(wechatpay 插件),Flutter 端无对应能力,不实现
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/member_withdraw.dart';
import '../../utils/index.dart';

class WithdrawDetailPage extends StatefulWidget {
  const WithdrawDetailPage({super.key});

  @override
  State<WithdrawDetailPage> createState() => _WithdrawDetailPageState();
}

class _WithdrawDetailPageState extends State<WithdrawDetailPage> {
  static const Color primary = Color(0xFFFF2C55);

  int id = 0;
  bool loading = true;
  String errorMsg = '';
  /// 接口返回的详情
  Map<String, dynamic> detail = <String, dynamic>{};
  /// 列表项兜底数据
  Map<String, dynamic> fallback = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      id = int.tryParse('${args['id'] ?? 0}') ?? 0;
      final dynamic item = args['item'];
      if (item is Map) fallback = item.cast<String, dynamic>();
    }
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await MemberWithdrawApi.detail(id);
      if (!mounted) return;
      setState(() {
        detail = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final String message = MemberWithdrawApi.errorMsg(e, '加载失败');
      setState(() {
        errorMsg = message;
        loading = false;
      });
      // 有列表数据时只用轻提示,仍按列表内容展示
      if (fallback.isNotEmpty) MyDialog.toast(message);
    }
  }

  /// 实际展示的数据(接口优先,其次列表兜底)
  Map<String, dynamic> get info => detail.isNotEmpty ? detail : fallback;

  bool get hasData => info.isNotEmpty;

  int get status => int.tryParse('${info['status'] ?? 0}') ?? 0;

  /// 兼容不同字段名,取第一个非空值
  String pick(List<String> keys) {
    for (final String key in keys) {
      final String value = '${info[key] ?? ''}';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  /// 状态颜色: -1 拒绝 / -2 失败 红; 2 已到账 绿; 其余进行中 橙
  Color get statusColor {
    if (status == -1 || status == -2) return Colors.red;
    if (status == 2) return const Color(0xFF07C160);
    return const Color(0xFFFF9F0A);
  }

  IconData get statusIcon {
    if (status == 2) return Icons.check_circle_outline;
    if (status == -1 || status == -2) return Icons.cancel_outlined;
    return Icons.access_time;
  }

  /// 金额(元),值为空时返回空
  String money(String value) {
    if (value.isEmpty) return '';
    final num price = num.tryParse(value) ?? 0;
    return '¥${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('提现详情', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
      );
    }
    if (!hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/common-empty.png', width: 120.0),
            const SizedBox(height: 12.0),
            Text(errorMsg.isEmpty ? '暂无提现信息' : errorMsg,
                style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
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
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 24.0),
      children: <Widget>[
        _buildStatusCard(),
        const SizedBox(height: 12.0),
        _buildInfoCard(),
      ],
    );
  }

  /// 顶部: 金额 + 状态 + 拒绝理由
  Widget _buildStatusCard() {
    final String statusName = pick(<String>['status_name']);
    final String reason = status == -1
        ? pick(<String>['refuse_reason'])
        : (status == -2 ? pick(<String>['fail_reason']) : '');
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 24.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          Text(
            money(pick(<String>['apply_money'])),
            style: const TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
          ),
          if (statusName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(statusIcon, color: statusColor, size: 16.0),
                const SizedBox(width: 6.0),
                Text(statusName,
                    style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: statusColor)),
              ],
            ),
          ],
          if (reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12.0),
            Text(
              status == -1 ? '拒绝原因：$reason' : '失败原因：$reason',
              style: const TextStyle(fontSize: 12.0, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// 明细信息(与 H5 字段/显示条件一致)
  Widget _buildInfoCard() {
    final List<Widget> rows = <Widget>[
      _buildRow('当前状态', pick(<String>['status_name']), valueColor: statusColor),
      _buildRow('交易号', pick(<String>['withdraw_no'])),
      _buildRow('手续费', money(pick(<String>['service_money']))),
      _buildRow('申请时间', Utils.timeStampTurnTime(pick(<String>['apply_time']))),
      // H5: status 非 0 才显示审核时间
      if (status != 0) _buildRow('审核时间', Utils.timeStampTurnTime(pick(<String>['audit_time']))),
      _buildRow('银行名称', pick(<String>['bank_name'])),
      _buildRow('收款账号', pick(<String>['account_number'])),
      // H5: 仅拒绝态显示
      if (status == -1) _buildRow('拒绝理由', pick(<String>['refuse_reason']), valueColor: Colors.red),
      if (status == -2) _buildRow('失败原因', pick(<String>['fail_reason']), valueColor: Colors.red),
      // H5: 仅已转账显示
      if (status == 2) _buildRow('转账方式名称', pick(<String>['transfer_type_name'])),
      if (status == 2) _buildRow('转账时间', Utils.timeStampTurnTime(pick(<String>['payment_time']))),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(children: rows),
    );
  }

  /// 信息行(值为空时整行不显示)
  Widget _buildRow(String label, String value, {Color? valueColor}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100.0,
            child: Text(label, style: const TextStyle(fontSize: 14.0, color: Color(0xFF888888))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14.0, color: valueColor ?? const Color(0xFF333333))),
          ),
        ],
      ),
    );
  }
}
