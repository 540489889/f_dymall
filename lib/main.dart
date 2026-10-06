/// 入口文件main.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'controller/auth_store.dart';
import 'controller/video_store.dart';
import 'utils/ads.dart';
import 'utils/content.dart';
// 引入路由管理
import 'router/index.dart';

void main() async {
  // 必须先初始化绑定, 才能使用插件/存储
  WidgetsFlutterBinding.ensureInitialized();

  // 各原生插件初始化单独 try/catch: 任一个在 iOS 上抛异常都绝不能让整个 App 白屏
  try {
    await GetStorage.init();
  } catch (e) {
    debugPrint('[main] GetStorage.init 异常: $e');
  }

  // 注册GetxController
  Get.put(AuthStore());
  Get.put(VideoStore());

  // 初始化media_kit视频套件
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[main] MediaKit.ensureInitialized 异常: $e');
  }

  // 初始化穿山甲广告SDK(未配置 appId 时内部直接跳过, 不影响启动)
  try {
    await Ads.init();
  } catch (e) {
    debugPrint('[main] Ads.init 异常(已忽略, 不影响启动): $e');
  }

  // 穿山甲内容SDK(短剧/小视频): 依赖上面的广告SDK, 失败/H5 自动跳过, 页面走兜底
  try {
    await Content.init();
  } catch (e) {
    debugPrint('[main] Content.init 异常(已忽略): $e');
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
 const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
   // 是否windows平台
  bool isWindows() {
    if (kIsWeb) return false;
     final platform = Theme.of(context).platform;
     return platform == TargetPlatform.windows;
    }

   return AnnotatedRegion(
   value: const SystemUiOverlayStyle(
     // 状态栏透明,由各页面自己决定顶部背景;默认深色图标(适配白底页面)
    statusBarColor: Colors.transparent,
     statusBarIconBrightness: Brightness.dark, // Android 深色图标
    statusBarBrightness: Brightness.light, // iOS 深色图标
    systemNavigationBarColor: Colors.transparent,
   systemNavigationBarIconBrightness: Brightness.dark,
   ),
      child: GetMaterialApp(
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
        // 初始化路由(默认进入首页,不强制先登录)
       initialRoute: '/',
        // 路由页面
       getPages: routePages,
      navigatorKey: MyDialog.navigatorKey,
     ),
    );
  }
}
