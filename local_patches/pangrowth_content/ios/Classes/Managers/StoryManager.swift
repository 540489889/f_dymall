//
//  StoryManager.swift
//  pangrowth_content
//

import Foundation
import Flutter
import UIKit
import PangrowthMiniStory

final class StoryManager {

    private struct StoryWidget {
        let widgetId: String
        let controller: MNSMainViewController
    }

    private weak var contentManager: ContentManager?
    private var widgets: [String: StoryWidget] = [:]

    init(contentManager: ContentManager) {
        self.contentManager = contentManager
    }

    func createStoryHome(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        let args = call.arguments as? [String: Any]
        let config = args?["config"] as? [String: Any]
        let readerConfigMap = config?["readerConfig"] as? [String: Any]

        let params = MNStoryReaderOpenParams()
        applyReaderConfig(params: params, map: readerConfigMap)

        let controller = MNSMainViewController(readConfig: params)
        controller.modalPresentationStyle = .fullScreen

        let widgetId = args?["viewId"] as? String ?? "story_home_\(Int(Date().timeIntervalSince1970 * 1000))"
        widgets[widgetId] = StoryWidget(widgetId: widgetId, controller: controller)

        result([
            "widgetId": widgetId,
            "widgetType": "story_home",
            "success": true,
        ])
    }

    func showStoryHome(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String,
              let widget = widgets[widgetId] else {
            result(FlutterError(code: "WIDGET_NOT_FOUND", message: "未找到指定的短故事聚合页", details: nil))
            return
        }

        DispatchQueue.main.async {
            guard let presenter = UIApplication.shared.topMostViewController() else {
                result(FlutterError(code: "NO_ROOT_CONTROLLER", message: "无法获取根控制器", details: nil))
                return
            }

            if presenter.presentedViewController === widget.controller {
                result(["widgetId": widgetId, "shown": true])
                return
            }

            presenter.present(widget.controller, animated: true) {
                result(["widgetId": widgetId, "shown": true])
            }
        }
    }

    func destroyStoryHome(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let widgetId = args["widgetId"] as? String else {
            result(false)
            return
        }

        guard let widget = widgets.removeValue(forKey: widgetId) else {
            result(false)
            return
        }

        DispatchQueue.main.async {
            widget.controller.dismiss(animated: true) {
                result(true)
            }
        }
    }

    func getStoryCategoryList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        MNStoryManager.shareInstance().requestCategoryList { success, categories in
            if success {
                let items = categories.map { self.categoryToMap($0) }
                result(items)
            } else {
                result(FlutterError(code: "GET_STORY_CATEGORY_ERROR", message: "获取短故事分类失败", details: nil))
            }
        }
    }

    func getStoryList(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        let args = call.arguments as? [String: Any] ?? [:]
        let page = args["page"] as? Int ?? 1
        let count = args["count"] as? Int ?? 20
        let orderAsc = args["order"] as? Bool ?? true
        let orderType = orderAsc ? 0 : 1

        if let categoryId = args["categoryId"] as? Int, categoryId > 0 {
            MNStoryManager.shareInstance().requestCategoryStoryList(
                withCategoryId: categoryId,
                page: page,
                num: count,
                order: orderType
            ) { success, stories in
                if success {
                    result(stories.map { self.storyToMap($0) })
                } else {
                    result(FlutterError(code: "GET_STORY_LIST_ERROR", message: "获取短故事列表失败", details: nil))
                }
            }
        } else {
            MNStoryManager.shareInstance().requestAllStoryListPage(
                page,
                num: count,
                order: orderType
            ) { success, stories, _, _ in
                if success {
                    result(stories.map { self.storyToMap($0) })
                } else {
                    result(FlutterError(code: "GET_STORY_LIST_ERROR", message: "获取短故事列表失败", details: nil))
                }
            }
        }
    }

    func searchStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        guard let args = call.arguments as? [String: Any],
              let keyword = args["keyword"] as? String, !keyword.isEmpty else {
            result(FlutterError(code: "INVALID_PARAMETER", message: "搜索关键词不能为空", details: nil))
            return
        }

        let isFuzzy = args["isFuzzy"] as? Bool ?? true
        let page = args["page"] as? Int ?? 1
        let count = args["count"] as? Int ?? 20

        MNStoryManager.shareInstance().requestStoryList(
            withSearchWord: keyword,
            isFuzzy: isFuzzy,
            page: page,
            num: count
        ) { success, stories, _ in
            if success {
                result(stories.map { self.storyToMap($0) })
            } else {
                result(FlutterError(code: "SEARCH_STORY_ERROR", message: "搜索短故事失败", details: nil))
            }
        }
    }

    func getStoryHistory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        let args = call.arguments as? [String: Any] ?? [:]
        let page = args["page"] as? Int ?? 1
        let count = args["count"] as? Int ?? 20

        MNStoryManager.shareInstance().requestHistoryStoryList(page, num: count) { success, stories in
            if success {
                result(stories.map { self.storyToMap($0) })
            } else {
                result(FlutterError(code: "GET_STORY_HISTORY_ERROR", message: "获取历史记录失败", details: nil))
            }
        }
    }

    func favoriteStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        guard let args = call.arguments as? [String: Any],
              let storyId = args["storyId"] as? String,
              let id = Int(storyId) else {
            result(FlutterError(code: "INVALID_PARAMETER", message: "storyId不能为空", details: nil))
            return
        }

        let isFavorite = args["isFavorite"] as? Bool ?? true

        if isFavorite {
            MNStoryManager.shareInstance().requestCollectStory(id) { error in
                if let error = error {
                    result(FlutterError(code: "FAVORITE_STORY_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(true)
                }
            }
        } else {
            MNStoryManager.shareInstance().requestCancelCollectStory(id) { error in
                if let error = error {
                    result(FlutterError(code: "FAVORITE_STORY_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(true)
                }
            }
        }
    }

    func getFavoriteStories(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isStoryModuleReady(result: result) else { return }

        let args = call.arguments as? [String: Any] ?? [:]
        let page = args["page"] as? Int ?? 1
        let count = args["count"] as? Int ?? 20

        MNStoryManager.shareInstance().requestStoryCollectionList(page, num: count) { success, stories, _, _ in
            if success {
                result(stories.map { self.storyToMap($0) })
            } else {
                result(FlutterError(code: "GET_FAVORITE_STORY_ERROR", message: "获取收藏列表失败", details: nil))
            }
        }
    }

    func markAsRead(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(code: "UNSUPPORTED_OPERATION", message: "穿山甲短故事SDK暂未提供显式的已读标记接口", details: nil))
    }

    func likeStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(code: "UNSUPPORTED_OPERATION", message: "穿山甲短故事SDK暂未开放短故事点赞接口", details: nil))
    }

    func updateReadProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(code: "UNSUPPORTED_OPERATION", message: "穿山甲短故事SDK暂未提供阅读进度上报接口", details: nil))
    }

    private func isStoryModuleReady(result: @escaping FlutterResult) -> Bool {
        guard contentManager?.isStoryModuleReady() ?? false else {
            result(FlutterError(code: "SDK_NOT_READY", message: "短故事模块未启动，请先调用 PangrowthContent.start", details: nil))
            return false
        }
        return true
    }

    private func applyReaderConfig(params: MNStoryReaderOpenParams, map: [String: Any]?) {
        guard let map = map else { return }

        // 使用 map.keys.contains 检查参数是否存在,只在参数存在时才设置
        // 这样可以让SDK使用原生默认值
        if map.keys.contains("customRewardAD"), let custom = map["customRewardAD"] as? Bool {
            params.customRewardAD = custom
        }
        if map.keys.contains("addCustomRewardPoint"), let addPoint = map["addCustomRewardPoint"] as? Bool {
            params.addCustomRewardPoint = addPoint
        }
        if map.keys.contains("showCustomBottomBannerAD"), let showBanner = map["showCustomBottomBannerAD"] as? Bool {
            params.showCustomBottomBannerAD = showBanner
        }
        if map.keys.contains("showCustomMiddleAD"), let showMiddle = map["showCustomMiddleAD"] as? Bool {
            params.showCustomMiddleAD = showMiddle
        }
        if map.keys.contains("pageIntervalForMiddleAD"), let middleInterval = map["pageIntervalForMiddleAD"] as? Int {
            params.pageIntervalForMiddleAD = middleInterval
        }
    }

    private func storyToMap(_ story: MNStoryInfoModel) -> [String: Any] {
        let bookId = intValue(from: story, keys: ["book_id", "bookId"])
        let statsCount = intValue(from: story, keys: ["stats_count", "statsCount"])
        let favoriteState = intValue(from: story, keys: ["favorite_state", "favoriteState"])
        let favoriteTime = intValue(from: story, keys: ["favorite_time", "favoriteTime"])
        let createTime = intValue(from: story, keys: ["create_time", "createTime"])
        let index = intValue(from: story, keys: ["index", "currentIndex"])
        let total = intValue(from: story, keys: ["total"])
        let categoryId = intValue(from: story, keys: ["category_id", "categoryId"])
        let imageType = intValue(from: story, keys: ["cover_type", "coverType", "imageType"])

        let progress = doubleValue(from: story, keys: ["progress"])

        let title = stringValue(from: story, keys: ["title"])
        let description = stringValue(from: story, keys: ["desc", "description"])
        let author = stringValue(from: story, keys: ["author"])
        let coverUrl = stringValue(from: story, keys: ["cover_image", "coverImage"])
        let categoryName = stringValue(from: story, keys: ["category_name", "categoryName"])
        let contentPreview = stringValue(from: story, keys: ["content_truncation", "contentPreview", "content"])

        var extras: [String: Any] = [:]
        var mirror: Mirror? = Mirror(reflecting: story)
        while let current = mirror {
            for child in current.children {
                if let label = child.label {
                    extras[label] = child.value
                }
            }
            mirror = current.superclassMirror
        }

        return [
            "storyId": String(bookId),
            "id": bookId,
            "title": title,
            "description": description,
            "author": author,
            "coverUrl": coverUrl,
            "imageType": imageType,
            "categoryId": categoryId,
            "categoryName": categoryName,
            "total": total,
            "createTime": createTime,
            "currentIndex": index,
            "progress": progress,
            "statsCount": statsCount,
            "isFavorited": favoriteState == 1,
            "favoriteState": favoriteState,
            "favoriteTime": favoriteTime,
            "contentPreview": contentPreview,
            "extras": extras,
        ]
    }

    private func categoryToMap(_ category: Any) -> [String: Any] {
        if let model = category as? MNStoryCategoryListItemModel {
            let rawChildren: [Any]
            if let array = model.children as? [Any] {
                rawChildren = array
            } else if let array = model.children as? NSArray {
                rawChildren = Array(array)
            } else {
                rawChildren = []
            }
            let children = rawChildren.map { self.categoryToMap($0) }
            return [
                "id": model.category_id,
                "name": model.name ?? "",
                "level": model.level,
                "children": children,
            ]
        }

        if let item = category as? MNStoryCategoryItemModel {
            return [
                "id": item.category_id,
                "name": item.name ?? "",
                "level": item.level,
                "children": [],
            ]
        }

        return [:]
    }

    private func intValue(from object: NSObject, keys: [String]) -> Int {
        for key in keys {
            if object.responds(to: Selector(key)) {
                if let number = object.value(forKey: key) as? NSNumber {
                    return number.intValue
                }
                if let string = object.value(forKey: key) as? String, let value = Int(string) {
                    return value
                }
            }
        }
        return 0
    }

    private func doubleValue(from object: NSObject, keys: [String]) -> Double {
        for key in keys {
            if object.responds(to: Selector(key)) {
                if let number = object.value(forKey: key) as? NSNumber {
                    return number.doubleValue
                }
                if let string = object.value(forKey: key) as? String, let value = Double(string) {
                    return value
                }
            }
        }
        return 0
    }

    private func stringValue(from object: NSObject, keys: [String]) -> String {
        for key in keys {
            if object.responds(to: Selector(key)) {
                if let value = object.value(forKey: key) as? String {
                    return value
                }
                if let number = object.value(forKey: key) as? NSNumber {
                    return number.stringValue
                }
            }
        }
        return ""
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.activeKeyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }

    var activeKeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return windows.first { $0.isKeyWindow }
        }
    }
}
