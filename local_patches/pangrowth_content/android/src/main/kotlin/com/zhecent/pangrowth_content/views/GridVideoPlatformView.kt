package com.zhecent.pangrowth_content.views

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.managers.VideoManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.platform.PlatformView
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

internal class GridVideoPlatformView(
    context: Context,
    private val activity: FragmentActivity,
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private const val LOG_PREFIX = "[PC][GridNative]"
        private val activeViews = ConcurrentHashMap<String, WeakReference<GridVideoPlatformView>>()

        fun findView(gridId: String): GridVideoPlatformView? {
            return activeViews[gridId]?.get()
        }
    }

    private val container: FrameLayout = FrameLayout(context).apply {
        id = View.generateViewId()
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    private val gridId: String = (creationParams?.get("gridId") as? String)
        ?: "grid_${System.currentTimeMillis()}"
    private val layout: String = (creationParams?.get("layout") as? String)?.lowercase() ?: "grid"
    private val configMap: Map<String, Any>? = creationParams?.get("config") as? Map<String, Any>

    private var session: VideoManager.GridWidgetSession? = null
    private var disposed = false

    init {
        activeViews[gridId] = WeakReference(this)
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                container.removeOnAttachStateChangeListener(this)
                container.post { initializeWidget() }
            }

            override fun onViewDetachedFromWindow(v: View) {
                // no-op
            }
        })
    }

    private fun initializeWidget() {
        if (disposed || session != null) return
        try {
            val extraMap = (creationParams?.get("extra") as? Map<String, Any>) ?: emptyMap()
            val mergedConfig = configMap?.toMutableMap() ?: mutableMapOf()
            if (extraMap.isNotEmpty()) {
                mergedConfig.putAll(extraMap)
            }

            val sdkSession = sdkManager.createGridWidgetSession(mergedConfig, layout, gridId)
            session = sdkSession

            if (!sdkManager.attachGridWidget(gridId, container.id)) {
                throw IllegalStateException("Failed to attach grid widget")
            }

            logger.debug("$LOG_PREFIX PlatformView init gridId=$gridId layout=$layout", "GridVideoPlatformView")
        } catch (error: Throwable) {
            logger.error("$LOG_PREFIX PlatformView init failed", error, "GridVideoPlatformView")
            sendError("INIT_ERROR", error.message ?: "initialize failed")
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true
        logger.debug("$LOG_PREFIX PlatformView dispose gridId=$gridId", "GridVideoPlatformView")

        // 页面销毁时停止播放，释放资源
        try {
            sdkManager.setGridVideoUserVisibleDirect(gridId, false)
            logger.debug("$LOG_PREFIX 宫格视频已暂停", "GridVideoPlatformView")
        } catch (e: Exception) {
            logger.debug("$LOG_PREFIX 暂停失败: ${e.message}", "GridVideoPlatformView")
        }

        activeViews.remove(gridId)
        session = null
        sdkManager.destroyGridVideoDirect(gridId)
    }

    fun refresh(): Boolean = sdkManager.refreshGridVideoDirect(gridId)

    fun scrollToTop(): Boolean = sdkManager.scrollGridVideoToTopDirect(gridId)

    fun backRefresh(): Boolean = sdkManager.backRefreshGridVideoDirect(gridId)

    fun setUserVisible(isVisible: Boolean): Boolean = sdkManager.setGridVideoUserVisibleDirect(gridId, isVisible)

    fun canBackPress(): Boolean? = sdkManager.canBackPressGridVideoDirect(gridId)

    private fun sendError(code: String, message: String) {
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "gridId" to gridId,
        )
        eventHelper.sendEvent("onGridVideoError", contentId = gridId, extra = payload)
    }
}
