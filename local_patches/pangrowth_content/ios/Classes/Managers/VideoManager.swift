import Flutter
import UIKit
import LCDSDK

// MARK: - Protocol Definitions

/// 小视频管理器
/// 负责处理沉浸式小视频功能
/// 基于LCDSDK官方API实现
class VideoManager: NSObject, LCDGridVideoViewControllerDelegate, LCDVideoCardProviderDelegate, LCDVideoSingleCardProviderDelegate {

    // MARK: - Properties
    private var videoControllers: [String: LCDDrawVideoViewController] = [:]
    // 宫格小视频控制器存储
    private var gridVideoControllers: [String: LCDGridVideoViewController] = [:]
    // 小视频卡片相关存储
    private var videoCardElements: [String: Any] = [:]
    private var videoCardViews: [String: Any] = [:]
    // 小视频单卡片相关存储
    private var videoSingleCardElements: [String: Any] = [:]
    private var videoSingleCardViews: [String: Any] = [:]
    // 添加缺失的存储容器
    private var videoCardProviders: [String: LCDVideoCardProvider] = [:]
    private var videoSingleCardProviders: [String: LCDVideoSingleCardProvider] = [:]
    private var eventSink: FlutterEventSink?

    // MARK: - Public Methods

    /// 设置事件sink
    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
    }

    /// 创建沉浸式小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createVideo called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 创建小视频控制器
            let drawVC = LCDDrawVideoViewController { [weak self] config in
                self?.configureDrawVideoController(config: config, configMap: configMap, videoId: videoId)
            }

            // 存储控制器
            videoControllers[videoId] = drawVC

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true
            ]

            result(resultMap)
            print("VideoManager: Video created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating video: \(error)")
            result(FlutterError(code: "CREATE_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    /// 展示小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func showVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: showVideo called")

        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC",
                              message: "Cannot find root view controller",
                              details: nil))
            return
        }

        // 获取展示样式（iOS专用）
        var presentationStyle: UIModalPresentationStyle = .fullScreen
        if let styleString = arguments["presentationStyle"] as? String {
            switch styleString {
            case "pageSheet":
                presentationStyle = .pageSheet
            case "formSheet":
                presentationStyle = .formSheet
            default:
                presentationStyle = .fullScreen
            }
        }

        drawVC.modalPresentationStyle = presentationStyle

        // 展示视频控制器
        rootViewController.present(drawVC, animated: true) { [weak self] in
            // 通知视图已展示
            drawVC.drawVideoViewControllerDidAppear()

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "shown": true
            ]

            result(resultMap)
            print("VideoManager: Video shown successfully: \(videoId)")
        }
    }

    /// 刷新小视频数据
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func refreshVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.refreshData { error in
            if let error = error {
                result(FlutterError(code: "REFRESH_ERROR",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                result([
                    "videoId": videoId,
                    "refreshed": true
                ])
            }
        }
    }

    /// 用户返回时的挽留刷新
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func refreshVideoToStayUser(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.refreshDataToStayUser { error in
            if let error = error {
                result(FlutterError(code: "REFRESH_ERROR",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                result([
                    "videoId": videoId,
                    "refreshed": true
                ])
            }
        }
    }

    /// 显示挽留提示
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func showToastToStayUser(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.showToastToStayUser()

        result([
            "videoId": videoId,
            "shown": true
        ])
    }

    /// 销毁小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func destroyVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result([
                "videoId": videoId,
                "destroyed": false,
                "message": "Video not found"
            ])
            return
        }

        // 通知视图将要消失
        drawVC.drawVideoViewControllerDidDisappear()

        // 如果正在展示，先关闭
        if drawVC.presentingViewController != nil {
            drawVC.dismiss(animated: false) { [weak self] in
                self?.videoControllers.removeValue(forKey: videoId)
            }
        } else {
            videoControllers.removeValue(forKey: videoId)
        }

        result([
            "videoId": videoId,
            "destroyed": true
        ])

        print("VideoManager: Video destroyed successfully: \(videoId)")
    }

    /// 设置同步数据（一起看视频功能）
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func setSyncData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String,
              let syncData = arguments["data"] as? String,
              let refreshType = arguments["type"] as? Int else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId, data and type cannot be null",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.syncData(toPlay: syncData, refreshType: Int32(refreshType)) { isSuccess, msg in
            result([
                "videoId": videoId,
                "isSuccess": isSuccess,
                "message": msg ?? "",
                "type": refreshType
            ])
        }
    }

    /// 获取当前视频在列表中的位置
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func getCurrentIndex(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        let currentIndex = drawVC.currentIndexVideoList()

        result([
            "videoId": videoId,
            "currentIndex": currentIndex
        ])
    }

    /// 滚动到指定位置
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func scrollToIndex(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String,
              let index = arguments["index"] as? Int else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId and index cannot be null",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        let success = drawVC.scroll(to: index)

        result([
            "videoId": videoId,
            "index": index,
            "success": success
        ])
    }

    /// 暂停当前视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func pauseCurrentVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.pauseCurrentVideo()

        result([
            "videoId": videoId,
            "paused": true
        ])
    }

    /// 播放当前视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func playCurrentVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.playCurrentVideo()

        result([
            "videoId": videoId,
            "playing": true
        ])
    }

    /// 控制播放进度（毫秒）
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func seekVideoToMSeconds(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String,
              let mSeconds = arguments["mSeconds"] as? Double else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId and mSeconds cannot be null",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        drawVC.seekVideo(toMSeconds: Float(mSeconds))

        result([
            "videoId": videoId,
            "mSeconds": mSeconds,
            "success": true
        ])
    }

    /// 创建举报内容页面
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createReportContent(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId cannot be null or empty",
                              details: nil))
            return
        }

        guard let drawVC = videoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Video with ID \(videoId) not found",
                              details: nil))
            return
        }

        if let reportVC = drawVC.createReportContentViewController() {
            // 设置举报完成回调
            reportVC.reportContentCompletionHandler = { [weak self] isSuccess, event in
                self?.sendEvent(eventType: "video_report_result", data: [
                    "videoId": videoId,
                    "isSuccess": isSuccess,
                    "groupId": event.group_id
                ])
            }

            // 展示举报页面
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                let navController = UINavigationController(rootViewController: reportVC)
                navController.modalPresentationStyle = .fullScreen
                rootViewController.present(navController, animated: true)

                result([
                    "videoId": videoId,
                    "reportCreated": true
                ])
            } else {
                result(FlutterError(code: "NO_ROOT_VC",
                                  message: "Cannot find root view controller",
                                  details: nil))
            }
        } else {
            result([
                "videoId": videoId,
                "reportCreated": false,
                "message": "Cannot create report content (may be showing ad)"
            ])
        }
    }

    // MARK: - Private Methods

    /// 配置小视频控制器
    /// - Parameters:
    ///   - config: 配置对象
    ///   - configMap: 配置参数
    ///   - videoId: 视频ID
    private func configureDrawVideoController(config: LCDDrawVideoVCConfig, configMap: [String: Any], videoId: String) {
        // 设置代理
        config.delegate = self
        config.adDelegate = self

        // 配置基本属性
        if let showCloseButton = configMap["showCloseButton"] as? Bool {
            config.showCloseButton = showCloseButton
        }

        if let hiddenGuideGeste = configMap["hiddenGuideGeste"] as? Bool {
            config.hiddenGuideGeste = hiddenGuideGeste
        }

        // 配置视图大小
        if let size = configMap["viewSize"] as? [String: Any],
           let width = size["width"] as? Double,
           let height = size["height"] as? Double {
            config.viewSize = CGSize(width: width, height: height)
        }

        // 配置底部偏移
        if let bottomOffset = configMap["bottomOffset"] as? Double {
            config.out_bottomOffset = CGFloat(bottomOffset)
        }

        // 配置进度条样式
        if let progressBarStyle = configMap["progressBarStyle"] as? Int {
            if progressBarStyle == 1 {
                config.progressBarStyle = .lightContent
            } else if progressBarStyle == 2 {
                config.progressBarStyle = .darkContent
            }
        }

        // 配置频道选项
        if let tabOptions = configMap["drawVCTabOptions"] as? Int {
            switch tabOptions {
            case 1:
                config.drawVCTabOptions = .recommand
            case 2:
                config.drawVCTabOptions = .following
            case 3:
                config.drawVCTabOptions = [.recommand, .following]
            default:
                config.drawVCTabOptions = [.recommand, .following]
            }
        }

        // 配置关注功能
        if let disableFollowing = configMap["shouldDisableFollowingFunc"] as? Bool {
            config.shouldDisableFollowingFunc = disableFollowing
        }

        // 配置频道名称隐藏
        if let hideTabBarView = configMap["shouldHideTabBarView"] as? Bool {
            config.shouldHideTabBarView = hideTabBarView
        }

        // 配置自定义刷新
        if let customRefresh = configMap["customRefresh"] as? Bool {
            config.customRefresh = customRefresh
        }

        // 配置推荐频道名称
        if let recommandTabName = configMap["recommandTabName"] as? String {
            config.recommandTabName = recommandTabName
        }

        // 配置场景标识
        if let scene = configMap["scene"] as? String {
            config.scene = scene
        }

        // 导航栏内边距配置
        if let navBarInset = configMap["navBarInset"] as? [String: Any] {
            let inset = LCDDrawVideoNavigationBarInset()
            if let top = navBarInset["top"] as? Double {
                inset.top = CGFloat(top)
            }
            if let left = navBarInset["left"] as? Double {
                inset.buttonLeft = CGFloat(left)
            }
            if let right = navBarInset["right"] as? Double {
                inset.buttonRight = CGFloat(right)
            }
            config.navBarInset = inset
        }

        // 一起看视频模式配置
        if let watchTogetherRole = configMap["watchTogetherRole"] as? String {
            switch watchTogetherRole {
            case "HOST":
                config.currentMode = .host
            case "USER":
                config.currentMode = .user
            default:
                config.currentMode = .default
            }
        }

        // 主控端看视频的GroupID配置
        if let hostGroupId = configMap["hostGroupId"] as? Int64, hostGroupId != -1 {
            config.watchVideoTogetherGroupID = hostGroupId
        }

        print("VideoManager: Video controller configured for ID: \(videoId)")
    }

    /// 发送事件到Flutter端
    /// - Parameters:
    ///   - eventType: 事件类型
    ///   - data: 事件数据
    private func sendEvent(eventType: String, data: [String: Any]) {
        let eventData: [String: Any] = [
            "eventType": eventType,
            "data": data
        ]

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(eventData)
        }

        print("VideoManager: Event sent - \(eventType): \(data)")
    }
}

// MARK: - LCDDrawVideoViewControllerDelegate
extension VideoManager: LCDDrawVideoViewControllerDelegate {

    /// 关闭按钮被点击
    func drawVideoCloseButtonClicked(_ viewController: UIViewController) {
        if let videoId = findVideoId(for: viewController) {
            sendEvent(eventType: "video_close", data: ["videoId": videoId])
        }
    }

    /// 页面切换
    func drawVideoCurrentVideoChanged(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_page_change", data: eventData)
        }
    }

    /// 数据刷新完成
    func drawVideoDataRefreshCompletion(_ error: Error?) {
        // 找到对应的video controller并发送事件
        // 这里简化处理，实际可能需要更精确的映射
        var eventData: [String: Any] = [:]
        if let error = error {
            eventData["error"] = error.localizedDescription
        } else {
            eventData["success"] = true
        }

        sendEvent(eventType: "video_refresh_complete", data: eventData)
    }

    /// 视频开始播放
    func drawVideoStartPlay(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_play", data: eventData)
        }
    }

    /// 视频播放完成
    func drawVideoPlayCompletion(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_completion", data: eventData)
        }
    }

    /// 视频播放结束
    func drawVideoOverPlay(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_over", data: eventData)
        }
    }

    /// 视频暂停播放
    func drawVideoPause(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_pause", data: eventData)
        }
    }

    /// 视频继续播放
    func drawVideoContinue(_ viewController: UIViewController, event: LCDEvent) {
        if let videoId = findVideoId(for: viewController) {
            var eventData: [String: Any] = [
                "videoId": videoId,
                "groupId": event.group_id
            ]

            eventData.merge(event.params) { (_, new) in new }

            sendEvent(eventType: "video_continue", data: eventData)
        }
    }

    /// 点击作者头像
    func lcdClickAuthorAvatarEvent(_ event: LCDEvent) {
        sendEvent(eventType: "video_click_author_avatar", data: [
            "groupId": event.group_id,
            "params": event.params
        ])
    }

    /// 点击作者昵称
    func lcdClickAuthorNameEvent(_ event: LCDEvent) {
        sendEvent(eventType: "video_click_author_name", data: [
            "groupId": event.group_id,
            "params": event.params
        ])
    }

    /// 点赞按钮点击
    func lcdClickLikeButton(_ isLike: Bool, event: LCDEvent) {
        sendEvent(eventType: "video_click_like", data: [
            "isLike": isLike,
            "groupId": event.group_id,
            "params": event.params
        ])
    }

    /// 点击评论按钮
    func lcdClickCommentButtonEvent(_ event: LCDEvent) {
        sendEvent(eventType: "video_click_comment", data: [
            "groupId": event.group_id,
            "params": event.params
        ])
    }

    /// 请求开始
    func lcdContentRequestStart(_ event: LCDEvent?) {
        sendEvent(eventType: "video_request_start", data: [
            "groupId": event?.group_id ?? 0,
            "params": event?.params ?? [:]
        ])
    }

    /// 请求成功
    func lcdContentRequestSuccess(_ events: [LCDEvent]) {
        let eventsData = events.map { event in
            return [
                "groupId": event.group_id,
                "params": event.params
            ]
        }

        sendEvent(eventType: "video_request_success", data: [
            "events": eventsData
        ])
    }

    /// 请求失败
    func lcdContentRequestFail(_ event: LCDEvent) {
        sendEvent(eventType: "video_request_fail", data: [
            "groupId": event.group_id,
            "params": event.params
        ])
    }

    /// 一起看视频 - 数据源变更回调
    func onDataSourceChange(_ dataSource: String, withAction refreshOrAppendIndex: Int32) {
        sendEvent(eventType: "video_data_source_change", data: [
            "dataSource": dataSource,
            "action": refreshOrAppendIndex
        ])
    }

    /// 一起看视频 - 拖动进度条松手回调
    func onVideSeek(toTime endTime: TimeInterval, inPosition position: Int) {
        sendEvent(eventType: "video_seek_to", data: [
            "endTime": endTime,
            "position": position
        ])
    }

    /// Tab栏切换控制器回调
    func pageViewControllerSwitch(to index: Int) {
        sendEvent(eventType: "video_page_view_controller_switch", data: [
            "index": index
        ])
    }

    /// 根据ViewController查找videoId
    /// - Parameter viewController: 视图控制器
    /// - Returns: 视频ID
    private func findVideoId(for viewController: UIViewController) -> String? {
        for (videoId, drawVC) in videoControllers {
            if drawVC == viewController {
                return videoId
            }
        }
        return nil
    }
}

// MARK: - LCDAdvertCallBackProtocol
extension VideoManager: LCDAdvertCallBackProtocol {

    /// 发起广告请求
    func lcdSendAdRequest(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_request", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 广告加载成功
    func lcdAdLoadSuccess(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_load_success", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 广告加载失败
    func lcdAdLoadFail(_ event: LCDAdTrackEvent, error: Error) {
        sendEvent(eventType: "video_ad_load_fail", data: [
            "adSlotID": event.adSlotID ?? "",
            "error": error.localizedDescription,
            "params": event.params
        ])
    }

    /// 广告填充失败
    func lcdAdFillFail(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_fill_fail", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 广告曝光
    func lcdAdWillShow(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_show", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 视频广告开始播放
    func lcdVideoAdStartPlay(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_play_start", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 视频广告暂停播放
    func lcdVideoAdPause(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_pause", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 视频广告继续播放
    func lcdVideoAdContinue(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_continue", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 视频广告停止播放
    func lcdVideoAdOverPlay(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_play_complete", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    /// 点击广告
    func lcdClickAdViewEvent(_ event: LCDAdTrackEvent) {
        sendEvent(eventType: "video_ad_click", data: [
            "adSlotID": event.adSlotID ?? "",
            "params": event.params
        ])
    }

    // MARK: - Grid Video Methods

    /// 创建宫格小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createGridVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createGridVideo called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 创建宫格小视频控制器
            let gridVC = LCDGridVideoViewController { config in
                self.configureGridVideoController(config: config, configMap: configMap, videoId: videoId)
            }

            gridVideoControllers[videoId] = gridVC

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true,
                "message": "宫格小视频创建成功"
            ]

            result(resultMap)
            print("VideoManager: Grid video created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating grid video: \(error)")
            result(FlutterError(code: "CREATE_FAILED",
                              message: "Failed to create grid video: \(error.localizedDescription)",
                              details: nil))
        }
    }

    /// 展示宫格小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func showGridVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId is required",
                              details: nil))
            return
        }

        guard let gridVC = gridVideoControllers[videoId] else {
            result(FlutterError(code: "VIDEO_NOT_FOUND",
                              message: "Grid video with ID \(videoId) not found",
                              details: nil))
            return
        }

        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                rootViewController.present(gridVC, animated: true) {
                    let resultMap: [String: Any] = [
                        "videoId": videoId,
                        "shown": true
                    ]
                    result(resultMap)
                }
            } else {
                result(FlutterError(code: "PRESENTATION_ERROR",
                                  message: "Failed to get root view controller",
                                  details: nil))
            }
        }
    }

    /// 销毁宫格小视频
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func destroyGridVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId is required",
                              details: nil))
            return
        }

        if let gridVC = gridVideoControllers[videoId] {
            DispatchQueue.main.async {
                gridVC.dismiss(animated: true)
                self.gridVideoControllers.removeValue(forKey: videoId)
                result(true)
            }
        } else {
            result(false)
        }
    }

    // MARK: - Video Card Methods

    /// 创建小视频卡片-信息流场景
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createVideoCardForNews(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createVideoCardForNews called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 获取小视频卡片Provider并配置
            let cardProvider = LCDVideoCardProvider.shared()
            self.configureVideoCardProvider(provider: cardProvider, configMap: configMap, videoId: videoId)

            // 创建ViewElement和View
            let element = cardProvider.buildViewElement()
            let cardView = cardProvider.buildView()

            videoCardElements[videoId] = element
            videoCardViews[videoId] = cardView

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true,
                "title": "",
                "userName": "",
                "commentCount": 0,
                "publishTime": 0
            ]

            result(resultMap)
            print("VideoManager: Video card for news created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating video card for news: \(error)")
            result(FlutterError(code: "CREATE_FAILED",
                              message: "Failed to create video card for news: \(error.localizedDescription)",
                              details: nil))
        }
    }

    /// 创建小视频卡片-推荐流场景
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createVideoCardForRecommend(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createVideoCardForRecommend called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 获取小视频卡片Provider并配置
            let cardProvider = LCDVideoCardProvider.shared()
            self.configureVideoCardProvider(provider: cardProvider, configMap: configMap, videoId: videoId)

            // 创建ViewElement和View
            let element = cardProvider.buildViewElement()
            let cardView = cardProvider.buildView()

            videoCardElements[videoId] = element
            videoCardViews[videoId] = cardView

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true,
                "title": "",
                "userName": "",
                "commentCount": 0,
                "publishTime": 0
            ]

            result(resultMap)
            print("VideoManager: Video card for recommend created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating video card for recommend: \(error)")
            result(FlutterError(code: "CREATE_FAILED",
                              message: "Failed to create video card for recommend: \(error.localizedDescription)",
                              details: nil))
        }
    }

    /// 创建小视频卡片-搜索场景
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createVideoCardForSearch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createVideoCardForSearch called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 获取小视频卡片Provider并配置
            let cardProvider = LCDVideoCardProvider.shared()
            self.configureVideoCardProvider(provider: cardProvider, configMap: configMap, videoId: videoId)

            // 创建ViewElement和View
            let element = cardProvider.buildViewElement()
            let cardView = cardProvider.buildView()

            videoCardElements[videoId] = element
            videoCardViews[videoId] = cardView

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true,
                "title": "",
                "userName": "",
                "commentCount": 0,
                "publishTime": 0
            ]

            result(resultMap)
            print("VideoManager: Video card for search created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating video card for search: \(error)")
            result(FlutterError(code: "CREATE_FAILED",
                              message: "Failed to create video card for search: \(error.localizedDescription)",
                              details: nil))
        }
    }

    /// 销毁小视频卡片
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func destroyVideoCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId is required",
                              details: nil))
            return
        }

        if videoCardProviders.removeValue(forKey: videoId) != nil {
            result(true)
        } else {
            result(false)
        }
    }

    // MARK: - Video Single Card Methods

    /// 创建小视频单卡片-信息流场景
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func createVideoSingleCardForNews(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("VideoManager: createVideoSingleCardForNews called")

        // 检查SDK是否已初始化
        guard LCDManager.sdkVersion != nil else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "LCDSDK is not initialized. Please call initialize() first.",
                              details: nil))
            return
        }

        do {
            // 解析配置参数
            var configMap: [String: Any] = [:]
            if let arguments = call.arguments as? [String: Any],
               let config = arguments["config"] as? [String: Any] {
                configMap = config
            }

            // 生成唯一的videoId
            let videoId = UUID().uuidString

            // 获取小视频单卡片Provider并配置
            let singleCardProvider = LCDVideoSingleCardProvider.shared()
            self.configureVideoSingleCardProvider(provider: singleCardProvider, configMap: configMap, videoId: videoId)

            // 创建ViewElement和View
            let element = singleCardProvider.buildViewElement()
            let singleCardView = singleCardProvider.buildView()

            videoSingleCardElements[videoId] = element
            videoSingleCardViews[videoId] = singleCardView

            let resultMap: [String: Any] = [
                "videoId": videoId,
                "success": true,
                "title": "",
                "userName": "",
                "commentCount": 0,
                "publishTime": 0
            ]

            result(resultMap)
            print("VideoManager: Video single card for news created successfully with ID: \(videoId)")

        } catch {
            print("VideoManager: Error creating video single card for news: \(error)")
            result(FlutterError(code: "CREATE_FAILED",
                              message: "Failed to create video single card for news: \(error.localizedDescription)",
                              details: nil))
        }
    }

    /// 销毁小视频单卡片
    /// - Parameters:
    ///   - call: Flutter方法调用
    ///   - result: Flutter结果回调
    func destroyVideoSingleCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let videoId = arguments["videoId"] as? String else {
            result(FlutterError(code: "INVALID_PARAM",
                              message: "videoId is required",
                              details: nil))
            return
        }

        if videoSingleCardProviders.removeValue(forKey: videoId) != nil {
            result(true)
        } else {
            result(false)
        }
    }

    // MARK: - Configuration Methods

    /// 配置宫格小视频控制器
    private func configureGridVideoController(config: LCDGridVideoVCConfig, configMap: [String: Any], videoId: String) {
        // 基础配置
        config.scene = configMap["scene"] as? String ?? "default"

        // 视图大小配置
        if let width = configMap["width"] as? Double, let height = configMap["height"] as? Double {
            config.viewSize = CGSize(width: width, height: height)
        }

        // 视图类型配置
        if let vcType = configMap["vcType"] as? String {
            switch vcType {
            case "waterfall":
                config.gridVideoVCType = .waterfall
            default:
                config.gridVideoVCType = .grid
            }
        }

        // 回调配置
        config.delegate = self
        config.adDelegate = self
    }

    /// 配置小视频卡片Provider
    private func configureVideoCardProvider(provider: LCDVideoCardProvider, configMap: [String: Any], videoId: String) {
        // 基础配置
        provider.scene = configMap["scene"] as? String ?? "default"

        // 视图大小配置
        if let width = configMap["width"] as? Double {
            provider.viewWidth = CGFloat(width)
        }
        if let height = configMap["height"] as? Double {
            provider.viewHeight = CGFloat(height)
        }

        // 卡片类型配置
        if let cardType = configMap["cardType"] as? String {
            switch cardType {
            case "type2_4":
                provider.cardType = .type2_4
            case "custom":
                provider.cardType = .typeCustom
            default:
                provider.cardType = .typeDefault
            }
        }

        // 显示配置
        if let shouldShowTitle = configMap["shouldShowTitle"] as? Bool {
            provider.shouldShowTitleView = shouldShowTitle
        }

        // 回调配置
        provider.delegate = self
        provider.adDelegate = self
    }

    /// 配置小视频单卡片Provider
    private func configureVideoSingleCardProvider(provider: LCDVideoSingleCardProvider, configMap: [String: Any], videoId: String) {
        // 基础配置
        provider.scene = configMap["scene"] as? String ?? "default"

        // 显示配置
        if let shouldShowTitle = configMap["shouldShowTitle"] as? Bool {
            provider.shouldShowTitle = shouldShowTitle
        }
        if let shouldShowPlayIcon = configMap["shouldShowPlayIcon"] as? Bool {
            provider.shouldShowPlayIcon = shouldShowPlayIcon
        }

        // 回调配置
        provider.delegate = self
        provider.adDelegate = self
    }

    // MARK: - Helper Methods

    /// 帮助方法：发送事件到Flutter
    private func sendEvent(eventType: String, data: [String: Any] = [:], videoId: String? = nil) {
        var eventData = data
        eventData["type"] = eventType
        if let videoId = videoId {
            eventData["videoId"] = videoId
        }

        DispatchQueue.main.async {
            self.eventSink?([
                "eventType": eventType,
                "data": eventData
            ])
        }
    }
}

// MARK: - LCDGridVideoViewControllerDelegate
extension VideoManager {

    func lcdGridDataRefreshCompletion(_ error: Error?) {
        if let error = error {
            sendEvent(eventType: "grid_video_refresh_error", data: [
                "error": error.localizedDescription
            ])
        } else {
            sendEvent(eventType: "grid_video_refresh_complete")
        }
    }

    func lcdClickGridItemEvent(_ event: LCDEvent, controller: UIViewController) {
        sendEvent(eventType: "grid_video_item_click", data: event.params ?? [:])
    }

    func lcdGridItemClientShowEvent(_ event: LCDEvent) {
        sendEvent(eventType: "grid_video_item_show", data: event.params ?? [:])
    }
}

// MARK: - LCDVideoCardProviderDelegate
extension VideoManager {

    func lcdVideoCardClickCellEvent(_ event: LCDEvent, cardView: UIView) {
        sendEvent(eventType: "video_card_click", data: event.params ?? [:])
    }

    func lcdVideoCardSwipeEnter(_ params: [AnyHashable: Any]?, cardView: UIView) {
        sendEvent(eventType: "video_card_swipe_enter", data: params as? [String: Any] ?? [:])
    }
}

// MARK: - LCDVideoSingleCardProviderDelegate
extension VideoManager {

    func lcdSingleCardClickEvent(_ event: LCDEvent, view: UIView) {
        sendEvent(eventType: "video_single_card_click", data: event.params ?? [:])
    }

    func lcdNativeDatasChanged(_ newNativeData: [LCDNativeDataModel]) {
        let dataArray = newNativeData.map { model in
            return [
                "title": model.title ?? ""
            ]
        }
        sendEvent(eventType: "video_single_card_data_changed", data: [
            "newData": dataArray
        ])
    }
}

