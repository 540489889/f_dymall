package com.zhecent.pangrowth_content.views

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.djx.interfaces.listener.IDJXAdListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaHomeListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaListener
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaUnlockListener
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXDramaDetailConfig
import com.bytedance.sdk.djx.model.DJXDramaUnlockAdMode
import com.bytedance.sdk.djx.model.DJXDramaUnlockInfo
import com.bytedance.sdk.djx.model.DJXDramaUnlockMethod
import com.bytedance.sdk.djx.params.DJXWidgetDramaHomeParams
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.plugin.platform.PlatformView
import java.lang.ref.WeakReference
import java.util.HashMap
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

@SuppressLint("ViewConstructor")
internal class DramaHomePlatformView(
    private val context: Context,
    private val activity: FragmentActivity,
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private const val TAG = "DramaHomeView"
        private val mainHandler = Handler(Looper.getMainLooper())
        private var activeViewId: String? = null
        private val activeViews = ConcurrentHashMap<String, WeakReference<DramaHomePlatformView>>()

        fun findView(viewId: String): DramaHomePlatformView? {
            return activeViews[viewId]?.get()
        }
    }

    private val container: FrameLayout = FrameLayout(context)
    private val viewId: String = (creationParams?.get("viewId") as? String)
        ?: "drama_home_${UUID.randomUUID()}"

    private var widget: IDJXWidget? = null
    private var fragment: Fragment? = null
    private var destroyed = false

    init {
        require(activeViewId == null) {
            "已存在短剧聚合页实例，创建前请先销毁上一实例"
        }
        activeViewId = viewId
        activeViews[viewId] = WeakReference(this)
        container.id = View.generateViewId()
        container.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )

        mainHandler.post { createDramaHomeInternal() }
    }

    override fun getView(): View = container

    override fun dispose() {
        destroyInternal()
    }

    private fun ensureSdkReady(): Boolean {
        if (!sdkManager.isDramaModuleReady()) {
            logger.error("内容 SDK 未启动，无法创建聚合页")
            eventHelper.sendError(
                ContentConstants.Events.ERROR,
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "请先调用 PangrowthContent.start 并确保 start 返回成功",
                mapOf("contentId" to viewId, "scene" to "drama_home"),
            )
            return false
        }

        if (!validationHelper.isAdSdkReady()) {
            logger.error("GroMore 广告 SDK 未初始化或未准备就绪")
            eventHelper.sendError(
                ContentConstants.Events.ERROR,
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "请先完成 GroMore 广告 SDK 初始化",
                mapOf("contentId" to viewId, "scene" to "drama_home"),
            )
            return false
        }
        return true
    }

    private fun createDramaHomeInternal() {
        if (!ensureSdkReady()) {
            activeViewId = null
            activeViews.remove(viewId)
            return
        }

        try {
            val params = buildWidgetParams()
            widget = DJXSdk.factory().createDramaHome(params)
            if (widget == null) {
                throw IllegalStateException("createDramaHome 返回 null")
            }
            fragment = widget!!.fragment
            if (fragment == null) {
                throw IllegalStateException("createDramaHome 未提供 Fragment")
            }

            attachFragment(fragment!!)
            emitEvent("drama_home_show", mapOf("success" to true))
        } catch (error: Throwable) {
            logger.error("创建短剧聚合页失败: ${error.message}", error)
            emitError("create_fail", error.message ?: "createDramaHome exception")
            destroyInternal()
        }
    }

    private fun attachFragment(target: Fragment) {
        val manager: FragmentManager = activity.supportFragmentManager
        manager.beginTransaction()
            .replace(container.id, target, viewId)
            .commitNowAllowingStateLoss()
    }

    private fun buildWidgetParams(): DJXWidgetDramaHomeParams {
        val configMap = (creationParams?.get("config") as? Map<*, *>)?.let { toMutableConfig(it) }
            ?: mutableMapOf()

        val detailConfig = createDetailConfig(configMap)
        val params = DJXWidgetDramaHomeParams.obtain(detailConfig)

        (configMap["showChangeBtn"] as? Boolean)?.let { params.showChangeBtn(it) }
        (configMap["showPageTitle"] as? Boolean)?.let { params.showPageTitle(it) }
        (configMap["showBackBtn"] as? Boolean)?.let { params.showBackBtn(it) }
        (configMap["topOffset"] as? Int)?.let { params.setTopOffset(it) }
        (configMap["topDramaId"] as? Int)?.let { params.topDramaId(it) }

        val topIds = configMap["topDramaIds"]
        if (topIds is List<*>) {
            params.mTopDramaIds = topIds.filterIsInstance<String>()
        }

        params.listener(object : IDJXDramaHomeListener() {
            override fun onItemClick(drama: DJXDrama?, map: MutableMap<String, Any>?) {
                super.onItemClick(drama, map)
                emitEvent(
                    "drama_home_item_click",
                    mapOf(
                        "drama" to drama?.let { dramaToMap(it) },
                        "extra" to map?.toMap(),
                    ),
                )
            }
        })
        return params
    }

    private fun createDetailConfig(configMap: MutableMap<String, Any?>): DJXDramaDetailConfig {
        val freeEpisodes = configMap["freeEpisodesCount"] as? Int ?: 5
        val unlockListener = object : IDJXDramaUnlockListener {
            override fun unlockFlowStart(
                drama: DJXDrama,
                callback: IDJXDramaUnlockListener.UnlockCallback,
                map: Map<String, Any>?,
            ) {
                emitEvent(
                    "drama_unlock_start",
                    mapOf(
                        "drama" to dramaToMap(drama),
                        "extras" to map,
                    ),
                )

                val unlockCount = configMap["unlockEpisodesCountUsingAD"] as? Int ?: 5
                val info = DJXDramaUnlockInfo(
                    drama.id,
                    unlockCount,
                    DJXDramaUnlockMethod.METHOD_AD,
                    false,
                )
                callback.onConfirm(info)
            }

            override fun unlockFlowEnd(
                drama: DJXDrama,
                errCode: IDJXDramaUnlockListener.UnlockErrorStatus?,
                map: Map<String, Any>?,
            ) {
                emitEvent(
                    "drama_unlock_end",
                    mapOf(
                        "drama" to dramaToMap(drama),
                        "errCode" to errCode?.name,
                        "extras" to map,
                    ),
                )
            }
        }

        val detailConfig = DJXDramaDetailConfig.obtain(
            DJXDramaUnlockAdMode.MODE_COMMON,
            freeEpisodes,
            unlockListener,
        )

        (configMap["hideTopInfo"] as? Boolean)?.let { detailConfig.hideTopInfo(it) }
        (configMap["hideBottomInfo"] as? Boolean)?.let { detailConfig.hideBottomInfo(it) }
        (configMap["hideBack"] as? Boolean)?.let { detailConfig.hideBack(it, null) }
        (configMap["hideMore"] as? Boolean)?.let { detailConfig.hideMore(it) }
        (configMap["hideLikeIcon"] as? Boolean)?.let { detailConfig.hideLikeButton(it) }
        (configMap["hideFavorIcon"] as? Boolean)?.let { detailConfig.hideFavorButton(it) }
        (configMap["hideRewardDialog"] as? Boolean)?.let { detailConfig.hideRewardDialog(it) }
        (configMap["enableInfiniteScroll"] as? Boolean)?.let { detailConfig.infiniteScrollEnabled(it) }

        detailConfig.listener(createDramaListener())
        detailConfig.adListener(createAdListener())
        return detailConfig
    }

    private fun createDramaListener(): IDJXDramaListener {
        return object : IDJXDramaListener() {
            override fun onDJXSeekTo(position: Int, time: Long) {
                emitEvent("seekTo", mapOf("position" to position, "time" to time))
            }

            override fun onDJXPageChange(position: Int, map: Map<String, Any>) {
                emitEvent("pageChange", mapOf("position" to position, "extra" to map))
            }

            override fun onDJXVideoPlay(map: Map<String, Any>) {
                emitEvent("videoPlay", map)
            }

            override fun onDJXVideoPause(map: Map<String, Any>) {
                emitEvent("videoPause", map)
            }

            override fun onDJXVideoContinue(map: Map<String, Any>) {
                emitEvent("videoContinue", map)
            }

            override fun onDJXVideoCompletion(map: Map<String, Any>) {
                emitEvent("videoCompletion", map)
            }

            override fun onDJXVideoOver(map: Map<String, Any>) {
                emitEvent("videoOver", map)
            }

            override fun onDJXClose() {
                emitEvent("close", emptyMap())
            }

            override fun onDJXRequestStart(map: Map<String, Any>?) {
                emitEvent("requestStart", map ?: emptyMap())
            }

            override fun onDJXRequestFail(code: Int, msg: String, map: Map<String, Any>?) {
                emitEvent(
                    "requestFail",
                    mapOf(
                        "code" to code,
                        "message" to msg,
                        "extra" to map,
                    ),
                )
            }

            override fun onDJXRequestSuccess(list: List<Map<String, Any>>) {
                emitEvent("requestSuccess", mapOf("list" to list))
            }
        }
    }

    private fun createAdListener(): IDJXAdListener {
        return object : IDJXAdListener() {
            override fun onDJXAdRequest(map: Map<String, Any>?) {
                emitEvent("drama_ad_request", map?.let { HashMap<String, Any?>(it) })
            }

            override fun onDJXAdRequestSuccess(map: Map<String, Any>?) {
                emitEvent("drama_ad_request_success", map?.let { HashMap<String, Any?>(it) })
            }

            override fun onDJXAdRequestFail(code: Int, msg: String, map: Map<String, Any>?) {
                emitEvent(
                    "drama_ad_request_fail",
                    mapOf(
                        "code" to code,
                        "message" to msg,
                        "extra" to map,
                    ),
                )
            }

            override fun onDJXAdShow(map: Map<String, Any>?) {
                emitEvent("drama_ad_show", map?.let { HashMap<String, Any?>(it) })
            }

            override fun onDJXAdClicked(map: Map<String, Any>?) {
                emitEvent("drama_ad_click", map?.let { HashMap<String, Any?>(it) })
            }
        }
    }

    private fun emitEvent(type: String, payload: Map<String, Any?>?) {
        val extra = mutableMapOf<String, Any?>("contentId" to viewId, "type" to type)
        extra["eventType"] = normalizeEventType(type)
        payload?.let { extra.putAll(it) }
        eventHelper.sendEvent(type, contentId = viewId, extra = extra)
    }

    private fun normalizeEventType(type: String): String {
        return when (type) {
            "drama_home_item_click" -> "itemClick"
            "drama_home_search" -> "search"
            "drama_home_category_switch" -> "categorySwitch"
            "drama_home_refresh" -> "refresh"
            "drama_home_load_more" -> "loadMore"
            "drama_home_show" -> "pageShow"
            "drama_home_hide" -> "pageHide"
            "drama_home_destroyed" -> "destroyed"
            else -> type
        }
    }

    private fun emitError(stage: String, message: String) {
        eventHelper.sendError(
            ContentConstants.Events.ERROR,
            ContentConstants.ErrorCodes.SDK_NOT_READY,
            message,
            mapOf("contentId" to viewId, "stage" to stage),
        )
    }

    private fun destroyInternal() {
        if (destroyed) {
            return
        }
        destroyed = true
        activeViewId = null
        activeViews.remove(viewId)
        mainHandler.post {
            try {
                fragment?.let {
                    activity.supportFragmentManager.beginTransaction()
                        .remove(it)
                        .commitAllowingStateLoss()
                }
                widget?.destroy()
                emitEvent("drama_home_destroyed", mapOf("success" to true))
            } catch (error: Throwable) {
                logger.error("销毁短剧聚合页异常: ${error.message}", error)
            } finally {
                fragment = null
                widget = null
            }
        }
    }

    private fun toMutableConfig(source: Map<*, *>): MutableMap<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        for ((key, value) in source.entries) {
            if (key is String) {
                map[key] = value
            }
        }
        return map
    }

    private fun dramaToMap(drama: DJXDrama): Map<String, Any?> {
        return mapOf(
            "id" to drama.id,
            "title" to drama.title,
            "coverImage" to drama.coverImage,
            "desc" to drama.desc,
            "index" to drama.index,
            "total" to drama.total,
            "status" to drama.status,
            "type" to drama.type,
            "isFavor" to drama.isFavor,
            "favoriteCount" to drama.favoriteCount,
        )
    }

    fun destroyOnCommand() {
        destroyInternal()
    }
}

private fun Map<String, Any>.toMap(): Map<String, Any> = HashMap(this)
