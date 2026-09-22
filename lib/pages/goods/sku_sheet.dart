/// 规格选择弹窗(商品详情"选择"入口)
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../api/goods.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../styles/index.dart';
import './coupon_sheet.dart' show trimNum;

/// 规格选择结果
class SkuSheetResult {
  const SkuSheetResult({required this.detail, required this.action, this.num = 1});

  /// 切换后的 SKU 详情(若没切 SKU 就是传入的详情)
  final Map<String, dynamic> detail;

  /// 'cart' 加入购物车 / 'buy' 立即购买
  final String action;

  /// 弹窗中选择的购买数量
  final int num;
}

/// 打开规格选择弹窗
Future<SkuSheetResult?> showSkuSheet(
  BuildContext context, {
  required Map<String, dynamic> detail,
}) async {
  return showModalBottomSheet<SkuSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => SkuSheet(detail: detail),
  );
}

class SkuSheet extends StatefulWidget {
  const SkuSheet({ super.key, required this.detail });

  final Map<String, dynamic> detail;

  @override
  State<SkuSheet> createState() => _SkuSheetState();
}

class _SkuSheetState extends State<SkuSheet> {
  /// 当前展示/选中的 SKU 详情
  late Map<String, dynamic> currentDetail;

  /// 已选规格值: spec_id -> spec_value_id
  late final Map<String, String> selectedValueIds = <String, String>{};

  /// 切 SKU 时 Loading
  bool loading = false;

  /// 购买数量
  int buyNum = 1;

  int get goodsId => currentDetail['goodsId'] as int? ?? 0;
  int get skuId => currentDetail['skuId'] as int? ?? 0;
  num get price => currentDetail['price'] as num? ?? 0;
  num get stock => currentDetail['stock'] as num? ?? 0;
  num get maxBuy => currentDetail['maxBuy'] as num? ?? 0;
  num get minBuy => currentDetail['minBuy'] as num? ?? 0;
  String get title => '${currentDetail['title'] ?? ''}';
  List<String> get images => (currentDetail['images'] as List? ?? const []).map((dynamic e) => '$e').toList();
  List<dynamic> get specGroups => (currentDetail['specGroups'] as List? ?? const []);
  List<dynamic> get specFormat => (currentDetail['specFormat'] as List? ?? const []);
  bool get hasSpec => specGroups.isNotEmpty;

  @override
  void initState() {
    super.initState();
    currentDetail = widget.detail;
    _initSelection();
    _clampNum();
  }

  /// 可买下限: 未设起购量时为 1
  int get minNum => minBuy > 0 ? minBuy.toInt() : 1;

  /// 可买上限: 库存优先,有限购时取小值,至少 1
  int get maxNum {
    int max = stock > 0 ? stock.toInt() : 1;
    if (maxBuy > 0 && maxBuy.toInt() < max) max = maxBuy.toInt();
    return max < 1 ? 1 : max;
  }

  /// 把购买数量夹到当前 SKU 允许的范围内
  void _clampNum() {
    final int lower = minNum > maxNum ? 1 : minNum;
    if (buyNum < lower) buyNum = lower;
    if (buyNum > maxNum) buyNum = maxNum;
  }

  /// 根据当前 SKU 的 sku_spec_format 初始化已选
  void _initSelection() {
    selectedValueIds.clear();
    for (final dynamic item in specFormat) {
      if (item is! Map) continue;
      final String specId = '${item['spec_id'] ?? ''}';
      final String valueId = '${item['spec_value_id'] ?? ''}';
      if (specId.isNotEmpty && valueId.isNotEmpty) {
        selectedValueIds[specId] = valueId;
      }
    }
  }

  /// 已选规格文本
  String get selectedText {
    if (!hasSpec) return '默认规格';
    final List<String> names = <String>[];
    for (final dynamic group in specGroups) {
      if (group is! Map) continue;
      final String specId = '${group['spec_id'] ?? ''}';
      final String selectedId = selectedValueIds[specId] ?? '';
      final List<dynamic> values = (group['value'] as List? ?? const []);
      for (final dynamic value in values) {
        if (value is Map && '${value['spec_value_id'] ?? ''}' == selectedId) {
          final String name = '${value['spec_value_name'] ?? ''}';
          if (name.isNotEmpty) names.add(name);
          break;
        }
      }
    }
    return names.isEmpty ? '请选择规格' : '已选规格：${names.join(' / ')}';
  }

  /// 切换 SKU
  Future<void> _onSelectValue(String specId, Map value) async {
    final String valueId = '${value['spec_value_id'] ?? ''}';
    if (selectedValueIds[specId] == valueId) return;

    setState(() {
      selectedValueIds[specId] = valueId;
    });

    final int? newSkuId = int.tryParse('${value['sku_id'] ?? ''}');
    if (newSkuId == null || newSkuId == skuId) return;

    setState(() => loading = true);
    try {
      final Map<String, dynamic> newDetail = await GoodsApi.detail(goodsId, skuId: newSkuId);
      if (mounted && newDetail.isNotEmpty) {
        setState(() {
          currentDetail = newDetail;
          _initSelection();
          _clampNum();
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _close({required String action}) {
    Navigator.of(context).pop(SkuSheetResult(detail: currentDetail, action: action, num: buyNum));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildHeader(),
                FStyle.divider,
                Expanded(child: _buildBody()),
                _buildQuantityRow(),
                _buildBottomBar(),
              ],
            ),
            if (loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Color(0xFFFF2C55), strokeWidth: 3.0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 顶部: 图 + 标题 + 价格 + 库存 + 已选 + 关闭
  Widget _buildHeader() {
    final String image = images.isEmpty ? '' : images.first;
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 商品图
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: image.isEmpty
              ? Container(width: 90.0, height: 90.0, color: Colors.grey.shade100, child: const Icon(Icons.image_outlined, color: Colors.grey))
              : CachedNetworkImage(
                  imageUrl: image,
                  width: 90.0,
                  height: 90.0,
                  fit: BoxFit.cover,
                  placeholder: (BuildContext context, String url) => Container(width: 90.0, height: 90.0, color: Colors.grey.shade100),
                  errorWidget: (BuildContext context, String url, dynamic error) => Container(
                    width: 90.0,
                    height: 90.0,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4.0,
              children: <Widget>[
                Text('¥${price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 18.0, fontWeight: FontWeight.w700)),
                Text('库存${trimNum(stock)}件', style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                Text(selectedText, style: const TextStyle(color: Colors.grey, fontSize: 12.0), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, size: 20.0, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  /// 规格列表
  Widget _buildBody() {
    if (!hasSpec) {
      // 单规格商品: 没有规格可选, 只保留底部数量行
      return const SizedBox.shrink();
    }
    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 10.0),
        itemCount: specGroups.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 22.0),
        itemBuilder: (BuildContext context, int index) {
          final Map group = specGroups[index] as Map;
          return _buildSpecGroup(group);
        },
      ),
    );
  }

  /// 单个规格组
  Widget _buildSpecGroup(Map group) {
    final String specId = '${group['spec_id'] ?? ''}';
    final String specName = '${group['spec_name'] ?? '规格'}';
    final List<dynamic> values = (group['value'] as List? ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10.0,
      children: <Widget>[
        Text(specName, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87)),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: values.whereType<Map>().map<Widget>((dynamic value) {
            final String valueId = '${value['spec_value_id'] ?? ''}';
            final bool selected = selectedValueIds[specId] == valueId;
            // 后端未返回库存标记时视为可选,只有明确标记无货才置灰
            final bool hasStock = value['hasStock'] != false;
            return _buildSpecChip(value: value, selected: selected, enabled: hasStock, specId: specId);
          }).toList(),
        ),
      ],
    );
  }

  /// 规格选项 chip
  Widget _buildSpecChip({required Map value, required bool selected, required bool enabled, required String specId}) {
    final String name = '${value['spec_value_name'] ?? ''}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _onSelectValue(specId, value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF2F2) : (enabled ? Colors.white : Colors.grey.shade100),
          border: Border.all(
            color: selected ? const Color(0xFFFF2C55) : (enabled ? Colors.grey.shade300 : Colors.grey.shade200),
            width: selected ? 1.2 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? const Color(0xFFFF2C55) : (enabled ? Colors.black87 : Colors.grey.shade400),
            fontSize: 12.0,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 购买数量(固定展示在底部按钮上方,不随规格列表滚动)
  Widget _buildQuantityRow() {
    final int max = maxNum;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 2.0),
      child: Row(
        children: <Widget>[
          const Text('购买数量', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Colors.black87)),
          if (maxBuy > 0) ...<Widget>[
            const SizedBox(width: 6.0),
            Text('限购${trimNum(maxBuy)}件', style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
          ],
          if (stock > 0 && stock <= 20) ...<Widget>[
            const SizedBox(width: 6.0),
            Text('仅剩${trimNum(stock)}件', style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
          ],
          const Spacer(),
          _buildNumButton(icon: Icons.remove, enabled: buyNum > minNum, onTap: () => setState(() => buyNum -= 1)),
          SizedBox(
            width: 46.0,
            height: 30.0,
            child: Center(child: Text('$buyNum', style: const TextStyle(fontSize: 14.0, color: Colors.black87))),
          ),
          _buildNumButton(icon: Icons.add, enabled: buyNum < max, onTap: () => setState(() => buyNum += 1)),
        ],
      ),
    );
  }

  /// 数量加减按钮
  Widget _buildNumButton({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30.0,
        height: 30.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: enabled ? Colors.grey.shade300 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Icon(icon, size: 16.0, color: enabled ? Colors.black87 : Colors.grey.shade400),
      ),
    );
  }

  /// 底部按钮(加入购物车 / 立即购买)
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
      decoration: BoxDecoration(color: Colors.white, boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8.0)]),
      child: Row(
        spacing: 10.0,
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(action: 'cart'),
              child: Container(
                height: 44.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: <Color>[Color(0xFFFFA726), Color(0xFFFFCA28)]),
                  borderRadius: BorderRadius.circular(22.0),
                ),
                child: const Text('加入购物车', style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(action: 'buy'),
              child: Container(
                height: 44.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: <Color>[Color(0xFFFF2C55), Color(0xFFFF7A45)]),
                  borderRadius: BorderRadius.circular(22.0),
                ),
                child: const Text('立即购买', style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
