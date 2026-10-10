/// 入口文件main.dart
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'controller/auth_store.dart';
import 'controller/video_store.dart';
import 'controller/app_config.dart';
// 开发调试: 暂时注释穿山甲相关 import(恢复广告时与本文件里的 Ads.init / Content.init 一起解开)
// import 'utils/ads.dart';
// import 'utils/content.dart';
// 引入路由管理
import 'router/index.dart';
import 'components/splash_cover.dart';
import 'utils/privacy_agreement.dart';

void main() async {
  // 必须先初始化绑定, 才能使用插件/存储
  WidgetsFlutterBinding.ensureInitialized();

  // 全局未捕获错误兜底(含首帧绘制/回调中的异步错误), 至少能打到日志, 不再静默白屏
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[uncaught] $error\n$stack');
    return true;
  };

  // 各原生插件初始化单独 try/catch: 任一个在 iOS 上抛异常都绝不能让整个 App 白屏
  try {
    await GetStorage.init();
    // 读取首次启动隐私协议同意状态(必须在 runApp 前完成,决定初始路由)
    await PrivacyAgreement.init();
  } catch (e) {
    debugPrint('[main] 存储初始化异常: $e');
  }

  // 注册GetxController(也包裹, 避免在 runApp 前抛异常导致纯白屏)
  try {
    Get.put(AuthStore());
    Get.put(VideoStore());
    Get.put(AppConfig()); // 进入 App 即拉取 /api/config/init 全局配置
  } catch (e) {
    debugPrint('[main] Get.put 异常: $e');
  }

  // 全局错误兜底: 即使后续 UI 构建抛错也能在日志看到, 而不是纯白屏
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // 诊断用兜底(确认 iOS 正常后可删除): 构建出错时显示具体错误, 而不是纯白屏
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          '页面渲染出错(请截图反馈):\n${details.exception}\n\n${details.stack}',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    );
  };

  // 先启动 UI, 不要被原生 SDK 初始化阻塞。
  // 关键: Ads.init() 内部在 iOS 会 await requestIDFA(弹 ATT 跟踪授权框),
  // 首启时该 await 会卡住 / 与系统网络授权框互相干扰, 导致 runApp 迟迟不执行 -> 白屏;
  // 二次启动 ATT 已授权会立即返回才正常。所以必须在 runApp 之后再做这类初始化。
  runApp(const MyApp());

  // 以下为不阻塞首帧的后台初始化, 各自兜底, 任一失败不影响首屏使用
  unawaited(_initSdks());
}

/// 后台初始化原生 SDK(广告/内容/媒体), 不在启动关键路径上
Future<void> _initSdks() async {
  // 初始化media_kit视频套件
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[main] MediaKit.ensureInitialized 异常: $e');
  }

  // 初始化穿山甲广告SDK(内部 iOS 会弹 ATT 授权框, 已放到首帧之后, 不阻塞启动)
  // 开发调试: 暂时注释掉(见 AdsConfig.debugDisable), 恢复时把下面 5 行解开
  // try {
  //   await Ads.init();
  // } catch (e) {
  //   debugPrint('[main] Ads.init 异常(已忽略, 不影响启动): $e');
  // }

  // 穿山甲内容SDK(短剧/小视频): 依赖上面的广告SDK, 失败/H5 自动跳过, 页面走兜底
  // 开发调试: 广告SDK 关了它也起不来, 一并注释; 恢复时把下面 5 行解开
  // try {
  //   await Content.init();
  // } catch (e) {
  //   debugPrint('[main] Content.init 异常(已忽略): $e');
  // }
}

class MyApp extends StatelessWidget {
 const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyAgreement.agreedNotifier,
      builder: (BuildContext context, bool agreed, Widget? child) {
        // 是否windows平台
        bool isWindows() {
          if (kIsWeb) return false;
          final platform = Theme.of(context).platform;
          return platform == TargetPlatform.windows;
        }

        return AnnotatedRegion(
          value: const SystemUiOverlayStyle(
            // 启动图期间状态栏透明: 由启动图自己决定底色,避免出现一条白/黑边
            // 状态栏透明,由各页面自己决定顶部背景;默认深色图标(适配白底页面)
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Android 深色图标
            statusBarBrightness: Brightness.light, // iOS 深色图标
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Stack(
            fit: StackFit.expand,
            // Stack 在 GetMaterialApp 之外,拿不到 MaterialApp 注入的 Directionality,
            // 这里显式给 textDirection,否则默认 AlignmentDirectional.topStart 会报错
            textDirection: TextDirection.ltr,
            children: <Widget>[
              GetMaterialApp(
                // 注意: 这里不能靠换 key 重建来应用新的 initialRoute
                // * navigatorKey 是同一个 GlobalKey, 重建时旧 NavigatorState 会被"接管",
                //   路由栈仍是 /privacy_agreement, initialRoute 不会生效
                // * 同意隐私政策后由隐私页自己 Get.offAllNamed('/') 完成跳转
                title: '乐惠新零售',
                debugShowCheckedModeBanner: false,
                // 排查路由跳转用: debug 下打印路由变化
                routingCallback: (Routing? routing) {
                  if (kDebugMode) {
                    debugPrint('route -> current=${routing?.current} previous=${routing?.previous} isBack=${routing?.isBack} args=${routing?.args}');
                  }
                },
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF2C55)),
                  useMaterial3: true,
                  fontFamily: isWindows() ? 'Microsoft YaHei' : null,
                  // 全局 toast 居中显示(默认在底部)
                  extensions: <ThemeExtension<dynamic>>[
                    ShirneDialogTheme(toastStyle: ToastStyle().center()),
                  ],
                ),
                // 中文本地化: 日期选择器等需要 MaterialLocalizations(zh_CN),否则报错
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('zh', 'CN'),
                  Locale('en', 'US'),
                ],
                // 首次未同意隐私政策概要: 先进同意页; 已同意则正常进首页
                initialRoute: agreed ? '/' : '/privacy_agreement',
                // 路由页面
                getPages: routePages,
                // 点击页面空白处收起软键盘: iOS 没有系统返回键(Android 点返回键能收), 只能靠点空白
                // * 子 widget 自带手势(按钮/列表项)时会在手势竞技场里赢, 这里的 onTap 不会触发, 不影响正常点击
                // * 滚动时收起另见各页面 ScrollView 的 keyboardDismissBehavior
                builder: (BuildContext context, Widget? child) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: child,
                ),
                navigatorKey: MyDialog.navigatorKey,
              ),
              // 启动图遮罩: 仅已同意时展示, 盖在 App 最上层, 首页首屏数据加载完成后淡出
              if (agreed) const SplashCover(),
            ],
          ),
        );
      },
    );
  }
}
