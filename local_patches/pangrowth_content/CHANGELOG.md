## 1.0.3

- 整理文档和优化代码格式 / Organized documentation and optimized code formatting

## 1.0.2

### 🐛 Bug 修复 / Bug Fixes
- 修复 iOS DramaPlayer 解锁回调中 episode 和 totalEpisodes 参数为 null 的问题 / Fixed null episode and totalEpisodes parameters in iOS DramaPlayer unlock callback
- 修复 DramaSwipeFlow 在 iOS 平台暂停/恢复控制不生效的问题 / Fixed pause/resume control not working in DramaSwipeFlow on iOS
- 修复 DramaSwipeFlow 在 Android 平台暂停/恢复控制不生效的问题 / Fixed pause/resume control not working in DramaSwipeFlow on Android
- 补充 DramaHomeController 缺失的控制方法（seekTo、setCurrentPage、getCurrentDramaIndex、setCurrentDramaIndex、openMoreDialog、backRefresh）/ Added missing control methods to DramaHomeController (seekTo, setCurrentPage, getCurrentDramaIndex, setCurrentDramaIndex, openMoreDialog, backRefresh)
- 补充 DramaSwipeFlowController 缺失的控制方法（seekTo、setCurrentPage、getCurrentDramaIndex、setCurrentDramaIndex、openMoreDialog）/ Added missing control methods to DramaSwipeFlowController (seekTo, setCurrentPage, getCurrentDramaIndex, setCurrentDramaIndex, openMoreDialog)
- 补充 DramaCardController 缺失的控制方法（pause、resume、refresh、retryLoadData）/ Added missing control methods to DramaCardController (pause, resume, refresh, retryLoadData)
- 完善所有 Widget 的 Listener 事件回调映射 / Improved Listener event callback mapping for all Widgets

## 1.0.1

- 首次发布：集成 PanGrowth 短剧/小视频内容能力 / Initial release: Integrated PanGrowth drama series and short video content capabilities
- 提供初始化、推荐、收藏、历史记录与事件监听 API / Provides initialization, recommendation, favorites, history and event listening APIs
- 支持 Android 与 iOS 平台，并兼容沉浸式原生视图组件 / Supports Android and iOS platforms with immersive native view components
