/// 全局状态管理
library;

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../api/coupon.dart';
import '../api/member.dart';
import '../config/index.dart';

class AuthStore extends GetxController {
static AuthStore get to => Get.find();
final GetStorage storage = GetStorage();
// 存储键名
final String authKey = 'authorization';
// 登录验证token
RxString authorization = ''.obs;
// 会员信息(/api/member/info)
RxMap memberInfo = <String, dynamic>{}.obs;
// 已绑定门店id,0 表示未绑定
RxInt storeId = 0.obs;
// 可用优惠券数量(/coupon/api/coupon/num)
RxInt couponNum = 0.obs;
// 券数量安全读取(web热重载会保留旧实例, 新增字段可能未初始化, 读不到时按0处理)
int get couponCount {
  try {
    return couponNum.value;
  } catch (_) {
    return 0;
  }
}
// 判断是否登录
bool get isLogin => storage.hasData(authKey);

// ===== 会员信息快捷读取(字段来自 /api/member/info) =====
// 会员id
int get memberId => int.tryParse('${memberInfo['member_id'] ?? ''}') ?? 0;
// 昵称(为空时回退用户名)
String get nickname {
  final String val = '${memberInfo['nickname'] ?? ''}'.trim();
  return val.isNotEmpty ? val : '${memberInfo['username'] ?? ''}';
}
// 头像完整地址(相对路径拼接图片域名)
String get headimg {
  final String val = '${memberInfo['headimg'] ?? ''}'.trim();
  if (val.isEmpty) return '';
  if (val.startsWith('http')) return val;
  return '${Config.imgDomain}/$val';
}
// 账号(用户名)
String get username => '${memberInfo['username'] ?? ''}'.trim();
// 真实姓名
String get realname => '${memberInfo['realname'] ?? ''}'.trim();
// 性别: 0 未知 / 1 男 / 2 女
int get sex => int.tryParse('${memberInfo['sex'] ?? ''}') ?? 0;
// 性别文案
String get sexName => sex == 1 ? '男' : (sex == 2 ? '女' : '未知');
// 生日(yyyy-MM-dd),未设置返回空
String get birthday {
  final dynamic val = memberInfo['birthday'];
  if (val == null) return '';
  final int time = int.tryParse('$val') ?? 0;
  if (time <= 0) return '';
  return time.toString().length <= 10
      ? DateTime.fromMillisecondsSinceEpoch(time * 1000).toString().substring(0, 10)
      : DateTime.fromMillisecondsSinceEpoch(time).toString().substring(0, 10);
}
// 会员等级名
String get memberLevelName => '${memberInfo['member_level_name'] ?? ''}';
// 余额 = balance + balance_money
String get balance {
  final double a = double.tryParse('${memberInfo['balance'] ?? 0}') ?? 0;
  final double b = double.tryParse('${memberInfo['balance_money'] ?? 0}') ?? 0;
  return (a + b).toStringAsFixed(2);
}
// 积分
String get point => '${memberInfo['point'] ?? 0}';
// 手机号
String get mobile => '${memberInfo['mobile'] ?? ''}';
// 已绑定门店名
String get storeName => '${memberInfo['store_name'] ?? ''}';
// 是否已绑定门店(store_id 非 0; 少数账号只下发 store_name, 一并兼容)
bool get hasStore => storeId.value != 0 || storeName.isNotEmpty;

// ===== 个人资料页(设置)用字段 =====
// 是否已设置登录密码(修改密码时决定走「原密码」还是「短信动态码」)
bool get hasPassword {
  final dynamic val = memberInfo['password'];
  if (val == null) return false;
  if (val is num) return val != 0;
  final String text = '$val'.trim();
  return text.isNotEmpty && text != '0';
}
// 是否已绑定微信(wxopen_openid 有值即已绑定)
bool get wxBound => '${memberInfo['wxopen_openid'] ?? ''}'.trim().isNotEmpty;
// 账号是否允许修改(is_edit_username == 1)
bool get canEditUsername => '${memberInfo['is_edit_username'] ?? ''}' == '1';
// 所在地址: 省/市/区 id
int get provinceId => int.tryParse('${memberInfo['province_id'] ?? ''}') ?? 0;
int get cityId => int.tryParse('${memberInfo['city_id'] ?? ''}') ?? 0;
int get districtId => int.tryParse('${memberInfo['district_id'] ?? ''}') ?? 0;
// 所在地址: 省市区文本 / 详细地址
String get fullAddress => '${memberInfo['full_address'] ?? ''}';
String get address => '${memberInfo['address'] ?? ''}';

@override
void onInit() async {
  super.onInit();
  await GetStorage.init();
  // 初始化
  final authVal = storage.read(authKey);
  if(authVal != null) {
  authorization.value = authVal;
 }
 // 已登录: 启动时拉取会员信息
 if (authorization.value.isNotEmpty) {
  loadMemberInfo();
 }
}
// 设置登录验证key
void setAuthorization(dynamic data) {
 authorization.value = data;
  storage.write(authKey, data);
  update();
}
// 拉取会员信息,失败静默不抛(避免影响登录/启动主流程)
Future<void> loadMemberInfo() async {
  try {
    final dynamic res = await MemberApi.info();
    if (res is Map) {
      // 会员被锁定(status == 0): 清空登录态,与H5处理一致
      if ('${res['status'] ?? ''}' == '0') {
        logout();
        return;
      }
      memberInfo.value = Map<String, dynamic>.from(res);
      storeId.value = int.tryParse('${res['store_id'] ?? ''}') ?? 0;
      update();
      await loadCouponNum();
    }
  } catch (_) {}
}
// 可用优惠券数量,失败静默(数量仅为「我的」页展示用,不阻断主流程)
Future<void> loadCouponNum() async {
  try {
    couponNum.value = await CouponApi.num();
  } catch (_) {}
}
// 退出
void logout() {
 authorization.value = '';
  storage.remove(authKey);
  memberInfo.value = <String, dynamic>{};
  storeId.value = 0;
  couponNum.value = 0;
 update();
 }
}
