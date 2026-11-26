import Flutter
import UIKit
import PangrowthDJX

/// 短剧卡片 PlatformView
///
/// 使用 DJXPlayletCard 封装穿山甲内容SDK的短剧卡片组件,
/// 实现真正的内嵌卡片,支持 play/pause/stop 控制。
class DramaCardPlatformView: NSObject, FlutterPlatformView, DJXPlayletCardDelegate {

    // MARK: - Static Cache

    private static var viewCache = NSMapTable<NSString, DramaCardPlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> DramaCardPlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    // MARK: - Properties

    private let contentView: UIView
    private var card: DJXPlayletCard?
    private let cardId: String
    private let messenger: FlutterBinaryMessenger
    private var methodChannel: FlutterMethodChannel?

    // MARK: - Initialization

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self.messenger = messenger

        // 解析参数
        var params: [String: Any] = [:]
        if let arguments = args as? [String: Any] {
            params = arguments
        }

        // 获取或生成 cardId
        self.cardId = params["cardId"] as? String ?? UUID().uuidString

        // 创建容器视图
        self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.contentView.backgroundColor = .clear
        self.contentView.clipsToBounds = true

        super.init()

        // 添加到缓存
        DramaCardPlatformView.viewCache.setObject(self, forKey: cardId as NSString)

        // 设置方法通道
        self.methodChannel = FlutterMethodChannel(
            name: "pangrowth_content/drama_card_view/\(viewId)",
            binaryMessenger: messenger
        )

        // 设置方法调用处理器
        weak var weakSelf = self
        methodChannel?.setMethodCallHandler { call, result in
            weakSelf?.handleMethodCall(call: call, result: result)
        }

        // 初始化卡片
        initializeCard(params: params)
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        return contentView
    }

    // MARK: - Private Methods

    private func initializeCard(params: [String: Any]) {
        // 检查 SDK 是否初始化
        guard DJXPlayletManager.shareInstance() != nil else {
            print("DramaCardPlatformView: DJXPlayletManager not available")
            return
        }

        // 解析配置参数
        let config = params["config"] as? [String: Any] ?? [:]
        guard let dramaId = config["dramaId"] as? Int else {
            print("DramaCardPlatformView: dramaId is required")
            return
        }

        // 创建卡片
        let card = DJXPlayletCard { [weak self] cardConfig in
            guard let self = self else { return }

            // 必填参数
            cardConfig.skit_id = dramaId

            // 可选参数 - 只在明确传递时设置,否则使用SDK默认值

            // @ios width: iOS特有的frame处理 - 根据width自动计算16:9比例的frame
            // Android端只处理width参数,iOS端处理完整frame(x=0, y=0, width, height=width*9/16)
            if let width = config["width"] as? Int {
                let widthCG = CGFloat(width)
                cardConfig.frame = CGRect(x: 0, y: 0, width: widthCG, height: widthCG * 9.0 / 16.0)
            } else {
                // 默认使用容器大小
                cardConfig.frame = self.contentView.bounds
            }

            if let mute = config["isMuteDefault"] as? Bool {
                cardConfig.mute = mute
            }

            if let loop = config["isLooping"] as? Bool {
                cardConfig.loop = loop
            }

            if let autoPlay = config["isAutoPlay"] as? Bool {
                cardConfig.autoPlay = autoPlay
            }

            // @ios hideActionUI: iOS特有参数 - 隐藏操作UI (Android无对应属性)
            if let hideActionUI = config["hideActionUI"] as? Bool {
                cardConfig.hideActionUI = hideActionUI
            }

            // @ios hidePlayButton: iOS特有参数 - 隐藏播放按钮 (Android无对应属性)
            if let hidePlayButton = config["hidePlayButton"] as? Bool {
                cardConfig.hidePlayButton = hidePlayButton
            }

            // @ios hideMuteButton: iOS特有参数 - 隐藏静音按钮 (Android无对应属性)
            if let hideMuteButton = config["hideMuteButton"] as? Bool {
                cardConfig.hideMuteButton = hideMuteButton
            }

            // Android专用参数 - iOS端忽略
            // @android hideSoundButton: 隐藏声音按钮 (iOS无对应属性)
            // @android hideReplayButton: 隐藏重播按钮 (iOS无对应属性)
        }

        card.delegate = self
        self.card = card

        // 添加到容器视图
        card.frame = contentView.bounds
        card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(card)

        print("DramaCardPlatformView: 卡片创建成功 - cardId: \(cardId), dramaId: \(dramaId)")
    }

    // MARK: - Control Methods

    func play() {
        card?.play()
    }

    func pause() {
        card?.pause()
    }

    func stop() {
        card?.stop()
    }

    func setMute(_ mute: Bool) {
        card?.muted = mute
    }

    func refresh() {
        card?.retryLoadData()
    }

    func reportShow(duration: Int) {
        card?.trackShow(withDuration: CGFloat(duration))
    }

    // MARK: - Query Methods

    func isPlaying() -> Bool {
        return card?.playbackState == .playing
    }

    func getDramaInfo() -> [String: Any]? {
        guard let playletInfo = card?.playletInfo else {
            return nil
        }
        // 使用标准的playletInfoToMap函数保持数据结构一致性
        return playletInfoToMap(playletInfo)
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

    func getGid() -> String? {
        guard let playletInfo = card?.playletInfo else {
            return nil
        }
        return String(playletInfo.group_id)
    }

    func getTitle() -> String? {
        guard let playletInfo = card?.playletInfo else {
            return nil
        }
        return playletInfo.title
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            play()
            result(true)

        case "pause":
            pause()
            result(true)

        case "stop":
            stop()
            result(true)

        case "setMute":
            guard let args = call.arguments as? [String: Any],
                  let mute = args["mute"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing mute parameter", details: nil))
                return
            }
            setMute(mute)
            result(true)

        case "refresh":
            refresh()
            result(true)

        case "reportShow":
            guard let args = call.arguments as? [String: Any],
                  let duration = args["duration"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing duration parameter", details: nil))
                return
            }
            reportShow(duration: duration)
            result(true)

        case "isPlaying":
            result(isPlaying())

        case "getDramaInfo":
            result(getDramaInfo())

        case "getGid":
            result(getGid())

        case "getTitle":
            result(getTitle())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Cleanup

    private func dispose() {
        card?.stop()
        card?.removeFromSuperview()
        card = nil
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil

        // 从缓存移除
        DramaCardPlatformView.viewCache.removeObject(forKey: cardId as NSString)

        print("DramaCardPlatformView: Disposed - cardId: \(cardId)")
    }

    // MARK: - DJXPlayletCardDelegate

    func playletCard(_ playletCard: DJXPlayletCard, didLoadData playletData: DJXPlayletInfoModel?, error: Error?) {
        if let error = error {
            print("DramaCardPlatformView: 数据加载失败 - \(error.localizedDescription)")
        } else {
            print("DramaCardPlatformView: 数据加载成功 - cardId: \(cardId)")
        }
    }

    func playletCardReady(toDisplay playletCard: DJXPlayletCard) {
        print("DramaCardPlatformView: 卡片就绪显示 - cardId: \(cardId)")
    }

    func playletCardReady(toPlay playletCard: DJXPlayletCard) {
        print("DramaCardPlatformView: 卡片就绪播放 - cardId: \(cardId)")
    }

    func playletCard(_ playletCard: DJXPlayletCard, playbackStateDidChanged playbackState: DJXPlayletCardPlaybackState) {
        print("DramaCardPlatformView: 播放状态变化 - state: \(playbackState.rawValue), cardId: \(cardId)")
    }

    func playletCardUserStopped(_ playletCard: DJXPlayletCard) {
        print("DramaCardPlatformView: 用户停止播放 - cardId: \(cardId)")
    }

    func playletCardDidFinish(_ playletCard: DJXPlayletCard, error: Error?, videoStatusException statusCode: Int) {
        if let error = error {
            print("DramaCardPlatformView: 播放完成(有错误) - \(error.localizedDescription), cardId: \(cardId)")
        } else {
            print("DramaCardPlatformView: 播放完成 - cardId: \(cardId)")
        }
    }
}
