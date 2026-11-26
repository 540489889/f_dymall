package com.zhecent.pangrowth_content.views

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.IDJXElement
import com.bytedance.sdk.djx.IDJXWidgetFactory
import com.bytedance.sdk.djx.model.DJXError
import com.bytedance.sdk.djx.params.DJXWidgetDramaCardParams
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
 * 短剧卡片 PlatformView
 *
 * 使用 IDJXElement 封装穿山甲内容SDK的短剧卡片组件,实现真正的内嵌卡片。
 * 支持 play/pause/stop 控制,适用于信息流等场景。
 */
internal class DramaCardPlatformView(
    context: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private val activeViews = ConcurrentHashMap<String, WeakReference<DramaCardPlatformView>>()

        fun findView(cardId: String): DramaCardPlatformView? {
            return activeViews[cardId]?.get()
        }
    }

    private val container: FrameLayout
    private val cardId: String = (creationParams?.get("cardId") as? String)
        ?: "drama_card_${UUID.randomUUID()}"

    private var element: IDJXElement? = null
    private var disposed = false

    init {
        Log.d("DramaCard", "====== DramaCardPlatformView INIT ======")
        Log.d("DramaCard", "cardId: $cardId")
        Log.d("DramaCard", "creationParams: $creationParams")
        activeViews[cardId] = WeakReference(this)

        // 创建容器布局
        container = FrameLayout(context).apply {
            id = View.generateViewId()
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            visibility = View.VISIBLE
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        Log.d("DramaCard", "Container created with id: ${container.id}")

        // 等待container被添加到view树后再初始化Widget
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                Log.d("DramaCard", "✅ Container已attached到window, 开始初始化卡片")
                container.removeOnAttachStateChangeListener(this)
                // 延迟一帧,确保完全attached
                container.post {
                    initializeCard()
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
                // 不需要处理
            }
        })

        Log.d("DramaCard", "====== INIT COMPLETE (waiting for attach) ======")
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true

        // 页面销毁时停止播放，释放资源
        try {
            element?.stop()
            Log.d("DramaCard", "卡片已停止 - cardId=$cardId")
        } catch (e: Exception) {
            Log.d("DramaCard", "停止卡片失败: ${e.message}")
        }

        // 然后销毁
        element?.destroy()
        element = null
        activeViews.remove(cardId)
    }

    /**
     * 初始化短剧卡片
     */
    private fun initializeCard() {
        if (disposed) return

        if (!DJXSdk.isStartSuccess()) {
            logger.error("DJXSdk 未启动，无法创建短剧卡片")
            sendError(ContentConstants.ErrorCodes.SDK_NOT_READY, "DJXSdk 未准备就绪")
            return
        }

        try {
            @Suppress("UNCHECKED_CAST")
            val config = (creationParams?.get("config") as? Map<String, Any>) ?: emptyMap()

            val dramaId = (config["dramaId"] as? Number)?.toInt()
            if (dramaId == null) {
                logger.error("dramaId 参数缺失")
                sendError(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空")
                return
            }

            // 构建卡片参数
            val params = buildParams(config)

            // 调用SDK加载卡片
            DJXSdk.factory().loadDramaCard(params, dramaId, object : IDJXWidgetFactory.Callback {
                override fun onSuccess(element: IDJXElement?) {
                    if (element == null) {
                        logger.error("短剧卡片返回空 element")
                        sendError("CARD_ELEMENT_NULL", "短剧卡片组件为空")
                        return
                    }

                    this@DramaCardPlatformView.element = element
                    Log.d("DramaCard", "✅ 卡片加载成功 - dramaId: $dramaId")

                    // 获取卡片View并添加到容器
                    val view = element.view
                    if (view == null) {
                        logger.error("卡片View为空")
                        sendError("CARD_VIEW_NULL", "卡片View为空")
                        return
                    }

                    // 移除旧的parent(如果有)
                    (view.parent as? ViewGroup)?.removeView(view)

                    // 添加到容器
                    container.addView(
                        view,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT
                        )
                    )

                    Log.d("DramaCard", "✅ 卡片View已添加到容器 - cardId=$cardId")

                    // 发送就绪事件
                    sendEvent("cardReady", mapOf("dramaId" to dramaId))
                }

                override fun onError(error: DJXError) {
                    logger.error("加载短剧卡片失败: ${error.msg}")
                    sendError("CARD_LOAD_FAILED", error.msg ?: "加载失败")
                }
            })

        } catch (e: Exception) {
            logger.error("初始化短剧卡片失败: ${e.message}")
            sendError("INIT_ERROR", e.message ?: "初始化失败")
        }
    }

    /**
     * 构建卡片参数
     */
    private fun buildParams(config: Map<String, Any>): DJXWidgetDramaCardParams {
        val params = DJXWidgetDramaCardParams.obtain()

        // 只传递非null参数,让SDK使用原生默认值
        (config["width"] as? Number)?.let { params.width(it.toInt()) }
        (config["hideSoundButton"] as? Boolean)?.let { params.hideSoundButton(it) }
        (config["hideReplayButton"] as? Boolean)?.let { params.hideReplayButton(it) }
        (config["isMuteDefault"] as? Boolean)?.let { params.muteDefault(it) }
        (config["isLooping"] as? Boolean)?.let { params.looping(it) }
        (config["isAutoPlay"] as? Boolean)?.let { params.autoPlay(it) }

        // iOS 专用参数在 Android 端忽略,无需处理 frame/hideActionUI 等

        return params
    }

    /**
     * 播放卡片
     */
    fun play() {
        element?.start()
    }

    /**
     * 暂停卡片
     */
    fun pause() {
        element?.pause()
    }

    /**
     * 停止卡片
     */
    fun stop() {
        element?.stop()
    }

    /**
     * 设置静音
     */
    fun setMute(mute: Boolean) {
        element?.setMute(mute)
    }

    /**
     * 刷新卡片
     */
    fun refresh() {
        element?.refresh()
    }

    /**
     * 上报曝光
     */
    fun reportShow(duration: Long) {
        element?.reportShow(duration)
    }

    /**
     * 查询是否正在播放
     */
    fun isPlaying(): Boolean {
        return element?.isPlaying() ?: false
    }

    /**
     * 获取短剧信息
     */
    fun getInfo(): Map<String, Any?>? {
        val drama = element?.drama ?: return null
        return mapOf(
            "id" to drama.id,
            "title" to drama.title,
            "coverImage" to drama.coverImage,
            "desc" to drama.desc,
        )
    }

    /**
     * 获取短剧GID
     */
    fun getGid(): String? {
        return element?.gid?.toString()
    }

    /**
     * 获取短剧标题
     */
    fun getTitle(): String? {
        return element?.title
    }

    /**
     * 处理 Flutter 端的方法调用
     */
    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                play()
                result.success(true)
            }
            "pause" -> {
                pause()
                result.success(true)
            }
            "stop" -> {
                stop()
                result.success(true)
            }
            "setMute" -> {
                val mute = call.argument<Boolean>("mute") ?: false
                setMute(mute)
                result.success(true)
            }
            "refresh" -> {
                refresh()
                result.success(true)
            }
            "reportShow" -> {
                val duration = call.argument<Number>("duration")?.toLong() ?: 0L
                reportShow(duration)
                result.success(true)
            }
            "isPlaying" -> {
                val isPlaying = element?.isPlaying() ?: false
                result.success(isPlaying)
            }
            "getDramaInfo" -> {
                val drama = element?.drama
                if (drama != null) {
                    result.success(mapOf(
                        "id" to drama.id,
                        "title" to drama.title,
                        "coverImage" to drama.coverImage,
                        "desc" to drama.desc,
                    ))
                } else {
                    result.success(null)
                }
            }
            "getGid" -> {
                result.success(element?.gid)
            }
            "getTitle" -> {
                result.success(element?.title)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun sendEvent(eventType: String, data: Map<String, Any?>) {
        Log.d("DramaCard", ">>> 发送事件: type=$eventType, cardId=$cardId")
        val payload = mutableMapOf<String, Any?>(
            "cardId" to cardId,
            "eventType" to eventType,
        )
        payload.putAll(data)
        eventHelper.sendEvent(ContentConstants.Events.DRAMA_CARD, contentId = cardId, extra = payload)
    }

    private fun sendError(code: String, message: String) {
        Log.e("DramaCard", ">>> 发送错误事件: code=$code, message=$message, cardId=$cardId")
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "cardId" to cardId,
        )
        eventHelper.sendError(ContentConstants.Events.ERROR, code, message, payload)
        Log.e("DramaCard", "<<< 错误事件已发送")
    }
}
