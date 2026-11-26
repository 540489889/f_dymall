import Flutter
import UIKit
import PangrowthDJX
import PangrowthMiniStory
import LCDSDK

/**
 * 穿山甲内容管理器
 * 负责处理短剧、故事等内容相关功能
 * 基于真实的DJXManager和DJXPlayletManager API实现
 */
private struct ContentManagerError: Error {
    let code: String
    let message: String
}

private struct PrivacyOptions {
    let allowPhoneState: Bool?
    let imei: String?
    let imsi: String?
    let allowAndroidId: Bool?
    let androidId: String?
    let allowMac: Bool?
    let allowOaid: Bool?
    let allowIccid: Bool?
    let allowSerialNumber: Bool?
    let allowGaid: Bool?
    let allowOperatorInfo: Bool?
    let teenagerMode: Bool?
    let onlyIcpNumber: Bool?
}

private struct ContentInitOptions {
    let configPath: String
    let enableDrama: Bool
    let enableStory: Bool
    let enableVideo: Bool
    let debugLog: Bool?
    let disableAbTest: Bool?
    let isNewUser: Bool?
    let newUserAliveSeconds: Int?
    let personalizationEnabled: Bool?
    let userId: String?
    let channel: String?
    let privacy: PrivacyOptions?
    let extra: [String: Any]?
    private let signature: String

    init(
        configPath: String,
        enableDrama: Bool,
        enableStory: Bool,
        enableVideo: Bool,
        debugLog: Bool?,
        disableAbTest: Bool?,
        isNewUser: Bool?,
        newUserAliveSeconds: Int?,
        personalizationEnabled: Bool?,
        userId: String?,
        channel: String?,
        privacy: PrivacyOptions?,
        extra: [String: Any]?
    ) {
        self.configPath = configPath
        self.enableDrama = enableDrama
        self.enableStory = enableStory
        self.enableVideo = enableVideo
        self.debugLog = debugLog
        self.disableAbTest = disableAbTest
        self.isNewUser = isNewUser
        self.newUserAliveSeconds = newUserAliveSeconds
        self.personalizationEnabled = personalizationEnabled
        self.userId = userId
        self.channel = channel
        self.privacy = privacy
        self.extra = extra
        self.signature = ContentInitOptions.buildSignature(
            configPath: configPath,
            enableDrama: enableDrama,
            enableStory: enableStory,
            enableVideo: enableVideo,
            debugLog: debugLog,
            disableAbTest: disableAbTest,
            isNewUser: isNewUser,
            newUserAliveSeconds: newUserAliveSeconds,
            personalizationEnabled: personalizationEnabled,
            userId: userId,
            channel: channel,
            privacy: privacy,
            extra: extra
        )
    }

    func isCompatible(with other: ContentInitOptions) -> Bool {
        return signature == other.signature
    }

    static func from(map: [String: Any]?, configPath: String) -> ContentInitOptions {
        guard let map = map else {
            return ContentInitOptions(
                configPath: configPath,
                enableDrama: true,
                enableStory: false,
                enableVideo: false,
                debugLog: nil,
                disableAbTest: nil,
                isNewUser: nil,
                newUserAliveSeconds: nil,
                personalizationEnabled: nil,
                userId: nil,
                channel: nil,
                privacy: nil,
                extra: nil
            )
        }

        let privacy = (map["privacy"] as? [String: Any]).map { raw -> PrivacyOptions in
            PrivacyOptions(
                allowPhoneState: raw["allowPhoneState"] as? Bool,
                imei: raw["imei"] as? String,
                imsi: raw["imsi"] as? String,
                allowAndroidId: raw["allowAndroidId"] as? Bool,
                androidId: raw["androidId"] as? String,
                allowMac: raw["allowMac"] as? Bool,
                allowOaid: raw["allowOaid"] as? Bool,
                allowIccid: raw["allowIccid"] as? Bool,
                allowSerialNumber: raw["allowSerialNumber"] as? Bool,
                allowGaid: raw["allowGaid"] as? Bool,
                allowOperatorInfo: raw["allowOperatorInfo"] as? Bool,
                teenagerMode: raw["teenagerMode"] as? Bool,
                onlyIcpNumber: raw["onlyIcpNumber"] as? Bool
            )
        }

        let extra = map["extra"] as? [String: Any]

        return ContentInitOptions(
            configPath: configPath,
            enableDrama: map["enableDrama"] as? Bool ?? true,
            enableStory: map["enableStory"] as? Bool ?? false,
            enableVideo: map["enableVideo"] as? Bool ?? true,
            debugLog: map["debugLog"] as? Bool,
            disableAbTest: map["disableAbTest"] as? Bool,
            isNewUser: map["isNewUser"] as? Bool,
            newUserAliveSeconds: coerceInt(map["newUserAliveSeconds"]),
            personalizationEnabled: map["personalizationEnabled"] as? Bool,
            userId: map["userId"] as? String,
            channel: map["channel"] as? String,
            privacy: privacy,
            extra: extra
        )
    }

    private static func coerceInt(_ value: Any?) -> Int? {
        switch value {
        case nil:
            return nil
        case let intValue as Int:
            return intValue
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func buildSignature(
        configPath: String,
        enableDrama: Bool,
        enableStory: Bool,
        enableVideo: Bool,
        debugLog: Bool?,
        disableAbTest: Bool?,
        isNewUser: Bool?,
        newUserAliveSeconds: Int?,
        personalizationEnabled: Bool?,
        userId: String?,
        channel: String?,
        privacy: PrivacyOptions?,
        extra: [String: Any]?
    ) -> String {
        var dict: [String: Any] = [
            "configPath": configPath,
            "enableDrama": enableDrama,
            "enableStory": enableStory,
            "enableVideo": enableVideo,
        ]

        if let debugLog = debugLog { dict["debugLog"] = debugLog }
        if let disableAbTest = disableAbTest { dict["disableAbTest"] = disableAbTest }
        if let isNewUser = isNewUser { dict["isNewUser"] = isNewUser }
        if let newUserAliveSeconds = newUserAliveSeconds { dict["newUserAliveSeconds"] = newUserAliveSeconds }
        if let personalizationEnabled = personalizationEnabled { dict["personalizationEnabled"] = personalizationEnabled }
        if let userId = userId { dict["userId"] = userId }
        if let channel = channel { dict["channel"] = channel }

        if let privacy = privacy {
            var privacyMap: [String: Any] = [:]
            if let value = privacy.allowPhoneState { privacyMap["allowPhoneState"] = value }
            if let value = privacy.imei { privacyMap["imei"] = value }
            if let value = privacy.imsi { privacyMap["imsi"] = value }
            if let value = privacy.allowAndroidId { privacyMap["allowAndroidId"] = value }
            if let value = privacy.androidId { privacyMap["androidId"] = value }
            if let value = privacy.allowMac { privacyMap["allowMac"] = value }
            if let value = privacy.allowOaid { privacyMap["allowOaid"] = value }
            if let value = privacy.allowIccid { privacyMap["allowIccid"] = value }
            if let value = privacy.allowSerialNumber { privacyMap["allowSerialNumber"] = value }
            if let value = privacy.allowGaid { privacyMap["allowGaid"] = value }
            if let value = privacy.allowOperatorInfo { privacyMap["allowOperatorInfo"] = value }
            if let value = privacy.teenagerMode { privacyMap["teenagerMode"] = value }
            if let value = privacy.onlyIcpNumber { privacyMap["onlyIcpNumber"] = value }
            dict["privacy"] = privacyMap
        }

        if let extra = extra {
            dict["extra"] = extra
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let signature = String(data: data, encoding: .utf8) {
            return signature
        }
        return UUID().uuidString
    }
}

class ContentManager: NSObject {
    private let registrar: FlutterPluginRegistrar?
    private var _eventSink: FlutterEventSink?

    var eventSink: FlutterEventSink? {
        return _eventSink
    }

    func isDramaModuleReady() -> Bool {
        return dramaModuleStarted
    }

    func isStoryModuleReady() -> Bool {
        return storyModuleStarted
    }

    func isVideoModuleReady() -> Bool {
        return videoModuleStarted
    }

    private var isInitialized = false
    private var isStarting = false
    private var isStarted = false
    private var initOptions: ContentInitOptions?
    private var tempConfigFile: URL?
    private var resolvedConfigPath: String?
    private var personalizationPreference: Bool?
    private var dramaModuleStarted = false
    private var storyModuleStarted = false
    private var videoModuleStarted = false

    // 存储已创建的聚合页ViewController，以便后续展示
    private var dramaHomeViewControllers = [String: DJXPlayletAggregatePageViewController]()

    // 滑滑流管理器
    private let dramaSwipeManager = DramaSwipeManager()
    // 短剧卡片管理器
    private let dramaCardManager = DramaCardManager()

    init(registrar: FlutterPluginRegistrar?) {
        self.registrar = registrar
        super.init()
    }

    deinit {
        if let tempFile = tempConfigFile {
            try? FileManager.default.removeItem(at: tempFile)
        }
    }

    // MARK: - SDK 初始化相关

    func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let rawConfigPath = args["configPath"] as? String,
              !rawConfigPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "configPath is required", details: nil))
            return
        }

        let configMap = args["config"] as? [String: Any]

        do {
            let resolution = try resolveConfigPath(rawConfigPath)
            let options = ContentInitOptions.from(map: configMap, configPath: resolution.pathForSignature)

            if isInitialized, let previous = initOptions {
                if previous.isCompatible(with: options) {
                    initOptions = options
                    personalizationPreference = options.personalizationEnabled
                    resolvedConfigPath = resolution.argumentForSdk
                    videoModuleStarted = false
                    sendEvent(eventType: "sdk_init_reused", data: [
                        "enableDrama": options.enableDrama,
                        "enableStory": options.enableStory,
                        "enableVideo": options.enableVideo,
                        "configSource": resolution.source
                    ])
                    result(true)
                } else {
                    result(FlutterError(
                        code: "INIT_INCOMPATIBLE",
                        message: "内容SDK已按照其他配置完成初始化，如需切换请重新启动应用",
                        details: nil
                    ))
                }
                return
            }

            try performInitialization(options: options, configArgument: resolution.argumentForSdk)

            if let previousTemp = tempConfigFile, previousTemp != resolution.tempFile {
                try? FileManager.default.removeItem(at: previousTemp)
            }
            tempConfigFile = resolution.tempFile

            initOptions = options
            personalizationPreference = options.personalizationEnabled
            resolvedConfigPath = resolution.argumentForSdk
            isInitialized = true
            videoModuleStarted = false

            sendEvent(eventType: "sdk_init_success", data: [
                "enableDrama": options.enableDrama,
                "enableStory": options.enableStory,
                "enableVideo": options.enableVideo,
                "configSource": resolution.source
            ])
            result(true)
        } catch let managerError as ContentManagerError {
            sendEvent(eventType: "sdk_init_fail", data: [
                "message": managerError.message,
                "code": managerError.code
            ])
            result(FlutterError(code: managerError.code, message: managerError.message, details: nil))
        } catch {
            sendEvent(eventType: "sdk_init_fail", data: [
                "message": error.localizedDescription
            ])
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    /**
     * 启动服务 - 使用真实的DJXManager.start API
     */
    func start(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized, let options = initOptions else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK未初始化，请先调用initialize", details: nil))
            return
        }

        if isStarting {
            result(FlutterError(code: "START_IN_PROGRESS", message: "内容SDK启动中，请稍后重试", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let requestDrama = (args?["startDrama"] as? Bool) ?? options.enableDrama
        let requestStory = (args?["startStory"] as? Bool) ?? options.enableStory
        let requestVideo = (args?["startVideo"] as? Bool) ?? options.enableVideo

        var modules: [String] = []
        if requestDrama && options.enableDrama {
            modules.append("drama")
        }
        if requestStory && options.enableStory {
            modules.append("story")
        }
        if requestVideo && options.enableVideo {
            modules.append("video")
        }

        if modules.isEmpty {
            result(true)
            return
        }

        isStarting = true
        isStarted = false
        dramaModuleStarted = false
        storyModuleStarted = false
        videoModuleStarted = false
        sendEvent(eventType: "sdk_start_start", data: ["modules": modules])

        let group = DispatchGroup()
        var hasError = false
        var firstError: [String: Any]? = nil

        if modules.contains("drama") {
            group.enter()
            DJXManager.start { [weak self] initStatus, userInfo in
                guard let self = self else { return }
                self.dramaModuleStarted = initStatus
                var extra = self.normalizeUserInfo(userInfo)
                extra["module"] = "drama"
                if initStatus {
                    self.sendEvent(eventType: "sdk_start_success", data: extra, contentId: "drama")
                } else {
                    hasError = true
                    if firstError == nil { firstError = extra }
                    self.sendEvent(eventType: "sdk_start_fail", data: extra, contentId: "drama")
                }
                group.leave()
            }
        }

        if modules.contains("story") {
            group.enter()
            MNManager.start { [weak self] initStatus, userInfo in
                guard let self = self else { return }
                self.storyModuleStarted = initStatus
                var extra = self.normalizeUserInfo(userInfo)
                extra["module"] = "story"
                if initStatus {
                    self.sendEvent(eventType: "sdk_start_success", data: extra, contentId: "story")
                } else {
                    hasError = true
                    if firstError == nil { firstError = extra }
                    self.sendEvent(eventType: "sdk_start_fail", data: extra, contentId: "story")
                }
                group.leave()
            }
        }

        if modules.contains("video") {
            group.enter()
            if let configPath = resolvedConfigPath {
                startVideoModule(configPath: configPath, options: options) { [weak self] success, extra in
                    guard let self = self else { return }
                    self.videoModuleStarted = success
                    var payload = extra
                    payload["module"] = "video"
                    if success {
                        self.sendEvent(eventType: "sdk_start_success", data: payload, contentId: "video")
                    } else {
                        hasError = true
                        if firstError == nil { firstError = payload }
                        self.sendEvent(eventType: "sdk_start_fail", data: payload, contentId: "video")
                    }
                    group.leave()
                }
            } else {
                let extra: [String: Any] = [
                    "module": "video",
                    "message": "缺少配置文件路径"
                ]
                hasError = true
                if firstError == nil { firstError = extra }
                sendEvent(eventType: "sdk_start_fail", data: extra, contentId: "video")
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isStarting = false
            if hasError {
                result(FlutterError(code: "START_FAILED", message: "部分模块启动失败", details: firstError))
            } else {
                self.isStarted = self.dramaModuleStarted || self.storyModuleStarted || self.videoModuleStarted
                self.applyPersonalizationPreferenceIfNeeded()
                result(true)
            }
        }
    }

    private func startVideoModule(
        configPath: String,
        options: ContentInitOptions,
        completion: @escaping (Bool, [String: Any]) -> Void
    ) {
        let videoConfig = buildVideoConfig(options: options)
        DispatchQueue.main.async {
            LCDManager.initialize(withConfigPath: configPath, config: videoConfig)
            LCDManager.start(completeHandler: { status, info in
                let success = (status == .success)
                var extra: [String: Any] = [
                    "message": success ? "视频模块启动成功" : "视频模块启动失败",
                    "status": status.rawValue
                ]

                if !info.isEmpty {
                    var normalized: [String: Any] = [:]
                    for (key, value) in info {
                        if let stringKey = key as? String {
                            normalized[stringKey] = value
                        }
                    }
                    if !normalized.isEmpty {
                        extra["userInfo"] = normalized
                    }
                }

                DispatchQueue.main.async {
                    completion(success, extra)
                }
            })
        }
    }

    // MARK: - 短剧相关功能

    private func performInitialization(options: ContentInitOptions, configArgument: String) throws {
        if options.enableDrama {
            let dramaConfig = buildDramaConfig(options: options)
            DJXManager.initialize(withConfigPath: configArgument, config: dramaConfig)
        }

        if options.enableStory {
            let storyConfig = buildStoryConfig(options: options)
            MNManager.initialize(withConfigPath: configArgument, config: storyConfig)
        }
    }

    private func buildDramaConfig(options: ContentInitOptions) -> DJXConfig {
        let config = DJXConfig()
        applyCommonConfig(config: config, options: options)
        return config
    }

    private func buildStoryConfig(options: ContentInitOptions) -> MNConfig {
        let config = MNConfig()
        applyCommonConfig(config: config, options: options)
        return config
    }

    private func buildVideoConfig(options: ContentInitOptions) -> LCDConfig {
        let config = LCDConfig()
        if let debugLog = options.debugLog {
            config.logLevel = debugLog ? .debug : .none
        }
        if let isNewUser = options.isNewUser {
            config.isNewUser = isNewUser
        }
        if let aliveSeconds = options.newUserAliveSeconds {
            config.aliveSeconds = Int32(aliveSeconds)
        }
        return config
    }

    private func applyCommonConfig(config: PGXConfig, options: ContentInitOptions) {
        // 1. 调试日志配置
        if let debugLog = options.debugLog {
            config.logLevel = debugLog ? .debug : .none
        }

        // 2. AB测试配置
        if let disableAbTest = options.disableAbTest {
            config.disableABTest = disableAbTest
        }

        // 3. 新用户配置
        if let isNewUser = options.isNewUser {
            config.isNewUser = isNewUser
        }
        if let aliveSeconds = options.newUserAliveSeconds {
            config.aliveSeconds = Int32(aliveSeconds)
        }

        // 4. 其他配置参数的处理说明
        // 注意：以下参数在iOS端PGXConfig中可能没有直接对应的属性
        // - imageCacheSize: iOS端通过系统缓存管理，无需显式配置

        // 隐私合规配置 - 需要通过privacyDelegate设置
        if let privacy = options.privacy {
            print("[ContentManager] Privacy options configured: \(privacy) (requires privacyDelegate implementation)")
            // 注意：隐私配置需要实现 PGXConfig.privacyDelegate
            // 具体实现取决于业务需求
        }

        // 用户ID - 可能需要通过用户登录接口单独设置
        if let userId = options.userId, !userId.isEmpty {
            print("[ContentManager] UserId configured: \(userId) (may require separate user login API)")
        }

        // 渠道标识 - 可能需要通过渠道配置或统计SDK设置
        if let channel = options.channel, !channel.isEmpty {
            print("[ContentManager] Channel configured: \(channel) (may require channel configuration)")
        }

        // 个性化推荐开关 - iOS端暂无公开API
        if let personalizationEnabled = options.personalizationEnabled {
            print("[ContentManager] Personalization configured: \(personalizationEnabled) (iOS SDK has no public API yet)")
            // 注意：从 applyPersonalizationPreferenceIfNeeded() 的实现可以看出，
            // iOS端暂未提供公开的个性化开关API
        }

        // 额外参数 - 自定义扩展配置
        if let extra = options.extra, !extra.isEmpty {
            print("[ContentManager] Extra parameters configured: \(extra)")
        }
    }

    private func applyPersonalizationPreferenceIfNeeded() {
        guard let preference = personalizationPreference else { return }
        // iOS 端暂未提供公开的个性化开关 API，这里仅透出事件提示。
        sendEvent(eventType: "personal_rec_switch_pending", data: ["enabled": preference])
        personalizationPreference = nil
    }

    private func resolveConfigPath(_ rawPath: String) throws -> ConfigResolution {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ContentManagerError(code: "INVALID_PARAMS", message: "configPath is empty")
        }

        let fileManager = FileManager.default

        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            let url = try writeTempConfig(json: trimmed)
            return ConfigResolution(argumentForSdk: url.path, pathForSignature: url.path, tempFile: url, source: "inline_json")
        }

        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
            let path = url.path
            if fileManager.fileExists(atPath: path) {
                return ConfigResolution(argumentForSdk: path, pathForSignature: path, tempFile: nil, source: "file_uri")
            } else {
                throw ContentManagerError(code: "CONFIG_FILE_NOT_FOUND", message: "配置文件不存在: \(path)")
            }
        }

        if trimmed.hasPrefix("/") {
            if fileManager.fileExists(atPath: trimmed) {
                return ConfigResolution(argumentForSdk: trimmed, pathForSignature: trimmed, tempFile: nil, source: "absolute_path")
            } else {
                throw ContentManagerError(code: "CONFIG_FILE_NOT_FOUND", message: "配置文件不存在: \(trimmed)")
            }
        }

        if let registrar = registrar {
            let assetKey = registrar.lookupKey(forAsset: trimmed)
            if let assetURL = Bundle.main.resourceURL?.appendingPathComponent(assetKey),
               fileManager.fileExists(atPath: assetURL.path) {
                return ConfigResolution(argumentForSdk: assetURL.path, pathForSignature: assetURL.path, tempFile: nil, source: "asset")
            }
        }

        if let path = Bundle.main.path(forResource: trimmed, ofType: nil), fileManager.fileExists(atPath: path) {
            return ConfigResolution(argumentForSdk: path, pathForSignature: path, tempFile: nil, source: "bundle")
        }

        if let path = Bundle.main.path(forResource: trimmed, ofType: "json"), fileManager.fileExists(atPath: path) {
            return ConfigResolution(argumentForSdk: path, pathForSignature: path, tempFile: nil, source: "bundle")
        }

        throw ContentManagerError(code: "CONFIG_FILE_NOT_FOUND", message: "配置文件未找到: \(trimmed)")
    }

    private func writeTempConfig(json: String) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pangrowth")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let fileURL = directory.appendingPathComponent("config_\(UUID().uuidString).json")
        try json.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func normalizeUserInfo(_ info: [AnyHashable: Any]?) -> [String: Any] {
        guard let info = info else { return [:] }
        var result: [String: Any] = [:]
        for (key, value) in info {
            if let keyString = key as? String {
                result[keyString] = value
            }
        }
        return result
    }

    private struct ConfigResolution {
        let argumentForSdk: String
        let pathForSignature: String
        let tempFile: URL?
        let source: String
    }

    /**
     * 获取短剧列表 - 使用真实的DJXPlayletManager API
     */
    func getDramaList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let page = (args?["page"] as? Int) ?? 1
        let count = (args?["count"] as? Int) ?? 20
        let order = (args?["order"] as? Bool) ?? true

        // 使用真实的DJXPlayletManager.requestAllPlayletListPage API（新版本使用success/failure回调）
        let playletManager = DJXPlayletManager.shareInstance()
        playletManager.requestAllPlayletListPage(
            page,
            num: count,
            order: order ? DJXPlayletOrderType(rawValue: 0)! : DJXPlayletOrderType(rawValue: 1)!,
            success: { (playletList, info) in
                DispatchQueue.main.async {
                    let list = playletList.map { playletInfoToMap($0) }
                    result(list)
                }
            },
            failure: { (error) in
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GET_DRAMA_LIST_FAILED",
                        message: "获取短剧列表失败: \(error.localizedDescription)",
                        details: ["error": error.localizedDescription]
                    ))
                }
            }
        )
    }

    /**
     * 创建短剧聚合页 - 使用真实的DJXPlayletAggregatePageViewController
     */
    func createDramaHome(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        do {
            print("Creating drama home view controller...")

            // 创建短剧配置
            let playletConfig = DJXPlayletConfig()

            // 处理可选的免费集数和解锁集数配置
            let args = call.arguments as? [String: Any]

            // 免费观看集数
            if let freeEpisodesCount = args?["freeEpisodesCount"] as? Int {
                print("Setting free episodes count: \(freeEpisodesCount)")
                playletConfig.freeEpisodesCount = freeEpisodesCount
            }

            // 观看广告解锁集数
            if let unlockEpisodesCountUsingAD = args?["unlockEpisodesCountUsingAD"] as? Int {
                print("Setting unlock episodes count using AD: \(unlockEpisodesCountUsingAD)")
                playletConfig.unlockEpisodesCountUsingAD = unlockEpisodesCountUsingAD
            }

            // 设置默认解锁模式
            playletConfig.playletUnlockADMode = .common

            // ========== 详情页UI配置参数 ==========

            // 隐藏顶部信息
            if let hideTopInfo = args?["hideTopInfo"] as? Bool {
                print("Setting hideTopInfo: \(hideTopInfo)")
                playletConfig.hideTopInfo = hideTopInfo
            }

            // 隐藏底部信息
            if let hideBottomInfo = args?["hideBottomInfo"] as? Bool {
                print("Setting hideBottomInfo: \(hideBottomInfo)")
                playletConfig.hideBottomInfo = hideBottomInfo
            }

            // 隐藏返回按钮 (详情页内的返回按钮)
            if let hideBack = args?["hideBack"] as? Bool {
                print("Setting hideBackButton: \(hideBack)")
                playletConfig.hideBackButton = hideBack
            }

            // 隐藏更多按钮
            if let hideMore = args?["hideMore"] as? Bool {
                print("Setting hideMoreButton: \(hideMore)")
                playletConfig.hideMoreButton = hideMore
            }

            // 隐藏点赞按钮
            if let hideLikeIcon = args?["hideLikeIcon"] as? Bool {
                print("Setting hideLikeIcon: \(hideLikeIcon)")
                playletConfig.hideLikeIcon = hideLikeIcon
            }

            // 隐藏收藏按钮 (iOS中对应hideCollectIcon)
            if let hideFavorIcon = args?["hideFavorIcon"] as? Bool {
                print("Setting hideCollectIcon: \(hideFavorIcon)")
                playletConfig.hideCollectIcon = hideFavorIcon
            }

            // 隐藏SDK激励解锁弹窗
            if let hideRewardDialog = args?["hideRewardDialog"] as? Bool {
                print("Setting hideRewardDialog: \(hideRewardDialog)")
                playletConfig.hideRewardDialog = hideRewardDialog
            }

            // 是否允许无限滑动 (iOS中使用相反的参数closeInfiniteScroll)
            if let enableInfiniteScroll = args?["enableInfiniteScroll"] as? Bool {
                print("Setting closeInfiniteScroll: \(!enableInfiniteScroll)")
                playletConfig.closeInfiniteScroll = !enableInfiniteScroll
            }

            // ========== Android专用参数 (iOS忽略) ==========

            if args?["showChangeBtn"] != nil {
                print("⚠️ showChangeBtn is Android-only parameter, ignored on iOS")
            }

            if args?["topOffset"] != nil {
                print("⚠️ topOffset is Android-only parameter, ignored on iOS")
            }

            // 使用真实的DJXPlayletAggregatePageViewController初始化
            let vc = DJXPlayletAggregatePageViewController { config in
                config.playletConfig = playletConfig

                // 处理可选参数 - 只设置Flutter明确传递的参数
                if let isShowNavigationItemBackButton = args?["isShowNavigationItemBackButton"] as? Bool {
                    print("Setting isShowNavigationItemBackButton: \(isShowNavigationItemBackButton)")
                    config.isShowNavigationItemBackButton = isShowNavigationItemBackButton
                } else if let showBackBtn = args?["showBackBtn"] as? Bool {
                    print("Setting showBackBtn (iOS equivalent): \(showBackBtn)")
                    config.isShowNavigationItemBackButton = showBackBtn
                }

                if let isShowNavigationItemTitle = args?["isShowNavigationItemTitle"] as? Bool {
                    print("Setting isShowNavigationItemTitle: \(isShowNavigationItemTitle)")
                    config.isShowNavigationItemTitle = isShowNavigationItemTitle
                } else if let showPageTitle = args?["showPageTitle"] as? Bool {
                    print("Setting showPageTitle (iOS equivalent): \(showPageTitle)")
                    config.isShowNavigationItemTitle = showPageTitle
                }

                // 处理置顶短剧ID
                var topSkitIds: [String] = []

                if let topDramaIds = args?["topDramaIds"] as? [String], !topDramaIds.isEmpty {
                    print("Setting topDramaIds: \(topDramaIds)")
                    topSkitIds = topDramaIds
                } else if let topDramaId = args?["topDramaId"] as? Int, topDramaId > 0 {
                    print("Setting topDramaId: \(topDramaId)")
                    topSkitIds = [String(topDramaId)]
                }

                if !topSkitIds.isEmpty {
                    config.topSkitIds = topSkitIds
                }
            }

            // ✅ 直接使用非可选对象，参照官方Demo实现
            print("Drama home view controller created successfully")

            // 生成一个唯一标识符
            let viewControllerId = UUID().uuidString

            // 存储ViewController以便后续展示
            dramaHomeViewControllers[viewControllerId] = vc

            result([
                "widgetId": viewControllerId,  // 保持与Android端一致的key命名
                "widgetType": "drama_home",
                "success": true
            ])
        } catch {
            print("Create drama home failed: \(error.localizedDescription)")
            result(FlutterError(
                code: "CREATE_DRAMA_HOME_ERROR",
                message: "创建短剧聚合页异常: \(error.localizedDescription)",
                details: [
                    "error": error.localizedDescription
                ]
            ))
        }
    }

    /**
     * 展示短剧聚合页
     * @param call FlutterMethodCall，包含widgetId参数
     * @param result Flutter回调
     */
    func showDramaHome(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String, !widgetId.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "widgetId is required", details: nil))
            return
        }

        guard let vc = dramaHomeViewControllers[widgetId] else {
            result(FlutterError(
                code: "WIDGET_NOT_FOUND",
                message: "未找到指定的聚合页组件，请先调用createDramaHome创建",
                details: ["widgetId": widgetId]
            ))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            do {
                print("Showing drama home view controller: \(widgetId)")

                // 获取当前根视图控制器
                guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
                    result(FlutterError(code: "NO_ROOT_VC", message: "未找到根视图控制器", details: nil))
                    return
                }

                // 找到当前显示的视图控制器
                var presentingVC = rootViewController
                while let presented = presentingVC.presentedViewController {
                    presentingVC = presented
                }

                // 如果当前VC是导航控制器，推送到导航栈
                if let navController = presentingVC as? UINavigationController {
                    navController.pushViewController(vc, animated: true)
                    print("Pushed drama home to navigation controller")
                } else if let navController = presentingVC.navigationController {
                    navController.pushViewController(vc, animated: true)
                    print("Pushed drama home to parent navigation controller")
                } else {
                    // 否则以模态方式展示（包装在导航控制器中）
                    let navController = UINavigationController(rootViewController: vc)
                    navController.modalPresentationStyle = .fullScreen
                    presentingVC.present(navController, animated: true) {
                        print("Presented drama home modally")
                    }
                }

                // 发送展示事件到Flutter
                strongSelf.sendEvent(eventType: "drama_home_show", data: [
                    "widgetId": widgetId,
                    "success": true
                ])

                result([
                    "widgetId": widgetId,
                    "shown": true
                ])

            } catch {
                print("Show drama home failed: \(error.localizedDescription)")
                result(FlutterError(
                    code: "SHOW_DRAMA_HOME_ERROR",
                    message: "展示短剧聚合页异常: \(error.localizedDescription)",
                    details: [
                        "widgetId": widgetId,
                        "error": error.localizedDescription
                    ]
                ))
            }
        }
    }

    /**
     * 搜索短剧 - 使用真实的DJXPlayletManager搜索API
     */
    func searchDrama(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let query = args["query"] as? String, !query.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMS", message: "query is required", details: nil))
            return
        }

        let page = (args["page"] as? Int) ?? 1
        let count = (args["count"] as? Int) ?? 20
        let isFuzzy = (args["isFuzzy"] as? Bool) ?? true

        // 使用真实的DJXPlayletManager搜索API（新版本使用success/failure回调）
        let playletManager = DJXPlayletManager.shareInstance()
        playletManager.requestCategoryPlayletLis(
            withSearchWord: query,
            isFuzzy: isFuzzy,
            page: page,
            num: count,
            success: { (playletList, hasMore) in
                DispatchQueue.main.async {
                    // 分解复杂表达式为简单步骤

                    var list: [[String: Any]] = []
                    for playlet in playletList {
                        let playletDict: [String: Any] = [
                            "id": playlet.shortplay_id,
                            "title": playlet.title ?? "",
                            "coverImage": playlet.cover_image ?? "",
                            "desc": playlet.desc ?? "",
                            "total": playlet.total,
                            "index": playlet.current_episode,
                            "type": ""
                        ]
                        list.append(playletDict)
                    }
                    result(list)
                }
            },
            failure: { (error) in
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "SEARCH_DRAMA_FAILED",
                        message: "搜索短剧失败: \(error.localizedDescription)",
                        details: ["error": error.localizedDescription]
                    ))
                }
            }
        )
    }

    // MARK: - 其他功能

    /**
     * 设置个性化推荐 - 使用真实的DJXManager API
     */
    func setPersonalization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let enabled = (args?["enabled"] as? Bool) ?? true

        // 使用真实的DJXManager.setPersonalizationRecommendation API
        DJXManager.setPersonalizationRecommendation(enabled)
        LCDManager.setPersonalizationRecommendation(enabled)
        result(nil)
    }

    /**
     * 获取个性化推荐设置 - 使用真实的DJXManager API
     */
    func getPersonalization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // 使用真实的DJXManager.personalizationRecommendation API
        let dramaEnabled = DJXManager.personalizationRecommendation()
        let videoEnabled = LCDManager.personalizationRecommendation()
        result(dramaEnabled || videoEnabled)
    }

    /**
     * 获取短剧分类列表 - 使用真实的DJXPlayletManager API
     */
    func getCategoryList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        // 使用真实的DJXPlayletManager.shareInstance().requestCategoryList API
        DJXPlayletManager.shareInstance().requestCategoryList { (success, categoryList) in
            DispatchQueue.main.async {
                if success {
                    result(categoryList)
                } else {
                    result(FlutterError(
                        code: "GET_CATEGORY_LIST_FAILED",
                        message: "获取分类列表失败",
                        details: nil
                    ))
                }
            }
        }
    }

    /**
     * 获取短剧历史记录 - 使用真实的DJXPlayletManager API
     */
    func getDramaHistory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let page = (args?["page"] as? Int) ?? 1
        let count = (args?["count"] as? Int) ?? 20

        // 使用真实的DJXPlayletManager.shareInstance().requestPlayletHistoryList API
        let playletManager = DJXPlayletManager.shareInstance()
        playletManager.requestPlayletHistoryList(
            withPage: page,
            num: count,
            success: { (playletList) in
                DispatchQueue.main.async {
                    let list = playletList.map { info -> [String: Any] in
                        var item = playletInfoToMap(info)
                        item["actionTime"] = info.favorite_time
                        item["index"] = info.current_episode
                        return item
                    }
                    result(list)
                }
            },
            failure: { (error) in
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GET_DRAMA_HISTORY_FAILED",
                        message: "获取短剧历史失败: \(error.localizedDescription)",
                        details: ["error": error.localizedDescription]
                    ))
                }
            }
        )
    }

    func getRecommendedDramaList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let page = (args?["page"] as? Int) ?? 1
        let count = (args?["count"] as? Int) ?? 20

        DJXPlayletManager.shareInstance().requestRecommendedPlayletListPage(
            page,
            num: count,
            success: { playletList, _ in
                DispatchQueue.main.async {
                    let list = playletList.map { playletInfoToMap($0) }
                    result(list)
                }
            },
            failure: { error in
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GET_RECOMMEND_DRAMA_FAILED",
                        message: "获取推荐短剧失败: \(error.localizedDescription)",
                        details: ["error": error.localizedDescription]
                    ))
                }
            }
        )
    }

    func getDramaListByIds(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        guard let idValues = args?["dramaIds"] as? [Any], !idValues.isEmpty else {
            result([])
            return
        }

        let idStrings = idValues.map { "\($0)" }
        DJXPlayletManager.shareInstance().requestPlayletList(withPlayletId: idStrings, success: { playletList in
            DispatchQueue.main.async {
                let list = playletList.map { playletInfoToMap($0) }
                result(list)
            }
        }, failure: { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "GET_DRAMA_BY_IDS_FAILED",
                    message: "根据ID获取短剧失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        })
    }

    func getDramaListByCategory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        guard let category = args?["category"] as? String, !category.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "category不能为空", details: nil))
            return
        }

        let page = (args?["page"] as? Int) ?? 1
        let count = (args?["count"] as? Int) ?? 20
        let order = (args?["order"] as? Int) ?? 0

        let orderType = DJXPlayletOrderType(rawValue: order)
            ?? DJXPlayletOrderType(rawValue: 0)
            ?? DJXPlayletOrderType(rawValue: 1)!
        DJXPlayletManager.shareInstance().requestCategoryPlayletLis(withCategory: category, page: page, num: count, order: orderType, success: { playletList in
            DispatchQueue.main.async {
                let list = playletList.map { playletInfoToMap($0) }
                result(list)
            }
        }, failure: { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "GET_DRAMA_BY_CATEGORY_FAILED",
                    message: "按分类获取短剧失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        })
    }

    func clearDramaHistory(result: @escaping FlutterResult) {
        DJXPlayletManager.shareInstance().requestPlayletHistoryClean(completion: {
            DispatchQueue.main.async {
                result(true)
            }
        }, failure: { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "CLEAR_HISTORY_FAILED",
                    message: "清空历史记录失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        })
    }

    func favorDrama(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let dramaId = (call.arguments as? [String: Any])?["dramaId"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "dramaId不能为空", details: nil))
            return
        }
        let favorite = ((call.arguments as? [String: Any])?["favorite"] as? Bool) ?? true

        let completion: () -> Void = {
            DispatchQueue.main.async { result(true) }
        }
        let failure: (Error) -> Void = { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "FAVOR_DRAMA_FAILED",
                    message: "收藏状态更新失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        }

        if favorite {
            DJXPlayletManager.shareInstance().collectShortplay(dramaId, success: completion, failure: failure)
        } else {
            DJXPlayletManager.shareInstance().cancelCollectShortplay(dramaId, success: completion, failure: failure)
        }
    }

    func likeEpisode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dramaId = args["dramaId"] as? Int,
              let episodeIndex = args["episodeIndex"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "参数不完整", details: nil))
            return
        }
        let like = (args["like"] as? Bool) ?? true

        let completion: () -> Void = {
            DispatchQueue.main.async { result(true) }
        }
        let failure: (Error) -> Void = { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "LIKE_EPISODE_FAILED",
                    message: "点赞状态更新失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        }

        if like {
            DJXPlayletManager.shareInstance().likeShortplay(dramaId, episode_index: episodeIndex, success: completion, failure: failure)
        } else {
            DJXPlayletManager.shareInstance().cancelLikeShortplay(dramaId, episode_index: episodeIndex, success: completion, failure: failure)
        }
    }

    func getDramaFavorList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let page = (args?["page"] as? Int) ?? 1
        let count = (args?["count"] as? Int) ?? 20

        DJXPlayletManager.shareInstance().requestCollectionList(page, pageSize: count, success: { playletList, hasMore in
            DispatchQueue.main.async {
                let items = playletList.map { playletInfoToMap($0) }
                let response: [String: Any] = [
                    "items": items,
                    "total": items.count,
                    "hasMore": hasMore,
                    "others": ["hasMore": hasMore]
                ]
                result(response)
            }
        }, failure: { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "GET_FAVOR_LIST_FAILED",
                    message: "获取收藏列表失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        })
    }

    func getDramaEpisodesStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dramaId = args["dramaId"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "dramaId不能为空", details: nil))
            return
        }
        let freeSet = (args["freeSet"] as? Int) ?? 0

        DJXPlayletManager.shareInstance().requestPlayletDetailsUnlockInfo(dramaId, freeEpisodeCount: freeSet, success: { statusArray in
            DispatchQueue.main.async {
                var list: [[String: Any]] = []
                for (index, value) in statusArray.enumerated() {
                    let isLocked = !(value.boolValue)
                    list.append(["index": index + 1, "isLocked": isLocked])
                }
                result(list)
            }
        }, failure: { error in
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "GET_EPISODE_STATUS_FAILED",
                    message: "获取剧集状态失败: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription]
                ))
            }
        })
    }

    func verifyDramaParams(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let total = (args?["total"] as? Int) ?? 0
        let freeSet = (args?["freeSet"] as? Int) ?? 0
        let lockSet = (args?["lockSet"] as? Int) ?? 0
        // iOS 暂无对应校验接口，直接返回输入值
        result([
            "total": total,
            "freeSet": freeSet,
            "lockSet": lockSet,
            "verified": false
        ])
    }


    // MARK: - 短剧滑滑流相关

    /**
     * 创建短剧滑滑流
     */
    func createDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }
        dramaSwipeManager.createDramaSwipeFlow(call: call, result: result)
    }

    /**
     * 展示短剧滑滑流
     */
    func showDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        dramaSwipeManager.showDramaSwipeFlow(call: call, result: result)
    }

    /**
     * 隐藏短剧滑滑流
     */
    func hideDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        dramaSwipeManager.hideDramaSwipeFlow(call: call, result: result)
    }

    /**
     * 销毁短剧滑滑流
     */
    func destroyDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        dramaSwipeManager.destroyDramaSwipeFlow(call: call, result: result)
    }

    // MARK: - 短剧卡片相关

    /**
     * 创建短剧卡片
     */
    func createDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStarted else {
            result(FlutterError(code: "NOT_STARTED", message: "SDK未启动", details: nil))
            return
        }
        dramaCardManager.createDramaCard(call: call, result: result)
    }

    /**
     * 展示短剧卡片
     */
    func showDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        dramaCardManager.showDramaCard(call: call, result: result)
    }

    /**
     * 播放短剧卡片
     */
    func playDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.playDramaCard(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.play()
            result(true)
            return
        }

        // 降级到Manager（兼容旧的Activity模式）
        dramaCardManager.playDramaCard(call: call, result: result)
    }

    /**
     * 暂停短剧卡片
     */
    func pauseDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.pauseDramaCard(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.pause()
            result(true)
            return
        }

        // 降级到Manager
        dramaCardManager.pauseDramaCard(call: call, result: result)
    }

    /**
     * 停止短剧卡片
     */
    func stopDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.stopDramaCard(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.stop()
            result(true)
            return
        }

        // 降级到Manager
        dramaCardManager.stopDramaCard(call: call, result: result)
    }

    /**
     * 设置短剧卡片静音状态
     */
    func setDramaCardMute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let mute = args["mute"] as? Bool else {
            dramaCardManager.setDramaCardMute(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.setMute(mute)
            result(true)
            return
        }

        // 降级到Manager
        dramaCardManager.setDramaCardMute(call: call, result: result)
    }

    /**
     * 上报短剧卡片展示埋点
     */
    func reportDramaCardShow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String,
              let duration = args["duration"] as? Int else {
            dramaCardManager.reportDramaCardShow(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.reportShow(duration: duration)
            result(true)
            return
        }

        // 降级到Manager
        dramaCardManager.reportDramaCardShow(call: call, result: result)
    }

    /**
     * 刷新短剧卡片数据
     */
    func refreshDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.refreshDramaCard(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            platformView.refresh()
            result(true)
            return
        }

        // 降级到Manager
        dramaCardManager.refreshDramaCard(call: call, result: result)
    }

    /**
     * 销毁短剧卡片
     */
    func destroyDramaCard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        dramaCardManager.destroyDramaCard(call: call, result: result)
    }

    /**
     * 判断短剧卡片是否正在播放
     */
    func isDramaCardPlaying(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.isDramaCardPlaying(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            result(platformView.isPlaying())
            return
        }

        // 降级到Manager
        dramaCardManager.isDramaCardPlaying(call: call, result: result)
    }

    /**
     * 获取短剧卡片的短剧信息
     */
    func getDramaCardInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.getDramaCardInfo(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            result(platformView.getDramaInfo())
            return
        }

        // 降级到Manager
        dramaCardManager.getDramaCardInfo(call: call, result: result)
    }

    /**
     * 获取短剧卡片的短剧GID
     */
    func getDramaCardGid(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.getDramaCardGid(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            result(platformView.getGid())
            return
        }

        // 降级到Manager
        dramaCardManager.getDramaCardGid(call: call, result: result)
    }

    /**
     * 获取短剧卡片的短剧标题
     */
    func getDramaCardTitle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cardId = args["cardId"] as? String else {
            dramaCardManager.getDramaCardTitle(call: call, result: result)
            return
        }

        // 优先查找PlatformView实例
        if let platformView = DramaCardPlatformView.find(viewId: cardId) {
            result(platformView.getTitle())
            return
        }

        // 降级到Manager
        dramaCardManager.getDramaCardTitle(call: call, result: result)
    }

    // MARK: - 解锁记录绑定

    func generateDramaUnlockSign(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let serverKey = args["serverKey"] as? String,
              let nonce = args["nonce"] as? String,
              let timestamp = args["timestamp"] as? NSNumber,
              let payload = args["payload"] as? [String: String],
              !serverKey.isEmpty, !nonce.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "参数不完整", details: nil))
            return
        }

        guard payload["ouid"] != nil else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "payload 必须包含 ouid", details: nil))
            return
        }

        if let sign = DJXManager.getSignWithPaySecretKey(serverKey, nonce: nonce, timeStamp: timestamp.doubleValue, params: payload) {
            result(sign)
        } else {
            result(FlutterError(code: "UNLOCK_SIGN_FAILED", message: "生成签名失败", details: nil))
        }
    }

    func loginDramaUnlock(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "参数不完整", details: nil))
            return
        }

        if let params = args["params"] as? String, !params.isEmpty {
            DJXManager.login(withParamsString: params) { success, userInfo in
                if success {
                    result(["success": true, "params": params])
                } else {
                    let detail = self.convertUserInfo(userInfo)
                    let message = (detail?["message"] as? String) ?? "绑定失败"
                    result(FlutterError(code: "UNLOCK_LOGIN_FAILED", message: message, details: detail))
                }
            }
            return
        }

        guard let serverKey = args["serverKey"] as? String,
              let nonce = args["nonce"] as? String,
              let timestamp = args["timestamp"] as? NSNumber,
              let payload = args["payload"] as? [String: String],
              !serverKey.isEmpty, !nonce.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "请提供 params 或 serverKey/nonce/timestamp/payload", details: nil))
            return
        }

        guard payload["ouid"] != nil else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "payload 必须包含 ouid", details: nil))
            return
        }

        guard let sign = DJXManager.getSignWithPaySecretKey(serverKey, nonce: nonce, timeStamp: timestamp.doubleValue, params: payload) else {
            result(FlutterError(code: "UNLOCK_SIGN_FAILED", message: "生成签名失败", details: nil))
            return
        }

        DJXManager.login(withParamsString: sign) { success, userInfo in
            if success {
                result(["success": true, "params": sign])
            } else {
                let detail = self.convertUserInfo(userInfo)
                let message = (detail?["message"] as? String) ?? "绑定失败"
                result(FlutterError(code: "UNLOCK_LOGIN_FAILED", message: message, details: detail))
            }
        }
    }

    func logoutDramaUnlock(result: @escaping FlutterResult) {
        DJXManager.logout { success, userInfo in
            if success {
                result(["success": true])
            } else {
                let detail = self.convertUserInfo(userInfo)
                let message = (detail?["message"] as? String) ?? "解绑失败"
                result(FlutterError(code: "UNLOCK_LOGOUT_FAILED", message: message, details: detail))
            }
        }
    }

    func isDramaUnlockLogin(result: @escaping FlutterResult) {
        result(DJXManager.isLogin())
    }

    private func convertUserInfo(_ userInfo: [AnyHashable: Any]?) -> [String: Any]? {
        guard let userInfo = userInfo else { return nil }
        var map: [String: Any] = [:]
        for (key, value) in userInfo {
            if let keyString = key as? String {
                map[keyString] = value
            }
        }
        return map
    }

    // MARK: - 事件处理

    /**
     * 发送事件到Flutter
     */
    func sendEvent(eventType: String, data: [String: Any]? = nil, contentId: String = "sdk") {
        // 🔍 调试日志: 记录事件发送
        if eventType.hasPrefix("drama_") {
            print("📡 [ContentManager] sendEvent - type=\(eventType), contentId=\(contentId)")
            print("📡 [ContentManager] eventSink状态: \(_eventSink != nil ? "✅" : "❌")")
            if let playerId = data?["playerId"] as? String {
                print("📡 [ContentManager] playerId=\(playerId)")
            }
        }

        guard let eventSink = self._eventSink else {
            if eventType.hasPrefix("drama_") {
                print("⚠️ [ContentManager] eventSink为nil,事件未发送")
            }
            return
        }

        var event: [String: Any] = [
            "type": eventType,
            "action": eventType,
            "contentId": contentId,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        if var payload = data {
            if let overrideContentId = payload["contentId"] as? String {
                event["contentId"] = overrideContentId
            }
            event["extra"] = payload
            payload.forEach { key, value in
                if event[key] == nil {
                    event[key] = value
                }
            }
        }

        if eventType.hasPrefix("drama_") {
            print("✅ [ContentManager] 事件已发送到Flutter")
        }

        eventSink(event)
    }
}

// MARK: - FlutterStreamHandler

extension ContentManager: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self._eventSink = events
        dramaSwipeManager.setEventSink(events)
        dramaCardManager.setEventSink(events)
        print("📻 [ContentManager] Event channel started listening - eventSink已设置 ✅")
        print("📻 [ContentManager] ContentManager实例: \(Unmanaged.passUnretained(self).toOpaque())")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self._eventSink = nil
        dramaSwipeManager.setEventSink(nil as FlutterEventSink?)
        dramaCardManager.setEventSink(nil)
        print("📻 [ContentManager] Event channel cancelled - eventSink已清空 ❌")
        return nil
    }
}

// MARK: - 数据映射辅助

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
