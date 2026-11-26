package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaUnlockListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDrawListener
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXDramaDetailConfig
import com.bytedance.sdk.djx.model.DJXDramaUnlockAdMode
import com.bytedance.sdk.djx.model.DJXDramaUnlockInfo
import com.bytedance.sdk.djx.model.DJXDramaUnlockMethod
import com.bytedance.sdk.djx.params.DJXWidgetDrawParams
import com.zhecent.pangrowth_content.DramaSwipeActivity
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class DramaSwipeCoordinator(
    private val applicationContext: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
    private val isSdkReady: () -> Boolean,
) {

    private var currentActivity: Activity? = null

    private val sessions = ConcurrentHashMap<String, DramaSwipeSession>()

    fun setActivity(activity: Activity?) {
        currentActivity = activity
    }

    fun dispose() {
        sessions.keys.toList().forEach { widgetId ->
            removeSession(widgetId)
        }
    }

    fun create(call: MethodCall, result: MethodChannel.Result) {
        if (!isSdkReady()) {
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "内容 SDK 未启动，请先调用 PangrowthContent.start",
                null,
            )
            return
        }

        if (!validationHelper.isAdSdkReady()) {
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "请先完成 GroMore 广告 SDK 初始化",
                null,
            )
            return
        }

        val widgetId = "drama_swipe_${UUID.randomUUID()}"
        val params = buildParams(widgetId, call)

        try {
            val widget = DJXSdk.factory().createDraw(params)
                ?: throw IllegalStateException("createDraw 返回 null")

            val session = DramaSwipeSession(
                widgetId = widgetId,
                widget = widget,
            )
            sessions[widgetId] = session

            result.success(
                mapOf(
                    "widgetId" to widgetId,
                    "widgetType" to "drama_swipe_flow",
                    "success" to true,
                ),
            )
        } catch (error: Throwable) {
            logger.error("创建短剧滑滑流失败: ${error.message}", error)
            result.error("CREATE_SWIPE_FAILED", error.message, null)
        }
    }

    fun show(call: MethodCall, result: MethodChannel.Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "widgetId 不能为空", null)
            return
        }

        val session = sessions[widgetId]
        if (session == null) {
            result.error("SWIPE_NOT_FOUND", "未找到对应的滑滑流实例", null)
            return
        }

        val activity = currentActivity
        if (activity == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "Activity 不可用", null)
            return
        }

        val fragment: Fragment = session.widget.fragment

        DramaSwipeActivity.registerFragment(widgetId, fragment)
        DramaSwipeActivity.attachCoordinator(widgetId, this)
        val intent = Intent(activity, DramaSwipeActivity::class.java).apply {
            putExtra(DramaSwipeActivity.EXTRA_WIDGET_ID, widgetId)
        }
        activity.startActivity(intent)

        result.success(
            mapOf(
                "widgetId" to widgetId,
                "shown" to true,
            ),
        )
        eventHelper.sendEvent("dramaSwipeFlowShown", contentId = widgetId)
    }

    fun hide(call: MethodCall, result: MethodChannel.Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "widgetId 不能为空", null)
            return
        }

        val session = sessions[widgetId]
        if (session == null) {
            result.error("SWIPE_NOT_FOUND", "未找到对应的滑滑流实例", null)
            return
        }

        session.activity?.get()?.finish()
        result.success(true)
        eventHelper.sendEvent("dramaSwipeFlowHidden", contentId = widgetId)
    }

    fun destroy(call: MethodCall, result: MethodChannel.Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "widgetId 不能为空", null)
            return
        }

        if (!sessions.containsKey(widgetId)) {
            result.error("SWIPE_NOT_FOUND", "未找到对应的滑滑流实例", null)
            return
        }

        removeSession(widgetId)
        result.success(true)
        eventHelper.sendEvent("dramaSwipeFlowDestroyed", contentId = widgetId)
    }

    fun bindActivity(widgetId: String, activity: DramaSwipeActivity?) {
        sessions[widgetId]?.activity = if (activity != null) {
            WeakReference<Activity?>(activity)
        } else {
            null
        }
    }

    fun onBackPressed(widgetId: String): Boolean {
        val session = sessions[widgetId] ?: return true
        return session.widget.canBackPress()
    }

    private fun buildParams(widgetId: String, call: MethodCall): DJXWidgetDrawParams {
        val params = DJXWidgetDrawParams.obtain()
        val args = call.arguments as? Map<*, *>

        // 按需设置参数，使用SDK默认值
        (args?.get("contentType") as? Number)?.toInt()?.let {
            params.mDrawContentType = it
        }

        val drawListener = object : IDJXDrawListener() {
            override fun onDJXRefreshFinish() {
                emitEvent(widgetId, "refreshFinish")
            }

            override fun onDJXSeekTo(position: Int, time: Long) {
                emitEvent(widgetId, "seekTo", mapOf("position" to position, "time" to time))
            }

            override fun onDJXPageChange(position: Int, map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "pageChange", sanitizeMap(map) + mapOf("position" to position))
            }

            override fun onDJXVideoPlay(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "videoPlay", sanitizeMap(map))
            }

            override fun onDJXVideoPause(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "videoPause", sanitizeMap(map))
            }

            override fun onDJXVideoContinue(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "videoContinue", sanitizeMap(map))
            }

            override fun onDJXVideoCompletion(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "videoCompletion", sanitizeMap(map))
            }

            override fun onDJXVideoOver(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "videoOver", sanitizeMap(map))
            }

            override fun onDJXClose() {
                emitEvent(widgetId, "close", finishOnClose = true)
            }

            override fun onDJXReportResult(isSucceed: Boolean, map: MutableMap<String, Any>?) {
                emitEvent(
                    widgetId,
                    "reportResult",
                    sanitizeMap(map) + mapOf("success" to isSucceed),
                )
            }

            override fun onDJXRequestStart(map: MutableMap<String, Any>?) {
                emitEvent(widgetId, "requestStart", sanitizeMap(map))
            }

            override fun onDJXRequestFail(code: Int, msg: String, map: MutableMap<String, Any>?) {
                emitEvent(
                    widgetId,
                    "requestFail",
                    sanitizeMap(map) + mapOf("code" to code, "message" to msg),
                )
            }

            override fun onDJXRequestSuccess(list: MutableList<MutableMap<String, Any>>?) {
                val payload = list?.map { sanitizeMap(it) } ?: emptyList()
                emitEvent(widgetId, "requestSuccess", mapOf("items" to payload))
            }

            override fun onChannelTabChange(channel: Int) {
                emitEvent(widgetId, "channelTabChange", mapOf("channel" to channel))
            }

            override fun onDurationChange(current: Long) {
                emitEvent(widgetId, "durationChange", mapOf("current" to current))
            }

            override fun createCustomView(container: ViewGroup?, map: MutableMap<String, Any>?): View? {
                // 暂不支持自定义 View，直接返回 null
                return null
            }
        }
        params.listener(drawListener)

        val detailListener = object : IDJXDramaListener() {
            override fun onDJXVideoPlay(map: MutableMap<String, Any>?) {
                emitDetailEvent("videoPlay", map)
            }

            override fun onDJXVideoPause(map: MutableMap<String, Any>?) {
                emitDetailEvent("videoPause", map)
            }

            override fun onDJXVideoContinue(map: MutableMap<String, Any>?) {
                emitDetailEvent("videoContinue", map)
            }

            override fun onDJXPageChange(position: Int, map: MutableMap<String, Any>?) {
                val payload = sanitizeMap(map) + mapOf("position" to position)
                emitDetailEvent("pageChange", payload)
            }

            private fun emitDetailEvent(type: String, map: Map<String, Any?>?) {
                emitEvent(widgetId, type, map ?: emptyMap())
            }

            private fun sanitizeMap(map: Map<String, Any>?): Map<String, Any?> = this@DramaSwipeCoordinator.sanitizeMap(map)
        }
        params.dramaListener(detailListener)

        val detailConfig = createDetailConfig(widgetId, args, detailListener)
        params.mDetailConfig = detailConfig

        (args?.get("bottomOffset") as? Number)?.toInt()?.let { params.mBottomOffset = it }
        (args?.get("titleTopMargin") as? Number)?.toInt()?.let { params.mTitleTopMargin = it }
        (args?.get("titleLeftMargin") as? Number)?.toInt()?.let { params.mTitleLeftMargin = it }
        (args?.get("titleRightMargin") as? Number)?.toInt()?.let { params.mTitleRightMargin = it }
        (args?.get("hideChannelName") as? Boolean)?.let { params.mIsHideChannelName = it }
        (args?.get("hideDramaInfo") as? Boolean)?.let { params.mIsHideDramaInfo = it }
        (args?.get("hideDramaEnter") as? Boolean)?.let { params.mIsHideDramaEnter = it }
        (args?.get("customCategory") as? String)?.let { params.mCustomCategory = it }
        (args?.get("progressBarStyle") as? Number)?.toInt()?.let { params.mProgressBarStyle = it }
        (args?.get("dramaFree") as? Number)?.toInt()?.let { params.mDramaFree = it }
        (args?.get("topDramaId") as? Number)?.toLong()?.let { params.mTopDramaId = it }
        (args?.get("channelType") as? Number)?.toInt()?.let { params.mDrawChannelType = it }

        (args?.get("enableRefresh") as? Boolean)?.let { params.enableRefresh(it) }
        (args?.get("hideClose") as? Boolean)?.let { params.hideClose(it, null) }
        (args?.get("hideLikeButton") as? Boolean)?.let {
            params.hideLikeButton(it)
            detailConfig.hideLikeButton(it)
        }
        (args?.get("hideFavorButton") as? Boolean)?.let {
            params.hideFavorButton(it)
            detailConfig.hideFavorButton(it)
        }
        (args?.get("hideDoubleClickLike") as? Boolean)?.let {
            params.hideDoubleClickLike(it)
            detailConfig.hideDoubleClick(it)
        }

        return params
    }

    private fun createDetailConfig(
        widgetId: String,
        args: Map<*, *>?,
        detailListener: IDJXDramaListener,
    ): DJXDramaDetailConfig {
        val freeSet = (args?.get("freeSet") as? Number)?.toInt()
            ?: (args?.get("dramaFree") as? Number)?.toInt()
            ?: 3
        val unlockCount = (args?.get("unlockEpisodesCount") as? Number)?.toInt()
            ?: (args?.get("lockSet") as? Number)?.toInt()
            ?: 1

        val detailConfig = DJXDramaDetailConfig.obtain(
            DJXDramaUnlockAdMode.MODE_COMMON,
            freeSet,
            object : IDJXDramaUnlockListener {
                override fun unlockFlowStart(
                    drama: DJXDrama,
                    callback: IDJXDramaUnlockListener.UnlockCallback,
                    map: Map<String, Any>?,
                ) {
                    val unlockInfo = DJXDramaUnlockInfo(
                        drama.id,
                        unlockCount,
                        DJXDramaUnlockMethod.METHOD_AD,
                        false,
                    )
                    callback.onConfirm(unlockInfo)
                }

                override fun unlockFlowEnd(
                    drama: DJXDrama,
                    errCode: IDJXDramaUnlockListener.UnlockErrorStatus?,
                    map: Map<String, Any>?,
                ) {
                    logger.debug("unlockFlowEnd: success=${errCode == null}")
                }
            },
        )

        detailConfig.listener(detailListener)
        return detailConfig
    }

    private fun emitEvent(
        widgetId: String,
        type: String,
        params: Map<String, Any?> = emptyMap(),
        finishOnClose: Boolean = false,
    ) {
        if (finishOnClose) {
            sessions[widgetId]?.activity?.get()?.finish()
        }
        val extra = if (params.isEmpty()) emptyMap() else mapOf("params" to params)
        eventHelper.sendEvent(type, contentId = widgetId, extra = extra)
    }

    private fun sanitizeMap(map: Map<*, *>?): Map<String, Any?> {
        if (map == null) return emptyMap()
        val safe = mutableMapOf<String, Any?>()
        map.entries.forEach { (key, value) ->
            val safeKey = key?.toString() ?: return@forEach
            safe[safeKey] = DramaMapper.sanitize(value)
        }
        return safe
    }

    private data class DramaSwipeSession(
        val widgetId: String,
        val widget: IDJXWidget,
        var activity: WeakReference<Activity?>? = null,
    )

    private fun removeSession(widgetId: String) {
        val session = sessions.remove(widgetId)
        if (session != null) {
            session.activity?.get()?.finish()
            runCatching { session.widget.destroy() }
        }
        DramaSwipeActivity.clearFragment(widgetId)
    }
}
