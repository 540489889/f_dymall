/// 全局状态管理
library;

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthStore extends GetxController {
static AuthStore get to => Get.find();
final GetStorage storage = GetStorage();
// 存储键名
final String authKey = 'authorization';
// 登录验证token
RxString authorization = ''.obs;
// 判断是否登录
bool get isLogin => storage.hasData(authKey);

@override
void onInit() async {
  super.onInit();
  await GetStorage.init();
  // 初始化
  final authVal = storage.read(authKey);
  if(authVal != null) {
  authorization.value = authVal;
 }
}
// 设置登录验证key
void setAuthorization(dynamic data) {
 authorization.value = data;
  storage.write(authKey, data);
  update();
}
// 退出
void logout() {
 authorization.value = '';
  storage.remove(authKey);
 update();
 }
}
