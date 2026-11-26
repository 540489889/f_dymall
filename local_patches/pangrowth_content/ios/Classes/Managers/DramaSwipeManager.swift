import Foundation
import UIKit
import Flutter
import PangrowthDJX

/// 短剧滑滑流管理器（基于 DJXDrawVideoViewController）
final class DramaSwipeManager: NSObject {

    private struct DramaSwipeSession {
        let controller: DJXDrawVideoViewController
        let delegate: DramaSwipeDelegate
    }

    private var eventSink: FlutterEventSink?
    private var sessions: [String: DramaSwipeSession] = [:]

    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
    }

    func createDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let widgetId = "drama_swipe_" + UUID().uuidString
        let args = (call.arguments as? [String: Any]) ?? [:]

        let delegate = DramaSwipeDelegate(widgetId: widgetId, manager: self)

        let controller = DJXDrawVideoViewController { config in
            self.configure(config: config, with: args, delegate: delegate)
        }
        controller.modalPresentationStyle = .fullScreen
        delegate.attach(controller: controller)

        sessions[widgetId] = DramaSwipeSession(controller: controller, delegate: delegate)

        result([
            "widgetId": widgetId,
            "widgetType": "drama_swipe_flow",
            "success": true,
        ])
    }

    func showDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String,
              let session = sessions[widgetId] else {
            result(FlutterError(code: "WIDGET_NOT_FOUND", message: "Widget not found", details: nil))
            return
        }

        DispatchQueue.main.async {
            guard let presenter = UIApplication.shared.topMostViewController() else {
                result(FlutterError(code: "NO_ROOT_CONTROLLER", message: "无法找到根控制器", details: nil))
                return
            }

            if presenter.presentedViewController === session.controller {
                self.emit(widgetId: widgetId, type: "dramaSwipeFlowShown")
                result(["widgetId": widgetId, "shown": true])
                return
            }

            presenter.present(session.controller, animated: true) {
                self.emit(widgetId: widgetId, type: "dramaSwipeFlowShown")
                result(["widgetId": widgetId, "shown": true])
            }
        }
    }

    func hideDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String,
              let session = sessions[widgetId] else {
            result(FlutterError(code: "WIDGET_NOT_FOUND", message: "Widget not found", details: nil))
            return
        }

        DispatchQueue.main.async {
            session.controller.dismiss(animated: true) {
                self.emit(widgetId: widgetId, type: "dramaSwipeFlowHidden")
                result(true)
            }
        }
    }

    func destroyDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String,
              let session = sessions.removeValue(forKey: widgetId) else {
            result(FlutterError(code: "WIDGET_NOT_FOUND", message: "Widget not found", details: nil))
            return
        }

        DispatchQueue.main.async {
            session.controller.dismiss(animated: false) {
                self.emit(widgetId: widgetId, type: "dramaSwipeFlowDestroyed")
                result(true)
            }
        }
    }

    private func configure(
        config: DJXDrawVideoVCConfig,
        with args: [String: Any],
        delegate: DramaSwipeDelegate
    ) {
        config.delegate = delegate
        let screenBounds = UIScreen.main.bounds
        config.viewSize = screenBounds.size

        // 配置标题栏顶部边距（iOS仅支持top属性）
        if let topMargin = args["titleTopMargin"] as? CGFloat {
            let navBarInset = config.navBarInset ?? DJXDrawVideoNavigationBarInset()
            navBarInset.top = topMargin
            config.navBarInset = navBarInset
        }

        // titleLeftMargin和titleRightMargin仅Android端支持

        if let bottomOffset = args["bottomOffset"] as? CGFloat {
            config.out_bottomOffset = bottomOffset
        }

        if let progress = args["progressBarStyle"] as? Int,
           let style = DJXDrawVideoProgressBarStyle(rawValue: progress) {
            config.progressBarStyle = style
        }

        if let name = args["customCategory"] as? String {
            config.recommandTabName = name
        }

        if let hideChannel = args["hideChannelName"] as? Bool {
            config.shouldHideTabBarView = hideChannel
        }

        if let hideInfo = args["hideDramaInfo"] as? Bool {
            setValueIfAvailable(config, key: "hiddenPlayletInfoView", value: hideInfo)
        }

        if let hideEnter = args["hideDramaEnter"] as? Bool {
            config.hiddenPlayletEnterView = hideEnter
        }

        // 配置下拉刷新功能
        if let enableRefresh = args["enableRefresh"] as? Bool {
            config.customRefresh = enableRefresh
        }

        // 配置按钮显示状态（仅在传入参数时设置）
        if let hide = args["hideLikeButton"] as? Bool {
            config.hideLikeIcon = hide
        }
        if let hide = args["hideFavorButton"] as? Bool {
            config.hideCollectIcon = hide
        }
        if let hide = args["hideDoubleClickLike"] as? Bool {
            config.disableDoubleClickLike = hide
        }
        if let hide = args["hideClose"] as? Bool {
            config.showCloseButton = !hide
        }

        // 配置频道类型（未传参时使用SDK默认值）
        if let channelType = args["channelType"] as? Int {
            switch channelType {
            case 2:
                config.drawVCTabOptions = .theater
            case 3:
                config.drawVCTabOptions = [.playlet_feed, .theater]
            default:
                config.drawVCTabOptions = .playlet_feed
            }
        }

        if let dramaFree = args["dramaFree"] as? Int {
            config.playletFreeCount = dramaFree
        }
        if let topDramaId = args["topDramaId"] as? Int {
            config.topSkitId = topDramaId
        }

        config.playletConfig = buildPlayletConfig(args: args)
    }

    private func buildPlayletConfig(args: [String: Any]) -> DJXPlayletConfig {
        let playletConfig = DJXPlayletConfig()
        playletConfig.playletUnlockADMode = .common
        if let freeCount = args["dramaFree"] as? Int {
            playletConfig.freeEpisodesCount = freeCount
        }
        if let unlockCount = args["unlockEpisodesCount"] as? Int {
            playletConfig.unlockEpisodesCountUsingAD = unlockCount
        }
        if let topDramaId = args["topDramaId"] as? Int {
            playletConfig.skitId = topDramaId
        }
        return playletConfig
    }

    fileprivate func emit(
        widgetId: String,
        type: String,
        params: [String: Any] = [:],
        dismiss: Bool = false
    ) {
        var payload = params
        payload["widgetId"] = widgetId

        if dismiss, let controller = sessions[widgetId]?.controller {
            controller.dismiss(animated: true, completion: nil)
        }

        sendEvent(type: type, widgetId: widgetId, params: payload)
    }

    private func sendEvent(type: String, widgetId: String, params: [String: Any]) {
        guard let sink = eventSink else { return }
        let payload: [String: Any] = [
            "type": type,
            "params": params,
        ]
        DispatchQueue.main.async {
            sink(payload)
        }
    }

    fileprivate func decode(event: DJXEvent?) -> [String: Any] {
        guard let event = event else { return [:] }
        var data: [String: Any] = [:]
        if let groupId = event.value(forKey: "group_id") {
            data["groupId"] = groupId
        }
        if let dramaId = event.value(forKey: "drama_id") {
            data["dramaId"] = dramaId
        }
        if let params = event.value(forKey: "params") as? [String: Any] {
            data.merge(sanitizeDictionary(params)) { _, new in new }
        }
        return data
    }

    fileprivate func sanitizeDictionary(_ dictionary: [String: Any]) -> [String: Any] {
        var safe: [String: Any] = [:]
        dictionary.forEach { key, value in
            if let sanitized = sanitize(value) {
                safe[key] = sanitized
            }
        }
        return safe
    }

    fileprivate func sanitize(_ value: Any?) -> Any? {
        guard let value = value else { return nil }
        if value is NSNull { return nil }

        switch value {
        case let number as NSNumber:
            return number
        case let string as NSString:
            return string as String
        case let dict as [String: Any]:
            return sanitizeDictionary(dict)
        case let array as [Any]:
            return array.compactMap { sanitize($0) }
        case let info as DJXPlayletInfoModel:
            return playletInfoToMap(info)
        default:
            return String(describing: value)
        }
    }

    fileprivate func playletInfoToMap(_ info: DJXPlayletInfoModel) -> [String: Any] {
        return [
            "id": info.shortplay_id,
            "title": info.title ?? "",
            "coverImage": info.cover_image ?? "",
            "desc": info.desc ?? "",
            "groupId": info.group_id,
            "favorite": info.favorite_state,
            "favoriteCount": info.favorite_count,
        ]
    }

    private func setValueIfAvailable(_ object: NSObject, key: String, value: Any) {
        let setterName = "set" + key.prefix(1).uppercased() + key.dropFirst() + ":"
        let setter = NSSelectorFromString(setterName)
        if object.responds(to: setter) || object.responds(to: NSSelectorFromString(key)) {
            object.setValue(value, forKey: key)
        }
    }
}

private final class DramaSwipeDelegate: NSObject, DJXDrawVideoViewControllerDelegate {
    weak var manager: DramaSwipeManager?
    let widgetId: String
    weak var controller: DJXDrawVideoViewController?

    init(widgetId: String, manager: DramaSwipeManager) {
        self.widgetId = widgetId
        self.manager = manager
    }

    func attach(controller: DJXDrawVideoViewController) {
        self.controller = controller
    }

    // MARK: - DJXDrawVideoViewControllerDelegate

    func drawVideoCurrentVideoChanged(_ viewController: UIViewController, event: DJXEvent) {
        var params = manager?.decode(event: event) ?? [:]
        if let position = (event.value(forKey: "params") as? [String: Any])?["position"] {
            params["position"] = position
        }
        manager?.emit(widgetId: widgetId, type: "pageChange", params: params)
    }

    func drawVideoStartPlay(_ viewController: UIViewController, event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "videoPlay", params: params)
    }

    func drawVideoPause(_ viewController: UIViewController, event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "videoPause", params: params)
    }

    func drawVideoContinue(_ viewController: UIViewController, event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "videoContinue", params: params)
    }

    func drawVideoPlayCompletion(_ viewController: UIViewController, event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "videoCompletion", params: params)
    }

    func drawVideoOverPlay(_ viewController: UIViewController, event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "videoOver", params: params)
    }

    func drawVideoCloseButtonClicked(_ viewController: UIViewController) {
        manager?.emit(widgetId: widgetId, type: "close", dismiss: true)
    }

    func drawVideoDataRefreshCompletion(_ error: Error?) {
        var params: [String: Any] = [:]
        if let error = error {
            params["error"] = error.localizedDescription
        } else {
            params["success"] = true
        }
        manager?.emit(widgetId: widgetId, type: "refreshFinish", params: params)
    }

    func pageViewControllerSwitch(to index: Int) {
        manager?.emit(widgetId: widgetId, type: "channelTabChange", params: ["channel": index])
    }

    func djxContentRequestStart(_ event: DJXEvent?) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "requestStart", params: params)
    }

    func djxContentRequestFail(_ event: DJXEvent) {
        let params = manager?.decode(event: event) ?? [:]
        manager?.emit(widgetId: widgetId, type: "requestFail", params: params)
    }

    func djxContentRequestSuccess(_ events: [DJXEvent]) {
        let items = events.map { manager?.decode(event: $0) ?? [:] }
        manager?.emit(widgetId: widgetId, type: "requestSuccess", params: ["items": items])
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.activeKeyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }

    var activeKeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return windows.first { $0.isKeyWindow }
        }
    }
}
