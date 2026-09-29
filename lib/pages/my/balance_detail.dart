/// 余额明细
/// 对齐 H5: pages_tool/member/balance_detail.vue
/// * 列表 /api/memberaccount/page(account_type: balance,balance_money)
/// * 月份筛选 /api/memberaccount/monthData,默认取第一个月
/// * 类型筛选 /api/memberaccount/fromType(balance + balance_money 两个分组)
/// * 订单/退款来源可跳转订单详情
library;

import 'package:flutter/material.dart';
import '../../components/common_empty.dart';
import 'package:get/get.dart';

import '../../api/member_account.dart';
import '../../styles/index.dart';
import '../../utils/index.dart';

class BalanceDetailPage extends StatefulWidget {
  const BalanceDetailPage({super.key});

  @override
  State<BalanceDetailPage> createState() => _BalanceDetailPageState();
}

class _BalanceDetailPageState extends State<BalanceDetailPage> {
  static const Color primary = Color(0xFFFF2C55);
  static const int pageSize = 20;

  final ScrollController controller = ScrollController();

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String errorMsg = '';
  int page = 1;

  // 月份筛选(H5 monthData)
  List<String> months = <String>[];
  String month = '';
  // 类型筛选(H5 fromType)
  List<Map<String, dynamic>> fromTypes = <Map<String, dynamic>>[
    <String, dynamic>{'label': '全部', 'value': '0'},
  ];
  String fromType = '0';

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
    loadFilters();
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

  /// 月份 / 类型筛选数据(H5 先取到月份再拉列表)
  /// 两个接口分开请求: 任意一个失败都不影响另一个的展示
  Future<void> loadFilters() async {
    List<String> m = <String>[];
    List<Map<String, dynamic>> t = <Map<String, dynamic>>[];
    try {
      m = await MemberAccountApi.monthData();
    } catch (_) {
      // 月份获取失败: 按「全部」处理
    }
    try {
      t = await MemberAccountApi.fromType();
    } catch (_) {
      // 类型获取失败: 只保留「全部」
    }
    if (!mounted) return;
    setState(() {
      months = m;
      month = m.isNotEmpty ? m.first : '';
      if (t.isNotEmpty) fromTypes = t;
    });
    await loadList(refresh: true);
  }

  /// 明细列表
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
      final List<Map<String, dynamic>> data = await MemberAccountApi.page(
        page: page,
        pageSize: pageSize,
        fromType: fromType,
        date: month,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          list = data;
        } else {
          list = <Map<String, dynamic>>[...list, ...data];
        }
        hasMore = data.length >= pageSize;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = MemberAccountApi.errorMsg(e, '明细加载失败');
        loading = false;
        loadingMore = false;
      });
    }
  }

  /// 秒级时间戳 -> yyyy-MM-dd HH:mm:ss(H5 $util.timeStampTurnTime)
  String formatTime(dynamic timestamp) => Utils.timeStampTurnTime(timestamp);

  /// 当前类型名称
  String get fromTypeLabel {
    for (final Map<String, dynamic> item in fromTypes) {
      if ('${item['value']}' == fromType) return '${item['label']}';
    }
    return '全部';
  }

  /// 明细 -> 订单详情(H5 toFromDetail)
  void toFromDetail(Map<String, dynamic> item) {
    final String type = '${item['from_type'] ?? ''}';
    final int tag = int.tryParse('${item['type_tag'] ?? ''}') ?? 0;
    if ((type == 'order' || type == 'refund') && tag > 0) {
      Get.toNamed('/order/detail', arguments: <String, dynamic>{'order_id': tag});
    }
  }

  /// 底部单选(月份 / 类型)
  Future<void> showOptions(String title, List<String> options, String current, ValueChanged<String> onPick) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: Text(title, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
              ),
              const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: const CommonEmpty(text: '暂无可选数据', imageWidth: 80.0),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String value = options[index];
                      final bool selected = value == current;
                      return ListTile(
                        dense: true,
                        title: Text(
                          value,
                          style: TextStyle(fontSize: 14.0, color: selected ? primary : const Color(0xFF333333)),
                        ),
                        trailing: selected ? const Icon(Icons.check, color: primary, size: 18.0) : null,
                        onTap: () {
                          Get.back();
                          onPick(value);
                        },
                      );
                    },
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('余额明细', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 顶部筛选(H5 tab: 月份 + 类型)
  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildFilter(
              months.isEmpty ? '全部' : month,
              () => showOptions('选择月份', months, month, (String value) {
                if (value == month) return;
                setState(() => month = value);
                loadList(refresh: true);
              }),
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: _buildFilter(
              fromTypeLabel,
              () => showOptions(
                '选择类型',
                fromTypes.map((Map<String, dynamic> e) => '${e['label']}').toList(),
                fromTypeLabel,
                (String value) {
                  for (final Map<String, dynamic> item in fromTypes) {
                    if ('${item['label']}' == value) {
                      if ('${item['value']}' == fromType) return;
                      setState(() => fromType = '${item['value']}');
                      loadList(refresh: true);
                      return;
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter(String text, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: onTap,
      child: Container(
        height: 32.0,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF333333)),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16.0, color: Color(0xFF999999)),
          ],
        ),
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
            Text(errorMsg.isEmpty ? '暂无余额明细' : errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: () => loadList(refresh: true),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(top: 10.0),
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length) return _buildFooter();
          return _buildItem(list[index]);
        },
      ),
    );
  }

  /// 加载更多 / 没有更多
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

  /// 明细项(H5 balances: 类型名 + 备注 + 时间 + 收支金额)
  Widget _buildItem(Map<String, dynamic> item) {
    final double amount = double.tryParse('${item['account_data'] ?? 0}') ?? 0;
    final String typeName = '${item['type_name'] ?? ''}';
    final String remark = '${item['remark'] ?? ''}';
    final String time = formatTime(item['create_time']);
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => toFromDetail(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 14.0, 15.0, 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            typeName,
                            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                          ),
                          if (remark.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6.0),
                            Text(remark, style: const TextStyle(fontSize: 12.0, color: Color(0xFF888888), height: 1.4)),
                          ],
                          if (time.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6.0),
                            Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFF999999))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      '${amount > 0 ? '+' : ''}${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                        color: amount > 0 ? primary : const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 15.0),
        ],
      ),
    );
  }
}
