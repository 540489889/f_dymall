import Flutter
import UIKit
import PangrowthDJX
import PangrowthMiniStory

public class PangrowthContentPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "pangrowth_content"
    private static let eventChannelName = "pangrowth_content_event"

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var contentManager: ContentManager?
    private var dramaPlayerManager: DramaPlayerManager?
    private var storyManager: StoryManager?
    private var videoManager: VideoManager?
    private var dramaHomeViewFactory: DramaHomePlatformViewFactory?
    private var dramaPlayerViewFactory: DramaPlayerPlatformViewFactory?
    private var dramaSwipeFlowViewFactory: DramaSwipeFlowPlatformViewFactory?
    private var dramaCardViewFactory: DramaCardPlatformViewFactory?
    private var videoPlatformViewFactory: VideoPlatformViewFactory?
    private var storyHomePlatformViewFactory: StoryHomePlatformViewFactory?
    private var gridVideoPlatformViewFactory: GridVideoPlatformViewFactory?
    private var userProfilePlatformViewFactory: UserProfilePlatformViewFactory?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PangrowthContentPlugin()

        // 方法通道
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        instance.methodChannel = methodChannel

        // 事件通道
        let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
        instance.eventChannel = eventChannel

        // 内容管理器
        instance.contentManager = ContentManager(registrar: registrar)
        eventChannel.setStreamHandler(instance.contentManager)

        // 播放页管理器
        instance.dramaPlayerManager = DramaPlayerManager()

        // 短故事管理器
        if let contentManager = instance.contentManager {
            instance.storyManager = StoryManager(contentManager: contentManager)
        }

        // 小视频管理器
        instance.videoManager = VideoManager()

        if let contentManager = instance.contentManager {
            let dramaFactory = DramaHomePlatformViewFactory(contentManager: contentManager)
            registrar.register(dramaFactory, withId: "pangrowth_content/drama_home_view")
            instance.dramaHomeViewFactory = dramaFactory

            let playerFactory = DramaPlayerPlatformViewFactory(
                contentManager: contentManager
            )
            registrar.register(playerFactory, withId: "pangrowth_content/drama_player_view")
            instance.dramaPlayerViewFactory = playerFactory

            // 注册短剧滑滑流 PlatformView
            let swipeFlowFactory = DramaSwipeFlowPlatformViewFactory(messenger: registrar.messenger())
            registrar.register(swipeFlowFactory, withId: "pangrowth_content/drama_swipe_flow_view")
            instance.dramaSwipeFlowViewFactory = swipeFlowFactory

            // 注册短剧卡片 PlatformView
            let cardFactory = DramaCardPlatformViewFactory(messenger: registrar.messenger())
            registrar.register(cardFactory, withId: "pangrowth_content/drama_card_view")
            instance.dramaCardViewFactory = cardFactory

            // 注册小视频 PlatformView
            let videoFactory = VideoPlatformViewFactory(messenger: registrar.messenger())
            registrar.register(videoFactory, withId: "pangrowth_content/video_view")
            instance.videoPlatformViewFactory = videoFactory

            // 注册短故事聚合页 PlatformView
            let storyHomeFactory = StoryHomePlatformViewFactory(messenger: registrar.messenger())
            registrar.register(storyHomeFactory, withId: "pangrowth_content/story_home_view")
            instance.storyHomePlatformViewFactory = storyHomeFactory

            // 注册宫格小视频 PlatformView
            let gridVideoFactory = GridVideoPlatformViewFactory(messenger: registrar.messenger())
            registrar.register(gridVideoFactory, withId: "pangrowth_content/grid_video_view")
            instance.gridVideoPlatformViewFactory = gridVideoFactory

            // 注册个人主页 PlatformView
            let userProfileFactory = UserProfilePlatformViewFactory(messenger: registrar.messenger())
            registrar.register(userProfileFactory, withId: "pangrowth_content/user_profile_view")
            instance.userProfilePlatformViewFactory = userProfileFactory
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let contentManager = self.contentManager else {
            result(FlutterError(code: "NO_MANAGER", message: "ContentManager is not available", details: nil))
            return
        }

        // 为播放页管理器设置事件sink
        if let eventSink = contentManager.eventSink {
            dramaPlayerManager?.setEventSink(eventSink)
            videoManager?.setEventSink(eventSink)
        }

        switch call.method {
        case "initialize":
            contentManager.initialize(call: call, result: result)
        case "start":
            contentManager.start(call: call, result: result)
        case "getDramaList":
            contentManager.getDramaList(call: call, result: result)
        case "getRecommendedDramaList":
            contentManager.getRecommendedDramaList(call: call, result: result)
        case "getDramaListByIds":
            contentManager.getDramaListByIds(call: call, result: result)
        case "getDramaListByCategory":
            contentManager.getDramaListByCategory(call: call, result: result)
        case "getCategoryList":
            contentManager.getCategoryList(call: call, result: result)
        case "searchDrama":
            contentManager.searchDrama(call: call, result: result)
        case "createDramaHome":
            contentManager.createDramaHome(call: call, result: result)
        case "showDramaHome":
            contentManager.showDramaHome(call: call, result: result)
        case "destroyDramaHome":
            if let args = call.arguments as? [String: Any], let widgetId = args["widgetId"] as? String {
                DramaHomePlatformView.find(viewId: widgetId)?.destroyOnCommand()
            }
            result(nil)
        case "getDramaHistory":
            contentManager.getDramaHistory(call: call, result: result)
        case "clearDramaHistory":
            contentManager.clearDramaHistory(result: result)
        case "favorDrama":
            contentManager.favorDrama(call: call, result: result)
        case "likeEpisode":
            contentManager.likeEpisode(call: call, result: result)
        case "getDramaFavorList":
            contentManager.getDramaFavorList(call: call, result: result)
        case "getDramaEpisodesStatus":
            contentManager.getDramaEpisodesStatus(call: call, result: result)
        case "verifyDramaParams":
            contentManager.verifyDramaParams(call: call, result: result)
        case "setPersonalization":
            contentManager.setPersonalization(call: call, result: result)
        case "getPersonalization":
            contentManager.getPersonalization(call: call, result: result)
        case "createDramaSwipeFlow":
            contentManager.createDramaSwipeFlow(call: call, result: result)
        case "showDramaSwipeFlow":
            contentManager.showDramaSwipeFlow(call: call, result: result)
        case "hideDramaSwipeFlow":
            contentManager.hideDramaSwipeFlow(call: call, result: result)
        case "destroyDramaSwipeFlow":
            contentManager.destroyDramaSwipeFlow(call: call, result: result)
        case "createDramaCard":
            contentManager.createDramaCard(call: call, result: result)
        case "showDramaCard":
            contentManager.showDramaCard(call: call, result: result)
        case "playDramaCard":
            contentManager.playDramaCard(call: call, result: result)
        case "pauseDramaCard":
            contentManager.pauseDramaCard(call: call, result: result)
        case "stopDramaCard":
            contentManager.stopDramaCard(call: call, result: result)
        case "setDramaCardMute":
            contentManager.setDramaCardMute(call: call, result: result)
        case "reportDramaCardShow":
            contentManager.reportDramaCardShow(call: call, result: result)
        case "refreshDramaCard":
            contentManager.refreshDramaCard(call: call, result: result)
        case "destroyDramaCard":
            contentManager.destroyDramaCard(call: call, result: result)
        case "isDramaCardPlaying":
            contentManager.isDramaCardPlaying(call: call, result: result)
        case "getDramaCardInfo":
            contentManager.getDramaCardInfo(call: call, result: result)
        case "getDramaCardGid":
            contentManager.getDramaCardGid(call: call, result: result)
        case "getDramaCardTitle":
            contentManager.getDramaCardTitle(call: call, result: result)
        // 短剧播放页相关方法
        case "createDramaPlayer":
            dramaPlayerManager?.createDramaPlayer(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "showDramaPlayer":
            dramaPlayerManager?.showDramaPlayer(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "seekTo":
            // 优先PlatformView模式,降级Activity模式
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               let duration = args["duration"] as? Int,
               platformView.handleSeekTo(duration: duration) {
                result(["success": true, "playerId": playerId, "duration": duration])
            } else {
                dramaPlayerManager?.seekTo(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "setSpeedPlay":
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               let payload = platformView.handleSetPlaySpeed(args: args) {
                result(payload)
            } else {
                dramaPlayerManager?.setSpeedPlay(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "setCurrentEpisode":
            // 优先PlatformView模式,降级Activity模式
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               let episode = args["episode"] as? Int,
               platformView.handleSetCurrentEpisode(episode: episode) {
                result(["success": true, "playerId": playerId, "episode": episode])
            } else {
                dramaPlayerManager?.setCurrentEpisode(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "getCurrentEpisode":
            dramaPlayerManager?.getCurrentEpisode(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "openMoreDialog":
            // 优先PlatformView模式,降级Activity模式
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               platformView.handleOpenMoreDialog() {
                result(["success": true, "playerId": playerId])
            } else {
                dramaPlayerManager?.openMoreDialog(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "openEpisodePanel":
            // 优先PlatformView模式,降级Activity模式
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               platformView.handleOpenEpisodePanel() {
                result(["success": true, "playerId": playerId])
            } else {
                dramaPlayerManager?.openEpisodePanel(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "refreshPlayer":
            // 优先PlatformView模式,降级Activity模式
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               platformView.handleRefreshPlayer() {
                result(["success": true, "playerId": playerId])
            } else {
                dramaPlayerManager?.refreshPlayer(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "enterPlayPage":
            dramaPlayerManager?.enterPlayPage(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "destroyDramaPlayer":
            dramaPlayerManager?.destroyDramaPlayer(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "setCustomAdOnShow":
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               platformView.handleCustomAdOnShow(cpm: args["cpm"] as? String) {
                result(true)
            } else {
                dramaPlayerManager?.setCustomAdOnShow(call: call, result: result) ?? result(true)
            }
        case "setCustomAdOnReward":
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId),
               platformView.handleCustomAdOnReward(
                   verify: args["verify"] as? Bool ?? false,
                   extra: args["extraData"] as? [String: Any]
               ) {
                result(true)
            } else {
                dramaPlayerManager?.setCustomAdOnReward(call: call, result: result) ?? result(true)
            }
        case "confirmUnlock":
            dramaPlayerManager?.confirmUnlock(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "cancelUnlock":
            dramaPlayerManager?.cancelUnlock(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
        case "unLockDrama":
            // 优先尝试PlatformView模式（嵌入式播放器）
            if let args = call.arguments as? [String: Any],
               let playerId = args["playerId"] as? String,
               let platformView = DramaPlayerPlatformView.find(viewId: playerId) {
                let episodeId = args["episodeId"] as? Int
                let unlockCount = args["lockSet"] as? Int
                let cancel = args["cancel"] as? Bool ?? false

                if platformView.unlockDrama(episodeId: episodeId, unlockCount: unlockCount, cancel: cancel) {
                    result(true)
                } else {
                    result(FlutterError(code: "NO_UNLOCK_CALLBACK", message: "未找到可用的解锁回调", details: nil))
                }
            } else {
                // 降级到Activity模式（全屏播放器）
                dramaPlayerManager?.unlockDrama(call: call, result: result) ?? result(FlutterError(code: "NO_PLAYER_MANAGER", message: "DramaPlayerManager is not available", details: nil))
            }
        case "generateDramaUnlockSign":
            contentManager.generateDramaUnlockSign(call: call, result: result)
        case "loginDramaUnlock":
            contentManager.loginDramaUnlock(call: call, result: result)
        case "logoutDramaUnlock":
            contentManager.logoutDramaUnlock(result: result)
        case "isDramaUnlockLogin":
            contentManager.isDramaUnlockLogin(result: result)
        // 短故事相关方法
        case "createStoryHome":
            storyManager?.createStoryHome(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "showStoryHome":
            storyManager?.showStoryHome(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "destroyStoryHome":
            storyManager?.destroyStoryHome(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "getStoryCategoryList":
            storyManager?.getStoryCategoryList(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "getStoryList":
            storyManager?.getStoryList(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "searchStory":
            storyManager?.searchStory(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "getStoryHistory":
            storyManager?.getStoryHistory(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "favoriteStory":
            storyManager?.favoriteStory(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "getFavoriteStories":
            storyManager?.getFavoriteStories(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "markAsRead":
            storyManager?.markAsRead(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "likeStory":
            storyManager?.likeStory(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        case "updateReadProgress":
            storyManager?.updateReadProgress(call: call, result: result) ?? result(FlutterError(code: "NO_STORY_MANAGER", message: "StoryManager is not available", details: nil))
        // 小视频相关方法
        case "createVideo":
            videoManager?.createVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "showVideo":
            videoManager?.showVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "refreshVideo":
            videoManager?.refreshVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "refreshVideoToStayUser":
            videoManager?.refreshVideoToStayUser(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "showToastToStayUser":
            videoManager?.showToastToStayUser(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        // 小视频高级功能方法
        case "setSyncData":
            videoManager?.setSyncData(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "scrollToTop", "backRefresh", "setAwakeData", "seekToPosition", "setCurrentPage", "pauseForWatchTogether", "resumeForWatchTogether":
            result(FlutterError(code: "UNSUPPORTED", message: "当前功能暂不支持 iOS", details: nil))
        case "getCurrentIndex":
            videoManager?.getCurrentIndex(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "scrollToIndex":
            videoManager?.scrollToIndex(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "pauseCurrentVideo":
            videoManager?.pauseCurrentVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "playCurrentVideo":
            videoManager?.playCurrentVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "seekVideoToMSeconds":
            videoManager?.seekVideoToMSeconds(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createReportContent":
            videoManager?.createReportContent(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "pauseVideo":
            handlePauseVideo(call: call, result: result)
        case "resumeVideo":
            handleResumeVideo(call: call, result: result)
        case "pauseDramaSwipeFlow":
            handlePauseDramaSwipeFlow(call: call, result: result)
        case "resumeDramaSwipeFlow":
            handleResumeDramaSwipeFlow(call: call, result: result)
        case "destroyVideo":
            videoManager?.destroyVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createGridVideo":
            videoManager?.createGridVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "showGridVideo":
            videoManager?.showGridVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "destroyGridVideo":
            videoManager?.destroyGridVideo(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createVideoCardForNews":
            videoManager?.createVideoCardForNews(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createVideoCardForRecommend":
            videoManager?.createVideoCardForRecommend(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createVideoCardForSearch":
            videoManager?.createVideoCardForSearch(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "destroyVideoCard":
            videoManager?.destroyVideoCard(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "createVideoSingleCardForNews":
            videoManager?.createVideoSingleCardForNews(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        case "destroyVideoSingleCard":
            videoManager?.destroyVideoSingleCard(call: call, result: result) ?? result(FlutterError(code: "NO_VIDEO_MANAGER", message: "VideoManager is not available", details: nil))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - PlatformView Control Methods

    private func handlePauseVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoId = args["videoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "videoId is required", details: nil))
            return
        }

        if let videoView = VideoPlatformView.find(viewId: videoId) {
            videoView.pause()
            result(true)
        } else {
            result(FlutterError(
                code: "NOT_FOUND",
                message: "Video view not found: \(videoId)",
                details: nil
            ))
        }
    }

    private func handleResumeVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoId = args["videoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "videoId is required", details: nil))
            return
        }

        if let videoView = VideoPlatformView.find(viewId: videoId) {
            videoView.resume()
            result(true)
        } else {
            result(FlutterError(
                code: "NOT_FOUND",
                message: "Video view not found: \(videoId)",
                details: nil
            ))
        }
    }

    private func handlePauseDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let swipeFlowId = args["swipeFlowId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "swipeFlowId cannot be null or empty", details: nil))
            return
        }

        guard let view = DramaSwipeFlowPlatformView.find(viewId: swipeFlowId) else {
            result(FlutterError(code: "SWIPE_FLOW_NOT_FOUND", message: "DramaSwipeFlow with ID \(swipeFlowId) not found", details: nil))
            return
        }

        view.pause()
        result(true)
    }

    private func handleResumeDramaSwipeFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let swipeFlowId = args["swipeFlowId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "swipeFlowId cannot be null or empty", details: nil))
            return
        }

        guard let view = DramaSwipeFlowPlatformView.find(viewId: swipeFlowId) else {
            result(FlutterError(code: "SWIPE_FLOW_NOT_FOUND", message: "DramaSwipeFlow with ID \(swipeFlowId) not found", details: nil))
            return
        }

        view.resume()
        result(true)
    }
}

// MARK: - Platform View Integrations
// Platform View implementations are in ios/Classes/Views/
