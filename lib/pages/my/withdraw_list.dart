/// 提现记录
/// 对齐 H5: pages_tool/member/withdrawal.vue
/// * /api/memberwithdraw/page 提现申请列表
/// * status: -1 已拒绝(refuse_reason) / -2 失败(fail_reason) / 1 待处理 / 2 已到账
/// * 点击项跳转 /my/withdraw_detail 查看详情
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/member_withdraw.dart';
import '../../utils/index.dart';

class WithdrawListPage extends StatefulWidget {
  const WithdrawListPage({super.key});

  @override
  State<WithdrawListPage> createState() => _WithdrawListPageState();
}

class _WithdrawListPageState extends State<WithdrawListPage> {
  static const Color primary = Color(0xFFFF2C55);
  static const int pageSize = 20;

  final ScrollController controller = ScrollController();

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String errorMsg = '';
  int page = 1;

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
      final List<Map<String, dynamic>> data = await MemberWithdrawApi.page(page: page, pageSize: pageSize);
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
        errorMsg = MemberWithdrawApi.errorMsg(e, '加载失败');
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('提现记录', style: TextStyle(fontSize: 17.0)),
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
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/common-empty.png', width: 120.0),
            const SizedBox(height: 12.0),
            Text(
              errorMsg.isEmpty ? '暂无提现记录' : errorMsg,
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
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length) return _buildFooter();
          return _buildItem(list[index]);
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: loadingMore
            ? const SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)),
              )
            : Text(hasMore ? '' : '没有更多了', style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
      ),
    );
  }

  /// 状态颜色: -1/-2 红色, 2 已到账绿色, 其余灰色
  Color statusColor(int status) {
    if (status == -1 || status == -2) return Colors.red;
    if (status == 2) return const Color(0xFF07C160);
    return const Color(0xFF999999);
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final int status = int.tryParse('${item['status'] ?? 0}') ?? 0;
    final num money = num.tryParse('${item['apply_money'] ?? 0}') ?? 0;
    final String time = Utils.timeStampTurnTime(item['apply_time']);
    final String reason = status == -1
        ? '拒绝原因：${item['refuse_reason'] ?? ''}'
        : (status == -2 ? '失败原因：${item['fail_reason'] ?? ''}' : '');
    final int id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: id > 0
            ? () => Get.toNamed(
                  '/my/withdraw_detail',
                  arguments: <String, dynamic>{'id': id, 'item': item},
                )
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${item['transfer_type_name'] ?? ''}',
                            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500)),
                        if (time.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6.0),
                          Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('¥${money.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, fontFamily: 'Arial')),
                      const SizedBox(height: 6.0),
                      Text('${item['status_name'] ?? ''}',
                          style: TextStyle(fontSize: 12.0, color: statusColor(status))),
                    ],
                  ),
                ],
              ),
              if (reason.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8.0),
                Text(reason, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
              ],
              const SizedBox(height: 12.0),
              const Divider(color: Color(0xFFF0F0F0), height: 1.0, thickness: 0.5),
            ],
          ),
        ),
      ),
    );
  }
}
