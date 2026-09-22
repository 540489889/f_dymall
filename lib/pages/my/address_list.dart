/// 收货地址管理
/// 对齐 H5: pages_tool/member/address.vue
/// * 列表 /api/memberaddress/page(type: 1 快递 2 同城, 同城需 store_id)
/// * 删除 /api/memberaddress/delete  设为默认 /api/memberaddress/setdefault
/// * 点击地址即设为默认(H5 address-item-top @click="setDefault");右侧「修改」进编辑页
/// * 从订单确认页进入(携带 back/select)时,设为默认成功后回退并把地址回传给上一页
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/address.dart';
import 'address_edit.dart';
import '../../styles/index.dart';

class AddressListPage extends StatefulWidget {
  /// [selectMode] 选择模式(订单确认页进入): 选中地址后回退并把地址回传给上一页
  /// [type] 1 普通收货地址 2 同城配送地址
  /// [storeId] 同城配送门店id
  const AddressListPage({
    super.key,
    this.selectMode = false,
    this.type = 1,
    this.storeId = 0,
  });

  final bool selectMode;
  final int type;
  final int storeId;

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  static const Color primary = Color(0xFFFF2C55);

  List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
  bool loading = true;
  String errorMsg = '';
  // 选择模式: 订单确认页进入(携带 select / back),选中后回退并把地址回传
  late bool selectMode = widget.selectMode;
  // 地址类型: 1 普通收货地址 2 同城配送地址
  late int type = widget.type;
  // 同城配送时的门店id(与 H5 一致: 取 delivery.store_id)
  late int storeId = widget.storeId;

  @override
  void initState() {
    super.initState();
    // 走命名路由时以 arguments 为准(仅当显式携带地址参数,避免误读上一页的 arguments)
    final dynamic args = Get.arguments;
    if (args is Map && (args.containsKey('select') || args.containsKey('back'))) {
      selectMode = args['select'] == true || '${args['back'] ?? ''}'.isNotEmpty;
      type = int.tryParse('${args['type'] ?? ''}') ?? type;
      storeId = int.tryParse('${args['store_id'] ?? ''}') ?? storeId;
    }
    load();
  }

  /// 地址列表(/api/memberaddress/page)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final List<Map<String, dynamic>> data = await AddressApi.page(pageSize: 50, type: type, storeId: storeId);
      if (!mounted) return;
      setState(() {
        list = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = AddressApi.errorMsg(e, '地址列表加载失败');
        loading = false;
      });
    }
  }

  /// 设为默认(/api/memberaddress/setdefault)
  /// 与 H5 一致: 成功后若有返回页则回退,否则刷新并提示
  Future<void> setDefault(Map<String, dynamic> item) async {
    final int id = int.tryParse('${item['id'] ?? ''}') ?? 0;
    if (id <= 0) return;
    if ('${item['is_default'] ?? ''}' == '1') {
      if (selectMode) Get.back(result: item);
      return;
    }
    try {
      await AddressApi.setDefault(id);
      if (!mounted) return;
      if (selectMode) {
        final Map<String, dynamic> selected = <String, dynamic>{...item, 'is_default': 1};
        Get.back(result: selected);
        return;
      }
      MyDialog.toast('修改默认地址成功');
      await load();
    } catch (e) {
      MyDialog.toast(AddressApi.errorMsg(e, '设置失败'));
    }
  }

  /// 新增/编辑地址(H5 addAddress),保存成功后刷新列表
  Future<void> openEdit([Map<String, dynamic>? item]) async {
    final int id = item == null ? 0 : int.tryParse('${item['id'] ?? ''}') ?? 0;
    final dynamic result = await Get.to<dynamic>(
      AddressEditPage(id: id, type: type, back: selectMode ? 'order' : ''),
    );
    if (result != true) return;
    await load();
    // 选择模式下新增/编辑后会成为默认地址,直接回传给上一页
    if (selectMode) {
      for (final Map<String, dynamic> e in list) {
        if ('${e['is_default'] ?? ''}' == '1') {
          if (mounted) Get.back(result: e);
          break;
        }
      }
    }
  }

  /// 删除地址(/api/memberaddress/delete)
  Future<void> deleteAddress(Map<String, dynamic> item) async {
    final int id = int.tryParse('${item['id'] ?? ''}') ?? 0;
    if (id <= 0) return;
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('操作提示', style: TextStyle(fontSize: 16.0)),
        content: const Text('确定要删除该地址吗?', style: TextStyle(fontSize: 14.0, color: Colors.black54)),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('确定', style: TextStyle(color: primary))),
        ],
      ),
    );
    if (confirm != true) return;
    // 与 H5 一致: 默认地址不能删除
    if ('${item['is_default'] ?? ''}' == '1') {
      MyDialog.toast('默认地址,不能删除');
      return;
    }
    try {
      await AddressApi.delete(id);
      MyDialog.toast('删除成功');
      await load();
    } catch (e) {
      MyDialog.toast(AddressApi.errorMsg(e, '删除失败'));
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
        title: const Text('收货地址', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildAddButton(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)));
    }
    if (list.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: primary,
      onRefresh: load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
        itemCount: list.length,
        itemBuilder: (BuildContext context, int index) => _buildItem(list[index]),
      ),
    );
  }

  /// 空状态(新增入口统一在底部按钮)
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.location_off_outlined, size: 56.0, color: Colors.grey.shade300),
          const SizedBox(height: 12.0),
          Text(errorMsg.isEmpty ? '暂无收货地址,请点击下方按钮添加' : errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 地址项
  Widget _buildItem(Map<String, dynamic> item) {
    final String name = '${item['name'] ?? ''}';
    final String mobile = '${item['mobile'] ?? ''}';
    final String detail = '${item['full_address'] ?? ''}${item['address'] ?? ''}';
    final bool isDefault = '${item['is_default'] ?? ''}' == '1';
    // 同城配送地址的距离文案(H5 item.local_data)
    final String localData = '${item['local_data'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 顶部信息: 点击即设为默认
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
              onTap: () => setDefault(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 14.0, 6.0, 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const Icon(Icons.location_on_outlined, size: 15.0, color: primary),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                mobile,
                                style: const TextStyle(fontSize: 13.0, color: Color(0xFF888888)),
                              ),
                              const SizedBox(width: 6.0),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(3.0),
                                  ),
                                  child: const Text(
                                    '默认',
                                    style: TextStyle(fontSize: 10.0, color: primary, height: 1.3),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            detail,
                            style: const TextStyle(fontSize: 13.0, color: Color(0xFF666666), height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    InkWell(
                      borderRadius: BorderRadius.circular(6.0),
                      onTap: () => openEdit(item),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 9.0, vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.edit_outlined, size: 15.0, color: Color(0xFF999999)),
                            SizedBox(height: 2.0),
                            Text('编辑', style: TextStyle(fontSize: 11.0, color: Color(0xFF999999), height: 1.2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: FStyle.dividerColor, height: 1.0, thickness: 0.5, indent: 15.0, endIndent: 15.0),
          // 底部: 设为默认 + 删除
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 4.0, 15.0, 4.0),
            child: Row(
              children: <Widget>[
                if (localData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Text(localData, style: const TextStyle(fontSize: 12.0, color: Color(0xFFFF4D4F))),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.0),
                    onTap: () => setDefault(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: <Widget>[
                          const Text('设为默认地址', style: TextStyle(fontSize: 12.0, color: Color(0xFF666666))),
                          SizedBox(
                            height: 24.0,
                            width: 36.0,
                            child: Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: isDefault,
                                activeThumbColor: primary,
                                activeTrackColor: primary.withValues(alpha: 0.35),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: isDefault ? null : (bool value) => setDefault(item),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (!isDefault)
                  InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: () => deleteAddress(item),
                    child: Container(
                      width: 26.0,
                      height: 26.0,
                      decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline, size: 15.0, color: Color(0xFF999999)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),
        ],
      ),
    );
  }

  /// 底部新增按钮
  Widget _buildAddButton() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0 + MediaQuery.of(context).padding.bottom),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0))),
        ),
        onPressed: () => openEdit(),
        child: const Text('新增收货地址', style: TextStyle(fontSize: 15.0)),
      ),
    );
  }
}
