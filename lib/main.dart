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
// 引入路由管理
import 'router/index.dart';

void main() async {
  // 初始化get_storage存储
 await GetStorage.init();
  // 注册GetxController
 Get.put(AuthStore());
Get.put(VideoStore());
  // 初始化media_kit视频套件
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

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
       title: 'Flutter3 DYMALL',
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
          fontFamily: isWindows() ? 'Microsoft YaHei' : null
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
