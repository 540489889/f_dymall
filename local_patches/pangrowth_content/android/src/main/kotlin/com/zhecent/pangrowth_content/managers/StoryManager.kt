package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.djx.model.DJXError
import com.bytedance.sdk.djx.model.DJXOthers
import com.bytedance.sdk.nov.api.INovCallback
import com.bytedance.sdk.nov.api.NovSdk
import com.bytedance.sdk.nov.api.model.NovCategory
import com.bytedance.sdk.nov.api.model.NovStory
import com.bytedance.sdk.nov.api.params.NovReaderConfig
import com.bytedance.sdk.nov.api.params.NovWidgetHomeParams
import com.zhecent.pangrowth_content.StoryHomeActivity
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal class StoryManager(
    private val context: Context,
    private val logger: ContentLogger,
    private val isSdkReady: () -> Boolean,
) {

    private val mainHandler = Handler(Looper.getMainLooper())

    private data class StoryWidget(val widget: IDJXWidget)

    private val storyWidgets = ConcurrentHashMap<String, StoryWidget>()
    private var activity: Activity? = null

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun cleanup() {
        storyWidgets.keys.forEach { id -> destroyWidgetInternal(id) }
        storyWidgets.clear()
    }

    private fun ensureStoryReady(result: Result): Boolean {
        if (!isSdkReady()) {
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "短故事模块未启动，请先调用 PangrowthContent.start 并确保 startStory = true",
                null,
            )
            return false
        }
        if (NovSdk.factory() == null) {
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "NovSdk.factory() 返回 null，内容SDK 可能未正确初始化",
                null,
            )
            return false
        }
        return true
    }

    fun createStoryHome(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        try {
            val args = call.arguments as? Map<*, *>
            val configMap = args?.get("config") as? Map<*, *>

            val readerConfig = buildReaderConfig(configMap?.get("readerConfig") as? Map<*, *>)
            val widgetParams = NovWidgetHomeParams(readerConfig)

            applyWidgetConfig(widgetParams, configMap)

            val widget = NovSdk.factory()?.createStoryHome(widgetParams)
                ?: throw IllegalStateException("createStoryHome 返回 null")

            val widgetId = configMap?.get("viewId")?.toString()
                ?: "story_home_${UUID.randomUUID()}"

            storyWidgets[widgetId] = StoryWidget(widget)

            result.success(
                mapOf(
                    "widgetId" to widgetId,
                    "widgetType" to "story_home",
                    "success" to true,
                ),
            )
        } catch (error: Throwable) {
            logger.error("创建短故事聚合页失败: ${error.message}", error)
            result.error("CREATE_STORY_HOME_ERROR", error.message, null)
        }
    }

    fun showStoryHome(call: MethodCall, result: Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrBlank()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "widgetId 不能为空", null)
            return
        }

        val stored = storyWidgets[widgetId]
        if (stored == null) {
            result.error("WIDGET_NOT_FOUND", "未找到对应的短故事聚合页", null)
            return
        }

        val fragment = stored.widget.fragment
        if (fragment == null) {
            result.error("FRAGMENT_NOT_AVAILABLE", "短故事聚合页未提供 Fragment", null)
            return
        }

        val hostActivity = activity
        StoryHomeActivity.setFragment(widgetId, fragment)

        mainHandler.post {
            try {
                val intent = Intent(context, StoryHomeActivity::class.java)
                intent.putExtra("widgetId", widgetId)
                if (hostActivity != null) {
                    hostActivity.startActivity(intent)
                } else {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
                result.success(mapOf("widgetId" to widgetId, "shown" to true))
            } catch (error: Throwable) {
                StoryHomeActivity.clearFragment(widgetId)
                logger.error("展示短故事聚合页失败: ${error.message}", error)
                result.error("SHOW_STORY_HOME_ERROR", error.message, null)
            }
        }
    }

    fun destroyStoryHome(call: MethodCall, result: Result) {
        val widgetId = call.argument<String>("widgetId")
        if (widgetId.isNullOrBlank()) {
            result.success(false)
            return
        }

        val destroyed = destroyWidgetInternal(widgetId)
        result.success(destroyed)
    }

    private fun destroyWidgetInternal(widgetId: String): Boolean {
        StoryHomeActivity.clearFragment(widgetId)
        val widget = storyWidgets.remove(widgetId) ?: return false
        return try {
            widget.widget.destroy()
            true
        } catch (error: Throwable) {
            logger.warn("销毁短故事聚合页失败: ${error.message}", error)
            false
        }
    }

    fun getStoryCategoryList(result: Result) {
        if (!ensureStoryReady(result)) return

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        service.requestCategoryList(object : INovCallback<List<NovCategory>> {
            override fun onSuccess(data: List<NovCategory>, others: DJXOthers?) {
                val list = data.map { StoryMapper.categoryToMap(it) }
                postSuccess(result, list)
            }

            override fun onError(error: DJXError) {
                postError(result, "GET_STORY_CATEGORY_ERROR", "获取短故事分类失败: ${error.msg}", error)
            }
        })
    }

    fun getStoryList(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20
        val orderAscending = call.argument<Boolean>("order") ?: true
        val orderValue = if (orderAscending) 0 else 1
        val categoryId = call.argument<Int>("categoryId")

        val callback = object : INovCallback<List<NovStory>> {
            override fun onSuccess(data: List<NovStory>, others: DJXOthers?) {
                val list = data.map { StoryMapper.storyToMap(it) }
                postSuccess(result, list)
            }

            override fun onError(error: DJXError) {
                postError(result, "GET_STORY_LIST_ERROR", "获取短故事列表失败: ${error.msg}", error)
            }
        }

        if (categoryId != null && categoryId > 0) {
            service.requestStoryByCategory(categoryId, orderValue, page, count, callback)
        } else {
            service.requestStoryFeed(orderValue, count, page, callback)
        }
    }

    fun searchStory(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        val query = call.argument<String>("keyword")
        if (query.isNullOrBlank()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "搜索关键词不能为空", null)
            return
        }

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        val isFuzzy = call.argument<Boolean>("isFuzzy") ?: true
        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        service.searchStory(query, isFuzzy, page, count, object : INovCallback<List<NovStory>> {
            override fun onSuccess(data: List<NovStory>, others: DJXOthers?) {
                val list = data.map { StoryMapper.storyToMap(it) }
                postSuccess(result, list)
            }

            override fun onError(error: DJXError) {
                postError(result, "SEARCH_STORY_ERROR", "搜索短故事失败: ${error.msg}", error)
            }
        })
    }

    fun getStoryHistory(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        service.getStoryHistory(page, count, object : INovCallback<List<NovStory>> {
            override fun onSuccess(data: List<NovStory>, others: DJXOthers?) {
                val list = data.map { StoryMapper.storyToMap(it) }
                postSuccess(result, list)
            }

            override fun onError(error: DJXError) {
                postError(result, "GET_STORY_HISTORY_ERROR", "获取短故事历史失败: ${error.msg}", error)
            }
        })
    }

    fun favoriteStory(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        val storyId = call.argument<String>("storyId")
        if (storyId.isNullOrBlank()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "storyId 不能为空", null)
            return
        }

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        val isFavorite = call.argument<Boolean>("isFavorite") ?: true

        val callback = object : INovCallback<Boolean> {
            override fun onSuccess(data: Boolean, others: DJXOthers?) {
                postSuccess(result, data)
            }

            override fun onError(error: DJXError) {
                postError(result, "FAVORITE_STORY_ERROR", "收藏操作失败: ${error.msg}", error)
            }
        }

        if (isFavorite) {
            service.storyFavorite(storyId.toInt(), callback)
        } else {
            service.storyFavoriteCancel(storyId.toInt(), callback)
        }
    }

    fun getFavoriteStories(call: MethodCall, result: Result) {
        if (!ensureStoryReady(result)) return

        val service = NovSdk.service()
        if (service == null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "NovSdk.service() 返回 null", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        service.getStoryFavorite(page, count, object : INovCallback<List<NovStory>> {
            override fun onSuccess(data: List<NovStory>, others: DJXOthers?) {
                val list = data.map { StoryMapper.storyToMap(it) }
                postSuccess(result, list)
            }

            override fun onError(error: DJXError) {
                postError(result, "GET_FAVORITE_STORY_ERROR", "获取收藏列表失败: ${error.msg}", error)
            }
        })
    }

    fun markAsRead(call: MethodCall, result: Result) {
        result.error("UNSUPPORTED_OPERATION", "穿山甲短故事SDK暂未提供显式的已读标记接口", null)
    }

    fun likeStory(call: MethodCall, result: Result) {
        result.error("UNSUPPORTED_OPERATION", "穿山甲短故事SDK暂未开放点赞接口", null)
    }

    fun updateReadProgress(call: MethodCall, result: Result) {
        result.error("UNSUPPORTED_OPERATION", "穿山甲短故事SDK暂未提供阅读进度上报接口", null)
    }

    private fun buildReaderConfig(map: Map<*, *>?): NovReaderConfig {
        val config = NovReaderConfig()
        if (map == null) return config

        (map["rewardCodeId"] as? String)?.let { config.rewardCodeId = it }

        (map["rewardAdMode"] as? String)?.let { mode ->
            config.rewardAdMode = when (mode.lowercase()) {
                "custom" -> NovReaderConfig.NovRewardAdMode.MODE_CUSTOM
                else -> NovReaderConfig.NovRewardAdMode.MODE_SDK
            }
        }

        (map["rewardAdMode"] as? Number)?.let { number ->
            config.rewardAdMode = if (number.toInt() == 1) {
                NovReaderConfig.NovRewardAdMode.MODE_CUSTOM
            } else {
                NovReaderConfig.NovRewardAdMode.MODE_SDK
            }
        }

        (map["endPageRecSize"] as? Number)?.let { config.endPageRecSize = it.toInt() }
        (map["defaultTextSize"] as? Number)?.let { config.defaultTextSize = it.toInt() }

        (map["defaultPageTurnMode"] as? String)?.let { mode ->
            config.defaultPageTurnMode = when (mode.lowercase()) {
                "simulate" -> NovReaderConfig.NovPageTurnMode.TURN_LEFT_RIGHT_SIMULATE
                "slip" -> NovReaderConfig.NovPageTurnMode.TURN_LEFT_RIGHT_SLIP
                "vertical" -> NovReaderConfig.NovPageTurnMode.TURN_UP_DOWN
                else -> NovReaderConfig.NovPageTurnMode.TURN_LEFT_RIGHT_TRANSLATE
            }
        }

        (map["endPageCardStyle"] as? String)?.let { style ->
            config.endPageCardStyle = when (style.lowercase()) {
                "mix" -> NovReaderConfig.NovEndPageCardStyle.STYLE_MIX
                else -> NovReaderConfig.NovEndPageCardStyle.STYLE_ONLY_TEXT
            }
        }

        (map["endPageCardStyle"] as? Number)?.let { number ->
            config.endPageCardStyle = if (number.toInt() == 1) {
                NovReaderConfig.NovEndPageCardStyle.STYLE_MIX
            } else {
                NovReaderConfig.NovEndPageCardStyle.STYLE_ONLY_TEXT
            }
        }

        return config
    }

    private fun applyWidgetConfig(params: NovWidgetHomeParams, map: Map<*, *>?) {
        if (map == null) return

        // 使用containsKey检查参数是否存在，只在参数存在时才设置
        // 这样可以让SDK使用原生默认值
        if (map.containsKey("canPullRefresh")) {
            (map["canPullRefresh"] as? Boolean)?.let { params.canPullRefresh = it }
        }
        if (map.containsKey("topOffset")) {
            (map["topOffset"] as? Number)?.let { params.topOffset = it.toInt() }
        }
        if (map.containsKey("recPageSize")) {
            (map["recPageSize"] as? Number)?.let { params.recPageSize = it.toInt() }
        }
    }

    private fun postSuccess(result: Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun postError(result: Result, code: String, message: String?, error: DJXError?) {
        logger.warn("$code: $message, code=${error?.code}, subCode=${error?.subCode}")
        val details = if (error == null) null else mapOf(
            "code" to error.code,
            "subCode" to error.subCode,
            "requestId" to error.requestId,
        )
        mainHandler.post { result.error(code, message, details) }
    }
}
