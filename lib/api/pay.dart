/// 支付相关接口
/// 对齐 H5: components/payment/payment.vue + components/ns-payment/ns-payment.vue
/// * /api/pay/type             可用支付方式
/// * /api/pay/getBalanceConfig 余额支付配置balance_show
/// * /api/memberaccount/usablebalance 会员可用余额
/// * /api/pay/info             支付单信息(pay_money/out_trade_no/return_url)
/// * /api/pay/pay              发起支付
/// * /api/pay/status           查询支付状态(1未支付 2已支付)
/// * /api/pay/resetpay         重置支付单据(取消支付后换取新支付单号)
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../utils/request.dart';

/// 支付方式(与 H5 payTypeList 一致)
class PayType {
  const PayType({
    required this.type,
    required this.name,
    this.provider = '',
  });

  /// 后台标识: wechatpay / alipay / offlinepay / yeepay
  final String type;

  /// 展示名称
  final String name;

  /// uni.requestPayment 的 provider: wxpay / alipay
  final String provider;

  /// 是否线下支付
  bool get isOffline => type == 'offlinepay';

  /// 是否微信支付
  bool get isWechat => type == 'wechatpay' || type == 'yeepay';

  /// 是否支付宝
  bool get isAlipay => type == 'alipay';
}

/// 发起支付结果(/api/pay/pay)
class PayResult {
  const PayResult({
    required this.paySuccess,
    required this.payType,
    this.url = '',
    this.message = '',
    this.data = const <String, dynamic>{},
    this.wxPay = const <String, String>{},
    this.miniProgramOrgId = '',
    this.prePayTn = '',
  });

  /// 已支付成功(余额付完/0元单)
  final bool paySuccess;

  /// 当前使用的支付方式
  final String payType;

  /// 需要跳转的支付链接(支付宝/微信H5支付页)
  final String url;

  /// 提示信息
  final String message;

  /// 原始支付参数(APP端唤起SDK用: timeStamp/nonceStr/package/signType/paySign)
  final Map<String, dynamic> data;

  /// 微信 APP 支付参数(从 data 里解析出的 SDK 参数,为空表示后台给的不是APP支付)
  /// * 键: appId / partnerId / prepayId / package / nonceStr / timeStamp / sign / signType
  final Map<String, String> wxPay;

  /// 微信小程序原始id(yeepay 通道: gh_xxx,用于拉起小程序支付)
  /// * 对应 H5: res.data.miniProgramOrgId
  final String miniProgramOrgId;

  /// 微信小程序支付页路径(yeepay 通道: 带支付参数的 page path)
  /// * 对应 H5: res.data.prePayTn
  final String prePayTn;

  /// 是否走「小程序支付」通道(yeepay)
  bool get isMiniProgramPay => miniProgramOrgId.isNotEmpty && prePayTn.isNotEmpty;
}

class PayApi {
  /// 默认支付方式(与 H5 components/payment/payment.vue payTypeList 一致)
  /// * yeepay 也是微信支付(后台常用配置),与 wechatpay 同名,命中时取前者
  static const List<PayType> defaultTypes = <PayType>[
    PayType(type: 'yeepay', name: '微信支付', provider: 'wxpay'),
    PayType(type: 'wechatpay', name: '微信支付', provider: 'wxpay'),
    PayType(type: 'alipay', name: '支付宝支付', provider: 'alipay'),
    PayType(type: 'offlinepay', name: '线下支付'),
  ];

  /// 可用支付方式(/api/pay/type,GET)
  /// * 返回后台配置的 pay_type 集合,为空表示未配置
  static Future<List<PayType>> payType({List<PayType>? types}) async {
    final Map<String, dynamic> res = await Request().getRaw('/api/pay/type');
    if ('${res['code']}' != '0') return <PayType>[];
    final dynamic data = res['data'];
    if (data == null) return <PayType>[];
    // 后台可能返回 { pay_type: 'yeepay,alipay' } / 'yeepay,alipay' / ['yeepay']
    final dynamic raw = data is Map ? (data['pay_type'] ?? data['pay_type_list'] ?? '') : data;
    final String text = raw is List ? raw.join(',') : '$raw';
    if (kDebugMode) debugPrint('[pay/type] $text');
    final String payType = text.trim();
    if (payType.isEmpty || payType == 'null' || payType == '[]' || payType == '{}') return <PayType>[];
    final List<PayType> all = types ?? defaultTypes;
    final List<PayType> result = <PayType>[];
    for (final PayType e in all) {
      // 与 H5 一致: res.data.pay_type.indexOf(val.type) != -1(包含匹配)
      if (!payType.contains(e.type)) continue;
      // 同名支付方式只保留一个(yeepay 与 wechatpay 同为微信支付)
      if (result.any((PayType x) => x.name == e.name)) continue;
      result.add(e);
    }
    return result;
  }

  /// 余额支付配置(/api/pay/getBalanceConfig): 返回 balance_show(1开启)
  static Future<int> balanceConfig() async {
    final Map<String, dynamic> res = await Request().postRaw('/api/pay/getBalanceConfig');
    final dynamic data = res['data'];
    if (data is Map) return int.tryParse('${data['balance_show'] ?? 0}') ?? 0;
    return 0;
  }

  /// 会员可用余额(/api/memberaccount/usablebalance)
  static Future<num> usableBalance() async {
    final Map<String, dynamic> res = await Request().postRaw('/api/memberaccount/usablebalance');
    final dynamic data = res['data'];
    if (data is Map) return num.tryParse('${data['usable_balance'] ?? 0}') ?? 0;
    return 0;
  }

  /// 支付单信息(/api/pay/info)
  /// * 返回 out_trade_no / pay_money / event / return_url 等
  static Future<Map<String, dynamic>> info(String outTradeNo) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/pay/info',
      data: <String, dynamic>{'out_trade_no': outTradeNo},
    );
    // 与 H5 一致: code >= 0 且 data 存在即视为成功
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code >= 0 && data is Map) return data.cast<String, dynamic>();
    throw Exception('${res['message'] ?? '未获取到支付信息'}');
  }

  /// 发起支付(/api/pay/pay)
  /// * [outTradeNo] 支付单号
  /// * [payType] 支付方式标识(无支付方式时传空,余额/0元支付场景)
  /// * [isBalance] 是否使用余额抵扣
  /// * [returnUrl] 支付完成回跳地址(H5端用于支付宝/微信支付后跳回)
  static Future<PayResult> pay({
    required String outTradeNo,
    String payType = '',
    int isBalance = 0,
    String returnUrl = '',
    int scene = 0,
  }) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/pay/pay',
      data: <String, dynamic>{
        'out_trade_no': outTradeNo,
        'pay_type': payType,
        'is_balance': isBalance,
        if (returnUrl.isNotEmpty) 'return_url': returnUrl,
        'scene': scene,
      },
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    final Map<String, dynamic> map = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    if (code < 0) {
      throw Exception('${res['message'] ?? '支付失败'}');
    }
    // 支付链接: 微信走 url,支付宝走 data(与 H5 location.href 一致)
    // * 不同通道字段名不统一(mweb_url / pay_url / h5_url),逐个兜取
    String url = '${map['url'] ?? ''}';
    if (url.isEmpty) url = '${map['mweb_url'] ?? ''}';
    if (url.isEmpty) url = '${map['pay_url'] ?? ''}';
    if (url.isEmpty) url = '${map['h5_url'] ?? ''}';
    if (url.isEmpty && (payType == 'alipay' || payType == 'yeepay')) url = '${map['data'] ?? ''}';
    final Map<String, String> wxPay = wxAppPayParamsOf(map);
    // yeepay 通道: 拉起微信小程序支付(与 H5 APP 端 res.data.miniProgramOrgId / prePayTn 一致)
    // * 少数通道会把参数塞在 data 里,这里做一层兜底
    String miniProgramOrgId = '${map['miniProgramOrgId'] ?? ''}';
    String prePayTn = '${map['prePayTn'] ?? ''}';
    final dynamic inner = map['data'];
    if (inner is Map) {
      final Map<String, dynamic> m = inner.cast<String, dynamic>();
      if (miniProgramOrgId.isEmpty) miniProgramOrgId = '${m['miniProgramOrgId'] ?? ''}';
      if (prePayTn.isEmpty) prePayTn = '${m['prePayTn'] ?? ''}';
    }
    if (kDebugMode) {
      debugPrint('[pay/pay] payType=$payType url=${url.isEmpty ? '(空)' : '有'} '
          'miniProgram=${miniProgramOrgId.isEmpty ? '(无)' : '$miniProgramOrgId / $prePayTn'} '
          'wxPay=${wxPay.isEmpty ? '(无SDK参数)' : wxPay.keys.toList()} dataKeys=${map.keys.toList()}');
    }
    return PayResult(
      paySuccess: '${map['pay_success'] ?? 0}' == '1' || '${map['pay_success'] ?? ''}' == 'true',
      payType: payType,
      url: url,
      message: '${res['message'] ?? ''}',
      data: map,
      wxPay: wxPay,
      miniProgramOrgId: miniProgramOrgId,
      prePayTn: prePayTn,
    );
  }

  /// 从支付结果里解析微信 APP 支付参数(唤起 fluwx 用)
  /// * 微信直连 / 易宝等不同通道字段命名不统一(全小写 / 驼峰),这里按候选 key 逐个兜取
  /// * 参数嵌在 data 里时(部分通道)做一层递归
  /// * 必需项: partnerId + prepayId + timeStamp + sign,缺一个就认为不是 APP 支付
  static Map<String, String> wxAppPayParamsOf(Map<String, dynamic> map) {
    String pick(Map<String, dynamic> source, List<String> keys) {
      for (final String key in keys) {
        final dynamic v = source[key];
        if (v == null) continue;
        final String s = '$v'.trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
      return '';
    }

    Map<String, String> parse(Map<String, dynamic> source) {
      final String partnerId = pick(source, const <String>['partnerId', 'partnerid', 'mchId', 'mch_id']);
      final String prepayId = pick(source, const <String>['prepayId', 'prepayid']);
      final String timeStamp = pick(source, const <String>['timeStamp', 'timestamp']);
      final String sign = pick(source, const <String>['sign', 'paySign', 'pay_sign']);
      if (partnerId.isEmpty || prepayId.isEmpty || timeStamp.isEmpty || sign.isEmpty) {
        return const <String, String>{};
      }
      return <String, String>{
        'appId': pick(source, const <String>['appId', 'appid']),
        'partnerId': partnerId,
        'prepayId': prepayId,
        // 微信固定值 Sign=WXPay,部分通道不下发,缺失时兜底
        'package': pick(source, const <String>['package', 'packageValue']).isEmpty
            ? 'Sign=WXPay'
            : pick(source, const <String>['package', 'packageValue']),
        'nonceStr': pick(source, const <String>['nonceStr', 'noncestr']),
        'timeStamp': timeStamp,
        'sign': sign,
        'signType': pick(source, const <String>['signType', 'sign_type']),
      };
    }

    final Map<String, String> own = parse(map);
    if (own.isNotEmpty) return own;
    final dynamic inner = map['data'];
    if (inner is Map) return parse(inner.cast<String, dynamic>());
    return const <String, String>{};
  }

  /// 查询支付状态(/api/pay/status): 返回 pay_status(1未支付 2已支付)
  static Future<int> status(String outTradeNo) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/pay/status',
      data: <String, dynamic>{'out_trade_no': outTradeNo},
    );
    if ('${res['code']}' != '0') return -1;
    final dynamic data = res['data'];
    if (data is Map) return int.tryParse('${data['pay_status'] ?? 0}') ?? 0;
    return 0;
  }

  /// 重置支付单据(/api/pay/resetpay): 返回新的 out_trade_no
  static Future<String> resetPay(String outTradeNo) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/pay/resetpay',
      data: <String, dynamic>{'out_trade_no': outTradeNo},
    );
    if ('${res['code']}' != '0') return '';
    final dynamic data = res['data'];
    if (data is Map) return '${data['out_trade_no'] ?? ''}';
    if (data is String) return data;
    return '$data';
  }
}
