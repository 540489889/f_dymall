package com.zhecent.pangrowth_content

import android.app.Activity
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.zhecent.pangrowth_content.views.DramaHomePlatformView
import com.zhecent.pangrowth_content.views.DramaHomePlatformViewFactory
import com.zhecent.pangrowth_content.views.DramaPlayerPlatformViewFactory
import com.zhecent.pangrowth_content.views.DramaSwipeFlowPlatformView
import com.zhecent.pangrowth_content.views.DramaSwipeFlowPlatformViewFactory
import com.zhecent.pangrowth_content.views.DramaCardPlatformViewFactory
import com.zhecent.pangrowth_content.views.VideoPlatformViewFactory
import com.zhecent.pangrowth_content.views.StoryHomePlatformViewFactory
import com.zhecent.pangrowth_content.views.GridVideoPlatformViewFactory
import com.zhecent.pangrowth_content.views.UserProfilePlatformViewFactory

class PangrowthContentPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var flutterBinding: FlutterPlugin.FlutterPluginBinding

    private lateinit var eventHelper: ContentEventHelper
    private lateinit var logger: ContentLogger
    private lateinit var validationHelper: ContentValidationHelper
    private lateinit var sdkManager: ContentSdkManager
    private lateinit var dramaHomeFactory: DramaHomePlatformViewFactory
    private lateinit var dramaPlayerFactory: DramaPlayerPlatformViewFactory
    private lateinit var dramaSwipeFlowFactory: DramaSwipeFlowPlatformViewFactory
    private lateinit var dramaCardFactory: DramaCardPlatformViewFactory
    private lateinit var videoFactory: VideoPlatformViewFactory
    private lateinit var storyHomeFactory: StoryHomePlatformViewFactory
    private lateinit var gridVideoFactory: GridVideoPlatformViewFactory
    private lateinit var userProfileFactory: UserProfilePlatformViewFactory

    private var currentActivity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterBinding = binding
        methodChannel = MethodChannel(binding.binaryMessenger, "pangrowth_content")
        eventChannel = EventChannel(binding.binaryMessenger, "pangrowth_content_event")

        eventHelper = ContentEventHelper()
        logger = ContentLogger.getInstance()
        validationHelper = ContentValidationHelper.getInstance(binding.applicationContext)
        sdkManager = ContentSdkManager(
            applicationContext = binding.applicationContext,
            flutterAssets = binding.flutterAssets,
            eventHelper = eventHelper,
            logger = logger,
            validationHelper = validationHelper,
        )

        dramaHomeFactory = DramaHomePlatformViewFactory(
            sdkManager = sdkManager,
            eventHelper = eventHelper,
            logger = logger,
            validationHelper = validationHelper,
        )
        dramaPlayerFactory = DramaPlayerPlatformViewFactory(
            sdkManager = sdkManager,
            eventHelper = eventHelper,
            logger = logger,
            validationHelper = validationHelper,
        )
        dramaSwipeFlowFactory = DramaSwipeFlowPlatformViewFactory(
            eventHelper = eventHelper,
            logger = logger,
        )
        dramaCardFactory = DramaCardPlatformViewFactory(
            eventHelper = eventHelper,
            logger = logger,
        )
        videoFactory = VideoPlatformViewFactory(
            eventHelper = eventHelper,
            logger = logger,
        )
        storyHomeFactory = StoryHomePlatformViewFactory(
            messenger = binding.binaryMessenger,
        )
        gridVideoFactory = GridVideoPlatformViewFactory(
            sdkManager = sdkManager,
            eventHelper = eventHelper,
            logger = logger,
        )
        userProfileFactory = UserProfilePlatformViewFactory(
            sdkManager = sdkManager,
            eventHelper = eventHelper,
            logger = logger,
        )

        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/drama_home_view",
            dramaHomeFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/drama_player_view",
            dramaPlayerFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/drama_swipe_flow_view",
            dramaSwipeFlowFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/drama_card_view",
            dramaCardFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/video_view",
            videoFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/story_home_view",
            storyHomeFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/grid_video_view",
            gridVideoFactory,
        )
        binding.platformViewRegistry.registerViewFactory(
            "pangrowth_content/user_profile_view",
            userProfileFactory,
        )

        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        logger.debug("PangrowthContentPlugin attached", ContentConstants.TAG)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        sdkManager.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> sdkManager.initialize(call, result)
            "start" -> sdkManager.start(call, result)
            "getDramaList" -> sdkManager.getDramaList(call, result)
            "getRecommendedDramaList" -> sdkManager.getRecommendedDramaList(call, result)
            "getDramaListByIds" -> sdkManager.getDramaListByIds(call, result)
            "getDramaListByCategory" -> sdkManager.getDramaListByCategory(call, result)
            "getCategoryList" -> sdkManager.getCategoryList(result)
            "searchDrama" -> sdkManager.searchDrama(call, result)
            "getDramaHistory" -> sdkManager.getDramaHistory(call, result)
            "clearDramaHistory" -> sdkManager.clearDramaHistory(result)
            "favorDrama" -> sdkManager.favorDrama(call, result)
            "likeEpisode" -> sdkManager.likeEpisode(call, result)
            "getDramaFavorList" -> sdkManager.getDramaFavorList(call, result)
            "getDramaEpisodesStatus" -> sdkManager.getDramaEpisodesStatus(call, result)
            "verifyDramaParams" -> sdkManager.verifyDramaParams(call, result)
            "setPersonalization" -> sdkManager.setPersonalization(call, result)
            "getPersonalization" -> sdkManager.getPersonalization(result)
            "createDramaSwipeFlow" -> sdkManager.createDramaSwipeFlow(call, result)
            "showDramaSwipeFlow" -> sdkManager.showDramaSwipeFlow(call, result)
            "hideDramaSwipeFlow" -> sdkManager.hideDramaSwipeFlow(call, result)
            "destroyDramaSwipeFlow" -> sdkManager.destroyDramaSwipeFlow(call, result)
            "createDramaCard" -> sdkManager.createDramaCard(call, result)
            "showDramaCard" -> sdkManager.showDramaCard(call, result)
            "playDramaCard" -> sdkManager.playDramaCard(call, result)
            "pauseDramaCard" -> sdkManager.pauseDramaCard(call, result)
            "stopDramaCard" -> sdkManager.stopDramaCard(call, result)
            "setDramaCardMute" -> sdkManager.setDramaCardMute(call, result)
            "reportDramaCardShow" -> sdkManager.reportDramaCardShow(call, result)
            "refreshDramaCard" -> sdkManager.refreshDramaCard(call, result)
            "destroyDramaCard" -> sdkManager.destroyDramaCard(call, result)
            "isDramaCardPlaying" -> sdkManager.isDramaCardPlaying(call, result)
            "getDramaCardInfo" -> sdkManager.getDramaCardInfo(call, result)
            "getDramaCardGid" -> sdkManager.getDramaCardGid(call, result)
            "getDramaCardTitle" -> sdkManager.getDramaCardTitle(call, result)
            "createDramaPlayer" -> sdkManager.createDramaPlayer(call, result)
            "showDramaPlayer" -> sdkManager.showDramaPlayer(call, result)
            "seekTo" -> sdkManager.seekTo(call, result)
            "setSpeedPlay" -> sdkManager.setSpeedPlay(call, result)
            "setCurrentEpisode" -> sdkManager.setCurrentEpisode(call, result)
            "getCurrentEpisode" -> sdkManager.getCurrentEpisode(call, result)
            "openMoreDialog" -> sdkManager.openMoreDialog(call, result)
            "openEpisodePanel" -> sdkManager.openEpisodePanel(call, result)
            "refreshPlayer" -> sdkManager.refreshPlayer(call, result)
            "destroyDramaPlayer" -> sdkManager.destroyDramaPlayer(call, result)
            "setCustomAdOnShow" -> sdkManager.setCustomAdOnShow(call, result)
            "setCustomAdOnReward" -> sdkManager.setCustomAdOnReward(call, result)
            "unLockDrama" -> sdkManager.unlockDrama(call, result)
            "confirmUnlock" -> sdkManager.confirmUnlock(call, result)
            "cancelUnlock" -> sdkManager.cancelUnlock(call, result)
            "generateDramaUnlockSign" -> sdkManager.generateDramaUnlockSign(call, result)
            "loginDramaUnlock" -> sdkManager.loginDramaUnlock(call, result)
            "logoutDramaUnlock" -> sdkManager.logoutDramaUnlock(result)
            "isDramaUnlockLogin" -> sdkManager.isDramaUnlockLogin(result)
            "createStoryHome" -> sdkManager.createStoryHome(call, result)
            "showStoryHome" -> sdkManager.showStoryHome(call, result)
            "destroyStoryHome" -> sdkManager.destroyStoryHome(call, result)
            "getStoryCategoryList" -> sdkManager.getStoryCategoryList(result)
            "getStoryList" -> sdkManager.getStoryList(call, result)
            "searchStory" -> sdkManager.searchStory(call, result)
            "getStoryHistory" -> sdkManager.getStoryHistory(call, result)
            "favoriteStory" -> sdkManager.favoriteStory(call, result)
            "getFavoriteStories" -> sdkManager.getFavoriteStories(call, result)
            "markAsRead" -> sdkManager.markStoryAsRead(call, result)
            "likeStory" -> sdkManager.likeStory(call, result)
            "updateReadProgress" -> sdkManager.updateStoryReadProgress(call, result)
            "createVideo" -> sdkManager.createVideo(call, result)
            "showVideo" -> sdkManager.showVideo(call, result)
            "refreshVideo" -> sdkManager.refreshVideo(call, result)
            "scrollToTop" -> sdkManager.scrollToTop(call, result)
            "backRefresh" -> sdkManager.backRefresh(call, result)
            "refreshVideoToStayUser" -> sdkManager.refreshVideoToStayUser(call, result)
            "showToastToStayUser" -> sdkManager.showToastToStayUser(call, result)
            "setAwakeData" -> sdkManager.setAwakeData(call, result)
            "seekToPosition" -> sdkManager.seekToPosition(call, result)
            "setCurrentPage" -> sdkManager.setCurrentPage(call, result)
            "setSyncData" -> sdkManager.setSyncData(call, result)
            "pauseForWatchTogether" -> sdkManager.pauseForWatchTogether(call, result)
            "resumeForWatchTogether" -> sdkManager.resumeForWatchTogether(call, result)
            "pauseVideo" -> sdkManager.pauseVideo(call, result)
            "resumeVideo" -> sdkManager.resumeVideo(call, result)
            "pauseDramaSwipeFlow" -> handlePauseDramaSwipeFlow(call, result)
            "resumeDramaSwipeFlow" -> handleResumeDramaSwipeFlow(call, result)
            "destroyVideo" -> sdkManager.destroyVideo(call, result)
            "createGridVideo" -> sdkManager.createGridVideo(call, result)
            "showGridVideo" -> sdkManager.showGridVideo(call, result)
            "destroyGridVideo" -> sdkManager.destroyGridVideo(call, result)
            "createDoubleFeedVideo" -> sdkManager.createDoubleFeedVideo(call, result)
            "showDoubleFeedVideo" -> sdkManager.showDoubleFeedVideo(call, result)
            "destroyDoubleFeedVideo" -> sdkManager.destroyDoubleFeedVideo(call, result)
            "refreshGridVideo" -> sdkManager.refreshGridVideo(call, result)
            "scrollGridVideoToTop" -> sdkManager.scrollGridVideoToTop(call, result)
            "backRefreshGridVideo" -> sdkManager.backRefreshGridVideo(call, result)
            "setGridVideoUserVisible" -> sdkManager.setGridVideoUserVisible(call, result)
            "canBackPressGridVideo" -> sdkManager.canBackPressGridVideo(call, result)
            "createUserProfile" -> sdkManager.createUserProfile(call, result)
            "showUserProfile" -> sdkManager.showUserProfile(call, result)
            "refreshUserProfile" -> sdkManager.refreshUserProfile(call, result)
            "backRefreshUserProfile" -> sdkManager.backRefreshUserProfile(call, result)
            "canBackPressUserProfile" -> sdkManager.canBackPressUserProfile(call, result)
            "destroyUserProfile" -> sdkManager.destroyUserProfile(call, result)
            "createVideoCardForNews" -> sdkManager.createVideoCardForNews(call, result)
            "createVideoCardForRecommend" -> sdkManager.createVideoCardForRecommend(call, result)
            "createVideoCardForSearch" -> sdkManager.createVideoCardForSearch(call, result)
            "destroyVideoCard" -> sdkManager.destroyVideoCard(call, result)
            "createVideoSingleCardForNews" -> sdkManager.createVideoSingleCardForNews(call, result)
            "destroyVideoSingleCard" -> sdkManager.destroyVideoSingleCard(call, result)
            "getCurrentIndex" -> sdkManager.getCurrentIndex(call, result)
            "scrollToIndex" -> sdkManager.scrollToIndex(call, result)
            "pauseCurrentVideo" -> sdkManager.pauseCurrentVideo(call, result)
            "playCurrentVideo" -> sdkManager.playCurrentVideo(call, result)
            "seekVideoToMSeconds" -> sdkManager.seekVideoToMSeconds(call, result)
            "createReportContent" -> sdkManager.createReportContent(call, result)
            "destroyDramaHome" -> handleDestroyDramaHome(call, result)
            "createDramaHome", "showDramaHome" -> {
                result.error(
                    ContentConstants.ErrorCodes.INVALID_ARGUMENT,
                    "当前版本使用 PlatformView 内嵌短剧聚合页，请使用 DramaHomeNativeView",
                    null,
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun handleDestroyDramaHome(call: MethodCall, result: Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrEmpty()) {
            result.success(null)
            return
        }
        DramaHomePlatformView.findView(widgetId)?.destroyOnCommand()
        result.success(null)
    }

    private fun handlePauseDramaSwipeFlow(call: MethodCall, result: Result) {
        try {
            val swipeFlowId = call.argument<String>("swipeFlowId")
            if (swipeFlowId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "swipeFlowId cannot be null or empty", null)
                return
            }

            val view = DramaSwipeFlowPlatformView.findView(swipeFlowId)
            if (view == null) {
                result.error("SWIPE_FLOW_NOT_FOUND", "DramaSwipeFlow with ID $swipeFlowId not found", null)
                return
            }

            view.pause()
            result.success(true)
        } catch (e: Exception) {
            result.error("PAUSE_SWIPE_FLOW_ERROR", e.message, null)
        }
    }

    private fun handleResumeDramaSwipeFlow(call: MethodCall, result: Result) {
        try {
            val swipeFlowId = call.argument<String>("swipeFlowId")
            if (swipeFlowId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "swipeFlowId cannot be null or empty", null)
                return
            }

            val view = DramaSwipeFlowPlatformView.findView(swipeFlowId)
            if (view == null) {
                result.error("SWIPE_FLOW_NOT_FOUND", "DramaSwipeFlow with ID $swipeFlowId not found", null)
                return
            }

            view.resume()
            result.success(true)
        } catch (e: Exception) {
            result.error("RESUME_SWIPE_FLOW_ERROR", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventHelper.updateEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        eventHelper.updateEventSink(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        sdkManager.setActivity(binding.activity)
        dramaHomeFactory.updateActivity(binding.activity)
        dramaPlayerFactory.updateActivity(binding.activity)
        dramaSwipeFlowFactory.updateActivity(binding.activity)
        videoFactory.updateActivity(binding.activity)
        storyHomeFactory.updateActivity(binding.activity)
        gridVideoFactory.updateActivity(binding.activity)
        userProfileFactory.updateActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
        sdkManager.setActivity(null)
        dramaHomeFactory.updateActivity(null)
        dramaPlayerFactory.updateActivity(null)
        dramaSwipeFlowFactory.updateActivity(null)
        videoFactory.updateActivity(null)
        storyHomeFactory.updateActivity(null)
        gridVideoFactory.updateActivity(null)
        userProfileFactory.updateActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        sdkManager.setActivity(binding.activity)
        dramaHomeFactory.updateActivity(binding.activity)
        dramaPlayerFactory.updateActivity(binding.activity)
        dramaSwipeFlowFactory.updateActivity(binding.activity)
        videoFactory.updateActivity(binding.activity)
        storyHomeFactory.updateActivity(binding.activity)
        gridVideoFactory.updateActivity(binding.activity)
        userProfileFactory.updateActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
        sdkManager.setActivity(null)
        dramaHomeFactory.updateActivity(null)
        dramaPlayerFactory.updateActivity(null)
        dramaSwipeFlowFactory.updateActivity(null)
        videoFactory.updateActivity(null)
        storyHomeFactory.updateActivity(null)
        gridVideoFactory.updateActivity(null)
        userProfileFactory.updateActivity(null)
    }
}
