import Flutter
import UIKit
import LCDSDK

/// GridVideo PlatformView
/// 将原生LCDGridVideoViewController桥接为Flutter可用的UIView
class GridVideoPlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var gridViewController: LCDGridVideoViewController?
    private var gridId: String
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView(frame: frame)
        _view.backgroundColor = .black

        // 解析参数
        var gridId: String = UUID().uuidString
        var layout: String = "grid"
        var config: [String: Any] = [:]

        if let argsDict = args as? [String: Any] {
            if let id = argsDict["gridId"] as? String {
                gridId = id
            }
            if let layoutValue = argsDict["layout"] as? String {
                layout = layoutValue
            }
            if let configValue = argsDict["config"] as? [String: Any] {
                config = configValue
            }
        }

        self.gridId = gridId

        super.init()

        // 创建MethodChannel
        if let messenger = messenger {
            methodChannel = FlutterMethodChannel(
                name: "pangrowth_content/grid_video_\(gridId)",
                binaryMessenger: messenger
            )
            methodChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleMethodCall(call, result: result)
            }

            // 创建EventChannel
            eventChannel = FlutterEventChannel(
                name: "pangrowth_content/grid_video_events_\(gridId)",
                binaryMessenger: messenger
            )
            eventChannel?.setStreamHandler(self)
        }

        // 创建GridVideoViewController
        createGridViewController(layout: layout, config: config)

        print("[PC][GridNative] PlatformView created gridId=\(gridId)")
    }

    func view() -> UIView {
        return _view
    }

    private func createGridViewController(layout: String, config: [String: Any]) {
        let gridVC = LCDGridVideoViewController { [weak self] vcConfig in
            self?.configureGridVideo(vcConfig: vcConfig, layout: layout, config: config)
        }

        gridViewController = gridVC

        // 将VC的view添加到容器view中
        if let gridView = gridVC.view {
            gridView.frame = _view.bounds
            gridView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            _view.addSubview(gridView)
        }

        print("[PC][GridNative] GridViewController created")
    }

    private func configureGridVideo(vcConfig: LCDGridVideoVCConfig, layout: String, config: [String: Any]) {
        // 设置布局类型
        if layout == "doubleFeed" {
            vcConfig.gridVideoVCType = .waterfall
        } else {
            vcConfig.gridVideoVCType = .grid
        }

        // 设置代理
        vcConfig.delegate = self

        // 解析配置参数
        if let scene = config["scene"] as? String {
            vcConfig.scene = scene
        }

        // cardStyle (normal/staggered) - iOS SDK通过gridVideoVCType设置
        // enableRefresh - iOS SDK通过customRefresh设置
        if let enableRefresh = config["enableRefresh"] as? Bool {
            vcConfig.customRefresh = !enableRefresh
        }

        // reportTopPadding - iOS SDK使用contentInset
        if let topPadding = config["reportTopPadding"] as? Double {
            vcConfig.contentInset = UIEdgeInsets(top: CGFloat(topPadding), left: 0, bottom: 0, right: 0)
        }

        print("[PC][GridNative] GridVideo configured: layout=\(layout)")
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "refresh":
            refresh(result: result)
        case "scrollToTop":
            scrollToTop(result: result)
        case "backRefresh":
            backRefresh(result: result)
        case "setUserVisible":
            setUserVisible(call: call, result: result)
        case "canBackPress":
            canBackPress(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func refresh(result: @escaping FlutterResult) {
        guard let gridVC = gridViewController else {
            result(FlutterError(code: "NOT_READY", message: "GridViewController not ready", details: nil))
            return
        }

        gridVC.refreshData { error in
            if let error = error {
                result(FlutterError(code: "REFRESH_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    private func scrollToTop(result: @escaping FlutterResult) {
        guard let gridVC = gridViewController else {
            result(FlutterError(code: "NOT_READY", message: "GridViewController not ready", details: nil))
            return
        }

        let scrollView = gridVC.dataView()
        scrollView.setContentOffset(.zero, animated: true)
        result(true)
    }

    private func backRefresh(result: @escaping FlutterResult) {
        // iOS SDK没有backRefresh方法，使用普通refresh代替
        refresh(result: result)
    }

    private func setUserVisible(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let visible = args["visible"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "visible parameter is required", details: nil))
            return
        }

        // iOS SDK通过ViewController的生命周期管理，这里不需要额外操作
        // 但为了保持API一致性，返回success
        print("[PC][GridNative] setUserVisible: \(visible)")
        result(true)
    }

    private func canBackPress(result: @escaping FlutterResult) {
        // iOS默认总是可以返回
        result(true)
    }

    deinit {
        print("[PC][GridNative] PlatformView dispose gridId=\(gridId)")

        // 触发完整的ViewController生命周期，释放SDK内部资源
        if let gridVC = gridViewController {
            // 1. 触发视图消失生命周期
            gridVC.viewWillDisappear(false)
            gridVC.viewDidDisappear(false)
            print("[PC][GridNative] 触发viewWillDisappear/viewDidDisappear")

            // 2. 调用dismiss前确保视图已detach
            gridVC.view.removeFromSuperview()

            // 3. dismiss controller (这会触发进一步的清理)
            gridVC.dismiss(animated: false, completion: nil)
        }

        methodChannel?.setMethodCallHandler(nil)
        eventChannel?.setStreamHandler(nil)
        gridViewController = nil
    }
}

// MARK: - FlutterStreamHandler

extension GridVideoPlatformView: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - LCDGridVideoViewControllerDelegate

extension GridVideoPlatformView: LCDGridVideoViewControllerDelegate {
    // 宫格item点击回调
    func lcdClickGridItemEvent(_ event: LCDEvent, controller: UIViewController) {
        sendEvent(name: "onItemClick", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    // 模块曝光回调
    func lcdGridItemClientShow(_ event: LCDEvent) {
        sendEvent(name: "onItemShow", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    // 数据刷新完成回调
    func lcdDataRefreshCompletion(_ error: Error?) {
        if let error = error {
            sendEvent(name: "onRefreshFailed", data: [
                "message": error.localizedDescription
            ])
        } else {
            sendEvent(name: "onRefreshSuccess", data: [:])
        }
    }

    // MARK: - LCDPlayerCallBackProtocol

    func drawVideoStartPlay(_ viewController: UIViewController, event: LCDEvent) {
        sendEvent(name: "onVideoStartPlay", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func drawVideoPlayCompletion(_ viewController: UIViewController, event: LCDEvent) {
        sendEvent(name: "onVideoPlayCompletion", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func drawVideoOverPlay(_ viewController: UIViewController, event: LCDEvent) {
        sendEvent(name: "onVideoOverPlay", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func drawVideoPause(_ viewController: UIViewController, event: LCDEvent) {
        sendEvent(name: "onVideoPause", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func drawVideoContinue(_ viewController: UIViewController, event: LCDEvent) {
        sendEvent(name: "onVideoContinue", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    // MARK: - LCDUserInteractionCallBackProtocol

    func lcdClickAuthorAvatarEvent(_ event: LCDEvent) {
        sendEvent(name: "onClickAuthorAvatar", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func lcdClickAuthorNameEvent(_ event: LCDEvent) {
        sendEvent(name: "onClickAuthorName", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func lcdClickLikeButton(_ isLike: Bool, event: LCDEvent) {
        sendEvent(name: "onClickLike", data: [
            "isLike": isLike,
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    func lcdClickCommentButtonEvent(_ event: LCDEvent) {
        sendEvent(name: "onClickComment", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    // MARK: - LCDRequestCallBackProtocol

    func lcdContentRequestStart(_ event: LCDEvent?) {
        sendEvent(name: "onRequestStart", data: [:])
    }

    func lcdContentRequestSuccess(_ events: [LCDEvent]) {
        let eventsData = events.map { event in
            return [
                "groupId": event.group_id,
                "params": event.params ?? [:]
            ] as [String: Any]
        }
        sendEvent(name: "onRequestSuccess", data: [
            "events": eventsData
        ])
    }

    func lcdContentRequestFail(_ event: LCDEvent) {
        sendEvent(name: "onRequestFail", data: [
            "groupId": event.group_id,
            "params": event.params ?? [:]
        ])
    }

    // MARK: - Helper Methods

    private func sendEvent(name: String, data: [String: Any]) {
        guard let eventSink = eventSink else { return }

        var eventData = data
        eventData["event"] = name
        eventData["gridId"] = gridId

        DispatchQueue.main.async {
            eventSink(eventData)
        }
    }
}
