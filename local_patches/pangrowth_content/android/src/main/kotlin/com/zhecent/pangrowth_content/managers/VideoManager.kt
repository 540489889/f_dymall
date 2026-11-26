package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import com.bytedance.sdk.dp.DPSdk
import com.bytedance.sdk.dp.IDPWidgetFactory
import com.bytedance.sdk.dp.IDPWidget
import com.bytedance.sdk.dp.DPWidgetDrawParams
import com.bytedance.sdk.dp.IDPDrawListener
import com.bytedance.sdk.dp.IDPAdListener
import com.bytedance.sdk.dp.DPWidgetGridParams
import com.bytedance.sdk.dp.IDPGridListener
import com.bytedance.sdk.dp.IDPElement
import com.bytedance.sdk.dp.DPWidgetVideoCardParams
import com.bytedance.sdk.dp.IDPVideoCardListener
import com.bytedance.sdk.dp.DPWidgetVideoSingleCardParams
import com.bytedance.sdk.dp.IDPVideoSingleCardListener
import com.bytedance.sdk.dp.DPRole
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import java.util.HashMap
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * 小视频管理器
 * 负责处理沉浸式小视频功能
 * 基于DPSdk官方API实现
 */
class VideoManager(
    private val context: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
) {

    companion object {
        private const val TAG = "VideoManager"
        private const val LOG_PREFIX_GRID = "[PC][GridNative]"

        /**
         * 清洗事件数据,移除不可序列化的对象
         *
         * Flutter 的 StandardMessageCodec 只支持基本类型:
         * - null
         * - Boolean
         * - Number (Int, Long, Double, etc.)
         * - String
         * - ByteArray
         * - List
         * - Map
         *
         * SDK 回调中可能包含自定义对象(如混淆后的类),会导致序列化失败崩溃
         */
        private fun sanitizeEventData(data: Any?): Any? {
            return when (data) {
                null -> null
                is Boolean, is Number, is String -> data
                is ByteArray -> data
                is Map<*, *> -> {
                    data.mapNotNull { (k, v) ->
                        val key = k?.toString() ?: return@mapNotNull null
                        val value = sanitizeEventData(v)
                        if (value != null || v == null) key to value else null
                    }.toMap()
                }
                is List<*> -> {
                    data.mapNotNull { sanitizeEventData(it) }
                }
                else -> {
                    // 不可序列化对象,记录日志后返回 null
                    Log.w(TAG, "Filtered unsupported type: ${data.javaClass.name} = $data")
                    null
                }
            }
        }
    }

    private var activity: Activity? = null
    private val videoWidgets = ConcurrentHashMap<String, IDPWidget>()
    private val videoDrawListeners = ConcurrentHashMap<String, VideoDrawListener>()
    private val videoAdListeners = ConcurrentHashMap<String, VideoAdListener>()

    // 宫格视频相关
    private val gridVideoWidgets = ConcurrentHashMap<String, IDPWidget>()
    private val gridVideoListeners = ConcurrentHashMap<String, VideoGridListener>()
    private val gridVideoLayouts = ConcurrentHashMap<String, GridWidgetLayout>()

    // 小视频卡片相关
    private val videoCardElements = ConcurrentHashMap<String, IDPElement>()
    private val videoCardListeners = ConcurrentHashMap<String, VideoCardListener>()

    // 小视频单卡片相关
    private val videoSingleCardElements = ConcurrentHashMap<String, IDPElement>()
    private val videoSingleCardListeners = ConcurrentHashMap<String, VideoSingleCardListener>()

    fun cleanup() {
        videoWidgets.keys.toList().forEach { destroyVideoInternal(it) }
        gridVideoWidgets.keys.toList().forEach { destroyGridVideoInternal(it) }
        videoCardElements.keys.toList().forEach { destroyVideoCardInternal(it) }
        videoSingleCardElements.keys.toList().forEach { destroyVideoSingleCardInternal(it) }
    }

    internal enum class GridWidgetLayout {
        GRID,
        DOUBLE_FEED,
    }

    internal data class GridWidgetSession(
        val videoId: String,
        val widget: IDPWidget,
    )

    private fun removeFragmentByTag(tag: String) {
        val fragmentActivity = activity as? FragmentActivity ?: return
        val fragmentManager = fragmentActivity.supportFragmentManager
        val fragment = fragmentManager.findFragmentByTag(tag) ?: return
        fragmentManager.beginTransaction()
            .remove(fragment)
            .commitAllowingStateLoss()
    }

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    /**
     * 创建沉浸式小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createVideo(call: MethodCall, result: Result) {
        Log.d(TAG, "createVideo called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity
            if (activity !is FragmentActivity) {
                result.error("ACTIVITY_ERROR", "Activity must be FragmentActivity", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createDrawParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val drawListener = VideoDrawListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoDrawListeners[videoId] = drawListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(drawListener)
            params.adListener(adListener)

            // 创建小视频组件
            val factory = DPSdk.factory()
            val widget = factory.createDraw(params)

            if (widget == null) {
                result.error("CREATE_FAILED", "Failed to create video widget", null)
                return
            }

            videoWidgets[videoId] = widget

            val resultMap = mapOf(
                "videoId" to videoId,
                "success" to true
            )

            result.success(resultMap)
            Log.d(TAG, "Video created successfully with ID: $videoId")

        } catch (e: Exception) {
            Log.e(TAG, "Error creating video", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 展示小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun showVideo(call: MethodCall, result: Result) {
        Log.d(TAG, "showVideo called")

        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            val activity = this.activity
            if (activity !is FragmentActivity) {
                result.error("ACTIVITY_ERROR", "Activity must be FragmentActivity", null)
                return
            }

            // 获取Fragment并添加到Activity中
            val fragment = widget.fragment
            val fragmentManager = activity.supportFragmentManager

            // 检查containerId参数（Android专用）
            val containerId = call.argument<Int>("containerId") ?: android.R.id.content

            fragmentManager.beginTransaction()
                .replace(containerId, fragment, "video_fragment_$videoId")
                .commitAllowingStateLoss()

            val resultMap = mapOf(
                "videoId" to videoId,
                "shown" to true
            )

            result.success(resultMap)
            Log.d(TAG, "Video shown successfully: $videoId")

        } catch (e: Exception) {
            Log.e(TAG, "Error showing video", e)
            result.error("SHOW_ERROR", e.message, null)
        }
    }

    /**
     * 刷新小视频数据
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun refreshVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.refresh()

            result.success(mapOf(
                "videoId" to videoId,
                "refreshed" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing video", e)
            result.error("REFRESH_ERROR", e.message, null)
        }
    }

    /**
     * 回到顶部
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun scrollToTop(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.scrollToTop()

            result.success(mapOf(
                "videoId" to videoId,
                "scrolled" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error scrolling to top", e)
            result.error("SCROLL_ERROR", e.message, null)
        }
    }

    /**
     * 用户返回时的挽留刷新
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun backRefresh(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.backRefresh()

            result.success(mapOf(
                "videoId" to videoId,
                "backRefreshed" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error back refresh", e)
            result.error("BACK_REFRESH_ERROR", e.message, null)
        }
    }

    /**
     * 销毁小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun destroyVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val (destroyed, message) = destroyVideoInternal(videoId)
            val response = mutableMapOf<String, Any?>(
                "videoId" to videoId,
                "destroyed" to destroyed,
            )
            message?.let { response["message"] = it }
            result.success(response)
            if (destroyed) {
                Log.d(TAG, "Video destroyed successfully: $videoId")
            } else {
                Log.w(TAG, "Video destroy skipped: $videoId, reason=${message ?: "unknown"}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error destroying video", e)
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    /**
     * 设置唤醒数据
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun setAwakeData(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            val data = call.argument<String>("data")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            if (data.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "data cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.setAwakeData(data)

            result.success(mapOf(
                "videoId" to videoId,
                "success" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error setting awake data", e)
            result.error("SET_AWAKE_DATA_ERROR", e.message, null)
        }
    }

    /**
     * 播放指定位置视频到指定时间点
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun seekToPosition(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            val position = call.argument<Int>("position")
            val time = call.argument<Long>("time")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            if (position == null || time == null) {
                result.error("INVALID_PARAM", "position and time cannot be null", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.seekTo(time.toLong())

            result.success(mapOf(
                "videoId" to videoId,
                "position" to position,
                "time" to time,
                "success" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error seeking to position", e)
            result.error("SEEK_TO_POSITION_ERROR", e.message, null)
        }
    }

    /**
     * 设置播放特定位置的视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun setCurrentPage(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            val position = call.argument<Int>("position")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            if (position == null) {
                result.error("INVALID_PARAM", "position cannot be null", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            val success = widget.setCurrentPage(position)

            result.success(mapOf(
                "videoId" to videoId,
                "position" to position,
                "success" to success
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error setting current page", e)
            result.error("SET_CURRENT_PAGE_ERROR", e.message, null)
        }
    }

    /**
     * 设置播放数据（一起看视频功能）
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun setSyncData(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            val data = call.argument<String>("data")
            val type = call.argument<Int>("type")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            if (data.isNullOrEmpty() || type == null) {
                result.error("INVALID_PARAM", "data and type cannot be null", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            // 创建监听器来处理同步数据结果
            val listener = object : IDPWidgetFactory.IEnterListener {
                override fun onEnterResult(result_code: Int, msg: String?) {
                    result.success(mapOf(
                        "videoId" to videoId,
                        "isSuccess" to (result_code == 0), // 0表示成功
                        "message" to (msg ?: ""),
                        "type" to type,
                        "resultCode" to result_code
                    ))
                }
            }

            widget.setSyncData(data, type, listener)

        } catch (e: Exception) {
            Log.e(TAG, "Error setting sync data", e)
            result.error("SET_SYNC_DATA_ERROR", e.message, null)
        }
    }

    /**
     * 一起看视频 - 暂停播放
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun pauseForWatchTogether(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.pauseForWatchTogether()

            result.success(mapOf(
                "videoId" to videoId,
                "paused" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error pausing for watch together", e)
            result.error("PAUSE_FOR_WATCH_TOGETHER_ERROR", e.message, null)
        }
    }

    /**
     * 一起看视频 - 恢复播放
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun resumeForWatchTogether(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")

            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val widget = videoWidgets[videoId]
            if (widget == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            widget.resumeForWatchTogether()

            result.success(mapOf(
                "videoId" to videoId,
                "resumed" to true
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error resuming for watch together", e)
            result.error("RESUME_FOR_WATCH_TOGETHER_ERROR", e.message, null)
        }
    }

    // =====================================================
    // 宫格小视频功能
    // =====================================================

    /**
     * 创建宫格小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    @Throws(IllegalStateException::class)
    internal fun createGridWidget(
        configMap: Map<String, Any>?,
        layout: GridWidgetLayout,
        specifiedVideoId: String? = null,
    ): GridWidgetSession {
        logger.debug(
            "$LOG_PREFIX_GRID createGridWidget layout=$layout specifiedId=$specifiedVideoId config=${configMap.orEmpty()}",
            TAG,
        )
        if (!DPSdk.isStartSuccess()) {
            throw IllegalStateException("DPSdk is not started. Please call start() first.")
        }

        val fragmentActivity = activity as? FragmentActivity
            ?: throw IllegalStateException("Activity must be FragmentActivity")

        val params = createGridParams(configMap)
        val videoId = specifiedVideoId ?: UUID.randomUUID().toString()

        val gridListener = VideoGridListener(videoId)
        val adListener = VideoAdListener(videoId)
        gridVideoListeners[videoId] = gridListener
        videoAdListeners[videoId] = adListener

        params.listener(gridListener)
        params.adListener(adListener)

        val factory = DPSdk.factory()
        val widget = when (layout) {
            GridWidgetLayout.GRID -> factory.createGrid(params)
            GridWidgetLayout.DOUBLE_FEED -> factory.createDoubleFeed(params)
        } ?: throw IllegalStateException("Failed to create grid widget for layout=$layout")

        gridVideoWidgets[videoId] = widget
        gridVideoLayouts[videoId] = layout

        logger.debug("createGridWidget success -> id=$videoId, layout=$layout", TAG)
        return GridWidgetSession(videoId, widget)
    }

    fun createGridVideo(call: MethodCall, result: Result) {
        Log.d(TAG, "createGridVideo called")

        try {
            val configMap = call.argument<Map<String, Any>>("config")
            val session = createGridWidget(configMap, GridWidgetLayout.GRID)
            result.success(
                mapOf(
                    "videoId" to session.videoId,
                    "success" to true,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating grid video", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 创建双Feed小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createDoubleFeedVideo(call: MethodCall, result: Result) {
        Log.d(TAG, "createDoubleFeedVideo called")

        try {
            val configMap = call.argument<Map<String, Any>>("config")
            val session = createGridWidget(configMap, GridWidgetLayout.DOUBLE_FEED)
            result.success(
                mapOf(
                    "videoId" to session.videoId,
                    "success" to true,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating double feed video", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    internal fun attachGridWidget(videoId: String, containerId: Int, tag: String? = null): Boolean {
        val fragmentActivity = activity as? FragmentActivity ?: return false
        val widget = gridVideoWidgets[videoId] ?: return false
        val fragment = widget.fragment ?: return false
        val fragmentManager = fragmentActivity.supportFragmentManager

        fragmentManager.beginTransaction()
            .replace(containerId, fragment, tag ?: "grid_video_fragment_$videoId")
            .commitAllowingStateLoss()

        return true
    }

    /**
     * 展示宫格小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun showGridVideo(call: MethodCall, result: Result) {
        Log.d(TAG, "showGridVideo called")

        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            // 检查containerId参数（Android专用）
            val containerId = call.argument<Int>("containerId") ?: android.R.id.content

            if (!attachGridWidget(videoId, containerId)) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }

            val resultMap = mapOf(
                "videoId" to videoId,
                "shown" to true
            )

            result.success(resultMap)
            Log.d(TAG, "Grid video shown successfully: $videoId")

        } catch (e: Exception) {
            Log.e(TAG, "Error showing grid video", e)
            result.error("SHOW_ERROR", e.message, null)
        }
    }

    fun refreshGridVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }
            if (!refreshGridVideoInternal(videoId)) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }
            result.success(
                mapOf(
                    "videoId" to videoId,
                    "refreshed" to true,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing grid video", e)
            result.error("REFRESH_ERROR", e.message, null)
        }
    }

    fun scrollGridVideoToTop(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }
            if (!scrollGridVideoToTopInternal(videoId)) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }
            result.success(
                mapOf(
                    "videoId" to videoId,
                    "scrolled" to true,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error scrollToTop grid video", e)
            result.error("SCROLL_ERROR", e.message, null)
        }
    }

    fun backRefreshGridVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }
            if (!backRefreshGridVideoInternal(videoId)) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }
            result.success(
                mapOf(
                    "videoId" to videoId,
                    "refreshed" to true,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error backRefresh grid video", e)
            result.error("BACK_REFRESH_ERROR", e.message, null)
        }
    }

    fun setGridVideoUserVisible(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            val isVisible = call.argument<Boolean>("isVisible") ?: true
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }
            if (!setGridVideoUserVisibleInternal(videoId, isVisible)) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error setGridVideoUserVisible", e)
            result.error("SET_VISIBLE_ERROR", e.message, null)
        }
    }

    fun canBackPressGridVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }
            val value = canBackPressGridVideoInternal(videoId)
            if (value == null) {
                result.error("VIDEO_NOT_FOUND", "Grid video with ID $videoId not found", null)
                return
            }
            result.success(value)
        } catch (e: Exception) {
            Log.e(TAG, "Error canBackPress grid video", e)
            result.error("BACK_PRESS_ERROR", e.message, null)
        }
    }

    /**
     * 销毁宫格小视频
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun destroyGridVideo(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val (destroyed, message) = destroyGridVideoInternal(videoId)
            val response = mutableMapOf<String, Any?>(
                "videoId" to videoId,
                "destroyed" to destroyed,
            )
            message?.let { response["message"] = it }
            result.success(response)
            if (destroyed) {
                Log.d(TAG, "Grid video destroyed successfully: $videoId")
            } else {
            Log.w(TAG, "Grid video destroy skipped: $videoId, reason=${message ?: "unknown"}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error destroying grid video", e)
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    fun destroyDoubleFeedVideo(call: MethodCall, result: Result) {
        destroyGridVideo(call, result)
    }

    // =====================================================
    // 小视频卡片功能
    // =====================================================

    /**
     * 创建小视频卡片(1.4图)
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createVideoCard(call: MethodCall, result: Result) {
        Log.d(TAG, "createVideoCard called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity ?: run {
                result.error("ACTIVITY_ERROR", "Activity is null", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createVideoCardParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val cardListener = VideoCardListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoCardListeners[videoId] = cardListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(cardListener)
            params.adListener(adListener)

            // 创建小视频卡片
            val factory = DPSdk.factory()
            factory.loadVideoCard(params, object : IDPWidgetFactory.Callback {
                override fun onError(code: Int, msg: String?) {
                    Log.e(TAG, "Failed to create video card: code=$code, msg=$msg")
                    result.error("CREATE_FAILED", "Failed to create video card: $msg", mapOf(
                        "code" to code
                    ))
                }

                override fun onSuccess(data: IDPElement?) {
                    if (data == null) {
                        result.error("CREATE_FAILED", "Video card element is null", null)
                        return
                    }

                    videoCardElements[videoId] = data

                    val resultMap = mapOf(
                        "videoId" to videoId,
                        "success" to true
                    )

                    result.success(resultMap)
                    Log.d(TAG, "Video card created successfully with ID: $videoId")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Error creating video card", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 创建小视频卡片(2.4图)
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createSmallVideoCard(call: MethodCall, result: Result) {
        Log.d(TAG, "createSmallVideoCard called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity ?: run {
                result.error("ACTIVITY_ERROR", "Activity is null", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createVideoCardParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val cardListener = VideoCardListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoCardListeners[videoId] = cardListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(cardListener)
            params.adListener(adListener)

            // 创建小视频卡片(2.4图)
            val factory = DPSdk.factory()
            factory.loadSmallVideoCard(params, object : IDPWidgetFactory.Callback {
                override fun onError(code: Int, msg: String?) {
                    Log.e(TAG, "Failed to create small video card: code=$code, msg=$msg")
                    result.error("CREATE_FAILED", "Failed to create small video card: $msg", mapOf(
                        "code" to code
                    ))
                }

                override fun onSuccess(data: IDPElement?) {
                    if (data == null) {
                        result.error("CREATE_FAILED", "Small video card element is null", null)
                        return
                    }

                    videoCardElements[videoId] = data

                    val resultMap = mapOf(
                        "videoId" to videoId,
                        "success" to true
                    )

                    result.success(resultMap)
                    Log.d(TAG, "Small video card created successfully with ID: $videoId")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Error creating small video card", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 创建自定义宽高小视频卡片
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createCustomVideoCard(call: MethodCall, result: Result) {
        Log.d(TAG, "createCustomVideoCard called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity ?: run {
                result.error("ACTIVITY_ERROR", "Activity is null", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createVideoCardParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val cardListener = VideoCardListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoCardListeners[videoId] = cardListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(cardListener)
            params.adListener(adListener)

            // 创建自定义宽高小视频卡片
            val factory = DPSdk.factory()
            factory.loadCustomVideoCard(params, object : IDPWidgetFactory.Callback {
                override fun onError(code: Int, msg: String?) {
                    Log.e(TAG, "Failed to create custom video card: code=$code, msg=$msg")
                    result.error("CREATE_FAILED", "Failed to create custom video card: $msg", mapOf(
                        "code" to code
                    ))
                }

                override fun onSuccess(data: IDPElement?) {
                    if (data == null) {
                        result.error("CREATE_FAILED", "Custom video card element is null", null)
                        return
                    }

                    videoCardElements[videoId] = data

                    val resultMap = mapOf(
                        "videoId" to videoId,
                        "success" to true
                    )

                    result.success(resultMap)
                    Log.d(TAG, "Custom video card created successfully with ID: $videoId")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Error creating custom video card", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 获取小视频卡片View
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun getVideoCardView(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val element = videoCardElements[videoId]
            if (element == null) {
                result.error("CARD_NOT_FOUND", "Video card with ID $videoId not found", null)
                return
            }

            val view = element.view
            if (view == null) {
                result.error("VIEW_NULL", "Video card view is null", null)
                return
            }

            // 这里需要将View添加到容器中，具体实现取决于Flutter端的需求
            // 目前先返回成功状态，实际的View操作需要在Flutter端通过PlatformView来实现

            result.success(mapOf(
                "videoId" to videoId,
                "hasView" to true,
                "viewWidth" to view.width,
                "viewHeight" to view.height
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error getting video card view", e)
            result.error("GET_VIEW_ERROR", e.message, null)
        }
    }

    /**
     * 销毁小视频卡片
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun destroyVideoCard(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val (destroyed, message) = destroyVideoCardInternal(videoId)
            val response = mutableMapOf<String, Any?>(
                "videoId" to videoId,
                "destroyed" to destroyed,
            )
            message?.let { response["message"] = it }
            result.success(response)
            if (destroyed) {
                Log.d(TAG, "Video card destroyed successfully: $videoId")
            } else {
                Log.w(TAG, "Video card destroy skipped: $videoId, reason=${message ?: "unknown"}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error destroying video card", e)
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    // =====================================================
    // 小视频单卡片功能
    // =====================================================

    /**
     * 创建小视频单卡片
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createVideoSingleCard(call: MethodCall, result: Result) {
        Log.d(TAG, "createVideoSingleCard called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity ?: run {
                result.error("ACTIVITY_ERROR", "Activity is null", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createVideoSingleCardParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val singleCardListener = VideoSingleCardListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoSingleCardListeners[videoId] = singleCardListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(singleCardListener)
            params.adListener(adListener)

            // 创建小视频单卡片
            val factory = DPSdk.factory()
            factory.loadVideoSingleCard(params, object : IDPWidgetFactory.Callback {
                override fun onError(code: Int, msg: String?) {
                    Log.e(TAG, "Failed to create video single card: code=$code, msg=$msg")
                    result.error("CREATE_FAILED", "Failed to create video single card: $msg", mapOf(
                        "code" to code
                    ))
                }

                override fun onSuccess(data: IDPElement?) {
                    if (data == null) {
                        result.error("CREATE_FAILED", "Video single card element is null", null)
                        return
                    }

                    videoSingleCardElements[videoId] = data

                    val resultMap = mapOf(
                        "videoId" to videoId,
                        "success" to true,
                        "title" to (data.title ?: ""),
                        "userName" to (data.userName ?: ""),
                        "commentCount" to (data.commentCount ?: 0),
                        "publishTime" to (data.publishTime ?: 0L)
                    )

                    result.success(resultMap)
                    Log.d(TAG, "Video single card created successfully with ID: $videoId")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Error creating video single card", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 创建小视频单卡片-信息流场景
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun createVideoSingleCard4News(call: MethodCall, result: Result) {
        Log.d(TAG, "createVideoSingleCard4News called")

        try {
            // 检查SDK是否已启动
            if (!DPSdk.isStartSuccess()) {
                result.error("SDK_NOT_STARTED", "DPSdk is not started. Please call start() first.", null)
                return
            }

            val activity = this.activity ?: run {
                result.error("ACTIVITY_ERROR", "Activity is null", null)
                return
            }

            // 解析配置参数
            val configMap = call.argument<Map<String, Any>>("config")
            val params = createVideoSingleCardParams(configMap)

            // 生成唯一的videoId
            val videoId = UUID.randomUUID().toString()

            // 创建事件监听器
            val singleCardListener = VideoSingleCardListener(videoId)
            val adListener = VideoAdListener(videoId)
            videoSingleCardListeners[videoId] = singleCardListener
            videoAdListeners[videoId] = adListener

            // 设置监听器到参数中
            params.listener(singleCardListener)
            params.adListener(adListener)

            // 创建小视频单卡片-信息流场景
            val factory = DPSdk.factory()
            factory.loadVideoSingleCard4News(params, object : IDPWidgetFactory.Callback {
                override fun onError(code: Int, msg: String?) {
                    Log.e(TAG, "Failed to create video single card for news: code=$code, msg=$msg")
                    result.error("CREATE_FAILED", "Failed to create video single card for news: $msg", mapOf(
                        "code" to code
                    ))
                }

                override fun onSuccess(data: IDPElement?) {
                    if (data == null) {
                        result.error("CREATE_FAILED", "Video single card for news element is null", null)
                        return
                    }

                    videoSingleCardElements[videoId] = data

                    val resultMap = mapOf(
                        "videoId" to videoId,
                        "success" to true,
                        "title" to (data.title ?: ""),
                        "userName" to (data.userName ?: ""),
                        "commentCount" to (data.commentCount ?: 0),
                        "publishTime" to (data.publishTime ?: 0L)
                    )

                    result.success(resultMap)
                    Log.d(TAG, "Video single card for news created successfully with ID: $videoId")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Error creating video single card for news", e)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    /**
     * 获取小视频单卡片View
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun getVideoSingleCardView(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val element = videoSingleCardElements[videoId]
            if (element == null) {
                result.error("CARD_NOT_FOUND", "Video single card with ID $videoId not found", null)
                return
            }

            val view = element.view
            if (view == null) {
                result.error("VIEW_NULL", "Video single card view is null", null)
                return
            }

            // 这里需要将View添加到容器中，具体实现取决于Flutter端的需求
            // 目前先返回成功状态，实际的View操作需要在Flutter端通过PlatformView来实现

            result.success(mapOf(
                "videoId" to videoId,
                "hasView" to true,
                "viewWidth" to view.width,
                "viewHeight" to view.height,
                "title" to (element.title ?: ""),
                "userName" to (element.userName ?: ""),
                "commentCount" to (element.commentCount ?: 0),
                "publishTime" to (element.publishTime ?: 0L)
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error getting video single card view", e)
            result.error("GET_VIEW_ERROR", e.message, null)
        }
    }

    /**
     * 销毁小视频单卡片
     * @param call Flutter方法调用
     * @param result Flutter结果回调
     */
    fun destroyVideoSingleCard(call: MethodCall, result: Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "videoId cannot be null or empty", null)
                return
            }

            val (destroyed, message) = destroyVideoSingleCardInternal(videoId)
            val response = mutableMapOf<String, Any?>(
                "videoId" to videoId,
                "destroyed" to destroyed,
            )
            message?.let { response["message"] = it }
            result.success(response)
            if (destroyed) {
                Log.d(TAG, "Video single card destroyed successfully: $videoId")
            } else {
                Log.w(TAG, "Video single card destroy skipped: $videoId, reason=${message ?: "unknown"}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error destroying video single card", e)
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    /**
     * 创建DPWidgetDrawParams参数对象
     */
    private fun createDrawParams(configMap: Map<String, Any>?): DPWidgetDrawParams {
        val params = DPWidgetDrawParams.obtain()

        if (configMap != null) {
            // 广告偏移量
            if (configMap.containsKey("adOffset")) {
                val adOffset = (configMap["adOffset"] as? Number)?.toInt() ?: 0
                params.adOffset(adOffset)
            }

            // 底部偏移量
            if (configMap.containsKey("bottomOffset")) {
                val bottomOffset = (configMap["bottomOffset"] as? Number)?.toInt() ?: 0
                params.bottomOffset(bottomOffset)
            }

            // 是否隐藏关闭按钮
            if (configMap.containsKey("hideClose")) {
                val hideClose = configMap["hideClose"] as? Boolean ?: false
                params.hideClose(hideClose, null)
            }

            // 进度条样式
            if (configMap.containsKey("progressBarStyle")) {
                val style = (configMap["progressBarStyle"] as? Number)?.toInt()
                if (style == 1) {
                    params.progressBarStyle(DPWidgetDrawParams.PROGRESS_BAR_STYLE_LIGHT)
                } else if (style == 2) {
                    params.progressBarStyle(DPWidgetDrawParams.PROGRESS_BAR_STYLE_DARK)
                }
            }

            // 自定义频道名称
            if (configMap.containsKey("customCategory")) {
                val customCategory = configMap["customCategory"] as? String
                if (!customCategory.isNullOrEmpty()) {
                    params.customCategory(customCategory)
                }
            }

            // 场景标识
            if (configMap.containsKey("scene")) {
                val scene = configMap["scene"] as? String
                // 场景参数通过DPSdk设置，这里先记录
                Log.d(TAG, "Scene parameter: $scene")
            }

            // 标题栏边距设置
            if (configMap.containsKey("titleTopMargin")) {
                val titleTopMargin = (configMap["titleTopMargin"] as? Number)?.toInt() ?: -1
                if (titleTopMargin >= 0) {
                    params.titleTopMargin(titleTopMargin)
                }
            }

            if (configMap.containsKey("titleLeftMargin")) {
                val titleLeftMargin = (configMap["titleLeftMargin"] as? Number)?.toInt() ?: -1
                if (titleLeftMargin >= 0) {
                    params.titleLeftMargin(titleLeftMargin)
                }
            }

            if (configMap.containsKey("titleRightMargin")) {
                val titleRightMargin = (configMap["titleRightMargin"] as? Number)?.toInt() ?: -1
                if (titleRightMargin >= 0) {
                    params.titleRightMargin(titleRightMargin)
                }
            }

            // 频道类型配置
            if (configMap.containsKey("drawChannelType")) {
                val channelType = (configMap["drawChannelType"] as? Number)?.toInt()
                channelType?.let { params.drawChannelType(it) }
            }

            // 是否隐藏关注功能
            if (configMap.containsKey("hideFollow")) {
                val hideFollow = configMap["hideFollow"] as? Boolean ?: false
                params.hideFollow(hideFollow)
            }

            // 是否隐藏频道名称
            if (configMap.containsKey("hideChannelName")) {
                val hideChannelName = configMap["hideChannelName"] as? Boolean ?: false
                params.hideChannelName(hideChannelName)
            }

            // 是否支持下拉刷新
            if (configMap.containsKey("enableRefresh")) {
                val enableRefresh = configMap["enableRefresh"] as? Boolean ?: true
                params.enableRefresh(enableRefresh)
            }

            // 一起看视频角色配置
            if (configMap.containsKey("watchTogetherRole")) {
                val role = configMap["watchTogetherRole"] as? String
                when (role) {
                    "HOST" -> params.role(DPRole.HOST)
                    "USER" -> params.role(DPRole.USER)
                    else -> params.role(DPRole.NONE)
                }
            }

            // 主控端GroupID（仅在一起看视频主控端生效）
            if (configMap.containsKey("hostGroupId")) {
                val hostGroupId = (configMap["hostGroupId"] as? Number)?.toLong() ?: -1L
                if (hostGroupId != -1L) {
                    params.hostGroupId(hostGroupId)
                }
            }
        }

        return params
    }

    /**
     * 创建DPWidgetGridParams参数对象
     */
    private fun createGridParams(configMap: Map<String, Any>?): DPWidgetGridParams {
        val params = DPWidgetGridParams.obtain()

        if (configMap != null) {
            // 启用刷新功能
            if (configMap.containsKey("enableRefresh")) {
                val enableRefresh = configMap["enableRefresh"] as? Boolean ?: true
                params.enableRefresh(enableRefresh)
            }

            // 设置卡片样式
            if (configMap.containsKey("cardStyle")) {
                val cardStyle = configMap["cardStyle"] as? String
                if (cardStyle == "staggered") {
                    params.cardStyle(DPWidgetGridParams.CARD_STAGGERED_STYLE)
                } else {
                    params.cardStyle(DPWidgetGridParams.CARD_NORMAL_STYLE)
                }
            } else {
                // 默认使用瀑布流样式
                params.cardStyle(DPWidgetGridParams.CARD_STAGGERED_STYLE)
            }

            // 场景标识
            if (configMap.containsKey("scene")) {
                val scene = configMap["scene"] as? String
                if (!scene.isNullOrEmpty()) {
                    params.scene(scene)
                }
            }
        }

        return params
    }

    private inline fun <T> withGridWidget(
        videoId: String,
        noinline onMissing: (() -> Unit)? = null,
            action: (IDPWidget) -> T,
        ): T? {
        val widget = gridVideoWidgets[videoId]
        return if (widget != null) {
            logger.debug("$LOG_PREFIX_GRID withGridWidget hit videoId=$videoId", TAG)
            action(widget)
        } else {
            logger.warn("$LOG_PREFIX_GRID withGridWidget miss videoId=$videoId", tag = TAG)
            onMissing?.invoke()
            null
        }
    }

    /**
     * 创建DPWidgetVideoCardParams参数对象
     */
    private fun createVideoCardParams(configMap: Map<String, Any>?): DPWidgetVideoCardParams {
        val params = DPWidgetVideoCardParams.obtain()

        if (configMap != null) {
            // 是否隐藏标题和dislike
            if (configMap.containsKey("hideTitle")) {
                val hideTitle = configMap["hideTitle"] as? Boolean ?: false
                params.hideTitle(hideTitle)
            }

            // 场景标识
            if (configMap.containsKey("scene")) {
                val scene = configMap["scene"] as? String
                if (!scene.isNullOrEmpty()) {
                    params.scene(scene)
                }
            }

            // 设置Activity（dislike功能需要）
            val activity = this.activity
            if (activity != null && configMap.containsKey("enableDislike")) {
                val enableDislike = configMap["enableDislike"] as? Boolean ?: true
                if (enableDislike) {
                    params.dislikeListener(activity) { msg ->
                        Log.d(TAG, "Video card dislike: $msg")
                        sendEvent("video_card_dislike", mapOf(
                            "message" to msg
                        ))
                    }
                }
            }

            // 举报页面顶部padding
            if (configMap.containsKey("reportTopPadding")) {
                val padding = (configMap["reportTopPadding"] as? Number)?.toFloat()
                if (padding != null && padding >= 0) {
                    params.reportTopPadding(padding)
                }
            }
        }

        return params
    }

    /**
     * 创建DPWidgetVideoSingleCardParams参数对象
     */
    private fun createVideoSingleCardParams(configMap: Map<String, Any>?): DPWidgetVideoSingleCardParams {
        val params = DPWidgetVideoSingleCardParams.obtain()

        if (configMap != null) {
            // 是否隐藏播放按钮
            if (configMap.containsKey("hidePlay")) {
                val hidePlay = configMap["hidePlay"] as? Boolean ?: true
                params.hidePlay(hidePlay)
            }

            // 是否隐藏标题
            if (configMap.containsKey("hideTitle")) {
                val hideTitle = configMap["hideTitle"] as? Boolean ?: true
                params.hideTitle(hideTitle)
            }

            // 是否隐藏底部信息（仅在信息流场景生效）
            if (configMap.containsKey("hideBottomInfo")) {
                val hideBottomInfo = configMap["hideBottomInfo"] as? Boolean ?: true
                params.hideBottomInfo(hideBottomInfo)
            }

            // 设置封面图片高度
            if (configMap.containsKey("coverHeight")) {
                val coverHeight = (configMap["coverHeight"] as? Number)?.toFloat()
                if (coverHeight != null && coverHeight > 0) {
                    params.coverHeight(coverHeight)
                }
            }

            // 设置封面图片宽度
            if (configMap.containsKey("coverWidth")) {
                val coverWidth = (configMap["coverWidth"] as? Number)?.toFloat()
                if (coverWidth != null && coverWidth > 0) {
                    params.coverWidth(coverWidth)
                }
            }

            // 场景标识
            if (configMap.containsKey("scene")) {
                val scene = configMap["scene"] as? String
                if (!scene.isNullOrEmpty()) {
                    params.scene(scene)
                }
            }

            // 注意: componentPosition 功能在当前SDK版本中不可用

            // 举报页面顶部padding
            if (configMap.containsKey("reportTopPadding")) {
                val padding = (configMap["reportTopPadding"] as? Number)?.toFloat()
                if (padding != null && padding >= 0) {
                    params.reportTopPadding(padding)
                }
            }
        }

        return params
    }

    private fun destroyVideoInternal(videoId: String): Pair<Boolean, String?> {
        val widget = videoWidgets.remove(videoId)
        videoDrawListeners.remove(videoId)
        videoAdListeners.remove(videoId)
        removeFragmentByTag("video_fragment_$videoId")
        return if (widget != null) {
            try {
                widget.destroy()
                true to null
            } catch (error: Throwable) {
                logger.error("destroyVideo failed: $videoId", error, TAG)
                false to (error.message ?: "destroy failed")
            }
        } else {
            false to "Video not found"
        }
    }

    private fun destroyGridVideoInternal(videoId: String): Pair<Boolean, String?> {
        logger.debug("$LOG_PREFIX_GRID destroy videoId=$videoId", TAG)
        val widget = gridVideoWidgets.remove(videoId)
        gridVideoListeners.remove(videoId)
        videoAdListeners.remove(videoId)
        gridVideoLayouts.remove(videoId)
        removeFragmentByTag("grid_video_fragment_$videoId")
        return if (widget != null) {
            try {
                widget.destroy()
                logger.debug("$LOG_PREFIX_GRID destroy success videoId=$videoId", TAG)
                true to null
            } catch (error: Throwable) {
                logger.error("$LOG_PREFIX_GRID destroy failed videoId=$videoId", error, TAG)
                false to (error.message ?: "destroy failed")
            }
        } else {
            logger.warn("$LOG_PREFIX_GRID destroy miss videoId=$videoId", tag = TAG)
            false to "Grid video not found"
        }
    }

    private fun refreshGridVideoInternal(videoId: String): Boolean {
        logger.debug("$LOG_PREFIX_GRID refresh videoId=$videoId", TAG)
        return withGridWidget(videoId) {
            it.refresh()
            true
        } ?: false
    }

    private fun scrollGridVideoToTopInternal(videoId: String): Boolean {
        logger.debug("$LOG_PREFIX_GRID scrollToTop videoId=$videoId", TAG)
        return withGridWidget(videoId) {
            it.scrollToTop()
            true
        } ?: false
    }

    private fun backRefreshGridVideoInternal(videoId: String): Boolean {
        logger.debug("$LOG_PREFIX_GRID backRefresh videoId=$videoId", TAG)
        return withGridWidget(videoId) {
            it.backRefresh()
            true
        } ?: false
    }

    private fun setGridVideoUserVisibleInternal(videoId: String, isVisible: Boolean): Boolean {
        logger.debug("$LOG_PREFIX_GRID setVisible videoId=$videoId visible=$isVisible", TAG)
        return withGridWidget(videoId) { widget ->
            widget.fragment?.userVisibleHint = isVisible
            true
        } ?: false
    }

    private fun canBackPressGridVideoInternal(videoId: String): Boolean? {
        logger.debug("$LOG_PREFIX_GRID canBackPress videoId=$videoId", TAG)
        return withGridWidget(videoId) {
            it.canBackPress()
        }
    }

    internal fun refreshGridVideoDirect(videoId: String): Boolean = refreshGridVideoInternal(videoId)

    internal fun scrollGridVideoToTopDirect(videoId: String): Boolean = scrollGridVideoToTopInternal(videoId)

    internal fun backRefreshGridVideoDirect(videoId: String): Boolean = backRefreshGridVideoInternal(videoId)

    internal fun setGridVideoUserVisibleDirect(videoId: String, isVisible: Boolean): Boolean =
        setGridVideoUserVisibleInternal(videoId, isVisible)

    internal fun canBackPressGridVideoDirect(videoId: String): Boolean? = canBackPressGridVideoInternal(videoId)

    internal fun destroyGridVideoDirect(videoId: String): Pair<Boolean, String?> = destroyGridVideoInternal(videoId)

    private fun destroyVideoCardInternal(videoId: String): Pair<Boolean, String?> {
        val element = videoCardElements.remove(videoId)
        videoCardListeners.remove(videoId)
        videoAdListeners.remove(videoId)
        return if (element != null) {
            try {
                element.destroy()
                true to null
            } catch (error: Throwable) {
                logger.error("destroyVideoCard failed: $videoId", error, TAG)
                false to (error.message ?: "destroy failed")
            }
        } else {
            false to "Video card not found"
        }
    }

    private fun destroyVideoSingleCardInternal(videoId: String): Pair<Boolean, String?> {
        val element = videoSingleCardElements.remove(videoId)
        videoSingleCardListeners.remove(videoId)
        videoAdListeners.remove(videoId)
        return if (element != null) {
            try {
                element.destroy()
                true to null
            } catch (error: Throwable) {
                logger.error("destroyVideoSingleCard failed: $videoId", error, TAG)
                false to (error.message ?: "destroy failed")
            }
        } else {
            false to "Video single card not found"
        }
    }

    /**
     * 发送事件到Flutter端
     */
    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        val payload = HashMap<String, Any?>(data)
        val contentId = (payload["videoId"] as? String)
            ?: (payload["cardId"] as? String)
            ?: (payload["widgetId"] as? String)
            ?: eventType
        logger.debug("Event[$eventType] extras=$payload", TAG)
        eventHelper.sendEvent(eventType, contentId = contentId, extra = payload)
    }

    /**
     * 小视频Draw事件监听器
     */
    private inner class VideoDrawListener(private val videoId: String) : IDPDrawListener() {

        // IDPDrawListener回调方法
        override fun onDPRefreshFinish() {
            Log.d(TAG, "onDPRefreshFinish - videoId: $videoId")
            sendEvent("video_refresh_complete", mapOf(
                "videoId" to videoId
            ))
        }

        override fun onDPPageChange(position: Int, map: Map<String, Any>?) {
            Log.d(TAG, "onDPPageChange - position: $position, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "position" to position
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_page_change", eventData)
        }

        override fun onDPVideoPlay(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPlay - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_play", eventData)
        }

        override fun onDPVideoPause(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPause - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_pause", eventData)
        }

        override fun onDPVideoContinue(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoContinue - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_continue", eventData)
        }

        override fun onDPVideoCompletion(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoCompletion - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_completion", eventData)
        }

        override fun onDPVideoOver(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoOver - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_over", eventData)
        }

        override fun onDPClose() {
            Log.d(TAG, "onDPClose - videoId: $videoId")
            sendEvent("video_close", mapOf(
                "videoId" to videoId
            ))
        }

        override fun onDPRequestStart(map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestStart - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_request_start", eventData)
        }

        override fun onDPRequestFail(code: Int, msg: String?, map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestFail - code: $code, msg: $msg, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "code" to code
            )
            msg?.let { eventData["message"] = it }
            map?.let { eventData.putAll(it) }
            sendEvent("video_request_fail", eventData)
        }

        override fun onDPRequestSuccess(list: List<Map<String, Any>>?) {
            Log.d(TAG, "onDPRequestSuccess - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            // 清洗数据,移除不可序列化对象
            list?.let {
                val sanitized = sanitizeEventData(it)
                if (sanitized != null) {
                    eventData["data"] = sanitized
                }
            }
            sendEvent("video_request_success", eventData)
        }

        // 一起看视频相关回调方法
        override fun onDPListDataChange(map: Map<String, Any>?) {
            Log.d(TAG, "onDPListDataChange - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_data_source_change", eventData)
        }

        override fun onDPSeekTo(position: Int, time: Long) {
            Log.d(TAG, "onDPSeekTo - position: $position, time: $time, videoId: $videoId")
            sendEvent("video_seek_to", mapOf(
                "videoId" to videoId,
                "position" to position,
                "time" to time
            ))
        }

        // 用户交互回调
        override fun onDPClickAvatar(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAvatar - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_click_author_avatar", eventData)
        }

        override fun onDPClickAuthorName(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAuthorName - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_click_author_name", eventData)
        }

        override fun onDPClickComment(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickComment - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_click_comment", eventData)
        }

        override fun onDPClickLike(isLike: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickLike - isLike: $isLike, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isLike" to isLike
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_click_like", eventData)
        }

        override fun onDPClickShare(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickShare - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_click_share", eventData)
        }
    }

    /**
     * 小视频广告事件监听器
     */
    private inner class VideoAdListener(private val videoId: String) : IDPAdListener() {

        // IDPAdListener回调方法
        override fun onDPAdRequest(map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdRequest - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_request", eventData)
        }

        override fun onDPAdRequestSuccess(map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdRequestSuccess - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_load_success", eventData)
        }

        override fun onDPAdRequestFail(code: Int, msg: String?, map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdRequestFail - code: $code, msg: $msg, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "code" to code
            )
            msg?.let { eventData["message"] = it }
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_load_fail", eventData)
        }

        override fun onDPAdShow(map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdShow - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_show", eventData)
        }

        override fun onDPAdPlayStart(map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdPlayStart - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_play_start", eventData)
        }

        override fun onDPAdClicked(map: Map<String, Any>?) {
            Log.d(TAG, "onDPAdClicked - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_ad_click", eventData)
        }
    }

    /**
     * 小视频卡片事件监听器
     */
    private inner class VideoCardListener(private val videoId: String) : IDPVideoCardListener() {

        // IDPVideoCardListener回调方法
        override fun onDPItemClick(map: Map<String, Any>?) {
            Log.d(TAG, "onDPItemClick (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_click", eventData)
        }

        override fun onDPLSwipeEnter() {
            Log.d(TAG, "onDPLSwipeEnter (Card) - videoId: $videoId")
            sendEvent("video_card_swipe_enter", mapOf(
                "videoId" to videoId
            ))
        }

        override fun onDPClientShow(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClientShow (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_show", eventData)
        }

        // 播放器回调
        override fun onDPVideoPlay(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPlay (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_play", eventData)
        }

        override fun onDPVideoPause(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPause (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_pause", eventData)
        }

        override fun onDPVideoContinue(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoContinue (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_continue", eventData)
        }

        override fun onDPVideoCompletion(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoCompletion (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_completion", eventData)
        }

        override fun onDPVideoOver(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoOver (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_over", eventData)
        }

        // 用户交互回调
        override fun onDPClickAvatar(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAvatar (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_click_author_avatar", eventData)
        }

        override fun onDPClickAuthorName(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAuthorName (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_click_author_name", eventData)
        }

        override fun onDPClickComment(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickComment (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_click_comment", eventData)
        }

        override fun onDPClickLike(isLike: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickLike (Card) - isLike: $isLike, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isLike" to isLike
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_click_like", eventData)
        }

        // 请求回调
        override fun onDPRequestStart(map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestStart (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_request_start", eventData)
        }

        override fun onDPRequestFail(code: Int, msg: String?, map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestFail (Card) - code: $code, msg: $msg, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "code" to code
            )
            msg?.let { eventData["message"] = it }
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_request_fail", eventData)
        }

        override fun onDPRequestSuccess(list: List<Map<String, Any>>?) {
            Log.d(TAG, "onDPRequestSuccess (Card) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            // 清洗数据,移除不可序列化对象
            list?.let {
                val sanitized = sanitizeEventData(it)
                if (sanitized != null) {
                    eventData["data"] = sanitized
                }
            }
            sendEvent("video_card_request_success", eventData)
        }

        override fun onDPReportResult(isSucceed: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPReportResult (Card) - isSucceed: $isSucceed, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isSucceed" to isSucceed
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_card_report_result", eventData)
        }
    }

    /**
     * 宫格小视频事件监听器
     */
    private inner class VideoGridListener(private val videoId: String) : IDPGridListener() {

        // IDPGridListener回调方法
        override fun onDPGridItemClick(map: Map<String, Any>?) {
            Log.d(TAG, "onDPGridItemClick - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_item_click", eventData)
        }

        override fun onDPClientShow(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClientShow - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_item_show", eventData)
        }

        override fun onDPRefreshFinish() {
            Log.d(TAG, "onDPRefreshFinish (Grid) - videoId: $videoId")
            sendEvent("grid_video_refresh_complete", mapOf(
                "videoId" to videoId
            ))
        }

        // 播放器回调
        override fun onDPVideoPlay(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPlay (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_play", eventData)
        }

        override fun onDPVideoPause(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPause (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_pause", eventData)
        }

        override fun onDPVideoContinue(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoContinue (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_continue", eventData)
        }

        override fun onDPVideoCompletion(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoCompletion (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_completion", eventData)
        }

        override fun onDPVideoOver(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoOver (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_over", eventData)
        }

        // 用户交互回调
        override fun onDPClickAvatar(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAvatar (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_click_author_avatar", eventData)
        }

        override fun onDPClickAuthorName(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAuthorName (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_click_author_name", eventData)
        }

        override fun onDPClickComment(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickComment (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_click_comment", eventData)
        }

        override fun onDPClickLike(isLike: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickLike (Grid) - isLike: $isLike, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isLike" to isLike
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_click_like", eventData)
        }

        // 请求回调
        override fun onDPRequestStart(map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestStart (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_request_start", eventData)
        }

        override fun onDPRequestFail(code: Int, msg: String?, map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestFail (Grid) - code: $code, msg: $msg, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "code" to code
            )
            msg?.let { eventData["message"] = it }
            map?.let { eventData.putAll(it) }
            sendEvent("grid_video_request_fail", eventData)
        }

        override fun onDPRequestSuccess(list: List<Map<String, Any>>?) {
            Log.d(TAG, "onDPRequestSuccess (Grid) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            // 清洗数据,移除不可序列化对象(如 cover_list 中的混淆类)
            list?.let {
                val sanitized = sanitizeEventData(it)
                if (sanitized != null) {
                    eventData["data"] = sanitized
                }
            }
            sendEvent("grid_video_request_success", eventData)
        }
    }

    /**
     * 小视频单卡片事件监听器
     */
    private inner class VideoSingleCardListener(private val videoId: String) : IDPVideoSingleCardListener() {

        // IDPVideoSingleCardListener回调方法
        override fun onDPClick(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClick (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_click", eventData)
        }

        override fun onDPClientShow(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClientShow (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_show", eventData)
        }

        // 播放器回调
        override fun onDPVideoPlay(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPlay (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_play", eventData)
        }

        override fun onDPVideoPause(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoPause (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_pause", eventData)
        }

        override fun onDPVideoContinue(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoContinue (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_continue", eventData)
        }

        override fun onDPVideoCompletion(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoCompletion (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_completion", eventData)
        }

        override fun onDPVideoOver(map: Map<String, Any>?) {
            Log.d(TAG, "onDPVideoOver (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_over", eventData)
        }

        // 用户交互回调
        override fun onDPClickAvatar(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAvatar (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_click_author_avatar", eventData)
        }

        override fun onDPClickAuthorName(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickAuthorName (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_click_author_name", eventData)
        }

        override fun onDPClickComment(map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickComment (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_click_comment", eventData)
        }

        override fun onDPClickLike(isLike: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPClickLike (SingleCard) - isLike: $isLike, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isLike" to isLike
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_click_like", eventData)
        }

        // 请求回调
        override fun onDPRequestStart(map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestStart (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_request_start", eventData)
        }

        override fun onDPRequestFail(code: Int, msg: String?, map: Map<String, Any>?) {
            Log.d(TAG, "onDPRequestFail (SingleCard) - code: $code, msg: $msg, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "code" to code
            )
            msg?.let { eventData["message"] = it }
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_request_fail", eventData)
        }

        override fun onDPRequestSuccess(list: List<Map<String, Any>>?) {
            Log.d(TAG, "onDPRequestSuccess (SingleCard) - videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId
            )
            // 清洗数据,移除不可序列化对象
            list?.let {
                val sanitized = sanitizeEventData(it)
                if (sanitized != null) {
                    eventData["data"] = sanitized
                }
            }
            sendEvent("video_single_card_request_success", eventData)
        }

        override fun onDPReportResult(isSucceed: Boolean, map: Map<String, Any>?) {
            Log.d(TAG, "onDPReportResult (SingleCard) - isSucceed: $isSucceed, videoId: $videoId")
            val eventData = mutableMapOf<String, Any>(
                "videoId" to videoId,
                "isSucceed" to isSucceed
            )
            map?.let { eventData.putAll(it) }
            sendEvent("video_single_card_report_result", eventData)
        }
    }
}
