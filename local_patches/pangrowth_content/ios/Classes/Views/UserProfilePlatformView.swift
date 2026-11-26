import Flutter
import UIKit
import LCDSDK

/// UserProfile PlatformView
/// 将原生个人主页ViewController桥接为Flutter可用的UIView
class UserProfilePlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var profileViewController: UIViewController?
    private var profileId: String
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
        var profileId: String = UUID().uuidString
        var config: [String: Any] = [:]

        if let argsDict = args as? [String: Any] {
            if let id = argsDict["profileId"] as? String {
                profileId = id
            }
            if let configValue = argsDict["config"] as? [String: Any] {
                config = configValue
            }
        }

        self.profileId = profileId

        super.init()

        // 创建MethodChannel
        if let messenger = messenger {
            methodChannel = FlutterMethodChannel(
                name: "pangrowth_content/user_profile_\(profileId)",
                binaryMessenger: messenger
            )
            methodChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleMethodCall(call, result: result)
            }

            // 创建EventChannel
            eventChannel = FlutterEventChannel(
                name: "pangrowth_content/user_profile_events_\(profileId)",
                binaryMessenger: messenger
            )
            eventChannel?.setStreamHandler(self)
        }

        // 创建UserProfileViewController
        createProfileViewController(config: config)

        print("[PC][ProfileNative] PlatformView created profileId=\(profileId)")
    }

    func view() -> UIView {
        return _view
    }

    private func createProfileViewController(config: [String: Any]) {
        // 根据pageType选择不同的ViewController
        let pageTypeStr = config["pageType"] as? String ?? "USER_HOME_PAGE"

        let viewController: UIViewController

        switch pageTypeStr.uppercased() {
        case "USER_FAVORITE_VIDEO_PAGE":
            // 喜欢的视频页
            viewController = LCDAccessUserLikeListViewController { [weak self] vcConfig in
                self?.configureUserLikeList(vcConfig: vcConfig, config: config)
            }
        case "USER_FOCUS_PAGE":
            // 关注列表页
            viewController = LCDAccessUserFollowListViewController { [weak self] vcConfig in
                self?.configureUserFollowList(vcConfig: vcConfig, config: config)
            }
        default:
            // 个人主页完整版
            viewController = LCDAccessUserCenterViewController { [weak self] vcConfig in
                self?.configureUserCenter(vcConfig: vcConfig, config: config)
            }
        }

        profileViewController = viewController

        // 将VC的view添加到容器view中
        if let profileView = viewController.view {
            profileView.frame = _view.bounds
            profileView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            _view.addSubview(profileView)
        }

        print("[PC][ProfileNative] ProfileViewController created: pageType=\(pageTypeStr)")
    }

    private func configureUserCenter(vcConfig: LCDAccessUserCenterVCConfig, config: [String: Any]) {
        // 设置代理
        vcConfig.delegate = self

        // 设置viewSize
        if let width = config["width"] as? Double,
           let height = config["height"] as? Double {
            vcConfig.viewSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        // 设置scene
        if let scene = config["scene"] as? String {
            vcConfig.sceneForTrack = scene
        }

        // iOS SDK没有hideCloseIcon参数
    }

    private func configureUserLikeList(vcConfig: LCDAccessUserLikeListVConfig, config: [String: Any]) {
        // 设置代理
        vcConfig.delegate = self

        // 设置viewSize
        if let width = config["width"] as? Double,
           let height = config["height"] as? Double {
            vcConfig.viewSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        // 设置scene
        if let scene = config["scene"] as? String {
            vcConfig.sceneForTrack = scene
        }

        // rootViewController需要设置，但在PlatformView中无法获取，使用nil
        // 注意：这可能导致某些功能受限
    }

    private func configureUserFollowList(vcConfig: LCDAccessUserFollowListVCConfig, config: [String: Any]) {
        // 设置代理
        vcConfig.delegate = self

        // 设置viewSize
        if let width = config["width"] as? Double,
           let height = config["height"] as? Double {
            vcConfig.viewSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        // 设置scene
        if let scene = config["scene"] as? String {
            vcConfig.sceneForTrack = scene
        }

        // rootViewController需要设置，但在PlatformView中无法获取
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "refresh":
            refresh(result: result)
        case "backRefresh":
            backRefresh(result: result)
        case "canBackPress":
            canBackPress(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func refresh(result: @escaping FlutterResult) {
        // iOS SDK的个人主页没有refresh方法
        // 返回success保持API一致性
        print("[PC][ProfileNative] refresh called (iOS SDK不支持)")
        result(true)
    }

    private func backRefresh(result: @escaping FlutterResult) {
        // iOS SDK的个人主页没有backRefresh方法
        print("[PC][ProfileNative] backRefresh called (iOS SDK不支持)")
        result(true)
    }

    private func canBackPress(result: @escaping FlutterResult) {
        // iOS默认总是可以返回
        result(true)
    }

    deinit {
        print("[PC][ProfileNative] PlatformView dispose profileId=\(profileId)")
        methodChannel?.setMethodCallHandler(nil)
        eventChannel?.setStreamHandler(nil)
        profileViewController = nil
    }
}

// MARK: - FlutterStreamHandler

extension UserProfilePlatformView: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - LCDRequestCallBackProtocol

extension UserProfilePlatformView: LCDRequestCallBackProtocol {
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
}

// MARK: - LCDPlayerCallBackProtocol

extension UserProfilePlatformView: LCDPlayerCallBackProtocol {
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
}

// MARK: - LCDUserInteractionCallBackProtocol

extension UserProfilePlatformView: LCDUserInteractionCallBackProtocol {
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
}

// MARK: - LCDAccessUserLikeListViewControllerDelegate

extension UserProfilePlatformView: LCDAccessUserLikeListViewControllerDelegate {
    func accessUserLikeListViewControllerScrollViewDidScroll(_ scrollView: UIScrollView) {
        sendEvent(name: "onScrollChanged", data: [
            "offset": scrollView.contentOffset.y
        ])
    }
}

// MARK: - LCDAccessUserFollowListViewControllerDelegate

extension UserProfilePlatformView: LCDAccessUserFollowListViewControllerDelegate {
    func accessUserFollowListViewControllerScrollViewDidScroll(_ scrollView: UIScrollView) {
        sendEvent(name: "onScrollChanged", data: [
            "offset": scrollView.contentOffset.y
        ])
    }
}

// MARK: - Helper Methods

extension UserProfilePlatformView {
    private func sendEvent(name: String, data: [String: Any]) {
        guard let eventSink = eventSink else { return }

        var eventData = data
        eventData["event"] = name
        eventData["profileId"] = profileId

        DispatchQueue.main.async {
            eventSink(eventData)
        }
    }
}
