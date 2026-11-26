import Flutter
import UIKit
import PangrowthMiniStory

/// 短故事聚合页 PlatformView (iOS 实现)
///
/// 使用 MNSMainViewController 封装短故事聚合页，
/// 实现真正的内嵌短故事聚合页面。
class StoryHomePlatformView: NSObject, FlutterPlatformView {

    // MARK: - Static Cache

    private static var viewCache = NSMapTable<NSString, StoryHomePlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> StoryHomePlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    // MARK: - Properties

    private let contentView: UIView
    private var mainViewController: MNSMainViewController?
    private let viewId: String
    private let messenger: FlutterBinaryMessenger

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

        // 获取或生成 viewId
        self.viewId = params["viewId"] as? String ?? UUID().uuidString

        // 创建容器视图
        self.contentView = UIView(frame: frame)
        self.contentView.backgroundColor = .black
        self.contentView.clipsToBounds = true

        super.init()

        // 添加到缓存
        StoryHomePlatformView.viewCache.setObject(self, forKey: self.viewId as NSString)

        // 初始化短故事聚合页
        initializeStoryHome(params: params, frame: frame)
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        return contentView
    }

    // MARK: - Private Methods

    private func initializeStoryHome(params: [String: Any], frame: CGRect) {

        // 创建阅读器配置
        let openParams = MNStoryReaderOpenParams()

        // 解析 readerConfig
        if let readerConfig = params["readerConfig"] as? [String: Any] {
            // 是否自定义激励广告
            if let customRewardAD = readerConfig["customRewardAD"] as? Bool {
                openParams.customRewardAD = customRewardAD
            }

            // 是否增加自定义解锁点
            if let addCustomRewardPoint = readerConfig["addCustomRewardPoint"] as? Bool {
                openParams.addCustomRewardPoint = addCustomRewardPoint
            }

            // 是否自定义激励入口
            if let customRewardEntryView = readerConfig["customRewardEntryView"] as? Bool {
                openParams.customRewardEntryView = customRewardEntryView
            }

            // 是否显示自定义底部banner广告
            if let showCustomBottomBannerAD = readerConfig["showCustomBottomBannerAD"] as? Bool {
                openParams.showCustomBottomBannerAD = showCustomBottomBannerAD
            }

            // 是否显示自定义章间广告
            if let showCustomMiddleAD = readerConfig["showCustomMiddleAD"] as? Bool {
                openParams.showCustomMiddleAD = showCustomMiddleAD
            }

            // 插入章间广告的间隔数
            if let pageIntervalForMiddleAD = readerConfig["pageIntervalForMiddleAD"] as? Int {
                openParams.pageIntervalForMiddleAD = pageIntervalForMiddleAD
            }

            // 翻页模式 (0:仿真, 1:滑页, 2:平移, 3:上下滚动)
            // 注意：此属性可能在某些 SDK 版本中不存在，暂时注释
            // if let pageTurnType = readerConfig["pageTurnType"] as? Int {
            //     openParams.pageTurnType = pageTurnType
            // }

            // 字体大小档位
            // 注意：此属性可能在某些 SDK 版本中不存在，暂时注释
            // if let fontSizeLevel = readerConfig["fontSizeLevel"] as? Int {
            //     openParams.fontSizeLevel = fontSizeLevel
            // }

            // 内容中插入View
            if let insertViewInsideContent = readerConfig["insertViewInsideContent"] as? Bool {
                openParams.insertViewInsideContent = insertViewInsideContent
            }

            if let pageIntervalForInsertView = readerConfig["pageIntervalForInsertView"] as? UInt {
                openParams.pageIntervalForInsertView = pageIntervalForInsertView
            }

            if let startLineForInsertView = readerConfig["startLineForInsertView"] as? UInt {
                openParams.startLineForInsertView = startLineForInsertView
            }

            if let insertViewHeight = readerConfig["insertViewHeight"] as? CGFloat {
                openParams.insertViewHeight = insertViewHeight
            }

        }

        // 创建短故事聚合页 ViewController
        let mainVC = MNSMainViewController(readConfig: openParams)
        self.mainViewController = mainVC

        // 设置视图框架
        mainVC.view.frame = contentView.bounds
        mainVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 添加到容器视图
        contentView.addSubview(mainVC.view)

        // 获取 Flutter ViewController
        guard let flutterVC = getFlutterViewController() else {
            return
        }

        // 将 UIViewController 添加为 Flutter ViewController 的子控制器
        flutterVC.addChild(mainVC)
        mainVC.didMove(toParent: flutterVC)

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

    // MARK: - Cleanup

    deinit {

        // 清理视图控制器
        if let vc = mainViewController {
            // 视图消失
            vc.view.removeFromSuperview()

            // 从父视图控制器移除
            vc.willMove(toParent: nil)
            vc.removeFromParent()
        }

        mainViewController = nil

        // 从缓存移除
        StoryHomePlatformView.viewCache.removeObject(forKey: viewId as NSString)

    }
}
