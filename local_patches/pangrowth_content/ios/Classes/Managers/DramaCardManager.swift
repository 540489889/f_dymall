import Foundation
import UIKit
import Flutter
import PangrowthDJX

class DramaCardManager: NSObject, DJXPlayletCardDelegate {

    private var eventSink: FlutterEventSink?
    private var cards: [String: DJXPlayletCard] = [:]
    private var controllers: [String: UIViewController] = [:]

    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
    }

    func createDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dramaId = args["dramaId"] as? Int else {
            result(FlutterError(code: "INVALID_PARAMS", message: "dramaId 必填", details: nil))
            return
        }

        let cardId = "drama_card_\(dramaId)_\(Int(Date().timeIntervalSince1970 * 1000))"

        let card = DJXPlayletCard { cardConfig in
            // 设置必填参数
            cardConfig.skit_id = dramaId

            // 可选参数 - 只在明确传递时设置,否则使用SDK默认值

            // @ios width: iOS特有的frame处理 - 根据width自动计算16:9比例的frame
            // Android端只处理width参数，iOS端处理完整frame（x=0, y=0, width, height=width*9/16）
            if let width = args["width"] as? Int {
                let widthCG = CGFloat(width)
                cardConfig.frame = CGRect(x: 0, y: 0, width: widthCG, height: widthCG * 9.0 / 16.0)
            }

            if let mute = args["isMuteDefault"] as? Bool {
                cardConfig.mute = mute
            }

            if let loop = args["isLooping"] as? Bool {
                cardConfig.loop = loop
            }

            if let autoPlay = args["isAutoPlay"] as? Bool {
                cardConfig.autoPlay = autoPlay
            }

            // @ios hideActionUI: iOS特有参数 - 隐藏操作UI (Android无对应属性)
            if let hideActionUI = args["hideActionUI"] as? Bool {
                cardConfig.hideActionUI = hideActionUI
            }

            // @ios hidePlayButton: iOS特有参数 - 隐藏播放按钮 (Android无对应属性)
            if let hidePlayButton = args["hidePlayButton"] as? Bool {
                cardConfig.hidePlayButton = hidePlayButton
            }

            // @ios hideMuteButton: iOS特有参数 - 隐藏静音按钮 (Android无对应属性)
            if let hideMuteButton = args["hideMuteButton"] as? Bool {
                cardConfig.hideMuteButton = hideMuteButton
            }

            // Android专用参数 - iOS端忽略
            // @android hideSoundButton: 隐藏声音按钮 (iOS无对应属性)
            // @android hideReplayButton: 隐藏重播按钮 (iOS无对应属性)
        }

        card.delegate = self
        cards[cardId] = card

        emitEvent(
            action: "dramaCard",
            data: [
                "cardId": cardId,
                "eventType": "cardCreated",
                "dramaId": dramaId
            ]
        )

        result([
            "success": true,
            "cardId": cardId
        ])
    }

    func showDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId],
              let root = rootViewController() else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在或无法找到根控制器", details: nil))
            return
        }

        let host = DramaCardHostViewController(card: card)
        controllers[cardId] = host

        host.onDismiss = { [weak self] in
            self?.controllers.removeValue(forKey: cardId)
            self?.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "cardDestroyed"
            ])
        }

        root.present(host, animated: true) {
            self.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "readyToDisplay"
            ])
        }

        result([
            "success": true,
            "cardId": cardId,
            "shown": true
        ])
    }

    func playDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        perform(cardId: call.arguments, result: result) { cardId, card in
            card.play()
            self.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "playbackStateChanged",
                "playbackState": "playing"
            ])
        }
    }

    func pauseDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        perform(cardId: call.arguments, result: result) { cardId, card in
            card.pause()
            self.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "playbackStateChanged",
                "playbackState": "paused"
            ])
        }
    }

    func stopDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        perform(cardId: call.arguments, result: result) { cardId, card in
            card.stop()
            self.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "userStopped"
            ])
        }
    }

    func setDramaCardMute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let mute = args["mute"] as? Bool,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        card.muted = mute
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "playbackStateChanged",
            "playbackState": mute ? "muted" : "unmuted"
        ])

        result([
            "success": true,
            "cardId": cardId
        ])
    }

    func reportDramaCardShow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let duration = args["duration"] as? Int,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        card.trackShow(withDuration: CGFloat(duration))
        result([
            "success": true,
            "cardId": cardId
        ])
    }

    func refreshDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        perform(cardId: call.arguments, result: result) { cardId, card in
            card.retryLoadData()
            self.emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "dataLoaded"
            ])
        }
    }

    func destroyDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards.removeValue(forKey: cardId) else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        card.stop()
        card.removeFromSuperview()
        controllers[cardId]?.dismiss(animated: true, completion: nil)
        controllers.removeValue(forKey: cardId)

        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "cardDestroyed"
        ])

        result([
            "success": true,
            "cardId": cardId,
            "destroyed": true
        ])
    }

    func isDramaCardPlaying(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        // SDK API变更:使用playbackState判断是否在播放
        result(card.playbackState == .playing)
    }

    func getDramaCardInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        // 使用标准的playletInfoToMap函数保持数据结构一致性
        let playletInfo = card.playletInfo
        result(playletInfoToMap(playletInfo))
    }

    // 与ContentManager.swift中的实现保持一致
    private func playletInfoToMap(_ info: DJXPlayletInfoModel) -> [String: Any] {
        let favoriteState = info.favorite_state
        // DJXPlayletInfoModel的script_name和script_author属性不可访问
        // 这些属性可能在SDK中不存在或不可访问,统一返回空字符串避免崩溃
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

    func getDramaCardGid(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        // SDK API变更:playletData改为playletInfo
        // playletInfo是非可选类型
        result(card.playletInfo.group_id)
    }

    func getDramaCardTitle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        // SDK API变更:playletData改为playletInfo
        // playletInfo是非可选类型
        result(card.playletInfo.title)
    }

    func cleanup() {
        cards.values.forEach { $0.stop() }
        cards.removeAll()
        controllers.values.forEach { $0.dismiss(animated: false, completion: nil) }
        controllers.removeAll()
    }

    // MARK: - DJXPlayletCardDelegate

    func playletCard(_ playletCard: DJXPlayletCard, didLoadData playletData: DJXPlayletInfoModel?, error: Error?) {
        guard let cardId = cardId(for: playletCard) else { return }
        if let error = error {
            emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "dataLoadFailed",
                "error": error.localizedDescription
            ])
        } else {
            emitEvent(action: "dramaCard", data: [
                "cardId": cardId,
                "eventType": "dataLoaded"
            ])
        }
    }

    func playletCardReady(toDisplay playletCard: DJXPlayletCard) {
        guard let cardId = cardId(for: playletCard) else { return }
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "readyToDisplay"
        ])
    }

    func playletCardReady(toPlay playletCard: DJXPlayletCard) {
        guard let cardId = cardId(for: playletCard) else { return }
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "readyToPlay"
        ])
    }

    func playletCard(_ playletCard: DJXPlayletCard, playbackStateDidChanged playbackState: DJXPlayletCardPlaybackState) {
        guard let cardId = cardId(for: playletCard) else { return }
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "playbackStateChanged",
            "playbackState": playbackState.rawValue
        ])
    }

    func playletCardUserStopped(_ playletCard: DJXPlayletCard) {
        guard let cardId = cardId(for: playletCard) else { return }
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "userStopped"
        ])
    }

    func playletCardDidFinish(_ playletCard: DJXPlayletCard, error: Error?, videoStatusException statusCode: Int) {
        guard let cardId = cardId(for: playletCard) else { return }
        emitEvent(action: "dramaCard", data: [
            "cardId": cardId,
            "eventType": "playbackFinished",
            "statusCode": statusCode,
            "error": error?.localizedDescription as Any
        ])
    }

    // MARK: - Helpers

    private func perform(cardId arguments: Any?, result: @escaping FlutterResult, action: (String, DJXPlayletCard) -> Void) {
        guard let args = arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let card = cards[cardId] else {
            result(FlutterError(code: "CARD_NOT_FOUND", message: "卡片不存在", details: nil))
            return
        }

        action(cardId, card)
        result([
            "success": true,
            "cardId": cardId
        ])
    }

    private func cardId(for card: DJXPlayletCard) -> String? {
        return cards.first { $0.value == card }?.key
    }

    private func emitEvent(action: String, data: [String: Any]) {
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
}

final class DramaCardHostViewController: UIViewController {
    private let card: DJXPlayletCard
    var onDismiss: (() -> Void)?

    init(card: DJXPlayletCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black

        card.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.width * 9.0 / 16.0)
        card.center = view.center
        view.addSubview(card)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onDismiss?()
    }
}
