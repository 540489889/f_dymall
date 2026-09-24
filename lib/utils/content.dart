/// 穿山甲内容输出(pangrowth_content): 短剧 / 小视频 / 短故事
/// * 依赖 gromore_ads: 必须先 Ads.init() 成功(Ads.ready) 才能初始化内容SDK
/// * 必须要有后台「内容合作」下发的 SDK_Setting_*.json, 否则初始化失败, 页面走兜底
/// * 只有 Android/iOS 有实现: H5/桌面端一律跳过, 否则 MissingPluginException
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:pangrowth_content/pangrowth_content.dart';

import 'ads.dart';

export 'package:pangrowth_content/pangrowth_content.dart';

class Content {
  /// 当前平台是否支持内容SDK(无 web 实现, H5 直接跳过)
  static bool get supported => !kIsWeb;

  /// 内容SDK是否可用(初始化成功后才能渲染短剧/小视频)
  static bool ready = false;

  /// 配置文件名(穿山甲后台下载, 如 SDK_Setting_5609594.json)
  /// * 放到 assets/ 根目录, 文件名必须跟这里一致, 且已在 pubspec 注册 assets/
  static const String configPath = 'SDK_Setting.json';

  /// 初始化内容SDK: 在 Ads.init() 之后调用, 失败不影响启动(页面走兜底)
  static Future<bool> init() async {
    if (!supported) {
      debugPrint('[content] 当前平台不支持内容SDK(H5/桌面端), 跳过初始化');
      return false;
    }
    if (ready) return true;
    // 内容SDK的广告(短剧解锁等)走 GroMore, 广告SDK没起来就别初始化
    if (!Ads.ready) {
      debugPrint('[content] 广告SDK未就绪, 跳过内容SDK初始化');
      return false;
    }
    try {
      final bool inited = await PangrowthContent.initialize(
        configPath: configPath,
        config: ContentConfig(
          enableDrama: true, // 短剧
          enableStory: false, // 短故事(暂不需要)
          enableVideo: true, // 小视频
          debugLog: kDebugMode,
        ),
      );
      if (!inited) {
        debugPrint('[content] 内容SDK初始化失败(检查 $configPath 是否存在/是否开通内容合作)');
        return false;
      }
      await PangrowthContent.start();
      ready = true;
      debugPrint('[content] 内容SDK启动成功');
      return true;
    } catch (e) {
      debugPrint('[content] 内容SDK初始化异常: $e');
      return false;
    }
  }
}
