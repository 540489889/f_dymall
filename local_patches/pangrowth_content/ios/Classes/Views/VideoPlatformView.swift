import Flutter
import UIKit
import LCDSDK

/// 沉浸式小视频 PlatformView
///
/// 使用 LCDDrawVideoViewController 封装穿山甲内容SDK的小视频组件，
/// 实现真正的内嵌小视频流，支持 pause/resume 控制。
class VideoPlatformView: NSObject, FlutterPlatformView {

    // MARK: - Static Cache

    private static var viewCache = NSMapTable<NSString, VideoPlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> VideoPlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    // MARK: - Properties

    private let contentView: UIView
    private var videoController: LCDDrawVideoViewController?
    private let videoId: String
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

        // 获取或生成 videoId
        self.videoId = params["videoId"] as? String ?? UUID().uuidString

        // 创建容器视图
        let width = params["width"] as? CGFloat ?? frame.width
        let height = params["height"] as? CGFloat ?? frame.height
        self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        self.contentView.backgroundColor = .black
        self.contentView.clipsToBounds = true

        super.init()

        // 添加到缓存
        VideoPlatformView.viewCache.setObject(self, forKey: videoId as NSString)

        // 设置方法通道
        self.methodChannel = FlutterMethodChannel(
            name: "pangrowth_content/video_view/\(viewId)",
            binaryMessenger: messenger
        )

        // 设置方法调用处理器
        weak var weakSelf = self
        methodChannel?.setMethodCallHandler { call, result in
            weakSelf?.handleMethodCall(call: call, result: result)
        }

        // 初始化视频控制器
        initializeVideoController(params: params)
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        return contentView
    }

    // MARK: - Private Methods

    private func initializeVideoController(params: [String: Any]) {
        // 检查 SDK 是否初始化
        // 注意：这里假设有全局检查方法，如果没有则跳过此检查
        // guard LCDSdk.isStartSuccess() else {
        //     print("VideoPlatformView: LCDSdk not available")
        //     return
        // }

        // 解析配置参数
        let channelType = params["channelType"] as? Int ?? 1
        let contentType = params["contentType"] as? Int ?? 1
        let hideChannelName = params["hideChannelName"] as? Bool ?? false
        let autoPlay = params["autoPlay"] as? Bool ?? true

        // 创建小视频Draw控制器
        let drawVC = LCDDrawVideoViewController { [weak self] config in
            guard let self = self else { return }

            config.customAppear = true
            config.viewSize = self.contentView.bounds.size

            // 设置频道类型
            switch channelType {
            case 1:
                config.drawVCTabOptions = .recommand  // 推荐频道
            case 2:
                config.drawVCTabOptions = .following  // 关注频道
            case 3:
                config.drawVCTabOptions = [.recommand, .following]  // 两个频道
            default:
                config.drawVCTabOptions = .recommand
            }

            // 是否隐藏频道名称（仅一个频道时生效）
            config.shouldHideTabBarView = hideChannelName

            // 不显示关闭按钮
            config.showCloseButton = false

            // 隐藏引导手势
            config.hiddenGuideGeste = true
        }

        self.videoController = drawVC

        // 添加视频控制器的视图
        addVideoViewController(drawVC)

        // 如果autoPlay=false，创建后立即暂停
        if !autoPlay {
            drawVC.drawVideoViewControllerDidDisappear()
            print("VideoPlatformView: 视频创建成功但暂停播放 - videoId: \(videoId)")
        } else {
            drawVC.drawVideoViewControllerDidAppear()
            print("VideoPlatformView: 视频创建成功并自动播放 - videoId: \(videoId)")
        }
    }

    private func addVideoViewController(_ viewController: UIViewController) {
        // 设置视图框架
        viewController.view.frame = contentView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 添加到容器视图
        contentView.addSubview(viewController.view)

        // 获取 Flutter ViewController
        guard let flutterVC = getFlutterViewController() else {
            print("VideoPlatformView: Failed to get Flutter view controller")
            return
        }

        // 将 UIViewController 添加为 Flutter ViewController 的子控制器
        flutterVC.addChild(viewController)
        viewController.didMove(toParent: flutterVC)

        print("VideoPlatformView: ViewController added to Flutter VC")
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
        videoController?.drawVideoViewControllerDidDisappear()
    }

    func resume() {
        videoController?.drawVideoViewControllerDidAppear()
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
        guard let vc = videoController else {
            methodChannel?.setMethodCallHandler(nil)
            methodChannel = nil
            VideoPlatformView.viewCache.removeObject(forKey: videoId as NSString)
            return
        }

        // 触发完整的ViewController生命周期，释放SDK内部资源

        // 1. 触发视图消失生命周期
        vc.viewWillDisappear(false)
        vc.viewDidDisappear(false)
        print("VideoPlatformView: 触发viewWillDisappear/viewDidDisappear - videoId: \(videoId)")

        // 2. 调用SDK的自定义消失方法（对于customAppear模式）
        vc.drawVideoViewControllerDidDisappear()
        print("VideoPlatformView: 调用drawVideoViewControllerDidDisappear - videoId: \(videoId)")

        // 3. 移除视图
        vc.view.removeFromSuperview()

        // 4. 断开父子关系
        vc.willMove(toParent: nil)
        vc.removeFromParent()

        // 5. 清理引用
        videoController = nil
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil

        // 从缓存移除
        VideoPlatformView.viewCache.removeObject(forKey: videoId as NSString)

        print("VideoPlatformView: Disposed - videoId: \(videoId)")
    }
}
