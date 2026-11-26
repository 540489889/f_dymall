package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import android.content.Intent
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.IDJXElement
import com.bytedance.sdk.djx.IDJXWidgetFactory
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXError
import com.bytedance.sdk.djx.params.DJXWidgetDramaCardParams
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.zhecent.pangrowth_content.DramaCardActivity
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper

/**
 * 短剧卡片管理器
 */
class DramaCardManager(
    private val context: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
    private val isSdkReady: () -> Boolean,
) {

    constructor(context: Context, eventSink: EventChannel.EventSink?) : this(
        context = context,
        eventHelper = ContentEventHelper().apply { updateEventSink(eventSink) },
        logger = ContentLogger.getInstance(),
        validationHelper = ContentValidationHelper.getInstance(context),
        isSdkReady = { true },
    )

    private var activity: Activity? = null

    private data class CardSession(
        val cardId: String,
        val dramaId: Long,
        val element: IDJXElement,
        var activityRef: WeakReference<Activity?>? = null,
    )

    private val cardSessions = ConcurrentHashMap<String, CardSession>()

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun bindActivity(cardId: String, activity: Activity?) {
        cardSessions[cardId]?.let {
            it.activityRef = activity?.let { act -> WeakReference(act) }
        }
    }

    fun cleanup() {
        cardSessions.values.forEach { session ->
            try {
                session.element.destroy()
            } catch (error: Throwable) {
                logger.warn("销毁卡片资源失败: ${error.message}", error)
            }
        }
        cardSessions.clear()
    }

    fun createDramaCard(call: MethodCall, result: MethodChannel.Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        if (!validationHelper.isAdSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "请先初始化 GroMore 广告 SDK", null)
            return
        }

        val dramaId = call.argument<Number>("dramaId")?.toLong()
        if (dramaId == null) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空", null)
            return
        }

        val params = buildParams(call)
        val cardId = "drama_card_${UUID.randomUUID()}"

        try {
            DJXSdk.factory().loadDramaCard(params, dramaId.toInt(), object : IDJXWidgetFactory.Callback {
                override fun onSuccess(element: IDJXElement?) {
                    if (element == null) {
                        logger.error("短剧卡片返回空 element")
                        result.error("CARD_ELEMENT_NULL", "短剧卡片组件为空", null)
                        return
                    }

                    cardSessions[cardId] = CardSession(
                        cardId = cardId,
                        dramaId = dramaId,
                        element = element,
                    )

                    emitEvent(cardId, "card_created", mapOf(
                        "dramaId" to dramaId,
                    ))

                    emitEvent(cardId, "card_data_loaded", mapOf(
                        "dramaId" to dramaId,
                        "drama" to mapDrama(element.drama),
                    ))

                    result.success(
                        mapOf(
                            "success" to true,
                            "cardId" to cardId,
                        ),
                    )
                }

                override fun onError(error: DJXError) {
                    val errorMap = mapOf(
                        "code" to error.code,
                        "message" to error.msg,
                        "subCode" to error.subCode,
                        "requestId" to error.requestId,
                    )
                    emitEvent(cardId, "card_create_failed", mapOf("error" to errorMap))
                    result.error(
                        "CARD_CREATE_FAILED",
                        error.msg ?: "短剧卡片加载失败",
                        errorMap,
                    )
                }
            })
        } catch (error: Throwable) {
            logger.error("创建短剧卡片异常", error)
            result.error("CARD_CREATE_EXCEPTION", "创建短剧卡片异常: ${error.message}", null)
        }
    }

    fun showDramaCard(call: MethodCall, result: MethodChannel.Result) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        val hostActivity = activity ?: run {
            result.error("NO_ACTIVITY", "当前 Activity 不可用", null)
            return
        }

        try {
            DramaCardActivity.registerElement(cardId, session.element)
            DramaCardActivity.attachManager(cardId, this)

            val intent = Intent(hostActivity, DramaCardActivity::class.java).apply {
                putExtra(DramaCardActivity.EXTRA_CARD_ID, cardId)
            }
            hostActivity.startActivity(intent)

            emitEvent(cardId, "card_ready_to_display", mapOf("dramaId" to session.dramaId))

            result.success(
                mapOf(
                    "success" to true,
                    "cardId" to cardId,
                    "shown" to true,
                ),
            )
        } catch (error: Throwable) {
            logger.error("展示短剧卡片失败", error)
            result.error("CARD_SHOW_FAILED", "展示短剧卡片失败: ${error.message}", null)
        }
    }

    fun playDramaCard(call: MethodCall, result: MethodChannel.Result) {
        execute(cardId = call.argument("cardId"), result = result) { session ->
            session.element.start()
            emitEvent(session.cardId, "card_playback_state_changed", mapOf("playbackState" to "playing"))
            true
        }
    }

    fun pauseDramaCard(call: MethodCall, result: MethodChannel.Result) {
        execute(call.argument("cardId"), result) { session ->
            session.element.pause()
            emitEvent(session.cardId, "card_playback_state_changed", mapOf("playbackState" to "paused"))
            true
        }
    }

    fun stopDramaCard(call: MethodCall, result: MethodChannel.Result) {
        execute(call.argument("cardId"), result) { session ->
            session.element.stop()
            emitEvent(session.cardId, "card_user_stopped", emptyMap())
            true
        }
    }

    fun setDramaCardMute(call: MethodCall, result: MethodChannel.Result) {
        val mute = call.argument<Boolean>("mute") ?: false
        execute(call.argument("cardId"), result) { session ->
            session.element.setMute(mute)
            emitEvent(session.cardId, "card_playback_state_changed", mapOf("playbackState" to if (mute) "muted" else "unmuted"))
            true
        }
    }

    fun reportDramaCardShow(call: MethodCall, result: MethodChannel.Result) {
        val duration = call.argument<Number>("duration")?.toLong() ?: 0L
        execute(call.argument("cardId"), result) { session ->
            session.element.reportShow(duration)
            emitEvent(session.cardId, "card_ready_to_play", mapOf("duration" to duration))
            true
        }
    }

    fun refreshDramaCard(call: MethodCall, result: MethodChannel.Result) {
        execute(call.argument("cardId"), result) { session ->
            session.element.refresh()
            emitEvent(session.cardId, "dataLoaded", mapOf("dramaId" to session.dramaId))
            true
        }
    }

    fun destroyDramaCard(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions.remove(cardId)
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            session.element.destroy()
            session.activityRef?.get()?.finish()
            DramaCardActivity.clear(cardId)
        } catch (error: Throwable) {
            logger.warn("销毁短剧卡片出现异常: ${error.message}", error)
        }

        emitEvent(cardId, "card_destroyed", mapOf("dramaId" to session.dramaId))

        result.success(
            mapOf(
                "success" to true,
                "cardId" to cardId,
                "destroyed" to true,
            ),
        )
    }

    fun isDramaCardPlaying(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            val isPlaying = session.element.isPlaying()
            result.success(isPlaying)
        } catch (error: Throwable) {
            logger.error("获取播放状态异常", error)
            result.error("GET_PLAYING_STATE_FAILED", error.message, null)
        }
    }

    fun getDramaCardInfo(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            val drama = session.element.drama
            if (drama != null) {
                result.success(mapDrama(drama))
            } else {
                result.success(null)
            }
        } catch (error: Throwable) {
            logger.error("获取短剧信息异常", error)
            result.error("GET_DRAMA_INFO_FAILED", error.message, null)
        }
    }

    fun getDramaCardGid(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            val gid = session.element.gid
            result.success(gid)
        } catch (error: Throwable) {
            logger.error("获取短剧GID异常", error)
            result.error("GET_GID_FAILED", error.message, null)
        }
    }

    fun getDramaCardTitle(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            val title = session.element.title
            result.success(title)
        } catch (error: Throwable) {
            logger.error("获取短剧标题异常", error)
            result.error("GET_TITLE_FAILED", error.message, null)
        }
    }

    private fun execute(cardId: String?, result: MethodChannel.Result, block: (CardSession) -> Boolean) {
        if (!isSdkReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        if (cardId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "cardId 不能为空", null)
            return
        }

        val session = cardSessions[cardId]
        if (session == null) {
            result.error("CARD_NOT_FOUND", "未找到短剧卡片实例", null)
            return
        }

        try {
            val success = block(session)
            result.success(mapOf("success" to success, "cardId" to cardId))
        } catch (error: Throwable) {
            logger.error("卡片操作异常", error)
            result.error("CARD_ACTION_FAILED", error.message, null)
        }
    }

    private fun buildParams(call: MethodCall): DJXWidgetDramaCardParams {
        val params = DJXWidgetDramaCardParams.obtain()

        call.argument<Int>("width")?.let { params.width(it) }
        call.argument<Boolean>("hideSoundButton")?.let { params.hideSoundButton(it) }
        call.argument<Boolean>("hideReplayButton")?.let { params.hideReplayButton(it) }
        call.argument<Boolean>("isMuteDefault")?.let { params.muteDefault(it) }
        call.argument<Boolean>("isLooping")?.let { params.looping(it) }
        call.argument<Boolean>("isAutoPlay")?.let { params.autoPlay(it) }

        // iOS 专用参数在 Android 端忽略，无需处理 frame/hideActionUI 等

        return params
    }

    private fun emitEvent(cardId: String, eventType: String, extras: Map<String, Any?>) {
        val payload = mutableMapOf<String, Any?>(
            "cardId" to cardId,
            "eventType" to eventType,
        )
        payload.putAll(extras)
        eventHelper.sendEvent("dramaCard", contentId = cardId, extra = payload)
    }

    private fun mapDrama(drama: DJXDrama?): Map<String, Any?>? {
        if (drama == null) return null
        return mapOf(
            "id" to drama.id,
            "title" to drama.title,
            "coverImage" to drama.coverImage,
            "desc" to drama.desc,
        )
    }
}
