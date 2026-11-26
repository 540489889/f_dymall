package com.zhecent.pangrowth_content.views

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * PlatformView 容器，用于在 Flutter 组件中内嵌短剧播放页。
 */
internal class DramaPlayerPlatformView(
    context: Context,
    private val activity: FragmentActivity,
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private val mainHandler = Handler(Looper.getMainLooper())
        private val activeViews = ConcurrentHashMap<String, WeakReference<DramaPlayerPlatformView>>()

        fun findView(viewId: String): DramaPlayerPlatformView? {
            return activeViews[viewId]?.get()
        }
    }

    private val container: FrameLayout = FrameLayout(context).apply {
        id = View.generateViewId()
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    private val viewId: String = (creationParams?.get("playerId") as? String)
        ?: "drama_player_${UUID.randomUUID()}"

    private var playerId: String? = null
    private var disposed = false

    init {
        activeViews[viewId] = WeakReference(this)
        mainHandler.post { initializePlayer() }
    }

    override fun getView(): View = container

    override fun dispose() {
        disposed = true

        // ✅ 主动发送 drama_player_destroyed 事件
        playerId?.let { id ->
            val payload = mapOf(
                "playerId" to id,
            )
            eventHelper.sendEvent("drama_player_destroyed", contentId = id, extra = payload)
        }

        destroyPlayer()
        activeViews.remove(viewId)
    }

    private fun initializePlayer() {
        if (disposed) return

        if (!sdkManager.isDramaModuleReady()) {
            logger.error("内容 SDK 未启动，无法创建短剧播放页")
            sendError(ContentConstants.ErrorCodes.SDK_NOT_READY, "请先调用 PangrowthContent.start 并确保成功")
            showError("内容 SDK 未启动")
            return
        }

        if (!validationHelper.isAdSdkReady()) {
            logger.error("GroMore 广告 SDK 未初始化")
            sendError(ContentConstants.ErrorCodes.SDK_NOT_READY, "请先完成 GroMore 广告 SDK 初始化")
            showError("广告 SDK 未准备就绪")
            return
        }

        val args = buildCreateArgs() ?: return

        sdkManager.createDramaPlayer(MethodCall("createDramaPlayer", args), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (disposed) {
                    destroyPlayer()
                    return
                }

                val map = result as? Map<*, *> ?: run {
                    sendError("CREATE_FAILED", "createDramaPlayer 返回异常")
                    showError("创建失败")
                    return
                }

                val id = map["playerId"] as? String
                if (id.isNullOrEmpty()) {
                    sendError("CREATE_FAILED", "返回参数缺少 playerId")
                    showError("创建失败")
                    return
                }

                playerId = id

                // ✅ 主动发送 drama_player_created 事件，携带实际的 playerId
                // 确保 Flutter 层能够正确注册 Listener 映射
                val payload = mapOf(
                    "playerId" to id,
                    "dramaId" to args["dramaId"],
                    "episode" to args["episode"],
                )
                eventHelper.sendEvent("drama_player_created", contentId = id, extra = payload)

                attachPlayer(id)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                logger.error("创建短剧播放页失败: $errorCode $errorMessage")
                sendError(errorCode, errorMessage ?: "创建播放页失败")
                showError(errorMessage ?: "创建失败")
            }

            override fun notImplemented() {
                logger.error("createDramaPlayer 未实现")
                sendError("NOT_IMPLEMENTED", "createDramaPlayer 未实现")
                showError("功能未实现")
            }
        })
    }

    private fun buildCreateArgs(): MutableMap<String, Any?>? {
        val args = mutableMapOf<String, Any?>()

        val dramaId = (creationParams?.get("dramaId") as? Number)?.toLong()
        if (dramaId == null || dramaId <= 0) {
            sendError(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空")
            showError("参数错误")
            return null
        }

        args["dramaId"] = dramaId
        val episode = (creationParams?.get("episode") as? Number)?.toInt() ?: 1
        args["episode"] = episode

        (creationParams?.get("groupId") as? Number)?.toInt()?.let { args["groupId"] = it }

        val config = (creationParams?.get("config") as? Map<*, *>)?.mapKeys { it.key.toString() }

        config?.get("adMode")?.let { args["adMode"] = it }
        config?.get("freeSet")?.let { value ->
            (value as? Number)?.toInt()?.let { args["freeSet"] = it }
        }
        config?.get("unlockSet")?.let { value ->
            (value as? Number)?.toInt()?.let { args["unlockSet"] = it }
        }
        config?.get("hideCellularToast")?.let { args["hideCellularToast"] = it }
        config?.get("hideRewardDialog")?.let { args["hideRewardDialog"] = it }
        config?.get("hideMore")?.let { args["hideMore"] = it }
        config?.get("hideBack")?.let { args["hideBack"] = it }
        config?.get("hideTopInfo")?.let { args["hideTopInfo"] = it }
        config?.get("hideBottomInfo")?.let { args["hideBottomInfo"] = it }
        config?.get("hideLikeIcon")?.let { args["hideLikeIcon"] = it }
        config?.get("hideCollectIcon")?.let { args["hideCollectIcon"] = it }
        config?.get("playStartTime")?.let { value ->
            (value as? Number)?.toDouble()?.let { args["playStartTime"] = it }
        }

        // 记录 playerId 作为额外字段，方便事件追踪
        args["playerIdHint"] = viewId

        return args
    }

    private fun attachPlayer(playerId: String) {
        val params = mapOf(
            "playerId" to playerId,
            "containerId" to container.id,
            "addToBackStack" to false,
        )

        sdkManager.showDramaPlayer(MethodCall("showDramaPlayer", params), object : MethodChannel.Result {
            override fun success(result: Any?) {
                logger.debug("短剧播放器嵌入成功 playerId=$playerId")

                // ✅ 主动发送 drama_player_shown 事件
                val payload = mapOf(
                    "playerId" to playerId,
                )
                eventHelper.sendEvent("drama_player_shown", contentId = playerId, extra = payload)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                logger.error("嵌入短剧播放页失败: $errorCode $errorMessage")
                sendError(errorCode, errorMessage ?: "展示播放页失败")
                showError(errorMessage ?: "展示失败")
            }

            override fun notImplemented() {
                logger.error("showDramaPlayer 未实现")
                sendError("NOT_IMPLEMENTED", "showDramaPlayer 未实现")
                showError("功能未实现")
            }
        })
    }

    private fun destroyPlayer() {
        val id = playerId ?: return
        playerId = null

        sdkManager.destroyDramaPlayer(MethodCall("destroyDramaPlayer", mapOf("playerId" to id)), object : MethodChannel.Result {
            override fun success(result: Any?) {
                logger.debug("销毁短剧播放页完成 playerId=$id")
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                logger.error("销毁短剧播放页异常: $errorCode $errorMessage")
            }

            override fun notImplemented() {}
        })
    }

    private fun showError(message: String) {
        if (container.childCount > 0) {
            container.removeAllViews()
        }
        val errorView = View.inflate(container.context, android.R.layout.simple_list_item_1, null)
        val textView = errorView.findViewById(android.R.id.text1) as? android.widget.TextView
        textView?.text = message
        textView?.textAlignment = View.TEXT_ALIGNMENT_CENTER
        textView?.setTextColor(android.graphics.Color.WHITE)
        errorView.setBackgroundColor(0xAA000000.toInt())
        container.addView(errorView)
    }

    private fun sendError(code: String, message: String) {
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "playerId" to viewId,
        )
        eventHelper.sendError(ContentConstants.Events.ERROR, code, message, payload)
    }
}
