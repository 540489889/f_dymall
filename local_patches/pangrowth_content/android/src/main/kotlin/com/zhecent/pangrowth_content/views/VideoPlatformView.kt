package com.zhecent.pangrowth_content.views

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.bytedance.sdk.dp.DPSdk
import com.bytedance.sdk.dp.DPWidgetDrawParams
import com.bytedance.sdk.dp.IDPWidget
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * 沉浸式小视频 PlatformView
 *
 * 使用 IDPWidget 封装穿山甲内容SDK的小视频组件，实现真正的内嵌小视频流。
 * 支持 pause/resume 控制，适用于 TabBar 场景。
 */
internal class VideoPlatformView(
    context: Context,
    private val activity: FragmentActivity,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private val activeViews = ConcurrentHashMap<String, WeakReference<VideoPlatformView>>()

        fun findView(viewId: String): VideoPlatformView? {
            return activeViews[viewId]?.get()
        }
    }

    private val container: FrameLayout
    private val viewId: String = (creationParams?.get("videoId") as? String)
        ?: "video_${UUID.randomUUID()}"

    private var widget: IDPWidget? = null
    private var disposed = false

    init {
        logger.debug("====== VideoPlatformView INIT ======")
        logger.debug("videoId: $viewId")
        logger.debug("creationParams: $creationParams")
        activeViews[viewId] = WeakReference(this)

        // 创建简单的容器布局
        container = FrameLayout(context).apply {
            id = View.generateViewId()
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            visibility = View.VISIBLE
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        logger.debug("Container created with id: ${container.id}")

        // 等待container被添加到view树后再初始化Widget
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                logger.debug("✅ Container已attached到window, 开始初始化Widget")
                container.removeOnAttachStateChangeListener(this)
                // 延迟一帧,确保完全attached
                container.post {
                    initializeWidget()
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
                // 不需要处理
            }
        })

        logger.debug("====== INIT COMPLETE (waiting for attach) ======")
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true

        // 页面销毁时停止播放，释放资源
        try {
            widget?.fragment?.userVisibleHint = false
            logger.debug("视频已暂停 - videoId=$viewId")
        } catch (e: Exception) {
            logger.debug("暂停视频失败: ${e.message}")
        }

        // 然后销毁
        widget?.destroy()
        widget = null
        activeViews.remove(viewId)
    }

    /**
     * 初始化小视频 Widget
     */
    private fun initializeWidget() {
        if (disposed) return

        if (!DPSdk.isStartSuccess()) {
            logger.error("DPSdk 未启动，无法创建小视频")
            sendError(ContentConstants.ErrorCodes.SDK_NOT_READY, "DPSdk 未准备就绪")
            return
        }

        try {
            val contentType = (creationParams?.get("contentType") as? Number)?.toInt() ?: 1
            val autoPlay = (creationParams?.get("autoPlay") as? Boolean) ?: true

            // 创建 Draw 视频流参数
            val params = DPWidgetDrawParams.obtain()
                .adOffset(0)  // 广告偏移
                .drawContentType(
                    when (contentType) {
                        1 -> DPWidgetDrawParams.DRAW_CONTENT_TYPE_ONLY_VIDEO  // 仅小视频
                        2 -> DPWidgetDrawParams.DRAW_CONTENT_TYPE_ONLY_LIVE   // 仅直播
                        3 -> DPWidgetDrawParams.DRAW_CONTENT_TYPE_VIDEO_LIVE  // 小视频+直播
                        else -> DPWidgetDrawParams.DRAW_CONTENT_TYPE_ONLY_VIDEO
                    }
                )

            // 使用 SDK Factory 创建 Draw Widget
            widget = DPSdk.factory().createDraw(params)

            if (widget == null) {
                logger.error("创建小视频 Widget 失败")
                sendError("CREATE_FAILED", "无法创建视频组件")
                return
            }

            // 将 Fragment 添加到容器
            val fragmentManager = activity.supportFragmentManager
            if (!fragmentManager.isStateSaved) {
                try {
                    fragmentManager
                        .beginTransaction()
                        .add(container.id, widget!!.fragment, "video_$viewId")
                        .commitNowAllowingStateLoss()

                    logger.debug("小视频Fragment已添加 - videoId=$viewId")

                    // 如果不自动播放，设置不可见
                    if (!autoPlay) {
                        widget?.fragment?.userVisibleHint = false
                        logger.debug("小视频暂停播放 - videoId=$viewId")
                    } else {
                        widget?.fragment?.userVisibleHint = true
                    }
                } catch (e: Exception) {
                    logger.error("Fragment添加失败: ${e.message}")
                    sendError("FRAGMENT_ADD_ERROR", e.message ?: "Fragment添加失败")
                    return
                }
            } else {
                logger.error("FragmentManager 状态已保存，无法添加 Fragment")
                sendError("FRAGMENT_ERROR", "FragmentManager 状态异常")
            }

        } catch (e: Exception) {
            logger.error("初始化小视频失败: ${e.message}")
            sendError("INIT_ERROR", e.message ?: "初始化失败")
        }
    }

    /**
     * 设置用户可见性，控制播放/暂停
     */
    fun setUserVisibleHint(isVisible: Boolean) {
        widget?.fragment?.userVisibleHint = isVisible
    }

    /**
     * 处理 Flutter 端的方法调用
     */
    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pause" -> {
                setUserVisibleHint(false)
                result.success(true)
            }
            "resume" -> {
                setUserVisibleHint(true)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun sendError(code: String, message: String) {
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "videoId" to viewId,
        )
        eventHelper.sendError(ContentConstants.Events.ERROR, code, message, payload)
    }
}