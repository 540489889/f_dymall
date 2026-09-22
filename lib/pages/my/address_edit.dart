/// 新增/编辑收货地址
/// 对齐 H5: pages_tool/member/address_edit.vue
/// * 详情 /api/memberaddress/info  保存 /api/memberaddress/add | edit
/// * 省市区 /api/address/lists(pid)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/address.dart';
import '../../styles/index.dart';

class AddressEditPage extends StatefulWidget {
  /// [id] 0 新增,否则编辑
  /// [type] 1 普通收货地址 2 同城配送地址
  /// [back] 非空表示从订单确认页进入(保存时置为默认地址)
  const AddressEditPage({
    super.key,
    this.id = 0,
    this.type = 1,
    this.back = '',
  });

  final int id;
  final int type;
  final String back;

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  static const Color primary = Color(0xFFFF2C55);

  // 0 新增,否则编辑
  late int id = widget.id;
  // 地址类型: 1 普通收货地址 2 同城配送地址(与 H5 localType 一致)
  late int type = widget.type;
  // 返回页: 从订单确认页进入时非空,编辑保存会置为默认地址(H5 address_edit.vue saveAddress)
  late String back = widget.back;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController telephoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  bool isDefault = false;
  bool loading = true;
  bool saving = false;

  // 省市区
  List<Map<String, dynamic>> provinces = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> cities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> districts = <Map<String, dynamic>>[];
  Map<String, dynamic>? province;
  Map<String, dynamic>? city;
  Map<String, dynamic>? district;
  // 详情返回的地区文本(未重新选择时直接提交)
  String originFullAddress = '';

  /// 中国大陆手机号
  static final RegExp _phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

  @override
  void initState() {
    super.initState();
    // 走命名路由时以 arguments 为准(仅当显式携带地址参数)
    final dynamic args = Get.arguments;
    if (args is Map && (args.containsKey('id') || args.containsKey('back'))) {
      id = int.tryParse('${args['id'] ?? ''}') ?? id;
      type = int.tryParse('${args['type'] ?? ''}') ?? type;
      back = '${args['back'] ?? ''}';
    }
    _init();
  }

  Future<void> _init() async {
    provinces = await AddressApi.areas(0);
    if (!mounted) return;
    if (id > 0) await loadDetail();
    if (mounted) setState(() => loading = false);
  }

  /// 地址详情
  Future<void> loadDetail() async {
    try {
      final Map<String, dynamic> data = await AddressApi.info(id);
      if (!mounted) return;
      nameCtrl.text = '${data['name'] ?? ''}';
      mobileCtrl.text = '${data['mobile'] ?? ''}';
      telephoneCtrl.text = '${data['telephone'] ?? ''}';
      addressCtrl.text = '${data['address'] ?? ''}';
      originFullAddress = '${data['full_address'] ?? ''}';
      isDefault = '${data['is_default'] ?? 0}' == '1';
      final int dataType = int.tryParse('${data['type'] ?? ''}') ?? 0;
      if (dataType > 0) type = dataType;
      // 回填省市区(逐级加载下级)
      final int pid = int.tryParse('${data['province_id'] ?? ''}') ?? 0;
      final int cid = int.tryParse('${data['city_id'] ?? ''}') ?? 0;
      final int did = int.tryParse('${data['district_id'] ?? ''}') ?? 0;
      province = _findById(provinces, pid);
      if (province != null && cid > 0) {
        cities = await AddressApi.areas(pid);
        city = _findById(cities, cid);
        if (city != null && did > 0) {
          districts = await AddressApi.areas(cid);
          district = _findById(districts, did);
        }
      }
      setState(() {});
    } catch (e) {
      MyDialog.toast(AddressApi.errorMsg(e, '地址详情加载失败'));
    }
  }

  Map<String, dynamic>? _findById(List<Map<String, dynamic>> list, int id) {
    for (final Map<String, dynamic> item in list) {
      if ((int.tryParse('${item['id'] ?? ''}') ?? 0) == id) return item;
    }
    return null;
  }

  /// 省市区文本: 省-市-区
  String get _fullAddress {
    final List<String> parts = <String>[
      if (province != null) '${province!['name'] ?? ''}',
      if (city != null) '${city!['name'] ?? ''}',
      if (district != null) '${district!['name'] ?? ''}',
    ];
    if (parts.isEmpty) return originFullAddress;
    return parts.join('-');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
    telephoneCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  /// 保存
  Future<void> save() async {
    final String name = nameCtrl.text.trim();
    final String mobile = mobileCtrl.text.trim();
    final String address = addressCtrl.text.trim();
    if (name.isEmpty) {
      MyDialog.toast('请输入姓名');
      return;
    }
    if (mobile.isEmpty) {
      MyDialog.toast('请输入手机号');
      return;
    }
    if (!_phoneRegExp.hasMatch(mobile)) {
      MyDialog.toast('请输入正确的手机号');
      return;
    }
    if (_fullAddress.isEmpty) {
      MyDialog.toast('请选择省市区县');
      return;
    }
    if (province == null) {
      MyDialog.toast('请选择省');
      return;
    }
    if (city == null) {
      MyDialog.toast('请选择市');
      return;
    }
    if (district == null) {
      MyDialog.toast('请选择区');
      return;
    }
    if (address.isEmpty) {
      MyDialog.toast('详细地址不能为空');
      return;
    }
    setState(() => saving = true);
    try {
      await AddressApi.save(
        id: id,
        name: name,
        mobile: mobile,
        telephone: telephoneCtrl.text.trim(),
        provinceId: int.tryParse('${province!['id'] ?? ''}') ?? 0,
        cityId: int.tryParse('${city!['id'] ?? ''}') ?? 0,
        districtId: int.tryParse('${district?['id'] ?? ''}') ?? 0,
        address: address,
        fullAddress: _fullAddress,
        // 与 H5 一致: 从订单页(back 非空)编辑已有地址保存时直接置为默认
        isDefault: id > 0 && back.isNotEmpty ? 1 : (isDefault ? 1 : 0),
        type: type,
      );
      if (!mounted) return;
      setState(() => saving = false);
      MyDialog.toast(id > 0 ? '修改成功' : '添加成功');
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      MyDialog.toast(AddressApi.errorMsg(e, '保存失败'));
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
        title: Text(id > 0 ? '编辑收货地址' : '新增收货地址', style: const TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)))
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(10.0),
                    children: <Widget>[
                      _buildFormCard(),
                      const SizedBox(height: 10.0),
                      _buildDefaultRow(),
                    ],
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
    );
  }

  /// 表单卡
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: <Widget>[
          _buildInputRow('收货人', '请输入收货人姓名', nameCtrl, maxLength: 30),
          _divider,
          _buildInputRow('手机号', '请输入手机号', mobileCtrl, keyboardType: TextInputType.phone, maxLength: 11, digitsOnly: true),
          _divider,
          _buildInputRow('固定电话', '选填', telephoneCtrl, maxLength: 20),
          _divider,
          _buildRegionRow(),
          _divider,
          _buildInputRow('详细地址', '请输入详细地址', addressCtrl, maxLength: 50),
        ],
      ),
    );
  }

  Widget get _divider => FStyle.divider;

  /// 输入行
  Widget _buildInputRow(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int? maxLength,
    bool digitsOnly = false,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(width: 76.0, child: Text(label, style: const TextStyle(fontSize: 14.0, color: Colors.black87))),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType ?? TextInputType.text,
            maxLength: maxLength,
            inputFormatters: digitsOnly ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly] : null,
            style: const TextStyle(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14.0, color: Colors.grey),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
            ),
          ),
        ),
      ],
    );
  }

  /// 所在地区(三级选择)
  Widget _buildRegionRow() {
    final String text = _fullAddress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openRegionPicker,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 76.0, child: Text('所在地区', style: TextStyle(fontSize: 14.0, color: Colors.black87))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Text(
                text.isEmpty ? '请选择省市区县' : text,
                style: TextStyle(fontSize: 14.0, color: text.isEmpty ? Colors.grey : Colors.black87),
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 12.0, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  /// 设为默认
  Widget _buildDefaultRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Row(
        children: <Widget>[
          const Expanded(child: Text('设为默认地址', style: TextStyle(fontSize: 14.0))),
          Switch(
            value: isDefault,
            activeThumbColor: primary,
            onChanged: (bool value) => setState(() => isDefault = value),
          ),
        ],
      ),
    );
  }

  /// 底部保存
  Widget _buildSaveButton() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0 + MediaQuery.of(context).padding.bottom),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 44.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
        ),
        onPressed: saving ? null : save,
        child: saving
            ? const SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Text('保存', style: TextStyle(fontSize: 15.0)),
      ),
    );
  }

  /// 省市区选择弹窗(三级联动 /api/address/lists)
  Future<void> _openRegionPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) {
            void selectProvince(Map<String, dynamic> item) {
              setSheet(() {
                province = item;
                city = null;
                district = null;
                cities = <Map<String, dynamic>>[];
                districts = <Map<String, dynamic>>[];
              });
              _loadChildren(setSheet, 1, int.tryParse('${item['id'] ?? ''}') ?? 0);
            }

            void selectCity(Map<String, dynamic> item) {
              setSheet(() {
                city = item;
                district = null;
                districts = <Map<String, dynamic>>[];
              });
              _loadChildren(setSheet, 2, int.tryParse('${item['id'] ?? ''}') ?? 0);
            }

            return SizedBox(
              height: 340.0,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 12.0),
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      const Text('选择地区', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 18.0, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        _buildRegionColumn(provinces, province, selectProvince),
                        _buildRegionColumn(cities, city, selectCity),
                        _buildRegionColumn(districts, district, (Map<String, dynamic> item) {
                          setSheet(() => district = item);
                          setState(() {});
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  /// 逐级加载下级地区
  /// * [level] 1 市 2 区
  Future<void> _loadChildren(StateSetter setSheet, int level, int pid) async {
    final List<Map<String, dynamic>> data = await AddressApi.areas(pid);
    if (!mounted) return;
    setSheet(() {
      if (level == 1) {
        cities = data;
        if (data.isNotEmpty) {
          city = data.first;
          districts = <Map<String, dynamic>>[];
          district = null;
        }
      } else {
        districts = data;
        district = data.isEmpty ? null : data.first;
      }
    });
    // 选中省后自动带出市/区,同步外层表单文案
    if (level == 1 && data.isNotEmpty) {
      await _loadChildren(setSheet, 2, int.tryParse('${data.first['id'] ?? ''}') ?? 0);
    } else {
      setState(() {});
    }
  }

  /// 地区列
  Widget _buildRegionColumn(
    List<Map<String, dynamic>> data,
    Map<String, dynamic>? selected,
    ValueChanged<Map<String, dynamic>> onSelect,
  ) {
    return Expanded(
      child: Container(
        color: const Color(0xFFF8F8F8),
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        child: ListView.builder(
          itemCount: data.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> item = data[index];
            final bool active = selected != null && '${selected['id']}' == '${item['id']}';
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                color: active ? Colors.white : Colors.transparent,
                child: Text(
                  '${item['name'] ?? ''}',
                  style: TextStyle(fontSize: 13.0, color: active ? primary : Colors.black54),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
