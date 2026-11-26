package com.zhecent.pangrowth_content.views

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaUnlockListener
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXDramaDetailConfig
import com.bytedance.sdk.djx.model.DJXDramaUnlockAdMode
import com.bytedance.sdk.djx.model.DJXDramaUnlockInfo
import com.bytedance.sdk.djx.model.DJXDramaUnlockMethod
import com.bytedance.sdk.djx.params.DJXWidgetDrawParams
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
 * 短剧剧场 PlatformView
 *
 * 使用 IDJXWidget 封装穿山甲内容SDK的短剧滑滑流组件，实现真正的内嵌剧场流。
 * 支持 pause/resume 控制，适用于 TabBar 场景。
 */
internal class DramaSwipeFlowPlatformView(
    context: Context,
    private val activity: FragmentActivity,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private val activeViews = ConcurrentHashMap<String, WeakReference<DramaSwipeFlowPlatformView>>()

        fun findView(swipeFlowId: String): DramaSwipeFlowPlatformView? {
            return activeViews[swipeFlowId]?.get()
        }
    }

    private val container: FrameLayout
    private val swipeFlowId: String = (creationParams?.get("swipeFlowId") as? String)
        ?: "swipe_flow_${UUID.randomUUID()}"

    private var widget: IDJXWidget? = null
    private var disposed = false

    init {
        Log.d("DramaSwipeFlow", "====== DramaSwipeFlowPlatformView INIT ======")
        Log.d("DramaSwipeFlow", "swipeFlowId: $swipeFlowId")
        Log.d("DramaSwipeFlow", "creationParams: $creationParams")
        activeViews[swipeFlowId] = WeakReference(this)

        // 创建简单的容器布局
        container = FrameLayout(context).apply {
            id = View.generateViewId()
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            // 显式设置可见性和背景
            visibility = View.VISIBLE
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        Log.d("DramaSwipeFlow", "Container created with id: ${container.id}")

        // 等待container被添加到view树后再初始化Widget
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                Log.d("DramaSwipeFlow", "✅ Container已attached到window, 开始初始化Widget")
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

        Log.d("DramaSwipeFlow", "====== INIT COMPLETE (waiting for attach) ======")
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true

        // 页面销毁时停止播放，释放资源
        try {
            widget?.fragment?.userVisibleHint = false
            logger.debug("短剧滑滑流已暂停 - swipeFlowId=$swipeFlowId")
        } catch (e: Exception) {
            logger.debug("暂停短剧滑滑流失败: ${e.message}")
        }

        // 然后销毁
        widget?.destroy()
        widget = null
        activeViews.remove(swipeFlowId)
    }

    /**
     * 初始化剧场 Widget
     */
    private fun initializeWidget() {
        if (disposed) return

        if (!DJXSdk.isStartSuccess()) {
            logger.error("DJXSdk 未启动，无法创建短剧剧场")
            sendError(ContentConstants.ErrorCodes.SDK_NOT_READY, "DJXSdk 未准备就绪")
            return
        }

        try {
            @Suppress("UNCHECKED_CAST")
            val config = (creationParams?.get("config") as? Map<String, Any>) ?: emptyMap()

            val channelType = (config["channelType"] as? Number)?.toInt() ?: 1
            val detailFree = (config["detailFree"] as? Number)?.toInt() ?: 5
            val unlockCount = (config["unlockCount"] as? Number)?.toInt() ?: 1
            val unlockAdMode = (config["unlockAdMode"] as? Number)?.toInt() ?: 0
            val hideTopInfo = (config["hideTopInfo"] as? Boolean) ?: false
            val hideBottomInfo = (config["hideBottomInfo"] as? Boolean) ?: false
            val hideLikeButton = (config["hideLikeButton"] as? Boolean) ?: false
            val hideFavorButton = (config["hideFavorButton"] as? Boolean) ?: false
            val showChangeBtn = (config["showChangeBtn"] as? Boolean) ?: true
            val hideBack = (config["hideBack"] as? Boolean) ?: true
            val setTopOffset = (config["setTopOffset"] as? Number)?.toInt() ?: 0
            val setBottomOffset = (config["setBottomOffset"] as? Number)?.toInt() ?: 0
            val autoPlay = (config["autoPlay"] as? Boolean) ?: true

            // 创建解锁监听器
            val unlockListener = object : IDJXDramaUnlockListener {
                override fun unlockFlowStart(
                    drama: DJXDrama,
                    callback: IDJXDramaUnlockListener.UnlockCallback,
                    map: Map<String, Any>?
                ) {
                    val unlockInfo = DJXDramaUnlockInfo(
                        drama.id,
                        unlockCount,
                        DJXDramaUnlockMethod.METHOD_AD,
                        false
                    )
                    callback.onConfirm(unlockInfo)
                    Log.d("DramaSwipeFlow", "unlockFlowStart: ${drama.id}, episodes: $unlockCount")
                }

                override fun unlockFlowEnd(
                    drama: DJXDrama,
                    errCode: IDJXDramaUnlockListener.UnlockErrorStatus?,
                    map: Map<String, Any>?
                ) {
                    Log.d("DramaSwipeFlow", "unlockFlowEnd: ${drama.id}, error: $errCode")
                }
            }

            // 创建短剧详情配置
            val detailConfig = DJXDramaDetailConfig.obtain(
                when (unlockAdMode) {
                    0 -> DJXDramaUnlockAdMode.MODE_COMMON
                    1 -> DJXDramaUnlockAdMode.MODE_SPECIFIC
                    else -> DJXDramaUnlockAdMode.MODE_COMMON
                },
                detailFree,
                unlockListener
            ).apply {
                hideTopInfo(hideTopInfo)
                hideBottomInfo(hideBottomInfo)
                hideLikeButton(hideLikeButton)
                hideFavorButton(hideFavorButton)

                if (hideBack) {
                    hideBack(true, null)
                }

                if (setTopOffset > 0) {
                    setTopOffset(setTopOffset)
                }
                if (setBottomOffset > 0) {
                    setBottomOffset(setBottomOffset)
                }
            }

            // 创建 Draw 剧场参数
            val params = DJXWidgetDrawParams.obtain()
                .adOffset(0)
                .drawContentType(DJXWidgetDrawParams.DRAW_CONTENT_TYPE_ONLY_DRAMA)
                .drawChannelType(
                    when (channelType) {
                        1 -> DJXWidgetDrawParams.DRAW_CHANNEL_TYPE_RECOMMEND
                        2 -> DJXWidgetDrawParams.DRAW_CHANNEL_TYPE_THEATER
                        3 -> DJXWidgetDrawParams.DRAW_CHANNEL_TYPE_RECOMMEND_THEATER
                        else -> DJXWidgetDrawParams.DRAW_CHANNEL_TYPE_RECOMMEND
                    }
                )
                .hideClose(hideBack, null)
                .hideChannelName(!showChangeBtn)
                .detailConfig(detailConfig)

            // 使用 SDK Factory 创建 Draw Widget
            widget = DJXSdk.factory().createDraw(params)

            if (widget == null) {
                logger.error("创建短剧剧场 Widget 失败")
                sendError("CREATE_FAILED", "无法创建剧场组件")
                return
            }

            // 将 Fragment 添加到容器
            val fragmentManager = activity.supportFragmentManager
            if (!fragmentManager.isStateSaved) {
                try {
                    fragmentManager
                        .beginTransaction()
                        .add(container.id, widget!!.fragment, "drama_swipe_flow_$swipeFlowId")
                        .commitNowAllowingStateLoss()

                    logger.debug("短剧滑滑流Fragment已添加 - swipeFlowId=$swipeFlowId")

                    // 如果不自动播放，设置Fragment不可见来暂停播放
                    if (!autoPlay) {
                        widget?.fragment?.userVisibleHint = false
                        logger.debug("短剧滑滑流暂停播放 - swipeFlowId=$swipeFlowId")
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
            logger.error("初始化短剧剧场失败: ${e.message}")
            sendError("INIT_ERROR", e.message ?: "初始化失败")
        }
    }

    /**
     * 暂停剧场播放（通过设置 Fragment 可见性）
     *
     * 使用 Fragment.userVisibleHint 属性来控制播放器的暂停/恢复，
     * 这是 Fragment 专门用于 ViewPager 等场景的可见性控制机制。
     *
     * userVisibleHint 比直接调用生命周期方法更可靠：
     * - 设置为 false 时，Fragment 会自动暂停内部的播放器
     * - 不会触发完整的生命周期，避免资源释放
     */
    fun pause() {
        widget?.fragment?.userVisibleHint = false
    }

    /**
     * 恢复剧场播放（通过设置 Fragment 可见性）
     *
     * 使用 Fragment.userVisibleHint 属性来控制播放器的暂停/恢复，
     * 这是 Fragment 专门用于 ViewPager 等场景的可见性控制机制。
     *
     * userVisibleHint 比直接调用生命周期方法更可靠：
     * - 设置为 true 时，Fragment 会自动恢复内部的播放器
     * - 不会触发完整的生命周期，避免重新初始化
     */
    fun resume() {
        widget?.fragment?.userVisibleHint = true
    }

    /**
     * 处理 Flutter 端的方法调用
     */
    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pause" -> {
                pause()
                result.success(true)
            }
            "resume" -> {
                resume()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun sendError(code: String, message: String) {
        Log.e("DramaSwipeFlow", ">>> 发送错误事件: code=$code, message=$message, swipeFlowId=$swipeFlowId")
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "swipeFlowId" to swipeFlowId,
        )
        eventHelper.sendError(ContentConstants.Events.ERROR, code, message, payload)
        Log.e("DramaSwipeFlow", "<<< 错误事件已发送")
    }
}