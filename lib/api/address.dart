/// 收货地址相关接口
/// 对齐 H5: pages_tool/member/address.vue + address_edit.vue + components/pick-regions
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class AddressApi {
  /// 地址列表(/api/memberaddress/page)
  /// * [type] 1 普通收货地址 2 同城配送地址
  static Future<List<Map<String, dynamic>>> page({
    int page = 1,
    int pageSize = 20,
    int type = 1,
    int storeId = 0,
  }) async {
    final dynamic res = await Request().post(
      '/api/memberaddress/page',
      data: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'type': type,
        'store_id': storeId,
      },
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// 地址详情(/api/memberaddress/info)
  static Future<Map<String, dynamic>> info(int id) async {
    final dynamic res = await Request().post(
      '/api/memberaddress/info',
      data: <String, dynamic>{'id': id},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 新增/编辑地址(/api/memberaddress/add | /api/memberaddress/edit)
  /// * [id] 为 0 时新增,否则编辑
  /// * [fullAddress] 省市区文本;[address] 详细地址
  static Future<dynamic> save({
    int id = 0,
    required String name,
    required String mobile,
    String telephone = '',
    required int provinceId,
    required int cityId,
    required int districtId,
    required String address,
    required String fullAddress,
    int isDefault = 0,
    int type = 1,
    String latitude = '',
    String longitude = '',
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'telephone': telephone,
      'province_id': provinceId,
      'city_id': cityId,
      'district_id': districtId,
      'community_id': 0,
      'address': address,
      'full_address': fullAddress,
      'latitude': type == 1 ? '' : latitude,
      'longitude': type == 1 ? '' : longitude,
      'is_default': isDefault,
      'type': type,
    };
    if (id > 0) data['id'] = id;
    return Request().post(
      id > 0 ? '/api/memberaddress/edit' : '/api/memberaddress/add',
      data: data,
    );
  }

  /// 三方(微信)地址导入(/api/memberaddress/addthreeparties)
  /// 对应 H5 一键获取地址: 入参为省市区名称而非id
  /// * Flutter 端暂无微信/小程序地址能力,接口保留备用
  static Future<dynamic> addThirdParties({
    required String name,
    required String mobile,
    required String province,
    required String city,
    required String district,
    required String address,
    required String fullAddress,
    int isDefault = 0,
  }) {
    return Request().post(
      '/api/memberaddress/addthreeparties',
      data: <String, dynamic>{
        'name': name,
        'mobile': mobile,
        'province': province,
        'city': city,
        'district': district,
        'address': address,
        'full_address': fullAddress,
        'is_default': isDefault,
      },
    );
  }

  /// 删除地址(/api/memberaddress/delete),默认地址不可删除
  static Future<dynamic> delete(int id) {
    return Request().post(
      '/api/memberaddress/delete',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 设为默认(/api/memberaddress/setdefault)
  static Future<dynamic> setDefault(int id) {
    return Request().post(
      '/api/memberaddress/setdefault',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 省市区列表(/api/address/lists),[pid] 上级id,取省级传 0
  static Future<List<Map<String, dynamic>>> areas(int pid) async {
    final dynamic res = await Request().post(
      '/api/address/lists',
      data: <String, dynamic>{'pid': pid},
    );
    if (res is List) {
      return res.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '操作失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.trim();
    return message.isEmpty ? fallback : message;
  }
}
