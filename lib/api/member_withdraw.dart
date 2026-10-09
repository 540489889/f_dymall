/// 提现相关接口
/// 对齐 H5: pages_tool/member/apply_withdrawal.vue + withdrawal.vue + account.vue + account_edit.vue
/// * 提现信息 /api/memberwithdraw/info(配置 + 可提现余额)
/// * 申请提现 /api/memberwithdraw/apply
/// * 提现记录 /api/memberwithdraw/page
/// * 提现方式 /api/memberwithdraw/transferType
/// * 提现账户 /api/memberbankaccount/page|defaultinfo|info|add|edit|delete|setdefault
library;

import 'package:dio/dio.dart';

import '../utils/request.dart';

class MemberWithdrawApi {
  /// 提现信息(/api/memberwithdraw/info)
  /// 返回 { config: { is_use, min, rate }, member_info: { balance_money, ... } }
  static Future<Map<String, dynamic>> info() async {
    final dynamic res = await Request().get('/api/memberwithdraw/info');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 申请提现(/api/memberwithdraw/apply)
  /// * [transferType] bank 银行卡 / alipay 支付宝 / wechatpay 微信
  /// * [bankName] 银行名称(bank 必填);[accountNumber] 提现账号(wechatpay 不填)
  static Future<dynamic> apply({
    required String applyMoney,
    String transferType = '',
    String realname = '',
    String mobile = '',
    String bankName = '',
    String accountNumber = '',
    int appletType = 0,
  }) {
    return Request().post(
      '/api/memberwithdraw/apply',
      data: <String, dynamic>{
        'apply_money': applyMoney,
        'transfer_type': transferType,
        'realname': realname,
        'mobile': mobile,
        'bank_name': bankName,
        'account_number': accountNumber,
        'applet_type': appletType,
      },
    );
  }

  /// 提现详情(/api/memberwithdraw/detail)
  /// * 对齐 /api/orderrefund/detail 的返回结构 { code, data, message }
  /// * [id] 提现申请id(列表项 id)
  static Future<Map<String, dynamic>> detail(int id) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/memberwithdraw/detail',
      data: <String, dynamic>{'id': id},
    );
    final int code = int.tryParse('${res['code']}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) throw Exception('${res['message'] ?? '未获取到提现详情'}');
    return data.cast<String, dynamic>();
  }

  /// 提现记录(/api/memberwithdraw/page)
  static Future<List<Map<String, dynamic>>> page({int page = 1, int pageSize = 20}) async {
    final dynamic res = await Request().post(
      '/api/memberwithdraw/page',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// 提现方式
  /// * [type] 'member' 用 /api/memberwithdraw/transferType;'fenxiao' 用 /fenxiao/api/withdraw/transferType
  /// * member 端过滤 balance(余额提现仅分销可用),fenxiao 保留 balance
  static Future<List<Map<String, dynamic>>> transferType({String type = 'member'}) async {
    final String url = type == 'fenxiao'
        ? '/fenxiao/api/withdraw/transferType'
        : '/api/memberwithdraw/transferType';
    final dynamic res = await Request().get(url);
    final List<Map<String, dynamic>> types = <Map<String, dynamic>>[];
    if (res is! Map) return types;
    final Map<String, dynamic> data = res.cast<String, dynamic>();
    data.forEach((String key, dynamic value) {
      if (type != 'fenxiao' && key == 'balance') return;
      types.add(<String, dynamic>{'label': '$value', 'value': key});
    });
    return types;
  }

  /// 提现账户列表(/api/memberbankaccount/page)
  static Future<List<Map<String, dynamic>>> accountPage({int page = 1, int pageSize = 20}) async {
    final dynamic res = await Request().post(
      '/api/memberbankaccount/page',
      data: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    if (res is Map) {
      final dynamic list = res['list'];
      if (list is List) {
        return list.whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// 默认提现账户(/api/memberbankaccount/defaultinfo)
  static Future<Map<String, dynamic>> accountDefaultInfo() async {
    final dynamic res = await Request().get('/api/memberbankaccount/defaultinfo');
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 账户详情(/api/memberbankaccount/info)
  static Future<Map<String, dynamic>> accountInfo(int id) async {
    final dynamic res = await Request().post(
      '/api/memberbankaccount/info',
      data: <String, dynamic>{'id': id},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 新增 / 编辑账户(/api/memberbankaccount/add | /api/memberbankaccount/edit)
  /// * [id] 为 0 时新增,否则编辑
  static Future<dynamic> accountSave({
    int id = 0,
    required String realname,
    required String mobile,
    required String withdrawType,
    String bankAccount = '',
    String branchBankName = '',
  }) {
    return Request().post(
      id > 0 ? '/api/memberbankaccount/edit' : '/api/memberbankaccount/add',
      data: <String, dynamic>{
        if (id > 0) 'id': id,
        'realname': realname,
        'mobile': mobile,
        'withdraw_type': withdrawType,
        'bank_account': bankAccount,
        'branch_bank_name': branchBankName,
      },
    );
  }

  /// 微信免确认收款授权(/api/memberbankaccount/authorization)
  /// * 对齐 H5 account.vue toTransferAuth: 传账户 id,拿回微信拉授权需要的三个参数
  /// * 返回 { mchid, appid, package_info },拿到后交给微信SDK openBusinessView
  /// * code < 0 或没数据时抛异常(页面直接 toast message)
  static Future<Map<String, dynamic>> accountAuthorization(int id) async {
    final Map<String, dynamic> res = await Request().postRaw(
      '/api/memberbankaccount/authorization',
      data: <String, dynamic>{'id': id},
    );
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    final dynamic data = res['data'];
    if (code < 0 || data is! Map) {
      throw Exception('${res['message'] ?? '获取授权信息失败'}');
    }
    return data.cast<String, dynamic>();
  }

  /// 设为默认账户(/api/memberbankaccount/setdefault)
  static Future<dynamic> accountSetDefault(int id) {
    return Request().post('/api/memberbankaccount/setdefault', data: <String, dynamic>{'id': id});
  }

  /// 删除账户(/api/memberbankaccount/delete),默认账户不可删除
  static Future<dynamic> accountDelete(int id) {
    return Request().post('/api/memberbankaccount/delete', data: <String, dynamic>{'id': id});
  }

  /// 统一取错误提示
  static String errorMsg(dynamic error, [String fallback = '操作失败']) {
    if (error is DioException) {
      final String message = (error.message ?? '').trim();
      if (message.isNotEmpty) return message;
      return '网络异常,请稍后重试';
    }
    final String message = '$error'.replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }
}
