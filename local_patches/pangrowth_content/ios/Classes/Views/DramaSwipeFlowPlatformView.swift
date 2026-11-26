import Flutter
import UIKit
import PangrowthDJX

/// 短剧剧场 PlatformView
///
/// 使用 DJXDrawVideoViewController 封装穿山甲内容SDK的短剧滑滑流组件，
/// 实现真正的内嵌剧场流，支持 pause/resume 控制。
class DramaSwipeFlowPlatformView: NSObject, FlutterPlatformView {

    // MARK: - Static Cache

    private static var viewCache = NSMapTable<NSString, DramaSwipeFlowPlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> DramaSwipeFlowPlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    // MARK: - Properties

    private let contentView: UIView
    private var swipeFlowController: DJXDrawVideoViewController?
    private let swipeFlowId: String
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

        // 获取或生成 swipeFlowId
        self.swipeFlowId = params["swipeFlowId"] as? String ?? UUID().uuidString

        // 创建容器视图
        let width = params["width"] as? CGFloat ?? frame.width
        let height = params["height"] as? CGFloat ?? frame.height
        self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        self.contentView.backgroundColor = .black
        self.contentView.clipsToBounds = true

        super.init()

        // 添加到缓存
        DramaSwipeFlowPlatformView.viewCache.setObject(self, forKey: swipeFlowId as NSString)

        // 设置方法通道
        self.methodChannel = FlutterMethodChannel(
            name: "pangrowth_content/drama_swipe_flow_view/\(viewId)",
            binaryMessenger: messenger
        )

        // 设置方法调用处理器
        weak var weakSelf = self
        methodChannel?.setMethodCallHandler { call, result in
            weakSelf?.handleMethodCall(call: call, result: result)
        }

        // 初始化剧场控制器
        initializeSwipeFlowController(params: params)

        // 选集弹窗遮挡修复：详情页「选集 >」弹出的面板是 SDK 私有类，
        // 无公开配置项，这里用运行时探测修正其位置
        DramaEpisodePanelFixer.start()
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        return contentView
    }

    // MARK: - Private Methods

    private func initializeSwipeFlowController(params: [String: Any]) {
        // 检查 SDK 是否初始化 - 使用DJXPlayletManager检查
        guard DJXPlayletManager.shareInstance() != nil else {
            print("DramaSwipeFlowPlatformView: DJXPlayletManager not available")
            return
        }

        // 解析配置参数
        let config = params["config"] as? [String: Any] ?? [:]
        let channelType = config["channelType"] as? Int ?? 1
        let detailFree = config["detailFree"] as? Int ?? 5
        let unlockCount = config["unlockCount"] as? Int ?? 1
        let unlockAdMode = config["unlockAdMode"] as? Int ?? 0
        let hideTopInfo = config["hideTopInfo"] as? Bool ?? false
        let hideBottomInfo = config["hideBottomInfo"] as? Bool ?? false
        let hideEnter = config["hideEnter"] as? Bool ?? false
        let hideLikeButton = config["hideLikeButton"] as? Bool ?? false
        let hideFavorButton = config["hideFavorButton"] as? Bool ?? false
        let showChangeBtn = config["showChangeBtn"] as? Bool ?? true
        let hideBack = config["hideBack"] as? Bool ?? true
        // 滑滑流关闭按钮 与 详情页返回键 拆成两个独立开关。
        // 原实现只有 hideBack: playletConfig.hideBackButton = hideBack,
        // 且 config.showCloseButton = !hideBack -> 想藏关闭按钮就必然丢掉详情页返回键。
        // 未显式传入新参数时回退到 hideBack, 保持旧行为不变。
        let hideFeedBack = config["hideFeedBack"] as? Bool ?? hideBack
        let hideDetailBack = config["hideDetailBack"] as? Bool ?? hideBack
        let autoPlay = config["autoPlay"] as? Bool ?? true

        // 原生侧实参日志: 用于确认 Flutter 传入的参数是否真的到达原生
        print("[DramaSwipeFlow] hideFeedBack=\(hideFeedBack) hideDetailBack=\(hideDetailBack) hideBack=\(hideBack) hideBottomInfo=\(hideBottomInfo) showChangeBtn=\(showChangeBtn) topOffset=\(String(describing: config["setTopOffset"]))")

        // 创建短剧详情配置
        let playletConfig = DJXPlayletConfig()
        playletConfig.freeEpisodesCount = detailFree
        playletConfig.unlockEpisodesCountUsingAD = unlockCount

        if unlockAdMode == 1 {
            playletConfig.playletUnlockADMode = .specific
        } else {
            playletConfig.playletUnlockADMode = .common
        }

        playletConfig.hideTopInfo = hideTopInfo
        playletConfig.hideBottomInfo = hideBottomInfo
        playletConfig.hideLikeIcon = hideLikeButton
        playletConfig.hideCollectIcon = hideFavorButton
        playletConfig.hideBackButton = hideDetailBack

        // fromTopMargin 可能是iOS的offset
        if let topOffset = config["setTopOffset"] as? Int, topOffset > 0 {
            playletConfig.fromTopMargin = CGFloat(topOffset)
        }

        // 创建剧场Draw控制器
        let drawVC = DJXDrawVideoViewController { [weak self] config in
            guard let self = self else { return }

            config.customAppear = true
            config.viewSize = self.contentView.bounds.size
            config.playletConfig = playletConfig

            // 设置频道类型 - 使用正确的枚举值
            switch channelType {
            case 1:
                config.drawVCTabOptions = .playlet_feed  // 推荐频道
            case 2:
                config.drawVCTabOptions = .theater       // 剧场频道
            case 3:
                config.drawVCTabOptions = [.playlet_feed, .theater]  // 两个频道
            default:
                config.drawVCTabOptions = .playlet_feed
            }

            // 设置是否显示频道切换
            config.shouldHideTabBarView = !showChangeBtn

            // 设置关闭按钮
            config.showCloseButton = !hideFeedBack

            // 隐藏引导手势
            config.hiddenGuideGeste = true
        }

        self.swipeFlowController = drawVC

        // 添加剧场控制器的视图
        addSwipeFlowViewController(drawVC)

        // 如果autoPlay=false，创建后立即暂停
        if !autoPlay {
            // 使用SDK专用方法暂停（与VideoPlatformView保持一致）
            drawVC.drawVideoViewControllerDidDisappear()
            print("DramaSwipeFlowPlatformView: 滑滑流创建成功但暂停播放 - swipeFlowId: \(swipeFlowId)")
        } else {
            print("DramaSwipeFlowPlatformView: 滑滑流创建成功并自动播放 - swipeFlowId: \(swipeFlowId)")
        }
    }

    private func addSwipeFlowViewController(_ viewController: UIViewController) {
        // 设置视图框架
        viewController.view.frame = contentView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 添加到容器视图
        contentView.addSubview(viewController.view)

        // 获取 Flutter ViewController
        guard let flutterVC = getFlutterViewController() else {
            print("DramaSwipeFlowPlatformView: Failed to get Flutter view controller")
            return
        }

        // 将 UIViewController 添加为 Flutter ViewController 的子控制器
        flutterVC.addChild(viewController)
        viewController.didMove(toParent: flutterVC)

        print("DramaSwipeFlowPlatformView: ViewController added to Flutter VC")
    }

    private func getFlutterViewController() -> UIViewController? {
        // 尝试从 window 层级找到 FlutterViewController
        var responder: UIResponder? = contentView
        while responder != nil {
            responder = responder?.next
            if let viewController = responder as? UIViewController {
                return viewController
            }
        }

        // 如果找不到，使用根视图控制器
        return UIApplication.shared.delegate?.window??.rootViewController
    }

    // MARK: - Control Methods

    func pause() {
        // 使用 DJXDrawVideoViewController 专用的暂停方法
        // 这与 VideoPlatformView 使用的方法相同，比生命周期方法更可靠
        swipeFlowController?.drawVideoViewControllerDidDisappear()
    }

    func resume() {
        // 使用 DJXDrawVideoViewController 专用的恢复方法
        // 这与 VideoPlatformView 使用的方法相同，比生命周期方法更可靠
        swipeFlowController?.drawVideoViewControllerDidAppear()
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pause":
            pause()
            result(true)

        case "resume":
            resume()
            result(true)

        case "dispose":
            dispose()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Cleanup

    private func dispose() {
        // 停止选集弹窗观察器，避免平台视图销毁后仍在轮询
        DramaEpisodePanelFixer.stop()
        guard let vc = swipeFlowController else {
            methodChannel?.setMethodCallHandler(nil)
            methodChannel = nil
            DramaSwipeFlowPlatformView.viewCache.removeObject(forKey: swipeFlowId as NSString)
            return
        }

        // 触发完整的ViewController生命周期，释放SDK内部资源

        // 1. 触发视图消失生命周期
        vc.viewWillDisappear(false)
        vc.viewDidDisappear(false)
        print("DramaSwipeFlowPlatformView: 触发viewWillDisappear/viewDidDisappear - swipeFlowId: \(swipeFlowId)")

        // 2. 移除视图
        vc.view.removeFromSuperview()

        // 3. 断开父子关系
        vc.willMove(toParent: nil)
        vc.removeFromParent()

        // 4. 清理引用
        swipeFlowController = nil
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil

        // 从缓存移除
        DramaSwipeFlowPlatformView.viewCache.removeObject(forKey: swipeFlowId as NSString)

        print("DramaSwipeFlowPlatformView: Disposed - swipeFlowId: \(swipeFlowId)")
    }
}