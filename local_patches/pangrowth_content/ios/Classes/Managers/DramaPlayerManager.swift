import Flutter
import UIKit
import PangrowthDJX

/// 短剧播放页管理器（iOS）
class DramaPlayerManager: NSObject {
    private var eventSink: FlutterEventSink?
    private var playerControllers: [String: DJXDrawVideoViewController] = [:]
    private var playerEpisodes: [String: Int] = [:]
    private var playerDramaIds: [String: Int] = [:]

    /// 解锁回调包装器（参考Android实现）
    private struct UnlockCallbackWrapper {
        let callback: (DJXPlayletUnlockModel) -> Void
        let drama: DJXPlayletInfoModel
        let unlockEpisodes: Int
    }

    private var unlockCallbacks: [String: UnlockCallbackWrapper] = [:]

    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
    }

    // MARK: - 创建与展示

    func createDramaPlayer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dramaId = args["dramaId"] as? Int else {
            result(FlutterError(code: "INVALID_PARAMS", message: "dramaId 必填", details: nil))
            return
        }

        let episode = args["episode"] as? Int ?? 1
        let playerId = "drama_player_\(dramaId)_\(episode)_\(Int(Date().timeIntervalSince1970 * 1000))"

        let config = DJXPlayletConfig()
        config.skitId = dramaId
        config.episode = episode

        if let freeSet = args["freeSet"] as? Int {
            config.freeEpisodesCount = freeSet
        }
        if let unlockSet = args["unlockSet"] as? Int {
            config.unlockEpisodesCountUsingAD = unlockSet
        }
        if let adMode = args["adMode"] as? String, adMode.lowercased() == "specific" {
            config.playletUnlockADMode = .specific
        } else {
            config.playletUnlockADMode = .common
        }
        if let hideBack = args["hideBack"] as? Bool {
            config.hideBackButton = hideBack
        }
        if let hideTop = args["hideTopInfo"] as? Bool {
            config.hideTopInfo = hideTop
        }
        if let hideBottom = args["hideBottomInfo"] as? Bool {
            config.hideBottomInfo = hideBottom
        }
        if let hideMore = args["hideMore"] as? Bool {
            config.hideMoreButton = hideMore
        }
        if let hideCellular = args["hideCellularToast"] as? Bool {
            config.hideCellularToast = hideCellular
        }
        if let closeInfinite = args["closeInfiniteScroll"] as? Bool {
            config.closeInfiniteScroll = closeInfinite
        } else if let infinite = args["infiniteScrollEnabled"] as? Bool {
            config.closeInfiniteScroll = !infinite
        }
        if let startTime = args["playStartTime"] as? Double {
            config.playStartTime = CGFloat(startTime)
        }
        if let fromTopMargin = args["fromTopMargin"] as? Double {
            config.fromTopMargin = CGFloat(fromTopMargin)
        }

        if let source = args["fromSource"] as? String {
            config.entranceType = mapEntrance(source)
        }

        let controller = DJXPlayletManager.shareInstance().playletViewController(withParams: config)
        playerControllers[playerId] = controller
        playerEpisodes[playerId] = episode
        playerDramaIds[playerId] = dramaId

        emitEvent("drama_player_created", data: [
            "playerId": playerId,
            "dramaId": dramaId,
            "episode": episode
        ])

        result([
            "success": true,
            "playerId": playerId,
            "dramaId": dramaId,
            "episode": episode
        ])
    }

    func showDramaPlayer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers[playerId],
              let root = rootViewController() else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在或无法获取根控制器", details: nil))
            return
        }

        let style = (args["presentationStyle"] as? String)?.lowercased()
        switch style {
        case "pagesheet":
            controller.modalPresentationStyle = .pageSheet
        case "formsheet":
            controller.modalPresentationStyle = .formSheet
        default:
            controller.modalPresentationStyle = .fullScreen
        }

        root.present(controller, animated: true) {
            self.emitEvent("drama_player_shown", data: [
                "playerId": playerId
            ])
        }

        result([
            "success": true,
            "playerId": playerId,
            "shown": true
        ])
    }

    // MARK: - 播放控制

    func seekTo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let duration = args["duration"] as? Int,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 与 duration 必填", details: nil))
            return
        }

        // ✅ 调用iOS SDK方法 (单位: 毫秒)
        controller.seekVideo(toMSeconds: Float(duration))

        emitEvent("drama_video_seek", data: [
            "playerId": playerId,
            "duration": duration
        ])

        result([
            "success": true,
            "playerId": playerId,
            "duration": duration
        ])
    }

    func setSpeedPlay(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let rawSpeed = args["speed"] else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 与 speed 必填", details: nil))
            return
        }

        let speed: Double
        if let value = rawSpeed as? Double {
            speed = value
        } else if let number = rawSpeed as? NSNumber {
            speed = number.doubleValue
        } else {
            result(FlutterError(code: "INVALID_PARAMS", message: "speed 参数类型错误", details: nil))
            return
        }

        guard let controller = playerControllers[playerId] else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        let scopeString = (args["scope"] as? String)?.lowercased() ?? "episode"
        let scope: DJXDrawVideoSpeedScope = scopeString == "drama" ? .shortPlay : .episode
        let clampedSpeed = max(0.25, min(speed, 3.0))

        controller.setPlaySpeed(CGFloat(clampedSpeed), scope: scope)
        emitEvent("drama_speed_change", data: [
            "playerId": playerId,
            "speed": clampedSpeed,
            "scope": scopeString
        ])

        result([
            "success": true,
            "playerId": playerId,
            "speed": clampedSpeed,
            "scope": scopeString
        ])
    }

    func setCurrentEpisode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let episode = args["episode"] as? Int,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 与 episode 必填", details: nil))
            return
        }

        controller.setCurrentPlayletEpisode(episode)
        playerEpisodes[playerId] = episode

        emitEvent("drama_episode_change", data: [
            "playerId": playerId,
            "episode": episode
        ])

        result([
            "success": true,
            "playerId": playerId,
            "episode": episode
        ])
    }

    func getCurrentEpisode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 必填", details: nil))
            return
        }

        let episode = playerEpisodes[playerId] ?? 1
        result([
            "success": true,
            "playerId": playerId,
            "currentEpisode": episode
        ])
    }

    func openEpisodePanel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        controller.chooseEpisode()
        DramaEpisodePanelFixer.shared.revealAfterChooseEpisode()
        result([
            "success": true,
            "playerId": playerId
        ])
    }

    func openMoreDialog(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        // ✅ 调用iOS SDK方法 (短剧右上角更多按钮)
        controller.playletMoreButtonClick()

        result(["success": true, "playerId": playerId])
    }

    func refreshPlayer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        // ✅ 调用iOS SDK方法 (刷新挽留用户)
        controller.refreshDataToStayUser(completion: { [weak self] error in
            if let error = error {
                self?.emitEvent("drama_refresh_error", data: [
                    "playerId": playerId,
                    "error": error.localizedDescription
                ])
            }
        })

        // 同时显示Toast提示 "再按一次返回键退出"
        controller.showToastToStayUser()

        result(["success": true, "playerId": playerId])
    }

    func enterPlayPage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers[playerId] else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        controller.enterPlayPage()
        result([
            "success": true,
            "playerId": playerId
        ])
    }

    func destroyDramaPlayer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              let controller = playerControllers.removeValue(forKey: playerId) else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        playerEpisodes.removeValue(forKey: playerId)
        playerDramaIds.removeValue(forKey: playerId)

        DispatchQueue.main.async {
            if controller.presentingViewController != nil {
                controller.dismiss(animated: true)
            }
        }

        emitEvent("drama_player_destroyed", data: [
            "playerId": playerId
        ])

        result([
            "success": true,
            "playerId": playerId,
            "destroyed": true
        ])
    }

    func setCustomAdOnShow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(true)
    }

    func setCustomAdOnReward(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(true)
    }

    func confirmUnlock(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              !playerId.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 不能为空", details: nil))
            return
        }

        guard let platformView = DramaPlayerPlatformView.find(viewId: playerId) else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        if platformView.confirmUnlock() {
            result(["success": true, "playerId": playerId])
        } else {
            result(FlutterError(code: "NO_UNLOCK_CALLBACK", message: "未找到可用的解锁回调", details: nil))
        }
    }

    func cancelUnlock(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              !playerId.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 不能为空", details: nil))
            return
        }

        guard let platformView = DramaPlayerPlatformView.find(viewId: playerId) else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }

        if platformView.cancelUnlock() {
            result(["success": true, "playerId": playerId])
        } else {
            result(FlutterError(code: "NO_UNLOCK_CALLBACK", message: "未找到可用的解锁回调", details: nil))
        }
    }

    /// 解锁短剧（参考Android实现：DramaPlayerManager.kt:568-606）
    ///
    /// 用于通过自定义逻辑控制解锁流程。
    /// 当Flutter层调用此方法时，会触发SDK的解锁回调，完成解锁操作。
    func unlockDrama(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              !playerId.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "playerId 不能为空", details: nil))
            return
        }

        // 从缓存中获取解锁回调包装器
        guard let wrapper = unlockCallbacks.removeValue(forKey: playerId) else {
            debugPrint("⚠️ [DramaPlayerManager] 未找到 playerId=\(playerId) 的解锁回调")
            result(FlutterError(code: "NO_UNLOCK_CALLBACK", message: "未找到可用的解锁回调", details: nil))
            return
        }

        let unlockEpisodeId = args["episodeId"] as? Int
        let unlockCount = args["lockSet"] as? Int
        let cancel = args["cancel"] as? Bool ?? false

        // 构建解锁信息对象
        let unlockInfo = DJXPlayletUnlockModel()
        unlockInfo.playletId = wrapper.drama.shortplay_id
        unlockInfo.unlockEpisodeCount = unlockCount ?? wrapper.unlockEpisodes
        unlockInfo.cancelUnlock = cancel
        unlockInfo.unlockModeType = .default

        // 调用SDK回调
        wrapper.callback(unlockInfo)

        // 更新播放集数
        if !cancel, let episodeId = unlockEpisodeId {
            playerEpisodes[playerId] = episodeId
        }

        debugPrint("✅ [DramaPlayerManager] 解锁成功: playerId=\(playerId), dramaId=\(wrapper.drama.shortplay_id), episode=\(unlockEpisodeId ?? -1), unlockCount=\(unlockCount ?? wrapper.unlockEpisodes), cancel=\(cancel)")
        result(true)
    }

    // MARK: - Helpers

    private func respondSuccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let playerId = args["playerId"] as? String,
              playerControllers[playerId] != nil else {
            result(FlutterError(code: "PLAYER_NOT_FOUND", message: "播放页不存在", details: nil))
            return
        }
        result(["success": true, "playerId": playerId])
    }

    private func emitEvent(_ action: String, data: [String: Any]) {
        var payload = data
        payload["action"] = action
        payload["timestamp"] = Int(Date().timeIntervalSince1970 * 1000)

        eventSink?(payload)
    }

    private func rootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    private func mapEntrance(_ value: String) -> DJXPlayletEntranceType {
        switch value.lowercased() {
        case "drama_home":
            return .home
        case "drama_card":
            return .card
        case "drama_history":
            return .history
        case "skit_mixed":
            return .skitMixed
        default:
            return .default
        }
    }
}
