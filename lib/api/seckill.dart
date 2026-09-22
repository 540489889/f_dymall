/// 限时秒杀相关接口
/// 对齐 H5: pages_promotion/seckill/(list|detail|payment).vue
/// * 场次列表   POST /seckill/api/seckill/lists
/// * 商品分页   POST /seckill/api/seckillgoods/page  (page/page_size/seckill_time_id/seckill_time_type)
/// * 商品列表   POST /seckill/api/seckillgoods/lists (seckill_time_id, 不分页, data 直接是数组)
/// * 秒杀详情   POST /seckill/api/seckillgoods/detail (seckill_id)
/// * 秒杀规格   POST /seckill/api/seckillgoods/goodsSku (goods_id + seckill_id)
/// * 下单       /seckill/api/ordercreate/(payment|calculate|create)
/// 注意: 秒杀插件接口只解析表单参数, 请求必须带 form: true, 否则报"缺少参数xxx"
library;

import 'dart:convert';

import '../config/index.dart';
import '../utils/request.dart';

/// 秒杀场次(一个时间段,如 00:00~23:00)
class SeckillTime {
  /// 场次id
  final int id;
  /// 场次名
  final String name;
  /// 当日开始秒数(0~86399)
  final int startTime;
  /// 当日结束秒数(0~86399)
  final int endTime;
  /// today 今日 / tomorrow 明日预告
  final String type;

  const SeckillTime({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.type = 'today',
  });

  factory SeckillTime.fromJson(Map<dynamic, dynamic> json) {
    return SeckillTime(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      startTime: int.tryParse('${json['seckill_start_time'] ?? 0}') ?? 0,
      endTime: int.tryParse('${json['seckill_end_time'] ?? 0}') ?? 0,
      type: '${json['type'] ?? 'today'}',
    );
  }

  bool get isTomorrow => type == 'tomorrow';

  /// 场次开始时间文案(HH:mm)
  String get startTimeText {
    final int h = startTime ~/ 3600;
    final int m = (startTime % 3600) ~/ 60;
    return '${_pad(h)}:${_pad(m)}';
  }

  /// 是否处于该场次进行中
  /// * [secondsOfDay] 当前服务器时间的当日秒数
  bool isNow(int secondsOfDay) {
    if (isTomorrow) return false;
    return secondsOfDay >= startTime && secondsOfDay < endTime;
  }

  /// 距开始/结束的剩余秒数(进行中返回距结束, 未开始返回距开始)
  /// * [secondsOfDay] 当前服务器时间的当日秒数
  int remainSeconds(int secondsOfDay) {
    if (isNow(secondsOfDay)) return endTime - secondsOfDay;
    int start = startTime - secondsOfDay;
    // 明日场: 需跨过当天剩余时间
    if (isTomorrow) start = 86400 - secondsOfDay + startTime;
    return start < 0 ? 0 : start;
  }

  /// 状态: 0 已结束 / 1 抢购中 / 2 即将开始 / 3 明日预告
  int statusOf(int secondsOfDay) {
    if (isTomorrow) return 3;
    if (isNow(secondsOfDay)) return 1;
    if (secondsOfDay < startTime) return 2;
    return 0;
  }

  static String _pad(int v) => v < 10 ? '0$v' : '$v';
}

class SeckillApi {
  /// 场次列表(/seckill/api/seckill/lists)
  /// * 返回 { list: [SeckillTime], timestamp: 服务器时间戳(秒) }
  static Future<Map<String, dynamic>> timeList() async {
    // timestamp 在响应顶层(不在 data 内), 用 postRaw 拿原始响应做对时
    final Map<String, dynamic> raw0 = await Request().postRaw('/seckill/api/seckill/lists', form: true);
    final int timestamp = int.tryParse('${raw0['timestamp'] ?? 0}') ?? 0;
    final dynamic data = raw0['data'];
    final dynamic raw = data is Map ? data['list'] : data;
    final List<SeckillTime> list = <SeckillTime>[];
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is Map) list.add(SeckillTime.fromJson(item));
      }
    } else if (raw is Map) {
      // 接口可能返回以 id 为 key 的对象(H5 用 Object.values)
      for (final dynamic item in raw.values) {
        if (item is Map) list.add(SeckillTime.fromJson(item));
      }
    }
    return <String, dynamic>{'list': list, 'timestamp': timestamp};
  }

  /// 秒杀商品分页(/seckill/api/seckillgoods/page)
  /// * [seckillTimeId] 场次id
  /// * [type] 场次类型 today / tomorrow
  /// * 返回 { list: [...], count: 总数, pageCount: 总页数 }
  /// * ⚠ 该接口有 bug: 会漏商品(实测少返回一条)且 goods_stock 返回负值(-2/0),
  ///   列表与首页统一改用 goodsList(/seckillgoods/lists)
  static Future<Map<String, dynamic>> goodsPage({
    required int seckillTimeId,
    String type = 'today',
    int page = 1,
    int pageSize = 10,
  }) async {
    final dynamic res = await Request().post(
      '/seckill/api/seckillgoods/page',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'seckill_time_id': seckillTimeId,
        'seckill_time_type': type,
      },
      form: true,
    );
    final dynamic list = res is Map ? res['list'] : res;
    return <String, dynamic>{
      'list': toCardList(list is List ? list : const []),
      'count': int.tryParse('${res is Map ? res['count'] ?? 0 : 0}') ?? 0,
      'pageCount': int.tryParse('${res is Map ? res['page_count'] ?? 1 : 1}') ?? 1,
    };
  }

  /// 秒杀商品列表(不分页, /seckill/api/seckillgoods/lists)
  /// * 注意: 该接口的场次参数名是 seckill_time_id(不是 seckill_id)
  static Future<List<Map<String, dynamic>>> goodsList({
    required int seckillTimeId,
    String type = 'today',
  }) async {
    final dynamic res = await Request().post(
      '/seckill/api/seckillgoods/lists',
      data: <String, dynamic>{'seckill_time_id': seckillTimeId, 'seckill_time_type': type},
      form: true,
    );
    final dynamic list = res is Map ? res['list'] : res;
    return toCardList(list is List ? list : const []);
  }

  /// 秒杀商品详情(/seckill/api/seckillgoods/detail)
  /// * [seckillId] 秒杀商品id(列表项的 id)
  /// * 返回页面可直接使用的结构化数据, 异常时返回空 map
  static Future<Map<String, dynamic>> detail(int seckillId) async {
    final Map<String, dynamic> raw0 = await Request().postRaw(
      '/seckill/api/seckillgoods/detail',
      data: <String, dynamic>{'seckill_id': seckillId},
      form: true,
    );
    final dynamic data = raw0['data'];
    final dynamic detail = data is Map ? data['goods_sku_detail'] : null;
    if (detail is! Map) return const {};

    final int timestamp = int.tryParse('${raw0['timestamp'] ?? 0}') ?? 0;
    // 场次区间: [{seckill_start_time, seckill_end_time}] -> SeckillTime
    final List<SeckillTime> times = <SeckillTime>[];
    final dynamic rawTimes = detail['time_list'];
    if (rawTimes is List) {
      for (final dynamic item in rawTimes) {
        if (item is Map) times.add(SeckillTime.fromJson(item));
      }
    }

    final List<String> imgList = _buildImages(detail);
    return <String, dynamic>{
      'seckillId': _toNum(detail['seckill_id'] ?? detail['id'] ?? seckillId),
      // 服务器时间戳(秒), 用于倒计时对时
      'timestamp': timestamp,
      'goodsId': _toNum(detail['goods_id']),
      'skuId': _toNum(detail['sku_id']),
      'title': '${detail['goods_name'] ?? ''}',
      'skuName': '${detail['sku_name'] ?? ''}',
      'introduction': '${detail['introduction'] ?? ''}',
      // 秒杀价
      'seckillPrice': _toNum(detail['seckill_price'] ?? detail['price']),
      // 原价
      'price': _toNum(detail['price']),
      'images': imgList.where((String e) => e.trim().isNotEmpty).map(_fixImage).toList(),
      'content': '${detail['goods_content'] ?? ''}',
      'saleNum': _toNum(detail['sale_num']),
      'stock': _toNum(detail['stock'] ?? detail['goods_stock']),
      'maxBuy': _toNum(detail['max_buy']),
      'unit': '${detail['unit'] ?? ''}',
      // 活动起止时间(秒级时间戳)
      'startTime': _toNum(detail['start_time']),
      'endTime': _toNum(detail['end_time']),
      // 场次区间(当日秒数)
      'times': times,
      'specFormat': _parseJsonList(detail['sku_spec_format']),
      'specGroups': _parseJsonList(detail['goods_spec_format']),
      'attrList': _parseJsonList(detail['goods_attr_format']),
      'expressType': detail['express_type'] ?? const {},
      'goodsService': (detail['goods_service'] ?? const []) as List,
      'shopInfo': data is Map ? (data['shop_info'] ?? const {}) : const {},
    };
  }

  /// 秒杀商品规格(/seckill/api/seckillgoods/goodsSku)
  /// * 返回 [{sku_id, seckill_price, price, stock, max_buy, sku_name, sku_spec_format, ...}]
  static Future<List<Map<String, dynamic>>> goodsSku({
    required int goodsId,
    required int seckillId,
  }) async {
    final dynamic res = await Request().post(
      '/seckill/api/seckillgoods/goodsSku',
      data: <String, dynamic>{'goods_id': goodsId, 'seckill_id': seckillId},
      form: true,
    );
    final dynamic list = res is Map ? res['list'] ?? res['data'] : res;
    if (list is! List) return const [];
    return list.whereType<Map>().map((Map e) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(e);
      // 规格字段是字符串化的 json(H5: JSON.parse(item.sku_spec_format / goods_spec_format))
      item['specFormat'] = _parseJsonList(item['sku_spec_format']);
      item['specTree'] = _parseJsonList(item['goods_spec_format']);
      return item;
    }).toList();
  }

  /// 规格树(商品维度, 各 sku 的 goods_spec_format 相同)
  /// * [{spec_id, spec_name, value: [{spec_value_id, spec_value_name, image, sku_id, disabled, selected}]}]
  /// * disabled=true 表示该规格未参与本次秒杀
  static List<Map<String, dynamic>> specTreeOf(List<dynamic> skus) {
    for (final dynamic sku in skus) {
      if (sku is! Map) continue;
      final dynamic tree = sku['specTree'];
      if (tree is List && tree.isNotEmpty) {
        return tree.whereType<Map>().map((Map e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  /// 规格文案(取 sku_spec_format 的 value_name)
  static String specTextOf(Map<dynamic, dynamic> sku) {
    final dynamic raw = sku['specFormat'];
    if (raw is List && raw.isNotEmpty) {
      final String text = raw
          .whereType<Map>()
          .map((Map e) => '${e['spec_value_name'] ?? ''}')
          .where((String e) => e.isNotEmpty)
          .join(' ');
      if (text.isNotEmpty) return text;
    }
    return '${sku['sku_name'] ?? ''}';
  }

  /// 商品列表转页面卡片结构
  /// * 列表字段: id(秒杀id)/goods_id/goods_name/goods_image/price/seckill_price/goods_stock/sale_num
  static List<Map<String, dynamic>> toCardList(List list) {
    return list.whereType<Map>().map((Map<dynamic, dynamic> item) {
      final String images = '${item['goods_image'] ?? ''}';
      final List<String> imageList = images.isEmpty
          ? const <String>[]
          : images.split(',').where((String e) => e.trim().isNotEmpty).toList();
      return <String, dynamic>{
        'id': _toNum(item['id']),
        'goodsId': _toNum(item['goods_id']),
        'title': '${item['goods_name'] ?? ''}',
        'price': _toNum(item['price']),
        'seckillPrice': _toNum(item['seckill_price'] ?? item['price']),
        'image': _fixImage(imageList.isEmpty ? '' : imageList.first),
        'images': imageList.map(_fixImage).toList(),
        'stock': _toNum(item['goods_stock'] ?? item['stock']),
        'saleNum': _toNum(item['sale_num']),
        'maxBuy': _toNum(item['max_buy']),
        'discountRate': _toNum(item['discount_rate']),
        'seckillName': '${item['seckill_name'] ?? ''}',
        'startTime': _toNum(item['start_time']),
        'endTime': _toNum(item['end_time']),
      };
    }).toList();
  }

  /// 详情轮播图: 优先 sku_images / goods_image, 回退 sku_image
  static List<String> _buildImages(Map<dynamic, dynamic> detail) {
    final List<String> result = <String>[];
    final String skuImages = '${detail['sku_images'] ?? ''}';
    if (skuImages.trim().isNotEmpty) result.addAll(skuImages.split(','));
    if (result.isEmpty) {
      final String goodsImage = '${detail['goods_image'] ?? ''}';
      if (goodsImage.trim().isNotEmpty) result.addAll(goodsImage.split(','));
    }
    if (result.isEmpty && '${detail['sku_image'] ?? ''}'.trim().isNotEmpty) {
      result.add('${detail['sku_image']}');
    }
    // 去空 + 去重(保持原顺序)
    final List<String> unique = <String>[];
    for (final String url in result) {
      final String item = url.trim();
      if (item.isNotEmpty && !unique.contains(item)) unique.add(item);
    }
    return unique;
  }

  /// json 字符串转 List(接口字段多为字符串化的 json)
  static List<dynamic> _parseJsonList(dynamic value) {
    if (value == null || '$value'.isEmpty) return const [];
    if (value is List) return value;
    try {
      return jsonDecode('$value') as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  /// 统一转 num(接口字段多为字符串)
  static num _toNum(dynamic value) {
    if (value == null || '$value'.isEmpty) return 0;
    return num.tryParse('$value') ?? 0;
  }

  /// 图片地址处理: 配置了 Config.imageProxy 时走代理(解决web跨域无法解码)
  static String _fixImage(String url) {
    if (url.isEmpty || Config.imageProxy.isEmpty) return url;
    return '${Config.imageProxy}${Uri.encodeComponent(url)}';
  }
}
