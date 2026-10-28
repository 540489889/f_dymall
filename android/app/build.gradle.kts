import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 华为厂商通道(离线推送): 不引入 agcp 插件 —— 它与本项目 AGP 8.11.1 + Kotlin DSL 不兼容,
// 一旦 apply 会让 com.android.application 访问器全部解析失败(namespace/compileSdk 等全报错)。
// 改为手写等价配置:
//   1) agconnect-services.json 放 src/main/assets/(华为 HMS push SDK 运行时读取 app_id)
//   2) AndroidManifest.xml 里的 com.huawei.hms.client.appid meta-data(华为通道注册用)
// 阿里云推送 SDK 自带华为/小米等厂商通道(由 initAndroidThirdPush 注册), 无需 JPush 插件。

// 签名配置: android/key.properties(不提交仓库)
// * debug 与 release 使用同一签名,保证微信开放平台只需登记一个签名MD5:
//   c5c09f6db62c3fa9be21a0f4a6f82c54(包名 com.chongloutech.lehui)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
// keystore 路径相对 gradle 根目录(android/)解析: keystore/ 与 key.properties 同层,
// 故 key.properties 里写 "keystore/lehui.keystore" 即可, 不要再写 app 模块相对路径(file() 会错)
val keystoreFile: File? =
    if (keystorePropertiesFile.exists()) rootProject.file(keystoreProperties["storeFile"] as String) else null

android {
    namespace = "com.chongloutech.lehui"
    // permission_handler_android 要求编译 SDK >= 37, Flutter 默认的 flutter.compileSdkVersion(36) 编不过
    // * 若提示找不到 android-37, 用 Android Studio 的 SDK Manager 安装 "Android SDK Platform 37"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // mobile_scanner(扫码)依赖的 camerax 需要开启脱糖
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 与穿山甲后台创建应用时填写的包名保持一致, 否则广告请求报 40006
        applicationId = "com.chongloutech.lehui"
        // GroMore 融合SDK要求 minSdk >= 24
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ===== 阿里云移动推送(离线推送) =====
        // * AppKey/AppSecret 由 Dart 侧 initPush(appKey:, appSecret:) 传入, 无需 manifestPlaceholders
        // * 华为 appid / 小米 id·key 写在 AndroidManifest.xml 的 <meta-data>, 不在此处
    }

    signingConfigs {
        // 覆盖默认 debug 签名,避免换机器后签名漂移导致微信授权报 -6
        // * keystoreFile 已在脚本顶部按 gradle 根目录(android/)解析, 与 key.properties/keystore/ 同层
        getByName("debug") {
            keystoreFile?.let {
                storeFile = it
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
        create("release") {
            if (keystoreFile != null) {
                storeFile = keystoreFile
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            } else {
                // 无签名文件时退回 debug 签名,保证 flutter run --release 仍能装
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Kotlin 2.x 起 kotlinOptions.jvmTarget 已废弃(会当编译错误),改用 compilerOptions DSL
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// ===== Android 16 短剧: 让短剧真正能播放 =====
// 已逐条真机排除的结论:
//   * 插件原版组合(djx/base 2.6.0.0)在这台 Android 16 上内容SDK初始化直接失败 -> 页面只能走兜底假数据。
//     其他手机能播是因为它们 Android <16, 2.6.0.0 在那些系统上正常。故 djx/base 必须升级。
//   * djx/base 升到 3.0.0.2 后初始化成功、DJX(短剧)侧 TLSv1 崩溃消失, 但短剧"一直加载" —— 根因是
//     DJX 发网络请求前要反射获取 DPSdk 版本号, 而插件 ContentSdkManager.initialize() 里 DPSdk.init
//     仅在 enableVideo=true 时才执行; 关掉小视频后 DP 根本没 init, 版本号拿不到, 请求参数不完整。
//   * DP 一旦 start 就必崩: 5.4.x 及更早 TLSv1 硬崩; 5.8.x 缺 com.pandora.common.env.Env$SdkContextEnv,
//     而 com.pandora.* 不在其 POM、不在任何已发布 AAR、仓库里也没有(已逐一核实)。
// 方案: 让 DPSdk.init 执行、但不让 video 模块 start ——
//   initialize 传 enableVideo=true(触发 DPSdk.init, 供 DJX 反射取版本号);
//   start 传 startVideo=false(modules 只含 drama, DPSdk 不会 start, 规避上述两种崩溃)。
//   实现见 lib/utils/content.dart。
// * mediation-sdk 不 force, 保持插件原生态 7.1.1.4, 避免破坏 GroMore 广告。
configurations.all {
    resolutionStrategy {
        // DP SDK 5.8.1.0(与 djx 3.0.0.2 同批次配套): 只会 init, 不会 start(startVideo=false), 故不会崩
        force("com.pangle.cn:pangrowth-dpsdk:5.8.1.0")
        // DJX 基础库: 修 DJX 侧 TLSv1, 且是这台 Android 16 上唯一能初始化成功的版本
        force("com.pangle.cn:pangrowth-djx-sdk-lite:3.0.0.2")
        force("com.pangle.cn:pangrowth-base:3.0.0.2")
        // 注意: 绝不要 exclude ttsdk-player_premium —— 它是火山引擎播放器, DJX(短剧)播视频依赖它
        //   (pangrowth-djx-sdk-lite 的 POM 明确声明 com.bytedanceapi:ttsdk-player_premium:1.42.3.5)。
        //   此前为防 dp 旧版撞类而全局排除它, 直接导致短剧"列表能看见但播不了"(播放器根本没进包);
        //   列表只需数据所以照常渲染, 播放才需要播放器。
        //   dp 5.8.1.0 的 POM 已不含该依赖, 故这条 exclude 不再需要, 已移除。
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // 阿里云移动推送: 原生 SDK(含华为/小米等厂商通道)由 aliyun_push 插件以 api 方式透传依赖,
    // 无需在此手动声明; 厂商通道注册由 Dart 侧 initAndroidThirdPush() 触发。
}

flutter {
    source = "../.."
}
