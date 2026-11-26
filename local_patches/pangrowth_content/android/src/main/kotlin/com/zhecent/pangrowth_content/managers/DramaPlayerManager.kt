package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.DJXPlaySpeedScope
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.djx.IDJXWidgetFactory
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXDramaDetailConfig
import com.bytedance.sdk.djx.model.DJXDramaUnlockAdMode
import com.bytedance.sdk.djx.model.DJXDramaUnlockInfo
import com.bytedance.sdk.djx.model.DJXDramaUnlockMethod
import com.bytedance.sdk.djx.params.DJXWidgetDramaDetailParams
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaUnlockListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXAdListener
import com.bytedance.sdk.djx.DJXRewardAdResult
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger


/**
 * 短剧播放页管理器
 * 负责处理短剧播放页的创建、展示和控制功能
 * 基于DJXSdk的createDramaDetail接口实现
 */
class DramaPlayerManager(
    private val context: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val isSdkReady: () -> Boolean,
) {

    companion object {
        private const val TAG = "DramaPlayerManager"
    }

    private var activity: Activity? = null

    private data class PlayerSession(
        val playerId: String,
        val dramaId: Long,
        var episode: Int,
        val widget: IDJXWidget,
        var customAdCallback: IDJXDramaUnlockListener.CustomAdCallback? = null,
    )

    private data class UnlockCallbackWrapper(
        val callback: IDJXDramaUnlockListener.UnlockCallback,
        val drama: DJXDrama,
        val unlockEpisodes: Int,
    )

    private data class PendingCustomAdShow(
        val cpm: String,
        val result: Result,
    )

    private data class PendingCustomAdReward(
        val verify: Boolean,
        val extra: Map<String, Any?>,
        val result: Result,
    )

    private val playerSessions = mutableMapOf<String, PlayerSession>()
    private val unlockCallbacks = mutableMapOf<String, UnlockCallbackWrapper>()
    private val pendingCustomAdShows = mutableMapOf<String, PendingCustomAdShow>()
    private val pendingCustomAdRewards = mutableMapOf<String, PendingCustomAdReward>()

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    /**
     * 创建短剧播放页
     */
    fun createDramaPlayer(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val hostActivity = activity
            if (hostActivity == null || hostActivity !is FragmentActivity) {
                logger.error("创建播放页失败: Activity 不可用或不是 FragmentActivity")
                result.error("NO_ACTIVITY", "Activity is not available", null)
                return
            }

            val dramaId = call.argument<Number>("dramaId")?.toLong()
            val episode = call.argument<Int>("episode") ?: 1
            if (dramaId == null) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空", null)
                return
            }

            val customPlayerId = call.argument<String>("playerIdHint")
            val playerId = customPlayerId ?: generatePlayerId(dramaId, episode)
            logger.debug("创建播放页: dramaId=$dramaId, episode=$episode, playerId=$playerId", TAG)

            val detailConfig = createDramaDetailConfig(call, playerId)
            val params = DJXWidgetDramaDetailParams.obtain(dramaId, episode, detailConfig)

            call.argument<Int>("currentDuration")?.let { params.currentDuration(it) }
            call.argument<String>("fromGid")?.let { params.fromGid(it) }
            call.argument<String>("fromSource")?.let {
                params.from(
                    when (it.lowercase()) {
                        "skit_mixed" -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.SKIT_MIXED
                        "drama_home_recently_watched" -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.DRAMA_HOME_RECENTLY_WATCHED
                        "drama_home" -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.DRAMA_HOME
                        "drama_history" -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.DRAMA_HISTORY
                        "drama_card" -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.DRAMA_CARD
                        else -> DJXWidgetDramaDetailParams.DJXDramaEnterFrom.DEFAULT
                    }
                )
            }
            call.argument<Map<String, Any>>("recMap")?.let { params.recMap(it) }

            val widget = DJXSdk.factory().createDramaDetail(params)
                ?: throw IllegalStateException("createDramaDetail 返回 null")

            playerSessions[playerId] = PlayerSession(
                playerId = playerId,
                dramaId = dramaId,
                episode = episode,
                widget = widget,
            )

            // emitEvent(playerId, "drama_player_created", mapOf(
            //     "dramaId" to dramaId,
            //     "episode" to episode,
            // ))

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "dramaId" to dramaId,
                    "episode" to episode,
                ),
            )
        } catch (error: Throwable) {
            logger.error("创建短剧播放页异常", error)
            result.error("CREATE_FAILED", "创建短剧播放页失败: ${error.message}", null)
        }
    }

    /**
     * 展示短剧播放页
     */
    fun showDramaPlayer(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            if (playerId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            val hostActivity = activity
            if (hostActivity !is FragmentActivity) {
                result.error("INVALID_ACTIVITY", "Activity 必须继承 FragmentActivity", null)
                return
            }

            val fragment: Fragment = session.widget.fragment
            val fragmentManager: FragmentManager = hostActivity.supportFragmentManager
            val transaction: FragmentTransaction = fragmentManager.beginTransaction()
            val containerId = call.argument<Int>("containerId") ?: android.R.id.content
            val tag = "drama_player_$playerId"
            val addToBackStack = call.argument<Boolean>("addToBackStack")
                ?: (containerId == android.R.id.content)

            transaction.replace(containerId, fragment, tag)

            if (addToBackStack) {
                transaction.addToBackStack(tag)
                transaction.commitAllowingStateLoss()
            } else {
                transaction.commitNowAllowingStateLoss()
            }

            // emitEvent(playerId, "drama_player_shown", mapOf(
            //     "dramaId" to session.dramaId,
            //     "episode" to session.episode,
            // ))

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "shown" to true,
                ),
            )
        } catch (error: Throwable) {
            logger.error("展示短剧播放页失败", error)
            result.error("SHOW_FAILED", "展示短剧播放页失败: ${error.message}", null)
        }
    }

    /**
     * 跳转到指定播放进度
     */
    fun seekTo(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            val duration = call.argument<Number>("duration")?.toLong()
            if (playerId.isNullOrEmpty() || duration == null) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 和 duration 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            session.widget.seekTo(duration)
            emitEvent(playerId, "drama_video_seek", mapOf("position" to duration))

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "duration" to duration,
                ),
            )
        } catch (error: Throwable) {
            logger.error("播放进度跳转失败", error)
            result.error("SEEK_FAILED", "跳转失败: ${error.message}", null)
        }
    }

    /**
     * 设置播放倍速
     */
    fun setSpeedPlay(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            val speedValue = call.argument<Number>("speed")?.toDouble()
            if (playerId.isNullOrEmpty() || speedValue == null) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 和 speed 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            val scopeKey = (call.argument<String>("scope") ?: "episode").lowercase()
            val scope = when (scopeKey) {
                "drama" -> DJXPlaySpeedScope.DJX_VIDEO_SPEED_SCOPE_DRAMA
                else -> DJXPlaySpeedScope.DJX_VIDEO_SPEED_SCOPE_EPISODE
            }

            val clampedSpeed = when {
                speedValue <= 0.0 -> 1.0
                speedValue > 3.0 -> 3.0
                else -> speedValue
            }.toFloat()

            session.widget.setSpeedPlay(clampedSpeed, scope)
            emitEvent(playerId, "drama_speed_change", mapOf(
                "speed" to clampedSpeed.toDouble(),
                "scope" to scopeKey,
            ))
            logger.debug("设置播放倍速: playerId=$playerId, speed=$clampedSpeed, scope=$scopeKey", TAG)

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "speed" to clampedSpeed.toDouble(),
                    "scope" to scopeKey,
                ),
            )
        } catch (error: Throwable) {
            logger.error("设置播放倍速失败", error)
            result.error("SET_SPEED_FAILED", "设置播放倍速失败: ${error.message}", null)
        }
    }

    /**
     * 设置当前播放集数
     */
    fun setCurrentEpisode(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            val episode = call.argument<Int>("episode")
            if (playerId.isNullOrEmpty() || episode == null) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 和 episode 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            session.widget.setCurrentDramaIndex(episode)
            session.episode = episode
            emitEvent(playerId, "drama_episode_change", mapOf(
                "episode" to episode,
                "dramaId" to session.dramaId,
            ))

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "episode" to episode,
                ),
            )
        } catch (error: Throwable) {
            logger.error("切换剧集失败", error)
            result.error("SET_EPISODE_FAILED", "切换剧集失败: ${error.message}", null)
        }
    }

    /**
     * 获取当前播放集数
     */
    fun getCurrentEpisode(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            if (playerId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            val currentEpisode = session.widget.currentDramaIndex
            session.episode = currentEpisode

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "currentEpisode" to currentEpisode,
                ),
            )
        } catch (error: Throwable) {
            logger.error("获取当前剧集失败", error)
            result.error("GET_EPISODE_FAILED", "获取当前剧集失败: ${error.message}", null)
        }
    }

    /**
     * 打开更多弹窗
     */
    fun openMoreDialog(call: MethodCall, result: Result) {
        handlePlaybackControl(call, result) { session ->
            session.widget.openMoreDialog()
            true
        }
    }

    /**
     * 打开选集面板
     */
    fun openEpisodePanel(call: MethodCall, result: Result) {
        handlePlaybackControl(call, result) { session ->
            session.widget.openDramaGallery()
            true
        }
    }

    /**
     * 刷新播放页
     */
    fun refreshPlayer(call: MethodCall, result: Result) {
        handlePlaybackControl(call, result) { session ->
            session.widget.backRefresh()
            true
        }
    }

    /**
     * 销毁播放页
     */
    fun destroyDramaPlayer(call: MethodCall, result: Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            if (playerId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
                return
            }

            val session = playerSessions.remove(playerId)
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            session.widget.destroy()

            pendingCustomAdShows.remove(playerId)?.result?.error(
                "PLAYER_DESTROYED",
                "播放器已销毁，无法继续处理自定义广告展示",
                null,
            )
            pendingCustomAdRewards.remove(playerId)?.result?.error(
                "PLAYER_DESTROYED",
                "播放器已销毁，无法继续处理自定义广告奖励",
                null,
            )

            val hostActivity = activity
            if (hostActivity is FragmentActivity) {
                val tag = "drama_player_$playerId"
                val fragmentManager = hostActivity.supportFragmentManager
                fragmentManager.findFragmentByTag(tag)?.let { fragment ->
                    fragmentManager.beginTransaction()
                        .remove(fragment)
                        .commitAllowingStateLoss()
                    fragmentManager.executePendingTransactions()
                }
            }

            // emitEvent(playerId, "drama_player_destroyed", mapOf(
            //     "dramaId" to session.dramaId,
            //     "episode" to session.episode,
            // ))

            result.success(
                mapOf(
                    "success" to true,
                    "playerId" to playerId,
                    "destroyed" to true,
                ),
            )
        } catch (error: Throwable) {
            logger.error("销毁短剧播放页失败", error)
            result.error("DESTROY_FAILED", "销毁播放页失败: ${error.message}", null)
        }
    }

    fun setCustomAdOnShow(call: MethodCall, result: Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
            return
        }

        val session = playerSessions[playerId]
        if (session == null) {
            result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
            return
        }

        val callback = session.customAdCallback
        if (callback == null) {
            pendingCustomAdShows.remove(playerId)?.result?.error(
                "NO_CUSTOM_AD",
                "已有未完成的自定义广告展示请求被新的请求覆盖",
                null,
            )
            val cpm = call.argument<String>("cpm") ?: ""
            pendingCustomAdShows[playerId] = PendingCustomAdShow(cpm, result)
            logger.info("自定义广告回调未就绪，等待 showCustomAd 事件: playerId=$playerId")
            return
        }

        val cpm = call.argument<String>("cpm") ?: ""
        try {
            callback.onShow(cpm)
            result.success(true)
        } catch (error: Throwable) {
            logger.error("执行自定义广告 onShow 失败", error)
            result.error("CUSTOM_AD_SHOW_FAILED", error.message, null)
        }
    }

    fun setCustomAdOnReward(call: MethodCall, result: Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
            return
        }

        val session = playerSessions[playerId]
        val callback = session?.customAdCallback
        if (callback == null) {
            val verify = call.argument<Boolean>("verify") ?: false
            val extra = call.argument<Map<String, Any?>>("extraData") ?: emptyMap()

            pendingCustomAdRewards.remove(playerId)?.result?.error(
                "NO_CUSTOM_AD",
                "已有未完成的自定义广告奖励请求被新的请求覆盖",
                null,
            )
            pendingCustomAdRewards[playerId] = PendingCustomAdReward(verify, extra, result)
            logger.info("自定义广告回调未就绪，等待 showCustomAd 事件(奖励阶段): playerId=$playerId")
            return
        }

        val verify = call.argument<Boolean>("verify") ?: false
        val extra = call.argument<Map<String, Any?>>("extraData") ?: emptyMap()

        try {
            // 使用正确的DJXRewardAdResult类，只传递verify参数
            callback.onRewardVerify(DJXRewardAdResult(verify))
            if (verify) {
                session.customAdCallback = null
            }
            result.success(true)
            logger.info("自定义广告奖励处理完成，验证结果: $verify")
        } catch (error: Throwable) {
            logger.error("执行自定义广告奖励回调失败", error)
            result.error("CUSTOM_AD_REWARD_FAILED", error.message, null)
        }
    }

    fun unlockDrama(call: MethodCall, result: Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
            return
        }

        val wrapper = unlockCallbacks[playerId]
        if (wrapper == null) {
            logger.warn("未找到 player=$playerId 的解锁回调")
            result.error("NO_UNLOCK_CALLBACK", "未找到可用的解锁回调", null)
            return
        }

        val unlockEpisodeId = call.argument<Int>("episodeId")
        val unlockCount = call.argument<Int>("lockSet")
        val cancel = call.argument<Boolean>("cancel") ?: false

        try {
            val unlockInfo = DJXDramaUnlockInfo(
                wrapper.drama.id,
                unlockCount ?: wrapper.unlockEpisodes,
                DJXDramaUnlockMethod.METHOD_AD,
                cancel,
            )
            wrapper.callback.onConfirm(unlockInfo)
            if (!cancel && unlockEpisodeId != null) {
                playerSessions[playerId]?.episode = unlockEpisodeId
            }
            unlockCallbacks.remove(playerId)
            logger.info(
                "通过Flutter触发解锁: playerId=$playerId, dramaId=${wrapper.drama.id}, episode=$unlockEpisodeId, unlockCount=${unlockCount ?: wrapper.unlockEpisodes}, cancel=$cancel",
            )
            result.success(true)
        } catch (error: Throwable) {
            logger.error("执行解锁回调失败", error)
            result.error("UNLOCK_FAILED", error.message, null)
        }
    }

    /**
     * 确认解锁（用于SDK广告+自定义弹窗模式）
     * Flutter层在用户确认解锁后调用此方法，触发SDK播放广告
     */
    fun confirmUnlock(call: MethodCall, result: Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
            return
        }

        val wrapper = unlockCallbacks.remove(playerId)
        if (wrapper == null) {
            logger.warn("未找到 player=$playerId 的解锁回调")
            result.error("NO_UNLOCK_CALLBACK", "未找到可用的解锁回调", null)
            return
        }

        try {
            val unlockInfo = DJXDramaUnlockInfo(
                wrapper.drama.id,
                wrapper.unlockEpisodes,
                DJXDramaUnlockMethod.METHOD_AD,
                false, // cancelUnlock = false
            )
            wrapper.callback.onConfirm(unlockInfo)
            logger.info("确认解锁: playerId=$playerId, dramaId=${wrapper.drama.id}, episodes=${wrapper.unlockEpisodes}")
            result.success(true)
        } catch (error: Throwable) {
            logger.error("确认解锁失败", error)
            result.error("CONFIRM_UNLOCK_FAILED", error.message, null)
        }
    }

    /**
     * 取消解锁（用户点击"残忍离开"）
     */
    fun cancelUnlock(call: MethodCall, result: Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
            return
        }

        val wrapper = unlockCallbacks.remove(playerId)
        if (wrapper == null) {
            logger.warn("未找到 player=$playerId 的解锁回调")
            result.error("NO_UNLOCK_CALLBACK", "未找到可用的解锁回调", null)
            return
        }

        try {
            val unlockInfo = DJXDramaUnlockInfo(
                wrapper.drama.id,
                wrapper.unlockEpisodes,
                DJXDramaUnlockMethod.METHOD_AD,
                true, // cancelUnlock = true
            )
            wrapper.callback.onConfirm(unlockInfo)
            logger.info("取消解锁: playerId=$playerId")
            result.success(true)
        } catch (error: Throwable) {
            logger.error("取消解锁失败", error)
            result.error("CANCEL_UNLOCK_FAILED", error.message, null)
        }
    }

    // 私有辅助方法

    private fun generatePlayerId(dramaId: Long, episode: Int): String {
        return "drama_player_${dramaId}_${episode}_${System.currentTimeMillis()}"
    }

    private fun handlePlaybackControl(
        call: MethodCall,
        result: Result,
        action: (PlayerSession) -> Boolean,
    ) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            val playerId = call.argument<String>("playerId")
            if (playerId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playerId 不能为空", null)
                return
            }

            val session = playerSessions[playerId]
            if (session == null) {
                result.error("PLAYER_NOT_FOUND", "未找到播放器实例", null)
                return
            }

            val success = action(session)

            result.success(
                mapOf(
                    "success" to success,
                    "playerId" to playerId,
                ),
            )
        } catch (error: Throwable) {
            logger.error("播放控制失败", error)
            result.error("CONTROL_FAILED", "播放控制失败: ${error.message}", null)
        }
    }

    private fun createDramaDetailConfig(call: MethodCall, playerId: String): DJXDramaDetailConfig {
        val adMode = when (call.argument<String>("adMode")?.lowercase()) {
            "specific" -> DJXDramaUnlockAdMode.MODE_SPECIFIC
            else -> DJXDramaUnlockAdMode.MODE_COMMON
        }

        val freeSet = call.argument<Int>("freeSet") ?: 5
        val unlockEpisodes = call.argument<Int>("unlockSet") ?: 10
        val config = DJXDramaDetailConfig.obtain(adMode, freeSet, createUnlockListener(playerId, unlockEpisodes))

        call.argument<Boolean>("hideRewardDialog")?.let { config.hideRewardDialog(it) }
        call.argument<Boolean>("hideBack")?.let { config.hideBack(it, null) }
        call.argument<Boolean>("hideTopInfo")?.let { config.hideTopInfo(it) }
        call.argument<Boolean>("hideBottomInfo")?.let { config.hideBottomInfo(it) }
        call.argument<Boolean>("hideMore")?.let { config.hideMore(it) }
        call.argument<Boolean>("hideLikeIcon")?.let { config.hideLikeButton(it) }
        call.argument<Boolean>("hideCollectIcon")?.let { config.hideFavorButton(it) }
        call.argument<Boolean>("hideCellularToast")?.let { config.hideCellularToast(it) }
        call.argument<Boolean>("disableDoubleClickLike")?.let { config.hideDoubleClick(it) }

        call.argument<Boolean>("infiniteScrollEnabled")?.let { config.infiniteScrollEnabled(it) }
        call.argument<Boolean>("closeInfiniteScroll")?.let { config.infiniteScrollEnabled(!it) }

        call.argument<Int>("bottomOffset")?.takeIf { it >= 0 }?.let { config.setBottomOffset(it) }
        call.argument<Int>("topOffset")?.takeIf { it >= 0 }?.let { config.setTopOffset(it) }
        call.argument<Int>("scriptTipsTopMargin")?.takeIf { it >= 0 }?.let { config.setScriptTipsTopMargin(it) }

        config.listener(createDramaListener(playerId))
        config.adListener(createAdListener(playerId))

        return config
    }

    private fun createUnlockListener(playerId: String, unlockEpisodes: Int): IDJXDramaUnlockListener {
        return object : IDJXDramaUnlockListener {
            override fun unlockFlowStart(
                drama: DJXDrama,
                callback: IDJXDramaUnlockListener.UnlockCallback,
                map: Map<String, Any>?,
            ) {
                // 保存callback，等待Flutter层调用confirmUnlock确认
                unlockCallbacks[playerId] = UnlockCallbackWrapper(callback, drama, unlockEpisodes)

                // ✅ 根据官方SDK文档，直接从map参数读取集数和总集数
                // 文档: docs/80-外部资源/穿山甲广告官方文档/pangrowth/android/6-短剧播放页及配置.md (第855-870行)
                val currentEpisode = map?.get("index") as? Int
                val totalEpisodes = map?.get("total") as? Int

                // ✅ 构建完整的drama信息，包含从SDK获取的集数信息
                val dramaData = mapDramaToMap(drama).toMutableMap().apply {
                    this["index"] = currentEpisode
                    this["total"] = totalEpisodes
                }

                emitEvent(playerId, "drama_unlock_start", mapOf(
                    "dramaId" to drama.id,
                    "drama" to dramaData,
                    "extra" to (map?.toMutableMap() ?: emptyMap<String, Any>()),
                ))

                // 不再立即调用callback.onConfirm()，等待Flutter层确认
                // val unlockInfo = DJXDramaUnlockInfo(drama.id, unlockEpisodes, DJXDramaUnlockMethod.METHOD_AD)
                // callback.onConfirm(unlockInfo)
            }

            override fun unlockFlowEnd(
                drama: DJXDrama,
                errCode: IDJXDramaUnlockListener.UnlockErrorStatus?,
                map: Map<String, Any>?,
            ) {
                emitEvent(playerId, "drama_unlock_end", mapOf(
                    "dramaId" to drama.id,
                    "drama" to mapDramaToMap(drama),
                    "success" to (errCode == null),
                    "errorCode" to errCode?.name,
                    "extra" to (map?.toMutableMap() ?: emptyMap<String, Any>()),
                ))
            }

            override fun showCustomAd(drama: DJXDrama, callback: IDJXDramaUnlockListener.CustomAdCallback) {
                val session = playerSessions[playerId]
                session?.customAdCallback = callback

                pendingCustomAdShows.remove(playerId)?.let { pending ->
                    try {
                        callback.onShow(pending.cpm)
                        pending.result.success(true)
                    } catch (error: Throwable) {
                        logger.error("执行自定义广告 onShow 失败(延迟触发)", error)
                        pending.result.error("CUSTOM_AD_SHOW_FAILED", error.message, null)
                    }
                }

                pendingCustomAdRewards.remove(playerId)?.let { pending ->
                    try {
                        callback.onRewardVerify(DJXRewardAdResult(pending.verify))
                        if (pending.verify) {
                            session?.customAdCallback = null
                        }
                        pending.result.success(true)
                    } catch (error: Throwable) {
                        logger.error("执行自定义广告奖励回调失败(延迟触发)", error)
                        pending.result.error("CUSTOM_AD_REWARD_FAILED", error.message, null)
                    }
                }

                emitEvent(playerId, "drama_show_custom_ad", mapOf(
                    "dramaId" to drama.id,
                    "drama" to mapDramaToMap(drama),
                ))
            }
        }
    }

    private fun createDramaListener(playerId: String): IDJXDramaListener {
        return object : IDJXDramaListener() {
            override fun onDJXSeekTo(position: Int, time: Long) {
                emitEvent(playerId, "drama_video_seek", mapOf(
                    "position" to position,
                    "time" to time,
                ))
            }

            override fun onDJXPageChange(position: Int, map: Map<String, Any>?) {
                val payload = map?.toMutableMap() ?: mutableMapOf()
                payload["position"] = position
                emitEvent(playerId, "drama_page_change", payload)
            }

            override fun onDJXVideoPlay(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_video_start_play", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXVideoPause(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_video_pause", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXVideoContinue(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_video_continue", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXVideoCompletion(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_video_completion", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXVideoOver(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_video_over_play", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXClose() {
                emitEvent(playerId, "drama_close")
            }

            override fun onDramaSwitch(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_switch", map?.toMutableMap() ?: emptyMap())
            }
        }
    }

    private fun createAdListener(playerId: String): IDJXAdListener {
        return object : IDJXAdListener() {
            override fun onDJXAdRequest(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_ad_request", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXAdRequestSuccess(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_ad_load_success", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXAdRequestFail(code: Int, msg: String, map: Map<String, Any>?) {
                val payload = map?.toMutableMap() ?: mutableMapOf()
                payload["code"] = code
                payload["message"] = msg
                emitEvent(playerId, "drama_ad_load_fail", payload)
            }

            override fun onDJXAdFillFail(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_ad_fill_fail", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXAdShow(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_ad_show", map?.toMutableMap() ?: emptyMap())
            }

            override fun onDJXAdClicked(map: Map<String, Any>?) {
                emitEvent(playerId, "drama_ad_click", map?.toMutableMap() ?: emptyMap())
            }
        }
    }

    private fun emitEvent(playerId: String, action: String, data: Map<String, Any?> = emptyMap()) {
        val payload = mutableMapOf<String, Any?>(
            "playerId" to playerId,
        )
        payload.putAll(data)
        eventHelper.sendEvent(action, contentId = playerId, extra = payload)
    }

    private fun mapDramaToMap(drama: DJXDrama): Map<String, Any?> {
        return mapOf(
            "id" to drama.id,
            "title" to drama.title,
            "coverImage" to drama.coverImage,
            "desc" to drama.desc,
        )
    }

    fun cleanup() {
        playerSessions.values.forEach { session ->
            try {
                session.widget.destroy()
            } catch (error: Throwable) {
                logger.warn("销毁播放页资源失败: ${error.message}", error)
            }
        }
        playerSessions.clear()
        unlockCallbacks.clear()
        pendingCustomAdShows.values.forEach { pending ->
            pending.result.error("PLAYER_DESTROYED", "内容 SDK 已清理，无法继续处理自定义广告展示", null)
        }
        pendingCustomAdRewards.values.forEach { pending ->
            pending.result.error("PLAYER_DESTROYED", "内容 SDK 已清理，无法继续处理自定义广告奖励", null)
        }
        pendingCustomAdShows.clear()
        pendingCustomAdRewards.clear()
    }
}
