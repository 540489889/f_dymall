import Flutter
import UIKit
import PangrowthDJX

/// 短剧播放器 PlatformView (iOS 实现)
///
/// 使用 DJXDrawVideoViewController 创建短剧播放器，
/// 实现真正的内嵌短剧播放体验。
///
/// 特性：
/// - 支持自定义广告回调
/// - 完整的播放控制（播放、暂停、跳转等）
/// - 丰富的事件回调（播放事件、解锁事件、广告事件）
/// - 支持多实例（可同时存在多个播放器）
final class DramaPlayerPlatformView: NSObject, FlutterPlatformView, DJXPlayletInterfaceProtocol, DJXPlayletPlayerProtocol, DJXPlayletAdvertProtocol {

    private static let viewCache = NSMapTable<NSString, DramaPlayerPlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> DramaPlayerPlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    private let container: UIView
    private weak var parentController: UIViewController?
    private var viewController: DJXDrawVideoViewController?
    private let contentManager: ContentManager
    private let params: [String: Any]?
    private let viewId: String

    private var customAdOnShow: ((String?) -> Void)?
    private var customAdOnReward: ((DJXRewardAdResult?) -> Void)?
    private var lastCpm: String?
    private var currentDramaInfo: DJXPlayletInfoModel?

    /// 解锁回调包装器
    private struct UnlockCallbackWrapper {
        let handler: (DJXPlayletUnlockModel) -> Void
        let infoModel: DJXPlayletInfoModel
        let unlockCount: Int
    }

    /// 缓存的解锁回调,等待Flutter层调用confirmUnlock或cancelUnlock
    private var unlockCallback: UnlockCallbackWrapper?

    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, contentManager: ContentManager) {
        self.params = args as? [String: Any]
        self.contentManager = contentManager
        self.viewId = (self.params?["playerId"] as? String) ?? UUID().uuidString
        self.container = UIView(frame: frame)
        self.container.clipsToBounds = true
        self.container.backgroundColor = .black
        super.init()

        // 🔍 调试日志: 检查ContentManager实例和EventSink状态
        print("📱 [DramaPlayerPlatformView] init - playerId=\(viewId)")
        print("📱 [DramaPlayerPlatformView] contentManager实例: \(Unmanaged.passUnretained(contentManager).toOpaque())")
        print("📱 [DramaPlayerPlatformView] eventSink状态: \(contentManager.eventSink != nil ? "已设置 ✅" : "未设置 ❌")")

        DramaPlayerPlatformView.viewCache.setObject(self, forKey: viewId as NSString)

        guard contentManager.isDramaModuleReady() else {
            sendError(code: "SDK_NOT_READY", message: "请先调用 start 并确保成功")
            showError(message: "内容 SDK 未启动")
            return
        }

        createPlayer()
    }

    func view() -> UIView {
        return container
    }

    func dispose() {
        teardown()
        DramaPlayerPlatformView.viewCache.removeObject(forKey: viewId as NSString)
    }

    func handleCustomAdOnShow(cpm: String?) -> Bool {
        guard let onShow = customAdOnShow else { return false }
        let value = cpm ?? ""
        lastCpm = value
        onShow(value)
        return true
    }

    func handleCustomAdOnReward(verify: Bool, extra: [String: Any]?) -> Bool {
        guard let rewardHandler = customAdOnReward else { return false }
        let result = DJXRewardAdResult()
        result.success = verify
        result.cpm = lastCpm ?? ""  // 确保CPM值非空
        if let extra = extra {
            result.extraData = extra
        }
        rewardHandler(result)
        if verify {
            customAdOnReward = nil
            customAdOnShow = nil
            lastCpm = nil
        }
        return true
    }

    func handleSetPlaySpeed(args: [String: Any]) -> [String: Any]? {
        guard let controller = viewController else { return nil }
        guard let rawSpeed = args["speed"] else { return nil }

        let speed: Double
        if let value = rawSpeed as? Double {
            speed = value
        } else if let number = rawSpeed as? NSNumber {
            speed = number.doubleValue
        } else {
            return nil
        }

        let scopeString = (args["scope"] as? String)?.lowercased() ?? "episode"
        let scope: DJXDrawVideoSpeedScope = scopeString == "drama" ? .shortPlay : .episode
        let clampedSpeed = max(0.25, min(speed, 3.0))

        controller.setPlaySpeed(CGFloat(clampedSpeed), scope: scope)
        sendEvent(type: "drama_speed_change", data: [
            "playerId": viewId,
            "speed": clampedSpeed,
            "scope": scopeString
        ])

        return [
            "success": true,
            "playerId": viewId,
            "speed": clampedSpeed,
            "scope": scopeString
        ]
    }

    /// 跳转播放进度
    func handleSeekTo(duration: Int) -> Bool {
        guard let controller = viewController else { return false }
        controller.seekVideo(toMSeconds: Float(duration))
        return true
    }

    /// 打开选集面板
    func handleOpenEpisodePanel() -> Bool {
        guard let controller = viewController else { return false }
        controller.chooseEpisode()
        return true
    }

    /// 打开更多弹窗
    func handleOpenMoreDialog() -> Bool {
        guard let controller = viewController else { return false }
        controller.playletMoreButtonClick()
        return true
    }

    /// 刷新挽留用户
    func handleRefreshPlayer() -> Bool {
        guard let controller = viewController else { return false }
        controller.refreshDataToStayUser(completion: { error in
            if let error = error {
                print("⚠️ refreshPlayer error: \(error.localizedDescription)")
            }
        })
        controller.showToastToStayUser()
        return true
    }

    /// 设置当前播放集数
    func handleSetCurrentEpisode(episode: Int) -> Bool {
        guard let controller = viewController else { return false }
        controller.setCurrentPlayletEpisode(episode)
        return true
    }

    private func createPlayer() {
        guard let parent = topViewController() else {
            sendError(code: "NO_ROOT_VC", message: "无法获取宿主控制器")
            showError(message: "宿主异常")
            return
        }

        guard let dramaId = (params?["dramaId"] as? NSNumber)?.intValue, dramaId > 0 else {
            sendError(code: "INVALID_ARGUMENT", message: "dramaId 不能为空")
            showError(message: "参数错误")
            return
        }

        let episode = (params?["episode"] as? NSNumber)?.intValue ?? 1
        let configMap = params?["config"] as? [String: Any]

        let playletConfig = DJXPlayletConfig()
        playletConfig.skitId = dramaId
        playletConfig.episode = episode
        if let groupId = (params?["groupId"] as? NSNumber)?.intValue {
            playletConfig.groupId = groupId
        }
        if let freeSet = (configMap?["freeSet"] as? NSNumber)?.intValue {
            playletConfig.freeEpisodesCount = freeSet
        }
        if let unlockSet = (configMap?["unlockSet"] as? NSNumber)?.intValue {
            playletConfig.unlockEpisodesCountUsingAD = unlockSet
        }
        if let adMode = configMap?["adMode"] as? String, adMode.lowercased() == "specific" {
            playletConfig.playletUnlockADMode = .specific
        } else {
            playletConfig.playletUnlockADMode = .common
        }
        if let hideTopInfo = configMap?["hideTopInfo"] as? Bool {
            playletConfig.hideTopInfo = hideTopInfo
        }
        if let hideBottomInfo = configMap?["hideBottomInfo"] as? Bool {
            playletConfig.hideBottomInfo = hideBottomInfo
        }
        if let hideMore = configMap?["hideMore"] as? Bool {
            playletConfig.hideMoreButton = hideMore
        }
        if let hideReward = configMap?["hideRewardDialog"] as? Bool {
            playletConfig.hideRewardDialog = hideReward
        }
        if let hideBack = configMap?["hideBack"] as? Bool {
            playletConfig.hideBackButton = hideBack
        }
        if let hideCellular = configMap?["hideCellularToast"] as? Bool {
            playletConfig.hideCellularToast = hideCellular
        }
        if let hideLike = configMap?["hideLikeIcon"] as? Bool {
            playletConfig.hideLikeIcon = hideLike
        }
        if let hideFavor = configMap?["hideCollectIcon"] as? Bool {
            playletConfig.hideCollectIcon = hideFavor
        }
        if let startTime = (configMap?["playStartTime"] as? NSNumber)?.doubleValue {
            playletConfig.playStartTime = CGFloat(startTime)
        }

        playletConfig.interfaceDelegate = self
        playletConfig.playerDelegate = self
        playletConfig.adDelegate = self

        let controller = DJXDrawVideoViewController { builder in
            builder.playletConfig = playletConfig
            builder.viewSize = self.container.bounds.size
            builder.customAppear = true
        }

        attach(controller: controller, to: parent)
        viewController = controller

        // ✅ 将事件发送延迟到下一个RunLoop,确保EventSink已经ready
        // 这样可以保证Flutter层的EventChannel.onListen已经被调用
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("📤 [DramaPlayerPlatformView] 异步发送 drama_player_created 事件")

            self.sendEvent(type: "drama_player_created", data: [
                "playerId": self.viewId,
                "dramaId": dramaId,
                "episode": episode
            ])

            self.sendEvent(type: "drama_player_shown", data: [
                "playerId": self.viewId,
                "dramaId": dramaId,
                "episode": episode
            ])
        }
    }

    private func attach(controller: DJXDrawVideoViewController, to parent: UIViewController) {
        parent.addChild(controller)
        controller.view.frame = container.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(controller.view)
        controller.didMove(toParent: parent)
        parentController = parent
    }

    private func teardown() {
        if let controller = viewController {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            viewController = nil
        }
        customAdOnReward = nil
        customAdOnShow = nil
        sendEvent(type: "drama_player_destroyed", data: ["playerId": viewId])
    }

    private func showError(message: String) {
        let label = UILabel(frame: container.bounds)
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(label)
    }

    private func sendEvent(type: String, data: [String: Any]? = nil) {
        var payload = data ?? [:]
        payload["playerId"] = viewId

        // 🔍 调试日志: 记录事件发送
        print("📤 [DramaPlayerPlatformView] sendEvent - type=\(type), playerId=\(viewId)")
        print("📤 [DramaPlayerPlatformView] eventSink状态: \(contentManager.eventSink != nil ? "✅" : "❌")")

        contentManager.sendEvent(eventType: type, data: payload, contentId: viewId)
    }

    private func sendError(code: String, message: String) {
        contentManager.sendEvent(
            eventType: "sdk_error",
            data: [
                "code": code,
                "message": message,
                "playerId": viewId,
                "scene": "drama_player"
            ],
            contentId: viewId
        )
    }

    private func emitPlayerLifecycleEvent(stage: String, infoModel: DJXPlayletInfoModel?) {
        sendEvent(type: "drama_video_event", data: [
            "playerId": viewId,
            "stage": stage,
            "drama": playletInfoToMap(infoModel)
        ])
    }

    private func emitAdLifecycleEvent(stage: String, event: DJXAdTrackEvent?, extra: [String: Any] = [:]) {
        var data: [String: Any] = [
            "stage": stage,
            "playerId": viewId
        ]
        if let dramaInfo = currentDramaInfo {
            data["drama"] = playletInfoToMap(dramaInfo)
        }
        extra.forEach { data[$0.key] = $0.value }
        sendEvent(type: "drama_ad_event", data: data)
    }

    private func playletInfoToMap(_ info: DJXPlayletInfoModel?) -> [String: Any] {
        guard let info = info else { return [:] }

        // 🔍 调试日志: 打印DJXPlayletInfoModel的原始字段
        print("📋 [iOS Debug] playletInfoToMap 被调用")
        print("📋 [iOS Debug] info.shortplay_id: \(info.shortplay_id)")
        print("📋 [iOS Debug] info.title: \(info.title ?? "nil")")
        print("📋 [iOS Debug] info.total: \(info.total)")
        print("📋 [iOS Debug] info.current_episode: \(info.current_episode)")

        let favoriteState = info.favorite_state
        // SDK中script_name和script_author属性不可访问,使用空值替代
        let typeValue = ""
        let scriptNameValue = ""
        let scriptAuthorValue = ""
        return [
            "id": info.shortplay_id,
            "title": info.title ?? "",
            "coverImage": info.cover_image ?? "",
            "desc": info.desc ?? "",
            "total": info.total,
            "index": info.current_episode,
            "type": typeValue,
            "typeId": 0,
            "status": info.status,
            "freeSet": 0,
            "lockSet": 0,
            "createTime": 0,
            "actionTime": info.favorite_time,
            "scriptName": scriptNameValue,
            "scriptAuthor": scriptAuthorValue,
            "isFavor": favoriteState == 1,
            "favoriteCount": info.favorite_count,
            "favoriteTime": info.favorite_time,
            "levelLabel": info.level_label,
            "isPotential": info.is_potential,
            "icpNumber": info.icp_number ?? "",
            "groupId": info.group_id,
            "episodeStatusList": []
        ]
    }

    private func topViewController(base: UIViewController? = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return tab.selectedViewController.flatMap { topViewController(base: $0) }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    // MARK: - DJXPlayletInterfaceProtocol

    func playletDetailUnlockFlowStart(_ infoModel: DJXPlayletInfoModel!, unlockInfoHandler: ((DJXPlayletUnlockModel) -> Void)!, extraInfo: [AnyHashable : Any]!) {
        print("🔔 [DramaPlayerPlatformView] playletDetailUnlockFlowStart 被调用 - playerId=\(viewId)")

        currentDramaInfo = infoModel
        let unlockCount = (params?["config"] as? [String: Any])?["unlockSet"] as? Int ?? 0
        let extras = extraInfo as? [String: Any] ?? [:]

        // 🔍 调试日志: 打印SDK传递的原始数据
        print("📋 [iOS Debug] ===== playletDetailUnlockFlowStart 数据追踪 =====")
        print("📋 [iOS Debug] infoModel.shortplay_id: \(infoModel?.shortplay_id ?? 0)")
        print("📋 [iOS Debug] infoModel.title: \(infoModel?.title ?? "nil")")
        print("📋 [iOS Debug] infoModel.total: \(infoModel?.total ?? 0)")
        print("📋 [iOS Debug] infoModel.current_episode: \(infoModel?.current_episode ?? 0)")
        print("📋 [iOS Debug] extraInfo完整内容: \(extras)")

        // ✅ iOS SDK的数据在infoModel对象中，不在extraInfo中
        // playletInfoToMap方法已经正确提取了 info.total 和 info.current_episode
        let dramaData = playletInfoToMap(infoModel)
        print("📋 [iOS Debug] playletInfoToMap返回 - index: \(dramaData["index"] ?? "nil"), total: \(dramaData["total"] ?? "nil")")
        print("📋 [iOS Debug] 完整dramaData: \(dramaData)")
        print("📋 [iOS Debug] =============================================")

        print("📋 [iOS Debug] 步骤1: 准备缓存 unlockCallback")
        // 缓存回调,等待Flutter层调用confirmUnlock或cancelUnlock
        // 不再立即调用unlockInfoHandler,避免在用户确认前就播放广告
        unlockCallback = UnlockCallbackWrapper(
            handler: unlockInfoHandler,
            infoModel: infoModel,
            unlockCount: unlockCount
        )
        print("📋 [iOS Debug] 步骤2: unlockCallback 已缓存")

        print("📋 [iOS Debug] 步骤3: 准备构建 extra 参数")
        // 构建包含完整信息的 extra 参数
        let extraData: [String: Any] = [
            "index": infoModel.current_episode,
            "total": infoModel.total,
            "unlockCount": unlockCount
        ]
        print("📋 [iOS Debug] 步骤4: extra 参数已构建 - \(extraData)")

        print("📋 [iOS Debug] 步骤5: 准备调用 sendEvent")
        sendEvent(type: "drama_unlock_start", data: [
            "playerId": viewId,
            "drama": dramaData,
            "extra": extraData  // 使用包含完整信息的 extraData
        ])
        print("📋 [iOS Debug] 步骤6: sendEvent 调用完成")

        // 🔍 调试日志: 验证事件是否发送
        print("📋 [iOS Debug] sendEvent('drama_unlock_start') 已调用")
        print("📋 [iOS Debug] eventSink状态: \(contentManager.eventSink != nil ? "✅ 已设置" : "❌ 未设置")")
        print("📋 [iOS Debug] ===== playletDetailUnlockFlowStart 执行完毕 =====")
    }

    func playletDetailUnlockFlowEnd(_ infoModel: DJXPlayletInfoModel!, success: Bool, error: Error?, extraInfo: [AnyHashable : Any]!) {
        let extras = extraInfo as? [String: Any] ?? [:]
        sendEvent(type: "drama_unlock_end", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(infoModel),
            "success": success,
            "errorCode": (error as NSError?)?.code ?? 0,
            "errorMessage": error?.localizedDescription ?? "",
            "extra": extras
        ])
    }

    func playletDetailUnlockFlowShowCustomAD(_ infoModel: DJXPlayletInfoModel!, onADWillShow: ((String) -> Void)!, onADRewardDidVerified: ((DJXRewardAdResult) -> Void)!) {
        customAdOnShow = { value in
            onADWillShow?(value ?? "")
        }
        customAdOnReward = { result in
            if let result = result {
                onADRewardDidVerified?(result)
            }
        }
        sendEvent(type: "drama_show_custom_ad", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(infoModel)
        ])
    }

    func playletDetailUnlockFlowStart(_ infoModel: DJXPlayletInfoModel!, unlockInfoHandler: ((DJXPlayletUnlockModel) -> Void)!) {
        playletDetailUnlockFlowStart(infoModel, unlockInfoHandler: unlockInfoHandler, extraInfo: [:])
    }

    func playletDetailUnlockFlowEnd(_ infoModel: DJXPlayletInfoModel!, success: Bool, error: Error!) {
        playletDetailUnlockFlowEnd(infoModel, success: success, error: error, extraInfo: [:])
    }

    func clickEnterView(_ infoModel: DJXPlayletInfoModel!) {
        currentDramaInfo = infoModel
        sendEvent(type: "drama_click_enter", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(infoModel)
        ])
    }

    func nextPlayletWillPlay(_ infoModel: DJXPlayletInfoModel!) {
        currentDramaInfo = infoModel
        sendEvent(type: "drama_next_playlet", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(infoModel)
        ])
    }

    // MARK: - DJXPlayletPlayerProtocol

    func drawVideoStartPlay(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        print("🔔 [DramaPlayerPlatformView] drawVideoStartPlay 被调用 - playerId=\(viewId)")

        currentDramaInfo = config
        sendEvent(type: "drama_video_start_play", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    func drawVideoOverPlay(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        print("🔔 [DramaPlayerPlatformView] drawVideoOverPlay 被调用 - playerId=\(viewId)")

        currentDramaInfo = config
        sendEvent(type: "drama_video_over_play", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    func drawVideoPause(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        print("🔔 [DramaPlayerPlatformView] drawVideoPause 被调用 - playerId=\(viewId)")

        currentDramaInfo = config
        sendEvent(type: "drama_video_pause", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    func drawVideoContinue(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        print("🔔 [DramaPlayerPlatformView] drawVideoContinue 被调用 - playerId=\(viewId)")

        currentDramaInfo = config
        sendEvent(type: "drama_video_continue", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    func drawVideoPlayCompletion(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        currentDramaInfo = config
        sendEvent(type: "drama_video_completion", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    func onVideSeek(toTime endTime: TimeInterval, inPosition position: Int) {
        sendEvent(type: "drama_video_seek", data: [
            "playerId": viewId,
            "position": position,
            "seekTime": endTime
        ])
    }

    func drawVideo(_ viewController: UIViewController!, config: DJXPlayletInfoModel!, progress: CGFloat) {
        // 播放进度回调 - 可选实现
        sendEvent(type: "drama_video_progress", data: [
            "playerId": viewId,
            "progress": progress,
            "drama": playletInfoToMap(config)
        ])
    }

    func drawVideoError(_ viewController: UIViewController!, config: DJXPlayletInfoModel!) {
        // 播放器错误回调
        sendError(code: "PLAYER_ERROR", message: "播放器内部错误")
        sendEvent(type: "drama_video_error", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(config)
        ])
    }

    // MARK: - DJXPlayletAdvertProtocol

    func djxSendAdRequest(_ event: DJXAdTrackEvent!) {
        print("🔔 [DramaPlayerPlatformView] djxSendAdRequest 被调用 - playerId=\(viewId)")

        sendEvent(type: "drama_ad_request", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxAdLoadSuccess(_ event: DJXAdTrackEvent!) {
        print("🔔 [DramaPlayerPlatformView] djxAdLoadSuccess 被调用 - playerId=\(viewId)")

        sendEvent(type: "drama_ad_load_success", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxAdLoadFail(_ event: DJXAdTrackEvent!, error: Error!) {
        print("🔔 [DramaPlayerPlatformView] djxAdLoadFail 被调用 - playerId=\(viewId)")

        sendEvent(type: "drama_ad_load_fail", data: [
            "playerId": viewId,
            "code": (error as NSError?)?.code ?? 0,
            "message": error?.localizedDescription ?? "",
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxAdFillFail(_ event: DJXAdTrackEvent!) {
        sendEvent(type: "drama_ad_fill_fail", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxAdWillShow(_ event: DJXAdTrackEvent!) {
        emitAdLifecycleEvent(stage: "will_show", event: event)
        sendEvent(type: "drama_ad_show", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxVideoAdStartPlay(_ event: DJXAdTrackEvent!) {
        sendEvent(type: "drama_ad_play_start", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxVideoAdPause(_ event: DJXAdTrackEvent!) {
        emitAdLifecycleEvent(stage: "pause", event: event)
    }

    func djxVideoAdContinue(_ event: DJXAdTrackEvent!) {
        emitAdLifecycleEvent(stage: "continue", event: event)
    }

    func djxVideoAdOverPlay(_ event: DJXAdTrackEvent!) {
        sendEvent(type: "drama_ad_play_finish", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxClickAdViewEvent(_ event: DJXAdTrackEvent!) {
        emitAdLifecycleEvent(stage: "click", event: event)
        sendEvent(type: "drama_ad_click", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxVideoBufferEvent(_ event: DJXAdTrackEvent!) {
        emitAdLifecycleEvent(stage: "buffer", event: event)
    }

    func djxVideoRewardFinishEvent(_ event: DJXAdTrackEvent!) {
        sendEvent(type: "drama_ad_reward_finish", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    func djxVideoRewardSkipEvent(_ event: DJXAdTrackEvent!) {
        sendEvent(type: "drama_ad_reward_skip", data: [
            "playerId": viewId,
            "drama": playletInfoToMap(currentDramaInfo)
        ])
    }

    // MARK: - Unlock Confirmation

    /// 确认解锁 - 当用户在Flutter层点击"解锁短剧"按钮时调用
    func confirmUnlock() -> Bool {
        guard let wrapper = unlockCallback else {
            return false
        }

        let unlockInfo = DJXPlayletUnlockModel()
        unlockInfo.playletId = wrapper.infoModel.shortplay_id
        unlockInfo.unlockEpisodeCount = wrapper.unlockCount
        unlockInfo.cancelUnlock = false  // 不取消,执行解锁
        unlockInfo.unlockModeType = .default

        wrapper.handler(unlockInfo)
        unlockCallback = nil  // 清空缓存

        return true
    }

    /// 取消解锁 - 当用户在Flutter层点击"残忍离开"按钮时调用
    func cancelUnlock() -> Bool {
        guard let wrapper = unlockCallback else {
            return false
        }

        let unlockInfo = DJXPlayletUnlockModel()
        unlockInfo.playletId = wrapper.infoModel.shortplay_id
        unlockInfo.unlockEpisodeCount = wrapper.unlockCount
        unlockInfo.cancelUnlock = true  // 取消解锁
        unlockInfo.unlockModeType = .default

        wrapper.handler(unlockInfo)
        unlockCallback = nil  // 清空缓存

        return true
    }

    /// 解锁短剧 - 支持自定义解锁逻辑（参考Android实现：DramaPlayerManager.kt:568-606）
    ///
    /// 与confirmUnlock的区别：
    /// - confirmUnlock: 固定使用广告解锁，不可取消
    /// - unlockDrama: 支持指定解锁集数、是否取消等参数
    ///
    /// - Parameters:
    ///   - episodeId: 集数ID（可选，用于更新状态）
    ///   - unlockCount: 解锁集数（可选，不指定则使用默认值）
    ///   - cancel: 是否取消解锁（默认false）
    /// - Returns: 是否成功调用解锁回调
    func unlockDrama(episodeId: Int?, unlockCount: Int?, cancel: Bool) -> Bool {
        guard let wrapper = unlockCallback else {
            print("⚠️ [DramaPlayerPlatformView] unlockDrama: unlockCallback为nil")
            return false
        }

        let unlockInfo = DJXPlayletUnlockModel()
        unlockInfo.playletId = wrapper.infoModel.shortplay_id
        unlockInfo.unlockEpisodeCount = unlockCount ?? wrapper.unlockCount
        unlockInfo.cancelUnlock = cancel
        unlockInfo.unlockModeType = .default

        wrapper.handler(unlockInfo)
        unlockCallback = nil  // 清空缓存

        print("✅ [DramaPlayerPlatformView] unlockDrama成功: playerId=\(viewId), dramaId=\(wrapper.infoModel.shortplay_id), episode=\(episodeId ?? -1), unlockCount=\(unlockCount ?? wrapper.unlockCount), cancel=\(cancel)")
        return true
    }
}
