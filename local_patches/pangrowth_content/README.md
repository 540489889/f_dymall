# pangrowth_content

穿山甲内容 Flutter 插件，基于 PanGrowth SDK 实现短剧播放、小视频、短故事等内容功能。

📖 [完整文档](https://www.zhecent.com/sdks/flutter-pangrowth-content)

> 💬 作者是一位经验丰富的互联网从业人员，深耕互联网多年。如果您在使用过程中遇到问题，或者想交流广告变现、短剧APP等相关话题，欢迎添加作者微信 **light_core** 交流探讨。

---

## 🔗 Flutter 穿山甲广告变现套件系列

本插件是 **Flutter 穿山甲系列插件** 的内容组件，依赖 [gromore_ads](https://pub.dev/packages/gromore_ads) 提供广告变现能力。

| 插件 | 说明 | 文档 |
|------|------|------|
| [**gromore_ads**](https://pub.dev/packages/gromore_ads) | GroMore 聚合广告（核心依赖） | [查看文档](https://www.zhecent.com/sdks/flutter-gromore-ads) |
| **pangrowth_content** | 穿山甲内容（当前插件） | [查看文档](https://www.zhecent.com/sdks/flutter-pangrowth-content) |
| **gromore_adspark** | 穿山甲 AdSpark 智能广告投放（规划中） | - |
| **pangle_ecommerce** | 穿山甲电商联盟 - 抖音电商CPS（规划中） | - |
| **pangle_global** | Pangle Global 穿山甲国际版（规划中） | - |

> **⚠️ 重要提示**: 使用本插件前必须先正确初始化 `gromore_ads`，详见下方[快速开始](#-快速开始)章节。

---

## ✨ 特性

- ✅ **短剧功能** - 短剧聚合页、播放器、剧集管理、收藏点赞
- ✅ **小视频功能** - 沉浸式小视频、宫格布局、双Feed流
- ✅ **短故事功能** - 故事阅读器、分类浏览、阅读进度管理
- ✅ **事件监听** - 完整的播放、用户交互事件回调
- ✅ **双平台支持** - Android 和 iOS 平台原生实现

## 📱 平台支持

| Android | iOS |
|---------|-----|
| ✅ 21+  | ✅ 11.0+ |

---

## 🛠️ 安装

### 1. 添加依赖

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  pangrowth_content: ^1.0.0
  gromore_ads: ^1.0.0  # 必需依赖
```

运行安装命令：

```bash
flutter pub get
```

### 2. Android 配置

#### 2.1 修改 `android/build.gradle`

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        // 必需：穿山甲广告SDK仓库
        maven { url 'https://artifact.bytedance.com/repository/pangle' }
        // 必需：穿山甲内容SDK仓库
        maven { url 'https://artifact.bytedance.com/repository/Volcengine' }
    }
}
```

#### 2.2 修改 `android/app/build.gradle`

```groovy
android {
    compileSdkVersion 33  // 或更高版本

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

### 3. iOS 配置

#### 3.1 修改 `ios/Podfile`

```ruby
# 必需：添加穿山甲 SDK 源
source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/volcengine/volcengine-specs.git'

platform :ios, '11.0'
```

#### 3.2 安装依赖

```bash
cd ios
pod install
cd ..
```

### 4. 配置文件

将穿山甲平台提供的 `SDK_Setting_XXXXXXX.json` 配置文件：

- **Flutter assets**（推荐）：放到项目根目录的 `assets/` 目录
- **Android 原生**：放到 `android/app/src/main/assets/`
- **iOS Bundle**：放到 `ios/Runner/` 并在 Xcode 中添加到 Copy Bundle Resources

在 `pubspec.yaml` 中注册资源：

```yaml
flutter:
  assets:
    - assets/
```

---

## 🚀 快速开始

### 初始化 SDK

```dart
import 'package:flutter/foundation.dart';
import 'package:gromore_ads/gromore_ads.dart';
import 'package:pangrowth_content/pangrowth_content.dart';

Future<void> initContentSDK() async {
  // 1. 先初始化 GroMore 广告 SDK（内容 SDK 依赖它）
  final adsReady = await GromoreAds.initAd(
    'your_gromore_app_id',
    useMediation: true,
    debugMode: kDebugMode,
  );

  if (!adsReady) {
    debugPrint('GroMore 广告 SDK 初始化失败');
    return;
  }

  // 2. 初始化内容 SDK
  final initialized = await PangrowthContent.initialize(
    configPath: 'SDK_Setting_5609594.json',
    config: const ContentConfig(
      enableDrama: true,   // 启用短剧
      enableStory: true,   // 启用故事
      enableVideo: true,   // 启用小视频
      debugLog: kDebugMode,
    ),
  );

  if (!initialized) {
    debugPrint('穿山甲内容 SDK 初始化失败');
    return;
  }

  // 3. 启动内容服务
  await PangrowthContent.start();
  debugPrint('✅ 内容 SDK 启动成功');
}
```

---

## 📺 短剧模块

### 短剧聚合页

在 Flutter 页面中嵌入短剧聚合页：

```dart
import 'package:flutter/material.dart';
import 'package:pangrowth_content/pangrowth_content.dart';

class DramaHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('短剧推荐')),
      body: DramaHomeNativeView(
        config: const DramaHomeConfig(
          showBackBtn: false,           // 已有 AppBar，不需要原生返回按钮
          freeEpisodesCount: 3,         // 前 3 集免费
          unlockEpisodesCountUsingAd: 2, // 激励广告解锁 2 集
        ),
      ),
    );
  }
}
```

### 短剧播放器

使用 SDK 默认广告解锁流程：

```dart
class DramaPlayerPage extends StatelessWidget {
  final int dramaId;

  const DramaPlayerPage({required this.dramaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DramaPlayerNativeView(
        config: DramaPlayerConfig(
          dramaId: dramaId,
          episode: 1,              // 起始集数
          adMode: 'common',        // SDK 广告模式
          freeSet: 2,              // 前 2 集免费
          unlockSet: 3,            // 每次解锁 3 集
        ),
      ),
    );
  }
}
```

### 获取短剧列表

```dart
// 获取推荐短剧列表
final dramas = await PangrowthContent.getRecommendedDramaList(
  page: 1,
  count: 20,
);

// 搜索短剧
final searchResults = await PangrowthContent.searchDrama(
  '都市',
  isFuzzy: true,
  page: 1,
  count: 15,
);

// 获取分类列表
final categories = await PangrowthContent.getCategoryList();

// 按分类获取短剧
final dramasByCategory = await PangrowthContent.getDramaListByCategory(
  '甜宠',
  page: 1,
  count: 20,
);
```

---

## 📱 小视频模块

### 沉浸式小视频

全屏沉浸式视频播放体验：

```dart
import 'package:flutter/material.dart';
import 'package:pangrowth_content/pangrowth_content.dart';

class VideoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoNativeView(
        channelType: 1,  // 1-推荐, 2-关注, 3-推荐+关注
        autoPlay: true,
        listener: VideoListener(
          onVideoReady: (videoId) {
            debugPrint('视频就绪: $videoId');
          },
          onVideoError: (error) {
            debugPrint('视频错误: $error');
          },
        ),
      ),
    );
  }
}
```

### 宫格小视频

宫格布局的视频浏览入口：

```dart
class GridVideoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('宫格小视频')),
      body: GridVideoNativeView(
        layout: GridVideoLayout.grid,  // grid-宫格布局, doubleFeed-双Feed布局
        config: const GridVideoConfig(
          scene: 'home_grid',
          cardStyle: GridVideoCardStyle.normal,
          enableRefresh: true,
        ),
      ),
    );
  }
}
```

---

## 📖 故事模块

短故事模块提供完整的阅读器、分类浏览、阅读历史和进度管理功能。

### 快速示例

```dart
// 获取故事列表
final stories = await PangrowthContent.getStoryList(
  page: 1,
  count: 20,
  categoryId: 1,
);

// 打开故事阅读器
class StoryReaderPage extends StatelessWidget {
  final int storyId;

  const StoryReaderPage({required this.storyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StoryReaderNativeView(
        storyId: storyId,
        storyName: '故事标题',
      ),
    );
  }
}
```

---

## 📡 事件监听

### Widget级别监听

通过 `Listener` 监听组件事件（推荐）：

```dart
DramaPlayerNativeView(
  config: config,
  listener: DramaPlayerListener(
    onPlayerReady: (playerId) {
      debugPrint('播放器就绪: $playerId');
    },
    onEpisodeChange: (episode) {
      debugPrint('集数切换: $episode');
    },
    onPlayerError: (error) {
      debugPrint('播放器错误: $error');
    },
  ),
)
```

### 全局事件监听

监听 SDK 底层的全局事件（用于日志、埋点等）：

```dart
// 设置事件监听器
PangrowthContent.onEventListener(MyContentEventListener());

class MyContentEventListener extends OnContentEventListener {
  @override
  void onDramaPlayerEvent(DramaPlayerEvent event) {
    print('短剧播放事件: ${event.action}');
  }

  @override
  void onVideoEvent(VideoEvent event) {
    print('小视频事件: ${event.type}');
  }

  // ... 其他事件回调
}

// 注销监听
await PangrowthContent.removeEventListener();
```


## ❓ 常见问题

### Android 编译失败

**Q: 提示找不到 SDK 依赖？**

A: 确认 `android/build.gradle` 中添加了两个 Maven 仓库：

```groovy
allprojects {
    repositories {
        maven { url 'https://artifact.bytedance.com/repository/pangle' }
        maven { url 'https://artifact.bytedance.com/repository/Volcengine' }
    }
}
```

### iOS 编译失败

**Q: 提示 CocoaPods 错误？**

A: 尝试以下步骤：

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter run
```

### 初始化失败

**Q: 提示配置文件找不到？**

A: 检查配置文件位置和文件名：

1. 确保文件名格式为 `SDK_Setting_XXXXXXX.json`
2. **Flutter assets**：放在 `assets/` 目录并在 `pubspec.yaml` 中注册
3. **Android**：放在 `android/app/src/main/assets/`
4. **iOS**：放在 `ios/Runner/` 并在 Xcode 中添加到 Copy Bundle Resources

```bash
flutter pub get
flutter clean
flutter run
```

### 运行时错误

**Q: Android 运行时崩溃，提示 MultiDex 问题？**

A: 在 `android/app/build.gradle` 中启用 multiDex：

```groovy
defaultConfig {
    multiDexEnabled true
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

**Q: 聚合页或播放器显示空白？**

A: 确保：
1. 已完成 SDK 初始化：`PangrowthContent.initialize()` 和 `PangrowthContent.start()`
2. GroMore 广告 SDK 已成功初始化
3. 网络连接正常

---

## 📄 许可证

本插件遵循 [LICENSE](LICENSE) 文件中的许可证条款。

---

## 💬 支持与反馈

- **作者**: Xlxinxi
- **邮箱**: 369620805@qq.com
- **微信**: light_core
- 📖 [完整文档](https://www.zhecent.com/sdks/flutter-pangrowth-content)
- **问题反馈**: [GitHub Issues](https://github.com/Xlxinxi/flutter_pangrowth_content/issues)

---

© 2025 ZheCent Technology. All rights reserved.
