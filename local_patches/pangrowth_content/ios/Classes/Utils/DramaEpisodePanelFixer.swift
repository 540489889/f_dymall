import Foundation
import UIKit
import ObjectiveC
import PangrowthDJX

/// iOS 短剧默认选集面板可见性修复。
///
/// 穿山甲 iOS SDK 的默认选集面板由 `DJXDrawVideoViewController#chooseEpisode` 打开，
/// SDK 没有暴露弹窗层级配置。Flutter PlatformView 内嵌 SDK 控制器时，面板可能被
/// 容器裁剪，或被详情页/Flutter 视图压在下面。这里在选集面板打开后统一提升非主
/// 窗口层级，并把疑似面板视图置顶。
final class DramaEpisodePanelFixer {
    static let shared = DramaEpisodePanelFixer()

    private var installed = false
    private weak var mainWindow: UIWindow?
    private var windowObserver: NSObjectProtocol?

    private init() {}

    func installIfNeeded() {
        guard !installed else { return }
        installed = true
        mainWindow = Self.allWindows.first { $0.isKeyWindow }

        windowObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let window = notification.object as? UIWindow else { return }
            self.raise(window: window)
            Self.bringLikelyPanelToFront()
        }

        swizzleChooseEpisode()
    }

    func revealAfterChooseEpisode() {
        revealEpisodePanel()
    }

    private func swizzleChooseEpisode() {
        let selector = NSSelectorFromString("chooseEpisode")
        let controllerClass: AnyClass = DJXDrawVideoViewController.self

        guard let method = class_getInstanceMethod(controllerClass, selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding).hasPrefix("v") else {
            print("[DramaEpisodePanelFixer] chooseEpisode 不是可替换的 ObjC void 方法，只保留窗口监听修复")
            return
        }

        let originalIMP = method_getImplementation(method)
        let block: @convention(block) (AnyObject) -> Void = { [weak self] object in
            typealias Original = @convention(c) (AnyObject, Selector) -> Void
            unsafeBitCast(originalIMP, to: Original.self)(object, selector)
            self?.revealEpisodePanel()
        }
        let swizzledIMP = imp_implementationWithBlock(block)

        if class_addMethod(controllerClass, selector, swizzledIMP, encoding) {
            print("[DramaEpisodePanelFixer] 已为 chooseEpisode 添加可见性修复")
        } else {
            method_setImplementation(method, swizzledIMP)
            print("[DramaEpisodePanelFixer] 已替换 chooseEpisode 实现以修复可见性")
        }
    }

    private func revealEpisodePanel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for window in Self.allWindows {
                self.raise(window: window)
            }
            Self.bringLikelyPanelToFront()
            Self.logHierarchy()
        }
    }

    private func raise(window: UIWindow) {
        guard window !== mainWindow, !window.isHidden else { return }
        let targetLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        if window.windowLevel.rawValue < targetLevel.rawValue {
            window.windowLevel = targetLevel
        }
    }

    private static func bringLikelyPanelToFront() {
        for window in allWindows {
            bringLikelyPanelToFront(in: window)
        }
    }

    private static func bringLikelyPanelToFront(in view: UIView) {
        for subview in view.subviews {
            if looksLikeEpisodePanel(subview) {
                view.bringSubviewToFront(subview)
                subview.isUserInteractionEnabled = true
                if subview.isHidden { subview.isHidden = false }
                if subview.alpha < 0.01 { subview.alpha = 1 }
            }
            bringLikelyPanelToFront(in: subview)
        }
    }

    private static func looksLikeEpisodePanel(_ view: UIView) -> Bool {
        let className = NSStringFromClass(type(of: view)).lowercased()
        let identifier = (view.accessibilityIdentifier ?? "").lowercased()
        let description = String(describing: view).lowercased()
        let signature = "\(className) \(identifier) \(description)"
        let keywords = ["episode", "select", "choose", "gallery", "panel", "dialog", "popup", "sheet"]
        guard keywords.contains(where: { keyword in signature.contains(keyword) }) else { return false }
        return view.frame.height < UIScreen.main.bounds.height * 0.85
    }

    private static func logHierarchy() {
        let windows = allWindows
        print("[DramaEpisodePanelFixer] windows=\(windows.count)")
        for window in windows {
            let root = window.rootViewController.map { NSStringFromClass(type(of: $0)) } ?? "nil"
            print("[DramaEpisodePanelFixer] window=\(NSStringFromClass(type(of: window))) level=\(window.windowLevel.rawValue) hidden=\(window.isHidden) root=\(root)")
        }
    }

    private static var allWindows: [UIWindow] {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        }
        return UIApplication.shared.windows
    }
}
