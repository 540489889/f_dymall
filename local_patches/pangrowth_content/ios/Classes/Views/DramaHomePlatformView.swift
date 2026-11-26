import Flutter
import UIKit
import PangrowthDJX

/// 短剧聚合页 PlatformView (iOS 实现)
///
/// 使用 DJXPlayletAggregatePageViewController 创建短剧聚合页，
/// 实现真正的内嵌短剧聚合页面。
///
/// 特性：
/// - 单实例模式：同时只能存在一个聚合页实例
/// - 自动管理生命周期：创建、显示、销毁
/// - 支持自定义配置：免费集数、解锁方式等
final class DramaHomePlatformView: NSObject, FlutterPlatformView {
    private static var activeViewId: String?
    private static var viewCache = NSMapTable<NSString, DramaHomePlatformView>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    static func find(viewId: String) -> DramaHomePlatformView? {
        return viewCache.object(forKey: viewId as NSString)
    }

    private let container: UIView
    private weak var parentController: UIViewController?
    private var viewController: DJXPlayletAggregatePageViewController?
    private let contentManager: ContentManager
    private let viewId: String
    private let params: [String: Any]?

    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, contentManager: ContentManager) {
        self.contentManager = contentManager
        self.params = args as? [String: Any]
        self.viewId = (self.params?["viewId"] as? String) ?? UUID().uuidString
        self.container = UIView(frame: frame)
        self.container.clipsToBounds = true
        self.container.backgroundColor = .clear
        super.init()

        if let active = DramaHomePlatformView.activeViewId, active != viewId {
            assertionFailure("短剧聚合页仅支持单实例，请先销毁现有实例")
            showError(message: "仅支持单个聚合页实例")
            return
        }

        DramaHomePlatformView.activeViewId = viewId
        DramaHomePlatformView.viewCache.setObject(self, forKey: viewId as NSString)

        guard contentManager.isDramaModuleReady() else {
            sendError(code: "SDK_NOT_READY", message: "请先调用 start 并确保 GroMore 初始化完成")
            showError(message: "SDK 未启动")
            DramaHomePlatformView.viewCache.removeObject(forKey: viewId as NSString)
            if DramaHomePlatformView.activeViewId == viewId {
                DramaHomePlatformView.activeViewId = nil
            }
            return
        }

        createDramaHome()
    }

    func view() -> UIView {
        return container
    }

    func dispose() {
        teardown()
    }

    func destroyOnCommand() {
        teardown()
    }

    private func createDramaHome() {
        do {
            let config = params?["config"] as? [String: Any]
            let playletConfig = buildPlayletConfig(config)
            let controller = DJXPlayletAggregatePageViewController { builder in
                builder.playletConfig = playletConfig

                if let showBack = config?["isShowNavigationItemBackButton"] as? Bool {
                    builder.isShowNavigationItemBackButton = showBack
                } else if let showBack = config?["showBackBtn"] as? Bool {
                    builder.isShowNavigationItemBackButton = showBack
                }

                if let showTitle = config?["isShowNavigationItemTitle"] as? Bool {
                    builder.isShowNavigationItemTitle = showTitle
                } else if let showTitle = config?["showPageTitle"] as? Bool {
                    builder.isShowNavigationItemTitle = showTitle
                }

                var topIds: [String] = []
                if let ids = config?["topDramaIds"] as? [String], !ids.isEmpty {
                    topIds = ids
                } else if let id = config?["topDramaId"] as? Int, id > 0 {
                    topIds = [String(id)]
                }
                if !topIds.isEmpty {
                    builder.topSkitIds = topIds
                }
            }

            attach(viewController: controller)
            viewController = controller
            sendEvent(type: "drama_home_show", data: ["success": true])
        } catch {
            sendError(code: "CREATE_DRAMA_HOME_ERROR", message: error.localizedDescription)
            showError(message: "创建失败")
            DramaHomePlatformView.viewCache.removeObject(forKey: viewId as NSString)
            if DramaHomePlatformView.activeViewId == viewId {
                DramaHomePlatformView.activeViewId = nil
            }
        }
    }

    private func buildPlayletConfig(_ config: [String: Any]?) -> DJXPlayletConfig {
        let playletConfig = DJXPlayletConfig()
        if let freeEpisodesCount = config?["freeEpisodesCount"] as? Int {
            playletConfig.freeEpisodesCount = freeEpisodesCount
        }
        if let unlockEpisodesCountUsingAD = config?["unlockEpisodesCountUsingAD"] as? Int {
            playletConfig.unlockEpisodesCountUsingAD = unlockEpisodesCountUsingAD
        }
        playletConfig.playletUnlockADMode = .common
        return playletConfig
    }

    private func attach(viewController controller: DJXPlayletAggregatePageViewController) {
        guard let parent = topViewController() else {
            sendError(code: "NO_ROOT_VC", message: "未找到有效的根视图控制器")
            showError(message: "宿主异常")
            return
        }

        parent.addChild(controller)
        controller.view.frame = container.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.translatesAutoresizingMaskIntoConstraints = true
        container.addSubview(controller.view)
        controller.didMove(toParent: parent)
        parentController = parent
    }

    private func teardown() {
        if let controller = viewController {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            viewController = nil
            sendEvent(type: "drama_home_destroyed", data: ["success": true])
        }
        DramaHomePlatformView.viewCache.removeObject(forKey: viewId as NSString)
        if DramaHomePlatformView.activeViewId == viewId {
            DramaHomePlatformView.activeViewId = nil
        }
    }

    private func showError(message: String) {
        let label = UILabel(frame: container.bounds)
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(label)
    }

    private func sendEvent(type: String, data: [String: Any]? = nil) {
        var payload = data ?? [:]
        payload["contentId"] = viewId
        payload["eventType"] = normalizeEventType(type)
        contentManager.sendEvent(eventType: type, data: payload, contentId: viewId)
    }

    private func normalizeEventType(_ type: String) -> String {
        switch type {
        case "drama_home_item_click": return "itemClick"
        case "drama_home_search": return "search"
        case "drama_home_category_switch": return "categorySwitch"
        case "drama_home_refresh": return "refresh"
        case "drama_home_load_more": return "loadMore"
        case "drama_home_show": return "pageShow"
        case "drama_home_hide": return "pageHide"
        case "drama_home_destroyed": return "destroyed"
        default: return type
        }
    }

    private func sendError(code: String, message: String) {
        let payload: [String: Any] = [
            "code": code,
            "message": message,
            "contentId": viewId,
            "scene": "drama_home"
        ]
        contentManager.sendEvent(eventType: "sdk_error", data: payload, contentId: viewId)
    }

    private func topViewController(base: UIViewController? = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return tab.selectedViewController.flatMap { topViewController(base: $0) }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
