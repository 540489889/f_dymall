/// APP 全局配置(启动时拉取 /api/config/init,全 App 共享)
library;

import 'package:get/get.dart';
import '../api/config.dart';
import '../utils/app_splash.dart';

class AppConfig extends GetxController {
  static AppConfig get to => Get.find<AppConfig>();

  /// 配置数据(启动拉取成功后写入,初始为空)
  final Rx<Map<String, dynamic>> data = Rx<Map<String, dynamic>>({});

  /// 便捷读取整份配置
  Map<String, dynamic> get config => data.value;

  /// 按 key 读取某项(取不到返回 [fallback])
  dynamic get(String key, [dynamic fallback]) =>
      data.value.containsKey(key) ? data.value[key] : fallback;

  /// 拉取失败后的最大重试次数
  static const int maxRetry = 3;

  bool _fetching = false;
  int _retries = 0;

  @override
  void onInit() {
    super.onInit();
    // 进入 App 即拉取配置
    fetch();
  }

  /// 配置为空时补拉一次
  /// * 幂等: 已有配置或正在拉取时直接返回, 多处调用不会重复发请求
  /// * 主要场景见 [fetch] 的重试说明: 首启那次请求失败后再给一次机会
  Future<void> fetchIfEmpty() async {
    if (data.value.isNotEmpty || _fetching) return;
    await fetch();
  }

  /// 拉取 /api/config/init 并写入 data
  Future<void> fetch() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final Map<String, dynamic> res = await ConfigApi.init();
      if (res.isNotEmpty) {
        data.value = res;
        _retries = 0;
        return;
      }
      // 首启(iOS 首次安装)时这个请求经常被系统网络授权弹窗打断: 弹窗没点之前请求直接失败,
      // 而它只拉这一次, 失败后本次启动就一直拿不到 diy 底部导航 -> 底部 tab 只剩文字没有图标。
      // 这里退避重试几次, 覆盖"用户点完授权弹窗 / 网络刚连上"这段时间
      // * 用循环而不是递归调 fetch(): 递归会被上面的 _fetching 拦掉(重试一直没生效)
      while (_retries < maxRetry && data.value.isEmpty) {
        _retries += 1;
        await Future<void>.delayed(Duration(seconds: 2 * _retries));
        if (data.value.isNotEmpty) break;
        final Map<String, dynamic> again = await ConfigApi.init();
        if (again.isNotEmpty) {
          data.value = again;
          _retries = 0;
          break;
        }
      }
    } finally {
      _fetching = false;
      // 请求成功 / 重试到放弃都算"配置阶段结束": 启动图还要等这个信号才关闭(见 AppSplash)
      AppSplash.markConfigReady();
    }
  }
}
