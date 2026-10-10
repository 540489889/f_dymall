/// 门店详情
/// 对齐 H5: pages_tool/store/detail.vue
/// * 数据 /api/store/info?store_id=xxx
/// * 结构: 门店图轮播 -> 信息卡(名称/营业状态/营业时间/标签/地址/电话) -> 门店地图
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/store.dart';
import '../../components/loading.dart';
import '../../components/static_map.dart';
import '../../styles/index.dart';

class StoreDetailPage extends StatefulWidget {
  const StoreDetailPage({super.key, this.storeId = 0});

  /// 门店id(命名路由进入时以 arguments 为准)
  final int storeId;

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  static const Color primary = Color(0xFFFF2C55);
  static const Color bgColor = Color(0xFFF5F6FA);
  static const Color subColor = Color(0xFF999CA7);
  // 营业中(H5 .store-state)
  static const Color stateColor = Color(0xFF66AD95);
  // 休息中 / 已停业(H5 .store-state.warning)
  static const Color stateWarningColor = Colors.red;
  // 服务标签(H5 .tag-item)
  static const Color tagColor = Color(0xFF6F7DAD);
  static const Color tagBgColor = Color(0xFFF4F5FA);
  static const Color lineColor = Color(0xFFEDEDED);

  Map<String, dynamic> detail = const {};
  bool loading = true;
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  /// 门店id: 路由传 Map / 数字 / 字符串,缺省用构造参数
  /// * 用 dynamic 兜底读取(web 热重载会保留旧实例,新增字段可能未初始化)
  int get storeId {
    final dynamic own = widget.storeId;
    final int ownId = own is int ? own : int.tryParse('$own') ?? 0;
    final dynamic args = Get.arguments;
    if (args is Map) return int.tryParse('${args['store_id'] ?? args['id'] ?? ''}') ?? ownId;
    return int.tryParse('$args') ?? ownId;
  }

  /// 加载门店详情
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> res = await StoreApi.info(storeId);
      if (!mounted) return;
      // 排查门店地图用: 经纬度没下发时静态图画不出来, 先看这条日志确认字段
      if (kDebugMode) {
        debugPrint('[store]门店详情字段: ${res.keys.toList()}');
        debugPrint('[store]经纬度: latitude=${res['latitude']} longitude=${res['longitude']}');
      }
      setState(() {
        detail = res;
        loading = false;
        errorMsg = res.isEmpty ? '门店不存在' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = '$e'.replaceAll(RegExp(r'^DioException.*message: '), '');
      });
    }
  }

  /* 数据快捷读取 */
  String get storeName => '${detail['store_name'] ?? ''}';
  String get telphone => '${detail['telphone'] ?? ''}';
  String get openDate => '${detail['open_date'] ?? ''}';
  String get latitude => '${detail['latitude'] ?? ''}';
  String get longitude => '${detail['longitude'] ?? ''}';
  /// 完整地址(H5 show_address: full_address 去逗号 + 详细地址)
  String get address => '${'${detail['full_address'] ?? ''}'.replaceAll(',', ' ')} ${detail['address'] ?? ''}'.trim();
  /// 营业状态: 1 营业中 / 0 休息中 / is_frozen 已停业
  int get status => int.tryParse('${detail['status'] ?? ''}') ?? -1;
  int get frozen {
    final dynamic val = detail['is_frozen'];
    if (val is Map) return int.tryParse('${val['is_frozen'] ?? ''}') ?? 0;
    return int.tryParse('$val') ?? 0;
  }
  String get stateText {
    if (frozen == 1) return '已停业';
    if (status == 0) return '休息中';
    if (status == 1) return '营业中';
    return '--';
  }
  bool get stateWarning => frozen == 1 || status == 0;
  /// 休息说明(仅休息中展示)
  String get closeDesc => status == 0 ? '${detail['close_desc'] ?? ''}' : '';
  /// 服务标签: 总店 / 门店自提 / 同城配送 / 物流配送
  List<String> get tags {
    final List<String> list = <String>[];
    if (_isOn(detail['is_default'])) list.add('总店');
    if (_isOn(detail['is_pickup'])) list.add('门店自提');
    if (_isOn(detail['is_o2o'])) list.add('同城配送');
    if (_isOn(detail['is_express'])) list.add('物流配送');
    return list;
  }
  /// 门店图片(store_images 兼容: [{pic_path}] / 逗号分隔字符串)
  List<String> get images {
    final List<String> list = <String>[];
    final dynamic raw = detail['store_images'];
    if (raw is List) {
      for (final dynamic item in raw) {
        final String path = item is Map ? '${item['pic_path'] ?? ''}' : '$item';
        final String url = StoreApi.img(path);
        if (url.isNotEmpty) list.add(url);
      }
    } else if (raw is String && raw.isNotEmpty) {
      for (final String path in raw.split(',')) {
        final String url = StoreApi.img(path.trim());
        if (url.isNotEmpty) list.add(url);
      }
    }
    // 没有图组时回退单张门店图
    if (list.isEmpty) {
      final String cover = StoreApi.img(detail['store_image']);
      if (cover.isNotEmpty) list.add(cover);
    }
    return list;
  }

  bool _isOn(dynamic val) => '${val ?? ''}' == '1';

  /// 拨打电话
  Future<void> callPhone() async {
    if (telphone.isEmpty) return;
    final Uri uri = Uri(scheme: 'tel', path: telphone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// 经纬度: 接口 latitude / longitude 多为字符串, 空 / 非数字 / 0 / 超范围都按没定位处理
  /// * 取不到时静态图画不出来(地图中心都没法给), 只能回落到按地址搜索
  double? _coord(String val) {
    final double? v = double.tryParse(val.trim());
    if (v == null || v == 0) return null;
    return v;
  }

  double? get lat {
    final double? v = _coord(latitude);
    return (v == null || v.abs() > 90) ? null : v;
  }

  double? get lng {
    final double? v = _coord(longitude);
    return (v == null || v.abs() > 180) ? null : v;
  }

  bool get hasLocation => lat != null && lng != null;

  /// 打开地图(有经纬度定位到点,否则按地址搜索)
  Future<void> openMap() async {
    final Uri uri = hasLocation
        ? Uri.parse('https://uri.amap.com/marker?position=$lng,$lat&name=${Uri.encodeComponent(storeName)}')
        : Uri.parse('https://uri.amap.com/search?keyword=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('门店详情', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: Loading(title: '加载中...'));
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 13.0, color: FStyle.c999)),
            const SizedBox(height: 12.0),
            TextButton(onPressed: load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHead(),
          // 信息卡上移压住图片底部(H5 .detail-content margin-top: -30rpx)
          Transform.translate(offset: const Offset(0, -15.0), child: _buildContent()),
          const SizedBox(height: 15.0),
          _buildMap(),
        ],
      ),
    );
  }

  /// 顶部门店图(底部渐变与背景融合,与 H5 .detail-head::after 一致)
  Widget _buildHead() {
    return SizedBox(
      // 门头图占比: 屏宽的 0.6(约 3:5),比之前的 0.45 更饱满,又不至于把下面的信息挤出首屏
      height: MediaQuery.sizeOf(context).width * 0.6,
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildSwiper()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56.0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, bgColor],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 图片轮播(多图时右下角显示 1/n,与 H5 .img-indicator-dots 一致)
  Widget _buildSwiper() {
    final List<String> list = images;
    if (list.isEmpty) {
      return Container(
        color: tagBgColor,
        alignment: Alignment.center,
        child: const Icon(Icons.storefront_rounded, color: Colors.grey, size: 48.0),
      );
    }
    return Swiper.children(
      autoplay: list.length > 1,
      duration: 600,
      pagination: list.length > 1
          ? const SwiperPagination(
              alignment: Alignment.bottomRight,
              builder: FractionPaginationBuilder(color: Colors.white70, activeColor: Colors.white, fontSize: 12.0),
            )
          : null,
      children: list
          .map((String url) => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: tagBgColor),
                errorWidget: (_, __, ___) => Container(
                  color: tagBgColor,
                  alignment: Alignment.center,
                  child: const Icon(Icons.storefront_rounded, color: Colors.grey, size: 48.0),
                ),
              ))
          .toList(),
    );
  }

  /// 信息卡: 名称+状态 / 营业时间+标签 / 地址 / 电话
  Widget _buildContent() {
    final bool hasTime = openDate.isNotEmpty || tags.isNotEmpty || closeDesc.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9.0)),
      child: Column(
        children: <Widget>[
          _buildNameRow(hasTime || address.isNotEmpty || telphone.isNotEmpty),
          if (hasTime) _buildTimeRow(address.isNotEmpty || telphone.isNotEmpty),
          if (address.isNotEmpty) _buildAddressRow(telphone.isNotEmpty),
          if (telphone.isNotEmpty) _buildTelphoneRow(false),
        ],
      ),
    );
  }

  /// 门店名 + 营业状态
  Widget _buildNameRow(bool withDivider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        border: withDivider ? const Border(bottom: BorderSide(color: lineColor, width: 0.5)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              storeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.5),
            ),
          ),
          const SizedBox(width: 10.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
            decoration: BoxDecoration(
              border: Border.all(color: stateWarning ? stateWarningColor : stateColor, width: 0.5),
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Text(
              stateText,
              style: TextStyle(fontSize: 11.0, color: stateWarning ? stateWarningColor : stateColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 休息说明 + 营业时间 + 服务标签
  Widget _buildTimeRow(bool withDivider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        border: withDivider ? const Border(bottom: BorderSide(color: lineColor, width: 0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (closeDesc.isNotEmpty) ...<Widget>[
            Text(closeDesc, style: const TextStyle(fontSize: 12.0, color: Colors.red)),
            const SizedBox(height: 6.0),
          ],
          if (openDate.isNotEmpty)
            Text(openDate, style: const TextStyle(fontSize: 12.0, color: subColor)),
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              children: tags
                  .map((String e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
                        decoration: BoxDecoration(color: tagBgColor, borderRadius: BorderRadius.circular(3.0)),
                        child: Text(e, style: const TextStyle(fontSize: 11.0, color: tagColor)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 地址 + 导航按钮
  Widget _buildAddressRow(bool withDivider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        border: withDivider ? const Border(bottom: BorderSide(color: lineColor, width: 0.5)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              address,
              style: const TextStyle(fontSize: 12.0, color: subColor, height: 1.5),
            ),
          ),
          const SizedBox(width: 10.0),
          _iconButton(Icons.navigation_outlined, openMap),
        ],
      ),
    );
  }

  /// 电话 + 拨号按钮
  Widget _buildTelphoneRow(bool withDivider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13.0),
      decoration: BoxDecoration(
        border: withDivider ? const Border(bottom: BorderSide(color: lineColor, width: 0.5)) : null,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              telphone,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: primary),
            ),
          ),
          _iconButton(Icons.phone_outlined, callPhone),
        ],
      ),
    );
  }

  /// 右侧灰底图标按钮(H5 .icondiy)
  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30.0,
        height: 24.0,
        decoration: BoxDecoration(color: tagBgColor, borderRadius: BorderRadius.circular(3.0)),
        alignment: Alignment.center,
        child: Icon(icon, size: 15.0, color: tagColor),
      ),
    );
  }

  /// 门店地图(静态地图图片;点击拉起外部地图导航)
  /// * 项目没接地图SDK(高德/百度/腾讯的 Flutter 插件都没引入), 不能内嵌可交互地图,
  ///   这里用静态地图接口出图: 有图能看清门店位置, 点一下再跳高德做导航
  Widget _buildMap() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15.0, 0, 15.0, 20.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(left: 12.0, top: 14.0, bottom: 10.0),
            child: Text('门店地图', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          GestureDetector(
            onTap: openMap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
              height: 180.0,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: tagBgColor, borderRadius: BorderRadius.circular(8.0)),
              // 有经纬度就出地图(静态图/瓦片由 StaticMap 内部选择), 没有才回落占位块
              child: hasLocation
                  ? StaticMap(latitude: lat!, longitude: lng!)
                  : _mapPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  /// 地图占位块: 接口没下发经纬度(画不出地图)时的兜底, 点击按地址搜索
  Widget _mapPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.location_on_outlined, size: 28.0, color: tagColor),
        const SizedBox(height: 6.0),
        const Text('门店未配置经纬度，点击按地址搜索', style: TextStyle(fontSize: 12.0, color: tagColor)),
      ],
    );
  }
}
