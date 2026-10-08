/// APP 全局配置(启动时拉取 /api/config/init,全 App 共享)
library;

import 'package:get/get.dart';
import '../api/config.dart';

class AppConfig extends GetxController {
  static AppConfig get to => Get.find<AppConfig>();

  /// 配置数据(启动拉取成功后写入,初始为空)
  final Rx<Map<String, dynamic>> data = Rx<Map<String, dynamic>>({});

  /// 便捷读取整份配置
  Map<String, dynamic> get config => data.value;

  /// 按 key 读取某项(取不到返回 [fallback])
  dynamic get(String key, [dynamic fallback]) =>
      data.value.containsKey(key) ? data.value[key] : fallback;

  @override
  void onInit() {
    super.onInit();
    // 进入 App 即拉取配置(失败忽略,不影响首屏)
    fetch();
  }

  /// 拉取 /api/config/init 并写入 data
  Future<void> fetch() async {
    final Map<String, dynamic> res = await ConfigApi.init();
    if (res.isNotEmpty) data.value = res;
  }
}
