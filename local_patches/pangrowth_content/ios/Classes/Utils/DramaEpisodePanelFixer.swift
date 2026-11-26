import UIKit

/// 短剧详情页「选集」弹窗 —— 诊断探针
///
/// 现状（真机日志）：点击「选集 >」后 SDK 弹出的 `DJXPlayletChooseViewController`
/// 的 view 是**全屏**（0,0,390,844）、以 child VC 形式挂在 FlutterViewController 上、
/// 直接 addSubview 到 FlutterView，链路上没有任何裁剪，所以「底部溢出」不是问题。
///
/// 现在要定位的是「弹窗打开后点击没反应」，因此这里只做观测、不改布局：
/// 1. 弹窗出现时 dump 完整视图树（frame / hidden / alpha / noTouch / disabled / clips）
/// 2. 打印 FlutterView 的 subview 叠放顺序，确认弹窗是否被兄弟视图压住
/// 3. 在 window 上装一个「只记录、不消费」的手势，打印每次触摸的落点与 hitTest 命中链
final class DramaEpisodePanelFixer: NSObject {

    static let shared = DramaEpisodePanelFixer()

    private var timer: Timer?
    private var lastPanelId: ObjectIdentifier?
    private var lastPanelName: String = ""
    private var repairedPanelId: ObjectIdentifier?
    private var panelWindow: UIWindow?
    private weak var panelHost: UIViewController?
    private var tapLogger: EpisodeTapLogger?
    private weak var observedWindow: UIWindow?

    // MARK: - 生命周期

    static func start() {
        shared.startWatching()
    }

    static func stop() {
        shared.timer?.invalidate()
        shared.timer = nil
        shared.lastPanelId = nil
        shared.repairedPanelId = nil
        shared.removeTapLogger()
        shared.panelWindow?.isHidden = true
        shared.panelWindow?.rootViewController = nil
        shared.panelWindow = nil
        shared.panelHost = nil
    }

    private func startWatching() {
        guard timer == nil else { return }
        print("[EpisodePanel] watcher started")
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - 轮询

    private func tick() {
        guard let win = Self.keyWindow() else { return }

        var panelVC: UIViewController?
        var panelName = ""
        for vc in Self.vcTree(from: win.rootViewController) {
            let name: String = NSStringFromClass(type(of: vc))
            if name.contains("Choose") || name.contains("Episode") {
                panelVC = vc
                panelName = name
                break
            }
        }

        guard let vc = panelVC else {
            lastPanelId = nil
            recycleOverlayIfNeeded()
            return
        }

        installTapLogger(window: win)

        let id = ObjectIdentifier(vc)
        guard lastPanelId != id else { return }
        lastPanelId = id
        lastPanelName = panelName

        handle(panel: vc, window: win, phase: "立刻")

        // 内容可能晚于 VC 出现，再抓一次稳定态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.lastPanelId == id, vc.view.window != nil else { return }
            self.handle(panel: vc, window: win, phase: "0.8s")
        }
    }

    // MARK: - 处理

    private func handle(panel vc: UIViewController, window win: UIWindow, phase: String) {
        let panelName: String = NSStringFromClass(type(of: vc))
        let root: UIView = vc.view
        let frameInWindow: CGRect = root.convert(root.bounds, to: win)

        var lines: [String] = []
        lines.append("[EpisodePanel][\(phase)] 弹窗 \(panelName)")
        lines.append("  window=\(Self.fmt(win.bounds)) safeArea=\(String(describing: win.safeAreaInsets))")
        lines.append("  panel.view.frame=\(Self.fmt(root.frame)) inWindow=\(Self.fmt(frameInWindow))"
                     + " clips=\(root.clipsToBounds) touch=\(root.isUserInteractionEnabled)"
                     + " alpha=\(String(format: "%.2f", root.alpha)) hidden=\(root.isHidden)")
        lines.append("  modalStyle=\(vc.modalPresentationStyle.rawValue)"
                     + " presenting=\(vc.presentingViewController.map { NSStringFromClass(type(of: $0)) } ?? "nil")"
                     + " parent=\(vc.parent.map { NSStringFromClass(type(of: $0)) } ?? "nil")")
        lines.append("  children=\(vc.children.count) presented=\(vc.presentedViewController.map { NSStringFromClass(type(of: $0)) } ?? "nil")")

        // 叠放顺序：谁盖在谁上面
        if let sv = root.superview {
            lines.append("  superview=\(NSStringFromClass(type(of: sv))) subviews=\(sv.subviews.count)"
                         + " panelIndex=\(sv.subviews.firstIndex(of: root).map(String.init) ?? "nil")")
            for i in 0..<sv.subviews.count {
                let v = sv.subviews[i]
                let f = v.convert(v.bounds, to: win)
                var flags: [String] = []
                if v.isHidden { flags.append("hidden") }
                if v.alpha < 0.99 { flags.append("alpha=\(String(format: "%.2f", v.alpha))") }
                if !v.isUserInteractionEnabled { flags.append("noTouch") }
                lines.append("    sib[\(i)] \(NSStringFromClass(type(of: v))) \(Self.fmt(f))"
                             + (flags.isEmpty ? "" : " {\(flags.joined(separator: ","))}")
                             + (v === root ? "  <-- 弹窗" : ""))
            }
        }

        // 视图树
        lines.append("  ---- 视图树 ----")
        lines.append(contentsOf: Self.dumpTree(root, window: win, maxDepth: 9))

        // 面板内的可点击控件：中心点 hitTest 看实际命中者
        let controls = Self.controls(in: root)
        if !controls.isEmpty {
            lines.append("  ---- 可点击控件 (\(controls.count)) ----")
            for (i, c) in controls.enumerated() {
                if i >= 12 { break }
                let f = c.convert(c.bounds, to: win)
                let center = CGPoint(x: f.midX, y: f.midY)
                let inside = win.bounds.contains(center)
                let hit = win.hitTest(center, with: nil)
                var hitDesc = "nil"
                if let h = hit {
                    hitDesc = NSStringFromClass(type(of: h))
                    if !h.isDescendant(of: root) { hitDesc += " (弹窗外!)" }
                    if !h.isUserInteractionEnabled { hitDesc += " (noTouch)" }
                }
                lines.append("    [\(i)] \(NSStringFromClass(type(of: c))) \(Self.fmt(f))"
                             + " 可点=\(c.isUserInteractionEnabled) 在屏内=\(inside) 命中=\(hitDesc)")
            }
        } else {
            lines.append("  ---- 面板内没有任何 UIControl ----")
        }

        print(lines.joined(separator: "\n"))

        // 等布局稳定后再判断/修复，避免弹窗入场动画期间误判
        if phase == "0.8s" {
            repairIfNeeded(panel: vc, root: root, window: win, phase: phase)
        }
    }

    // MARK: - 修复

    /// 关键：弹窗的 superview 是 FlutterView，层级顺序也正确（index 最大），
    /// 但 hitTest 命中的却是 Flutter platform view 里的 MTKView（播放器渲染层），
    /// 说明 FlutterView 在 hitTest 阶段把触点交给了平台视图，绕过了后加入的原生弹窗。
    /// 解法：把弹窗 VC 整体迁到一个透明的高层 UIWindow，让 hitTest 从新 window 开始，
    ///       不再经过 FlutterView。注意必须同时改 VC 的父子关系，否则会抛
    ///       UIViewControllerHierarchyInconsistency。
    private func repairIfNeeded(panel vc: UIViewController, root: UIView, window win: UIWindow, phase: String) {
        let id = ObjectIdentifier(root)
        guard repairedPanelId != id else { return }

        // 采样点：优先取一个「集数格子」的中心，其次取面板中心
        var probe = CGPoint(x: win.bounds.midX, y: win.bounds.midY)
        if let cell = Self.firstChooseCell(in: root), cell.window != nil {
            probe = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: win)
        } else if let sheet = Self.findBottomSheet(in: root) {
            probe = sheet.convert(CGPoint(x: sheet.bounds.midX, y: sheet.bounds.midY), to: win)
        }

        let before = win.hitTest(probe, with: nil)
        let beforeInPanel = before != nil && (before === root || before!.isDescendant(of: root))
        let selfHit = root.hitTest(root.convert(probe, from: win), with: nil)
        print("[EpisodePanel][修复] 采样点=\(Self.fmt(CGRect(origin: probe, size: .zero)))"
              + " window命中=\(before.map { NSStringFromClass(type(of: $0)) } ?? "nil")"
              + " 在弹窗内=\(beforeInPanel)"
              + " 弹窗自身hitTest=\(selfHit.map { NSStringFromClass(type(of: $0)) } ?? "nil")"
              + " 弹窗自身=\(selfHit != nil)")

        guard !beforeInPanel else {
            print("[EpisodePanel][修复] 命中正常，无需处理")
            return
        }

        repairedPanelId = id
        moveToOverlayWindow(panel: vc, root: root, base: win, probe: probe)
    }

    /// 把弹窗迁到透明浮层 window
    private func moveToOverlayWindow(panel vc: UIViewController, root: UIView, base win: UIWindow, probe: CGPoint) {
        guard let scene = win.windowScene else {
            print("[EpisodePanel][修复] 没有 windowScene，放弃")
            return
        }

        let overlay = UIWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        overlay.frame = win.bounds
        overlay.backgroundColor = .clear

        let host = UIViewController()
        host.view.backgroundColor = .clear
        overlay.rootViewController = host
        overlay.isHidden = false

        let oldParent = vc.parent.map { NSStringFromClass(type(of: $0)) } ?? "nil"

        // 先在原 parent 上解除关系，再接到新 host
        vc.willMove(toParent: nil)
        vc.removeFromParent()
        root.removeFromSuperview()

        host.addChild(vc)
        root.frame = host.view.bounds
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(root)
        vc.didMove(toParent: host)

        panelWindow = overlay
        panelHost = host

        // 触摸现在落在浮层 window 上，探针要跟过去
        installTapLogger(window: overlay)

        let after = overlay.hitTest(probe, with: nil)
        let afterInPanel = after != nil && (after === root || after!.isDescendant(of: root))
        print("[EpisodePanel][修复] 弹窗已从 \(oldParent) 迁到浮层 window"
              + " 命中=\(after.map { NSStringFromClass(type(of: $0)) } ?? "nil")"
              + " 在弹窗内=\(afterInPanel)")
    }

    /// 弹窗关闭后回收浮层 window，避免它挡住 Flutter 的触摸
    private func recycleOverlayIfNeeded() {
        guard let overlay = panelWindow else { return }
        let panelView = panelHost?.children.first?.view
        let stillVisible = panelView != nil && panelView?.superview != nil && panelView?.window != nil
        if !stillVisible {
            overlay.isHidden = true
            overlay.rootViewController = nil
            panelWindow = nil
            panelHost = nil
            // 下次打开时 VC 可能被复用、view 会重新挂回 FlutterView，必须重新判断与迁移
            repairedPanelId = nil
            print("[EpisodePanel][修复] 浮层 window 已回收")
        }
    }

    /// 找选集弹窗里的集数格子
    private static func firstChooseCell(in root: UIView) -> UIView? {
        var found: UIView?
        func walk(_ v: UIView, depth: Int) {
            if found != nil || depth > 9 { return }
            let cls: String = NSStringFromClass(type(of: v))
            if cls.contains("ChooseViewCell") || cls.contains("EpisodeCell") {
                found = v
                return
            }
            for sub in v.subviews {
                walk(sub, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return found
    }

    /// 找底部面板容器（不带 clips 的大块子视图）
    private static func findBottomSheet(in root: UIView) -> UIView? {
        var best: UIView?
        var bestArea: CGFloat = 0
        for sub in root.subviews {
            let f = sub.frame
            let area = f.width * f.height
            if f.height > root.bounds.height * 0.3, area > bestArea {
                best = sub
                bestArea = area
            }
        }
        return best
    }

    // MARK: - 触摸记录（只观测，不消费）

    private func installTapLogger(window: UIWindow) {
        if let existing = tapLogger, existing.view === window { return }
        removeTapLogger()
        let g = EpisodeTapLogger()
        g.cancelsTouchesInView = false
        g.delaysTouchesBegan = false
        g.delaysTouchesEnded = false
        window.addGestureRecognizer(g)
        tapLogger = g
        observedWindow = window
        print("[EpisodePanel] tap logger installed on window")
    }

    private func removeTapLogger() {
        if let g = tapLogger {
            g.view?.removeGestureRecognizer(g)
        }
        tapLogger = nil
        observedWindow = nil
    }

    /// 从某个点向上打印 hitTest 命中链
    static func hitChain(at p: CGPoint, in container: UIView) -> String {
        var parts: [String] = []
        var cursor: UIView? = container.hitTest(p, with: nil)
        var depth = 0
        while let v = cursor, depth < 8 {
            let f = v.convert(v.bounds, to: container)
            var extra = ""
            if !v.isUserInteractionEnabled { extra += " noTouch" }
            if v.isHidden { extra += " hidden" }
            if let c = v as? UIControl, !c.isEnabled { extra += " disabled" }
            parts.append("\(NSStringFromClass(type(of: v)))\(Self.fmt(f))\(extra)")
            cursor = v.superview
            depth += 1
        }
        return parts.isEmpty ? "nil" : parts.joined(separator: " <- ")
    }

    // MARK: - 工具

    static func fmt(_ r: CGRect) -> String {
        return String(format: "(%.0f,%.0f,%.0fx%.0f)", r.origin.x, r.origin.y, r.width, r.height)
    }

    private static func dumpTree(_ root: UIView, window: UIWindow, maxDepth: Int) -> [String] {
        var out: [String] = []

        func walk(_ v: UIView, depth: Int) {
            let f = v.convert(v.bounds, to: window)
            let cls: String = NSStringFromClass(type(of: v))
            let interesting = depth <= 4
                || cls.contains("DJX") || cls.contains("Episode") || cls.contains("Choose")
                || cls.contains("Button") || cls.contains("Cell") || cls.contains("Collection")
                || cls.contains("Table") || cls.contains("Scroll") || cls.contains("Label")
            if interesting, f.width > 0, f.height > 0 {
                var flags: [String] = []
                if !v.isUserInteractionEnabled { flags.append("noTouch") }
                if v.isHidden { flags.append("hidden") }
                if v.alpha < 0.99 { flags.append("alpha=\(String(format: "%.2f", v.alpha))") }
                if v.clipsToBounds { flags.append("clips") }
                if let c = v as? UIControl, !c.isEnabled { flags.append("disabled") }
                let pad = String(repeating: "  ", count: depth)
                out.append("    \(pad)\(cls) \(fmt(f))"
                           + (flags.isEmpty ? "" : " {\(flags.joined(separator: ","))}"))
            }
            if depth >= maxDepth { return }
            for sub in v.subviews {
                walk(sub, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
        return out
    }

    private static func controls(in root: UIView) -> [UIView] {
        var result: [UIView] = []
        func walk(_ v: UIView, depth: Int) {
            if v is UIControl || v.gestureRecognizers?.isEmpty == false {
                result.append(v)
            }
            if depth >= 9 { return }
            for sub in v.subviews {
                walk(sub, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return result
    }

    private static func keyWindow() -> UIWindow? {
        let all: [UIWindow] = allWindows()
        for w in all where w.isKeyWindow {
            return w
        }
        return all.first
    }

    private static func allWindows() -> [UIWindow] {
        var result: [UIWindow] = []
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene {
                result.append(contentsOf: ws.windows)
            }
        }
        return result
    }

    private static func vcTree(from root: UIViewController?) -> [UIViewController] {
        guard let root = root else { return [] }
        var result: [UIViewController] = [root]
        for child in root.children {
            result.append(contentsOf: vcTree(from: child))
        }
        if let presented = root.presentedViewController {
            result.append(contentsOf: vcTree(from: presented))
        }
        return result
    }
}

/// 只记录、不消费触摸的手势识别器
final class EpisodeTapLogger: UIGestureRecognizer {

    private var downPoint: CGPoint = .zero
    private var downTime: TimeInterval = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touches.first, let win = view else { return }
        downPoint = t.location(in: win)
        downTime = t.timestamp
        let hit = DramaEpisodePanelFixer.hitChain(at: downPoint, in: win)
        print("[EpisodePanel][TAP] DOWN \(DramaEpisodePanelFixer.fmt(CGRect(origin: downPoint, size: .zero)))"
              + " 命中链=\(hit)")
        state = .possible
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touches.first, let win = view else {
            state = .failed
            return
        }
        let p = t.location(in: win)
        let moved = hypot(p.x - downPoint.x, p.y - downPoint.y)
        let ms = (t.timestamp - downTime) * 1000
        let hit = DramaEpisodePanelFixer.hitChain(at: p, in: win)
        print("[EpisodePanel][TAP] UP \(DramaEpisodePanelFixer.fmt(CGRect(origin: p, size: .zero)))"
              + " 位移=\(String(format: "%.1f", moved))pt 耗时=\(String(format: "%.0f", ms))ms"
              + " 命中链=\(hit)")
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        print("[EpisodePanel][TAP] CANCEL 事件被系统或上层取消")
        state = .failed
    }

    override func reset() {
        super.reset()
        state = .possible
    }
}
