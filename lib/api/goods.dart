/// 商品相关接口
library;

import 'dart:convert';
import '../config/index.dart';
import '../utils/request.dart';

class GoodsApi {
  /// 首页商品分页(瀑布流)
  /// * [page] 页码,从1开始
  /// * [pageSize] 每页条数
  /// 返回 {page_count: 总页数, count: 总条数, list: 商品列表}
  static Future<Map<String, dynamic>> pageComponents({int page = 1, int pageSize = 12}) async {
    final dynamic res = await Request().post(
      '/api/goodssku/pageComponents',
      data: {'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      return {
        'page_count': res['page_count'] ?? 1,
        'count': res['count'] ?? 0,
        'list': (res['list'] ?? []) as List,
      };
    }
    return {'page_count': 1, 'count': 0, 'list': const []};
  }

  /// 商品分页(按分类/关键词筛选, /api/goodssku/page)
  /// * [categoryId] 一级分类id(0 表示全部,不传该参数)
  /// * [keyword] 搜索关键词
  /// * 已实测: category_id 与 keyword 生效, category_ids 无效
  /// 返回 {page_count: 总页数, count: 总条数, list: 商品列表}(字段与 pageComponents 一致)
  static Future<Map<String, dynamic>> pageList({
    int page = 1,
    int pageSize = 12,
    int categoryId = 0,
    String keyword = '',
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (categoryId > 0) data['category_id'] = categoryId;
    if (keyword.isNotEmpty) data['keyword'] = keyword;
    final dynamic res = await Request().post('/api/goodssku/page', data: data);
    if (res is Map) {
      return {
        'page_count': res['page_count'] ?? 1,
        'count': res['count'] ?? 0,
        'list': (res['list'] ?? []) as List,
      };
    }
    return {'page_count': 1, 'count': 0, 'list': const []};
  }

  /// 商品分类树(/api/goodscategory/tree)
  /// * 返回一级分类列表: [{category_id, category_name, pid, level, image, image_adv, ...}]
  /// * 接口异常时返回空列表
  static Future<List<Map<String, dynamic>>> categoryTree() async {
    final dynamic res = await Request().get('/api/goodscategory/tree');
    if (res is List) return res.cast<Map<String, dynamic>>();
    return const <Map<String, dynamic>>[];
  }

  /// 商品详情
  /// * [goodsId] 商品id,必须走 query 传参(body 不生效,后端会提示"缺少参数id")
  /// * [skuId] 规格 sku id,传了会切换到对应 SKU
  /// 返回页面可直接使用的结构化数据,接口异常时返回空 map
  static Future<Map<String, dynamic>> detail(int goodsId, {int? skuId}) async {
    final Map<String, dynamic> query = <String, dynamic>{'goods_id': goodsId};
    if (skuId != null) query['sku_id'] = skuId;
    final dynamic res = await Request().post(
      '/api/goodssku/detail',
      queryParameters: query,
    );
    final dynamic detail = res is Map ? res['goods_sku_detail'] : null;
    if (detail is! Map) return const {};

    // 轮播图: 多图实际在 goods_image / goods_image_list,sku_images 常为空
    final List<String> imgList = _buildImages(detail);

    return <String, dynamic>{
      'goodsId': detail['goods_id'],
      'skuId': detail['sku_id'],
      'title': '${detail['goods_name'] ?? ''}',
      // 副标题/卖点
      'introduction': '${detail['introduction'] ?? ''}',
      // 价格: 优惠价 > 会员价 > 原价,均为字符串
      'price': _toNum(detail['discount_price'] ?? detail['member_price'] ?? detail['price']),
      'originPrice': _toNum(detail['price']),
      'marketPrice': _toNum(detail['market_price']),
      'showMarketPrice': detail['market_price_show'] == 1,
      'images': imgList.where((String e) => e.trim().isNotEmpty).map(_fixImage).toList(),
      // 富文本详情(HTML)
      'content': '${detail['goods_content'] ?? ''}',
      'saleNum': _toNum(detail['sale_num']),
      'showSale': detail['sale_show'] == 1,
      'stock': _toNum(detail['stock'] ?? detail['goods_stock']),
      'showStock': detail['stock_show'] == 1,
      'labelName': '${detail['label_name'] ?? ''}',
      'unit': '${detail['unit'] ?? ''}',
      'isCollect': detail['is_collect'] == 1,
      // 1 在售, 0 下架
      'onSale': detail['goods_state'] == 1,
      'isFreeShipping': detail['is_free_shipping'] == 1,
      'specFormat': parseSpecFormat(detail['sku_spec_format']),
      'specGroups': parseSpecFormat(detail['goods_spec_format']),
      // 规格属性(商品参数): [{attr_name, attr_value_name}]
      'attrList': parseSpecFormat(detail['goods_attr_format']),
      'couponList': (detail['coupon_list'] ?? const []) as List,
      'goodsPromotion': (detail['goods_promotion'] ?? const []) as List,
      'bundlingList': (detail['bundling_list'] ?? const []) as List,
      'manjian': detail['manjian'],
      'expressType': detail['express_type'] ?? const {},
      'maxBuy': _toNum(detail['max_buy']),
      'minBuy': _toNum(detail['min_buy']),
      'purchasedNum': _toNum(detail['purchased_num']),
    };
  }

  /// 详情轮播图: 按优先级取图并去重
  /// 1) sku_images(逗号分隔)  2) goods_image_list[].pic_path
  /// 3) goods_image(逗号分隔) 4) sku_image_list.pic_path / sku_image
  static List<String> _buildImages(Map<dynamic, dynamic> detail) {
    List<String> result = <String>[];

    final String skuImages = '${detail['sku_images'] ?? ''}';
    if (skuImages.trim().isNotEmpty) result = skuImages.split(',');

    if (result.isEmpty) {
      final dynamic goodsImageList = detail['goods_image_list'];
      if (goodsImageList is List) {
        result = goodsImageList
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) => '${e['pic_path'] ?? ''}')
            .where((String e) => e.isNotEmpty)
            .toList();
      }
    }

    if (result.isEmpty) {
      final String goodsImage = '${detail['goods_image'] ?? ''}';
      if (goodsImage.trim().isNotEmpty) result = goodsImage.split(',');
    }

    if (result.isEmpty) {
      final dynamic skuImageList = detail['sku_image_list'];
      if (skuImageList is Map && '${skuImageList['pic_path'] ?? ''}'.isNotEmpty) {
        result = <String>['${skuImageList['pic_path']}'];
      }
    }

    if (result.isEmpty) result = <String>['${detail['sku_image'] ?? ''}'];

    // 去空 + 去重(保持原顺序)
    final List<String> unique = <String>[];
    for (final String url in result) {
      final String item = url.trim();
      if (item.isNotEmpty && !unique.contains(item)) unique.add(item);
    }
    return unique;
  }

  /// 统一转 num(接口字段多为字符串)
  static num _toNum(dynamic value) {
    if (value == null || '$value'.isEmpty) return 0;
    return num.tryParse('$value') ?? 0;
  }

  /// 商品列表转页面卡片结构
  static List<Map<String, dynamic>> toCardList(List list) {
    return list.map((item) {
      final String images = '${item['goods_image'] ?? ''}';
      final List<String> imageList = images.isEmpty ? const [] : images.split(',');
      return <String, dynamic>{
        'id': item['goods_id'],
        'skuId': item['sku_id'],
        'title': '${item['goods_name'] ?? ''}',
        'price': num.tryParse('${item['price']}') ?? 0,
        // 划线价(后端为 0.00 时表示未设置,页面内自行兜底)
        'marketPrice': num.tryParse('${item['market_price']}') ?? 0,
        'image': _fixImage(imageList.isEmpty ? '' : imageList.first),
        'images': imageList.map(_fixImage).toList(),
        'saleNum': '${item['sale_num'] ?? 0}',
        'shop': '${item['label_name'] ?? ''}',
        'stock': item['stock'] ?? 0,
        'unit': '${item['unit'] ?? ''}',
        'isFreeShipping': item['is_free_shipping'] == 1,
      };
    }).toList();
  }

  /// 图片地址处理: 配置了 Config.imageProxy 时走代理(解决web跨域无法解码)
  static String _fixImage(String url) {
    if (url.isEmpty || Config.imageProxy.isEmpty) return url;
    return '${Config.imageProxy}${Uri.encodeComponent(url)}';
  }

  /// 解析商品规格(用于详情规格选择)
  static List<dynamic> parseSpecFormat(dynamic value) {
    if (value == null || '$value'.isEmpty) return const [];
    try {
      return jsonDecode('$value') as List<dynamic>;
    } catch (e) {
      return const [];
    }
  }
}
