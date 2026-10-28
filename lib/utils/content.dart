/// 穿山甲内容输出(pangrowth_content): 短剧 / 小视频 / 短故事
/// * 依赖 gromore_ads: 必须先 Ads.init() 成功(Ads.ready) 才能初始化内容SDK
/// * 必须要有后台「内容合作」下发的 SDK_Setting_*.json, 否则初始化失败, 页面走兜底
/// * 只有 Android/iOS 有实现: H5/桌面端一律跳过, 否则 MissingPluginException
library;

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, ValueNotifier, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pangrowth_content/pangrowth_content.dart';

import 'ads.dart';

export 'package:pangrowth_content/pangrowth_content.dart';

class Content {
  /// 当前平台是否支持内容SDK(无 web 实现, H5 直接跳过)
  static bool get supported => !kIsWeb;

  /// 内容SDK是否可用(初始化成功后才能渲染短剧/小视频)
  /// * 用 ValueNotifier 暴露, 让短剧/小视频页在「隐私同意后才初始化」的场景下能自动重绘
  static final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  /// 兼容旧读法的 getter
  static bool get ready => readyNotifier.value;

  /// 配置文件名(穿山甲后台下载, 如 SDK_Setting_5609594.json)
  /// * 放到 assets/ 根目录, 文件名必须跟这里一致, 且已在 pubspec 注册 assets/
  static const String configPath = 'SDK_Setting.json';

  /// 开关: Android 16+(API36) 是否跳过整个内容SDK(应急兜底用, 一旦打开连短剧也看不了)。
  /// * false = 放开(当前值): 内容SDK正常初始化, 短剧可播放。
  ///   依赖 android/app/build.gradle.kts 把 djx-lite/base 升到 3.0.0.2(修 DJX 侧 TLSv1, 也是这台
  ///   Android 16 上唯一能初始化成功的版本), 并靠 initialize(enableVideo=true) + start(startVideo=false)
  ///   的组合让 DPSdk 只 init 不 start —— 既给 DJX 提供版本号, 又避开 DP 的致命崩溃。详见文件内注释。
  /// * true = 整体跳过(仅应急): 连短剧一起跳过, 页面走兜底。平时不需要开。
  static const bool skipContentOnAndroid16 = false;

  /// 是否为 Android 16(API 36)及以上: 该系统版本移除了 TLSv1, 老 DJX 内容SDK会闪退
  static Future<bool> _isAndroid16OrAbove() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final int sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        return sdkInt >= 36;
      }
    } catch (e) {
      debugPrint('[content] 读取 Android 版本失败(不跳过初始化): $e');
    }
    return false;
  }

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
    // Android 16(API36) 起系统移除 TLSv1: DJX(短剧)/DP(小视频) 老版本的 TLSSocketFactory 硬编码 TLSv1,
    // 在其自带 OkHttp 后台线程发请求时抛 IllegalArgumentException("protocol TLSv1 is not supported")
    // 且未被捕获 -> 整个 App 进程被杀。
    // 现状: DJX 侧已由 build.gradle.kts 中 djx-lite/base 3.0.0.2 修掉(真机验证有效);
    // DP 侧无法 start(一 start 必崩), 已用 start(startVideo=false) 让其只 init 不 start(见下方注释)。
    // 因此这里不再按 Android 16 整体跳过内容SDK。
    if (skipContentOnAndroid16 && await _isAndroid16OrAbove()) {
      debugPrint('[content] Android 16+ 跳过内容SDK初始化(规避 DP 短剧SDK TLSv1 闪退), 短剧/小视频走兜底');
      return false;
    }
    try {
      final bool inited = await PangrowthContent.initialize(
        configPath: configPath,
        config: ContentConfig(
          enableDrama: true, // 短剧: DJX SDK 负责, djx-lite/base 3.0.0.2 已修掉其 TLSv1, 可正常播放
          enableStory: false, // 短故事(暂不需要)
          // 小视频这里必须传 true(但下方 start 不启动 video 模块, 小视频实际仍不可用)。
          // 原因: 插件 ContentSdkManager.initialize() 中 DPSdk.init 只在 enableVideo=true 时执行,
          //   而 DJX 发网络请求前要反射获取 DPSdk 版本号 —— DP 没 init 就拿不到, 短剧会一直"加载中"
          //   却拉不到内容(真机已复现)。传 true 让 DPSdk.init 执行即可, DP 自身不会因此发网络请求。
          enableVideo: true,
          debugLog: kDebugMode,
        ),
      );
      if (!inited) {
        debugPrint('[content] 内容SDK初始化失败(检查 $configPath 是否存在/是否开通内容合作)');
        return false;
      }
      // 关键: startVideo=false —— modules 只含 drama, DPSdk 不会 start, 从而规避 DP 的两处致命崩溃
      //   (dp 5.4.x 及更早 TLSv1 硬崩; dp 5.8.x 缺 com.pandora.common.env.Env$SdkContextEnv, 该包仓库没有)。
      //   而 DPSdk 已在 initialize 阶段 init, DJX 能反射到版本号, 短剧数据请求参数才完整。
      await PangrowthContent.start(
        startDrama: true,
        startStory: false,
        startVideo: false,
      );
      readyNotifier.value = true;
      debugPrint('[content] 内容SDK启动成功');
      return true;
    } catch (e) {
      debugPrint('[content] 内容SDK初始化异常: $e');
      return false;
    }
  }
}
