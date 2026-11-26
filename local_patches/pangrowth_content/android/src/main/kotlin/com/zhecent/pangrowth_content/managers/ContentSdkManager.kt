package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.app.Application
import android.content.Context
import android.net.Uri
import com.bytedance.sdk.djx.DJXSdk
import com.bytedance.sdk.djx.DJXSdkConfig
import com.bytedance.sdk.djx.IDJXPrivacyController
import com.bytedance.sdk.djx.model.DJXError
import com.bytedance.sdk.djx.IDJXService
import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXEpisodeStatus
import com.bytedance.sdk.djx.model.DJXOthers
import com.bytedance.sdk.djx.model.DJXLock
import com.bytedance.sdk.djx.model.DJXUser
import com.bytedance.sdk.dp.DPSdk
import com.bytedance.sdk.dp.DPSdkConfig
import com.bytedance.sdk.dp.IDPPrivacyController
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.nov.api.NovSdk
import com.bytedance.sdk.nov.api.NovSdkConfig
import com.zhecent.pangrowth_content.common.ContentConstants
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.Charset
import java.util.concurrent.atomic.AtomicInteger
import java.lang.reflect.Proxy
import java.util.HashMap
import kotlin.reflect.KClass

internal class ContentSdkManager(
    private val applicationContext: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
) {

    private var currentActivity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var lastInitOptions: ContentInitOptions? = null
    private var lastConfigFile: File? = null
    private var isSdkInitialized = false
    private var isStarting = false
    private var personalizationPreference: Boolean? = null
    @Volatile
    private var dramaModuleStarted = false
    @Volatile
    private var storyModuleStarted = false
    @Volatile
    private var videoModuleStarted = false
    private var currentStartModules: Set<String>? = null

    private val dramaSwipeCoordinator = DramaSwipeCoordinator(
        applicationContext = applicationContext,
        eventHelper = eventHelper,
        logger = logger,
        validationHelper = validationHelper,
        isSdkReady = { isDramaModuleReady() },
    )

    private val dramaPlayerManager = DramaPlayerManager(
        context = applicationContext,
        eventHelper = eventHelper,
        logger = logger,
        isSdkReady = { isDramaModuleReady() },
    )

    private val dramaCardManager = DramaCardManager(
        context = applicationContext,
        eventHelper = eventHelper,
        logger = logger,
        validationHelper = validationHelper,
        isSdkReady = { isDramaModuleReady() },
    )

    private val storyManager = StoryManager(
        context = applicationContext,
        logger = logger,
        isSdkReady = { isStoryModuleReady() },
    )

    private val videoManager = VideoManager(
        context = applicationContext,
        eventHelper = eventHelper,
        logger = logger,
    )

    private val userProfileManager = UserProfileManager(
        context = applicationContext,
        eventHelper = eventHelper,
        logger = logger,
    )

    private inline fun <reified T> MethodCall.optionalArgument(key: String): T? {
        return if (hasArgument(key)) argument<T>(key) else null
    }

    fun setActivity(activity: Activity?) {
        currentActivity = activity
        dramaSwipeCoordinator.setActivity(activity)
        dramaPlayerManager.setActivity(activity)
        dramaCardManager.setActivity(activity)
        storyManager.setActivity(activity)
        videoManager.setActivity(activity)
        userProfileManager.setActivity(activity)
    }

    fun getRecommendedDramaList(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        // 只在用户明确提供参数时才传给SDK，否则让SDK使用自己的默认值
        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        try {
            DJXSdk.service().requestAllDramaByRecommend(page, count, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama -> DramaMapper.dramaToMap(drama as DJXDrama) } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_RECOMMEND_DRAMA_FAILED", "获取推荐短剧失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取推荐短剧异常", throwable)
            result.error("GET_RECOMMEND_DRAMA_ERROR", throwable.message, null)
        }
    }

    fun getDramaListByIds(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val ids = call.argument<List<Number>>("dramaIds")?.map { it.toLong() }
        if (ids.isNullOrEmpty()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            DJXSdk.service().requestDrama(ids, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama -> DramaMapper.dramaToMap(drama as DJXDrama) } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_DRAMA_BY_IDS_FAILED", "根据ID获取短剧失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("根据ID获取短剧异常", throwable)
            result.error("GET_DRAMA_BY_IDS_ERROR", throwable.message, null)
        }
    }

    fun getDramaListByCategory(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val category = call.argument<String>("category")
        if (category.isNullOrEmpty()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "category 不能为空", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20
        val order = call.argument<Int>("order") ?: 0

        try {
            DJXSdk.service().requestDramaByCategory(category, page, count, order, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama -> DramaMapper.dramaToMap(drama as DJXDrama) } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_DRAMA_BY_CATEGORY_FAILED", "按分类获取短剧失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("按分类获取短剧异常", throwable)
            result.error("GET_DRAMA_BY_CATEGORY_ERROR", throwable.message, null)
        }
    }

    fun clearDramaHistory(result: MethodChannel.Result) {
        try {
            DJXSdk.service().clearDramaHistory(object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    result.success(true)
                }

                override fun onError(error: DJXError) {
                    result.error("CLEAR_HISTORY_FAILED", "清空历史记录失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("清空历史记录异常", throwable)
            result.error("CLEAR_HISTORY_ERROR", throwable.message, null)
        }
    }

    fun favorDrama(call: MethodCall, result: MethodChannel.Result) {
        val dramaId = call.argument<Number>("dramaId")?.toLong() ?: run {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空", null)
            return
        }
        val favorite = call.argument<Boolean>("favorite") ?: true

        try {
            val service = DJXSdk.service()
            val callback = object : IDJXService.IDJXCallback<Any?> {
                override fun onSuccess(data: Any?, others: DJXOthers?) {
                    result.success(true)
                }

                override fun onError(error: DJXError) {
                    result.error("FAVOR_DRAMA_FAILED", "收藏状态更新失败: ${error.msg}", mapOf("code" to error.code))
                }
            }

            val methods = service::class.java.methods.filter { it.name == "favorDrama" }
            val handled = when {
                methods.any { it.parameterTypes.size == 4 } -> {
                    val method = methods.first { it.parameterTypes.size == 4 }
                    val episodeIndex = call.argument<Int>("episodeIndex") ?: 0
                    method.isAccessible = true
                    method.invoke(service, dramaId, episodeIndex, favorite, callback)
                    true
                }
                methods.any { it.parameterTypes.size == 3 } -> {
                    val method = methods.first { it.parameterTypes.size == 3 }
                    method.isAccessible = true
                    method.invoke(service, dramaId, favorite, callback)
                    true
                }
                else -> false
            }

            if (!handled) {
                result.error("FAVOR_DRAMA_UNSUPPORTED", "当前 SDK 不支持收藏接口", null)
            }
        } catch (throwable: Throwable) {
            logger.error("收藏状态更新异常", throwable)
            result.error("FAVOR_DRAMA_ERROR", throwable.message, null)
        }
    }

    fun likeEpisode(call: MethodCall, result: MethodChannel.Result) {
        val dramaId = call.argument<Number>("dramaId")?.toLong() ?: run {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空", null)
            return
        }
        val episodeIndex = call.argument<Int>("episodeIndex") ?: 0
        val like = call.argument<Boolean>("like") ?: true

        try {
            DJXSdk.service().likeEpisode(dramaId, episodeIndex, like, object : IDJXService.IDJXCallback<Any?> {
                override fun onSuccess(data: Any?, others: DJXOthers?) {
                    result.success(true)
                }

                override fun onError(error: DJXError) {
                    result.error("LIKE_EPISODE_FAILED", "点赞状态更新失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("点赞状态更新异常", throwable)
            result.error("LIKE_EPISODE_ERROR", throwable.message, null)
        }
    }

    fun getDramaFavorList(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        try {
            DJXSdk.service().getFavorList(page, count, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama -> DramaMapper.dramaToMap(drama as DJXDrama) } ?: emptyList()
                    val othersMap = DramaMapper.othersToMap(others)
                    val response = mutableMapOf<String, Any?>(
                        "items" to list,
                        "others" to othersMap,
                    )
                    response["total"] = (othersMap["total"] as? Number)?.toInt() ?: list.size
                    response["hasMore"] = othersMap["hasMore"] as? Boolean ?: false
                    result.success(response)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_FAVOR_LIST_FAILED", "获取收藏列表失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取收藏列表异常", throwable)
            result.error("GET_FAVOR_LIST_ERROR", throwable.message, null)
        }
    }

    fun getDramaEpisodesStatus(call: MethodCall, result: MethodChannel.Result) {
        val dramaId = call.argument<Number>("dramaId")?.toLong() ?: run {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "dramaId 不能为空", null)
            return
        }
        val freeSet = call.argument<Int>("freeSet") ?: 0

        try {
            DJXSdk.service().getEpisodesStatus(dramaId, freeSet, object : IDJXService.IDJXCallback<MutableList<DJXEpisodeStatus>?> {
                override fun onSuccess(data: MutableList<DJXEpisodeStatus>?, others: DJXOthers?) {
                    val mapped = DramaMapper.episodeStatusMap(data)
                    result.success(mapped)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_EPISODE_STATUS_FAILED", "获取剧集状态失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取剧集状态异常", throwable)
            result.error("GET_EPISODE_STATUS_ERROR", throwable.message, null)
        }
    }

    fun verifyDramaParams(call: MethodCall, result: MethodChannel.Result) {
        val total = call.argument<Int>("total") ?: run {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "total 不能为空", null)
            return
        }
        val freeSet = call.argument<Int>("freeSet") ?: 0
        val lockSet = call.argument<Int>("lockSet") ?: 0

        try {
            DJXSdk.service().verifyDramaParams(total, freeSet, lockSet, object : IDJXService.IDJXCallback<DJXLock?> {
                override fun onSuccess(data: DJXLock?, others: DJXOthers?) {
                    result.success(DramaMapper.reflectToMap(data))
                }

                override fun onError(error: DJXError) {
                    result.error("VERIFY_DRAMA_PARAMS_FAILED", "校验短剧参数失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("校验短剧参数异常", throwable)
            result.error("VERIFY_DRAMA_PARAMS_ERROR", throwable.message, null)
        }
    }

    fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val rawConfigPath = arguments?.get("configPath") as? String
        if (rawConfigPath.isNullOrBlank()) {
            result.error(
                ContentConstants.ErrorCodes.INVALID_ARGUMENT,
                "configPath 不能为空",
                null,
            )
            return
        }

        val configMap = arguments["config"] as? Map<String, Any?>
        logger.debug("内容SDK initialize 请求: configPath=$rawConfigPath configMapKeys=${configMap?.keys}")

        val resolution = try {
            resolveConfigPath(rawConfigPath)
        } catch (error: Throwable) {
            logger.error("解析配置文件失败: ${error.message}", error)
            result.error(
                ContentConstants.ErrorCodes.CONFIG_NOT_FOUND,
                error.message,
                null,
            )
            return
        }

        logger.debug(
            "内容SDK配置文件解析成功: source=${resolution.source}, path=${resolution.pathForSdk}, temp=${resolution.tempFile?.absolutePath}"
        )

        val options = ContentInitOptions.from(resolution.pathForSdk, configMap)

        if (isSdkInitialized && lastInitOptions != null) {
            if (lastInitOptions!!.isCompatibleWith(options)) {
                lastInitOptions = options
                personalizationPreference = options.personalizationEnabled
                eventHelper.sendEvent(
                    ContentConstants.Events.SDK_INIT_REUSED,
                    extra = mapOf(
                        "enableDrama" to options.enableDrama,
                        "enableStory" to options.enableStory,
                        "enableVideo" to options.enableVideo,
                    ),
                )
                result.success(true)
                return
            } else {
                result.error(
                    ContentConstants.ErrorCodes.INIT_INCOMPATIBLE,
                    "内容 SDK 已按其它配置完成初始化，如需切换请先重启进程",
                    null,
                )
                return
            }
        }

        eventHelper.sendEvent(
            ContentConstants.Events.SDK_INIT_START,
            extra = mapOf(
                "enableDrama" to options.enableDrama,
                "enableStory" to options.enableStory,
                "enableVideo" to options.enableVideo,
                "configSource" to resolution.source,
            ),
        )

        try {
            val application = applicationContext as? Application
                ?: throw IllegalStateException("applicationContext 不是 Application")

            if (options.enableDrama) {
                val dramaConfig = buildDramaConfig(options)
                DJXSdk.init(application, resolution.argumentForSdk, dramaConfig)
                logger.debug("DJXSdk.init 调用完成")
            }

            if (options.enableStory) {
                val novelConfig = buildStoryConfig(options)
                NovSdk.init(application, resolution.argumentForSdk, novelConfig)
                logger.debug("NovSdk.init 调用完成")
            }

            if (options.enableVideo) {
                val videoConfig = buildVideoConfig(options)
                DPSdk.init(application, resolution.argumentForSdk, videoConfig)
                logger.debug("DPSdk.init 调用完成")
            }

            lastConfigFile?.takeIf { it != resolution.tempFile }?.delete()
            lastConfigFile = resolution.tempFile
            lastInitOptions = options
            personalizationPreference = options.personalizationEnabled
            isSdkInitialized = true
            videoModuleStarted = false

            eventHelper.sendEvent(
                ContentConstants.Events.SDK_INIT_SUCCESS,
                extra = mapOf(
                    "enableDrama" to options.enableDrama,
                    "enableStory" to options.enableStory,
                    "enableVideo" to options.enableVideo,
                ),
            )
            result.success(true)
        } catch (error: Throwable) {
            logger.error("内容 SDK 初始化失败: ${error.message}", error)
            eventHelper.sendError(
                ContentConstants.Events.SDK_INIT_FAIL,
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                error.message ?: "初始化异常",
            )
            resolution.tempFile?.delete()
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                "内容 SDK 初始化失败: ${error.message}",
                null,
            )
        }
    }

    fun start(call: MethodCall, result: MethodChannel.Result) {
        if (!isSdkInitialized || lastInitOptions == null) {
            result.error(
                ContentConstants.ErrorCodes.SDK_NOT_INITIALIZED,
                "请先调用 initialize 完成初始化",
                null,
            )
            return
        }

        val args = call.arguments as? Map<*, *>
        val requestDrama = (args?.get("startDrama") as? Boolean) ?: lastInitOptions!!.enableDrama
        val requestStory = (args?.get("startStory") as? Boolean) ?: lastInitOptions!!.enableStory
        val requestVideo = (args?.get("startVideo") as? Boolean) ?: lastInitOptions!!.enableVideo

        val modules = mutableListOf<String>()
        if (requestDrama && lastInitOptions!!.enableDrama && !dramaModuleStarted) {
            modules += "drama"
        }
        if (requestStory && lastInitOptions!!.enableStory && !storyModuleStarted) {
            modules += "story"
        }
        if (requestVideo && lastInitOptions!!.enableVideo && !videoModuleStarted) {
            modules += "video"
        }

        logger.debug(
            "内容SDK start 请求: modules=$modules, isStarting=$isStarting, " +
                "dramaStarted=$dramaModuleStarted, storyStarted=$storyModuleStarted, videoStarted=$videoModuleStarted"
        )

        if (isStarting) {
            val alreadyReady = mutableSetOf<String>()
            if (dramaModuleStarted) alreadyReady += "drama"
            if (storyModuleStarted) alreadyReady += "story"
            if (videoModuleStarted) alreadyReady += "video"

            val currentModules = currentStartModules ?: emptySet()
            val satisfied = modules.all { it in alreadyReady || it in currentModules }

            if (satisfied) {
                logger.debug("重复的模块启动请求已复用，modules=$modules")
                result.success(true)
            } else {
                logger.warn(
                    "内容SDK start 请求被拒绝：已有启动流程进行中 currentModules=$currentModules, alreadyReady=$alreadyReady"
                )
                result.error(
                    ContentConstants.ErrorCodes.START_ALREADY_RUNNING,
                    "内容 SDK 启动进行中，请稍后重试",
                    null,
                )
            }
            return
        }

        val activityCheck = validationHelper.ensureActivity(currentActivity)
        if (activityCheck != null) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, activityCheck, null)
            return
        }

        if (modules.isEmpty()) {
            result.success(true)
            return
        }

        if (modules.contains("video") && !validationHelper.isAdSdkReady()) {
            val message = "请先完成 GroMore 广告 SDK 初始化"
            logger.warn("内容SDK start 包含 video，但 GroMore SDK 未就绪，拒绝启动")
            eventHelper.sendError(
                ContentConstants.Events.ERROR,
                ContentConstants.ErrorCodes.SDK_NOT_READY,
                message,
                mapOf("stage" to "start"),
            )
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, message, null)
            return
        }

        isStarting = true
        currentStartModules = modules.toSet()
        if (requestDrama) {
            dramaModuleStarted = false
        }
        if (requestStory) {
            storyModuleStarted = false
        }
        if (requestVideo) {
            videoModuleStarted = false
        }

        eventHelper.sendEvent(
            ContentConstants.Events.SDK_START_START,
            extra = mapOf("modules" to modules),
        )

        val pending = AtomicInteger(modules.size)
        var hasError = false
        var firstError: Map<String, Any?>? = null

        fun notifyCompletion(module: String, success: Boolean, extra: Map<String, Any?>) {
            if (module == "drama") {
                dramaModuleStarted = success
            }
            if (module == "story") {
                storyModuleStarted = success
            }
            if (module == "video") {
                videoModuleStarted = success
            }
            logger.debug("模块 $module 启动回调: success=$success extra=$extra")
            if (success) {
                eventHelper.sendEvent(
                    ContentConstants.Events.SDK_START_SUCCESS,
                    contentId = module,
                    extra = extra,
                )
            } else {
                hasError = true
                if (firstError == null) {
                    firstError = extra + mapOf("module" to module)
                }
                eventHelper.sendEvent(
                    ContentConstants.Events.SDK_START_FAIL,
                    contentId = module,
                    extra = extra,
                )
            }

            if (pending.decrementAndGet() == 0) {
                isStarting = false
                currentStartModules = null
                if (!hasError) {
                    logger.debug("内容SDK模块全部启动成功: $modules")
                    applyPersonalizationIfNeeded()
                    result.success(true)
                } else {
                    logger.warn("内容SDK模块启动失败: $firstError")
                    result.error(
                        ContentConstants.ErrorCodes.SDK_NOT_READY,
                        "部分模块启动失败",
                        firstError,
                    )
                }
            }
        }

        if (modules.contains("drama")) {
            startDramaModule { success, extra ->
                notifyCompletion("drama", success, extra)
            }
        }

        if (modules.contains("story")) {
            startStoryModule { success, extra ->
                notifyCompletion("story", success, extra)
            }
        }

        if (modules.contains("video")) {
            startVideoModule { success, extra ->
                notifyCompletion("video", success, extra)
            }
        }
    }

    fun dispose() {
        lastConfigFile?.delete()
        lastConfigFile = null
        dramaModuleStarted = false
        storyModuleStarted = false
        videoModuleStarted = false
        dramaSwipeCoordinator.dispose()
        dramaPlayerManager.cleanup()
        dramaCardManager.cleanup()
        storyManager.cleanup()
        videoManager.cleanup()
        userProfileManager.cleanup()
    }

    fun isDramaModuleReady(): Boolean = isSdkInitialized && dramaModuleStarted

    fun isStoryModuleReady(): Boolean = isSdkInitialized && storyModuleStarted

    fun isVideoModuleReady(): Boolean = isSdkInitialized && videoModuleStarted

    fun getPersonalization(result: MethodChannel.Result) {
        val value = getPersonalizationNative() ?: personalizationPreference
        if (value == null) {
            logger.warn("个性化推荐状态未知，返回默认 false")
        }
        result.success(value ?: false)
    }

    fun setPersonalization(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        val applied = setPersonalizationNative(enabled)
        personalizationPreference = enabled
        if (applied) {
            eventHelper.sendEvent(
                "personal_rec_switch",
                extra = mapOf("enabled" to enabled),
            )
            result.success(true)
        } else {
            logger.warn("个性化推荐切换失败，记录本地状态")
            result.success(false)
        }
    }

    fun createStoryHome(call: MethodCall, result: MethodChannel.Result) {
        storyManager.createStoryHome(call, result)
    }

    fun showStoryHome(call: MethodCall, result: MethodChannel.Result) {
        storyManager.showStoryHome(call, result)
    }

    fun destroyStoryHome(call: MethodCall, result: MethodChannel.Result) {
        storyManager.destroyStoryHome(call, result)
    }

    fun getStoryCategoryList(result: MethodChannel.Result) {
        storyManager.getStoryCategoryList(result)
    }

    fun getStoryList(call: MethodCall, result: MethodChannel.Result) {
        storyManager.getStoryList(call, result)
    }

    fun searchStory(call: MethodCall, result: MethodChannel.Result) {
        storyManager.searchStory(call, result)
    }

    fun getStoryHistory(call: MethodCall, result: MethodChannel.Result) {
        storyManager.getStoryHistory(call, result)
    }

    fun favoriteStory(call: MethodCall, result: MethodChannel.Result) {
        storyManager.favoriteStory(call, result)
    }

    fun getFavoriteStories(call: MethodCall, result: MethodChannel.Result) {
        storyManager.getFavoriteStories(call, result)
    }

    fun markStoryAsRead(call: MethodCall, result: MethodChannel.Result) {
        storyManager.markAsRead(call, result)
    }

    fun likeStory(call: MethodCall, result: MethodChannel.Result) {
        storyManager.likeStory(call, result)
    }

    fun updateStoryReadProgress(call: MethodCall, result: MethodChannel.Result) {
        storyManager.updateReadProgress(call, result)
    }

    // region Video API

    fun createVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createVideo(call, result)
    }

    fun showVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.showVideo(call, result)
    }

    fun refreshVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.refreshVideo(call, result)
    }

    fun scrollToTop(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.scrollToTop(call, result)
    }

    fun backRefresh(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.backRefresh(call, result)
    }

    fun refreshVideoToStayUser(call: MethodCall, result: MethodChannel.Result) {
        result.success(false)
    }

    fun showToastToStayUser(call: MethodCall, result: MethodChannel.Result) {
        result.success(false)
    }

    fun setAwakeData(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.setAwakeData(call, result)
    }

    fun seekToPosition(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.seekToPosition(call, result)
    }

    fun setCurrentPage(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.setCurrentPage(call, result)
    }

    fun setSyncData(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.setSyncData(call, result)
    }

    fun pauseForWatchTogether(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.pauseForWatchTogether(call, result)
    }

    fun resumeForWatchTogether(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.resumeForWatchTogether(call, result)
    }

    fun pauseVideo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "videoId cannot be null or empty", null)
                return
            }

            val view = com.zhecent.pangrowth_content.views.VideoPlatformView.findView(videoId)
            if (view == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            view.setUserVisibleHint(false)
            result.success(true)
        } catch (e: Exception) {
            result.error("PAUSE_VIDEO_ERROR", e.message, null)
        }
    }

    fun resumeVideo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val videoId = call.argument<String>("videoId")
            if (videoId.isNullOrEmpty()) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "videoId cannot be null or empty", null)
                return
            }

            val view = com.zhecent.pangrowth_content.views.VideoPlatformView.findView(videoId)
            if (view == null) {
                result.error("VIDEO_NOT_FOUND", "Video with ID $videoId not found", null)
                return
            }

            view.setUserVisibleHint(true)
            result.success(true)
        } catch (e: Exception) {
            result.error("RESUME_VIDEO_ERROR", e.message, null)
        }
    }

    fun destroyVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.destroyVideo(call, result)
    }

    fun createGridWidgetSession(
        configMap: Map<String, Any>?,
        layout: String,
        specifiedId: String? = null,
    ): VideoManager.GridWidgetSession {
        val gridLayout = if (layout.equals("doubleFeed", ignoreCase = true)) {
            VideoManager.GridWidgetLayout.DOUBLE_FEED
        } else {
            VideoManager.GridWidgetLayout.GRID
        }
        return videoManager.createGridWidget(configMap, gridLayout, specifiedId)
    }

    fun attachGridWidget(videoId: String, containerId: Int): Boolean {
        return videoManager.attachGridWidget(videoId, containerId)
    }

    fun refreshGridVideoDirect(videoId: String): Boolean {
        return videoManager.refreshGridVideoDirect(videoId)
    }

    fun scrollGridVideoToTopDirect(videoId: String): Boolean {
        return videoManager.scrollGridVideoToTopDirect(videoId)
    }

    fun backRefreshGridVideoDirect(videoId: String): Boolean {
        return videoManager.backRefreshGridVideoDirect(videoId)
    }

    fun setGridVideoUserVisibleDirect(videoId: String, isVisible: Boolean): Boolean {
        return videoManager.setGridVideoUserVisibleDirect(videoId, isVisible)
    }

    fun canBackPressGridVideoDirect(videoId: String): Boolean? {
        return videoManager.canBackPressGridVideoDirect(videoId)
    }

    fun createUserProfileSession(
        configMap: Map<String, Any>?,
        specifiedId: String? = null,
    ): UserProfileManager.UserProfileSession {
        return userProfileManager.createProfile(configMap, specifiedId)
    }

    fun attachUserProfile(profileId: String, containerId: Int): Boolean {
        return userProfileManager.attachProfile(profileId, containerId)
    }

    fun refreshUserProfileDirect(profileId: String): Boolean {
        return userProfileManager.refreshUserProfileDirect(profileId)
    }

    fun backRefreshUserProfileDirect(profileId: String): Boolean {
        return userProfileManager.backRefreshUserProfileDirect(profileId)
    }

    fun canBackPressUserProfileDirect(profileId: String): Boolean? {
        return userProfileManager.canBackPressUserProfileDirect(profileId)
    }

    fun destroyUserProfileDirect(profileId: String): Pair<Boolean, String?> {
        return userProfileManager.destroyUserProfileDirect(profileId)
    }

    fun destroyGridVideoDirect(videoId: String): Pair<Boolean, String?> {
        return videoManager.destroyGridVideoDirect(videoId)
    }

    fun createGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createGridVideo(call, result)
    }

    fun showGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.showGridVideo(call, result)
    }

    fun refreshGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.refreshGridVideo(call, result)
    }

    fun scrollGridVideoToTop(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.scrollGridVideoToTop(call, result)
    }

    fun backRefreshGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.backRefreshGridVideo(call, result)
    }

    fun setGridVideoUserVisible(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.setGridVideoUserVisible(call, result)
    }

    fun canBackPressGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.canBackPressGridVideo(call, result)
    }

    fun destroyGridVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.destroyGridVideo(call, result)
    }

    fun createDoubleFeedVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createDoubleFeedVideo(call, result)
    }

    fun showDoubleFeedVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.showGridVideo(call, result)
    }

    fun destroyDoubleFeedVideo(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.destroyDoubleFeedVideo(call, result)
    }

    fun createUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.createUserProfile(call, result)
    }

    fun showUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.showUserProfile(call, result)
    }

    fun refreshUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.refreshUserProfile(call, result)
    }

    fun backRefreshUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.backRefreshUserProfile(call, result)
    }

    fun canBackPressUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.canBackPressUserProfile(call, result)
    }

    fun destroyUserProfile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        userProfileManager.destroyUserProfile(call, result)
    }

    fun createVideoCardForNews(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createVideoCard(call, result)
    }

    fun createVideoCardForRecommend(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createSmallVideoCard(call, result)
    }

    fun createVideoCardForSearch(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createCustomVideoCard(call, result)
    }

    fun destroyVideoCard(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.destroyVideoCard(call, result)
    }

    fun createVideoSingleCardForNews(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.createVideoSingleCard4News(call, result)
    }

    fun destroyVideoSingleCard(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureVideoReady(result)) return
        videoManager.destroyVideoSingleCard(call, result)
    }

    fun getCurrentIndex(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "getCurrentIndex 仅支持 iOS", null)
    }

    fun scrollToIndex(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "scrollToIndex 仅支持 iOS", null)
    }

    fun pauseCurrentVideo(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "pauseCurrentVideo 仅支持 iOS", null)
    }

    fun playCurrentVideo(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "playCurrentVideo 仅支持 iOS", null)
    }

    fun seekVideoToMSeconds(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "seekVideoToMSeconds 仅支持 iOS", null)
    }

    fun createReportContent(call: MethodCall, result: MethodChannel.Result) {
        result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "createReportContent 仅支持 iOS", null)
    }

    private fun ensureVideoReady(result: MethodChannel.Result): Boolean {
        if (!isVideoModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "小视频模块未启动", null)
            return false
        }
        return true
    }

    // endregion

    fun createDramaSwipeFlow(call: MethodCall, result: MethodChannel.Result) {
        dramaSwipeCoordinator.create(call, result)
    }

    fun showDramaSwipeFlow(call: MethodCall, result: MethodChannel.Result) {
        dramaSwipeCoordinator.show(call, result)
    }

    fun hideDramaSwipeFlow(call: MethodCall, result: MethodChannel.Result) {
        dramaSwipeCoordinator.hide(call, result)
    }

    fun destroyDramaSwipeFlow(call: MethodCall, result: MethodChannel.Result) {
        dramaSwipeCoordinator.destroy(call, result)
    }

    fun createDramaCard(call: MethodCall, result: MethodChannel.Result) {
        dramaCardManager.createDramaCard(call, result)
    }

    fun showDramaCard(call: MethodCall, result: MethodChannel.Result) {
        dramaCardManager.showDramaCard(call, result)
    }

    fun playDramaCard(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.play()
                result.success(true)
                return
            }
        }

        // 降级到Manager (兼容旧的Activity模式)
        dramaCardManager.playDramaCard(call, result)
    }

    fun pauseDramaCard(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.pause()
                result.success(true)
                return
            }
        }

        // 降级到Manager
        dramaCardManager.pauseDramaCard(call, result)
    }

    fun stopDramaCard(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.stop()
                result.success(true)
                return
            }
        }

        // 降级到Manager
        dramaCardManager.stopDramaCard(call, result)
    }

    fun setDramaCardMute(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        val mute = call.argument<Boolean>("mute") ?: false

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.setMute(mute)
                result.success(true)
                return
            }
        }

        // 降级到Manager
        dramaCardManager.setDramaCardMute(call, result)
    }

    fun reportDramaCardShow(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")
        val duration = call.argument<Number>("duration")?.toLong() ?: 0L

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.reportShow(duration)
                result.success(true)
                return
            }
        }

        // 降级到Manager
        dramaCardManager.reportDramaCardShow(call, result)
    }

    fun refreshDramaCard(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                platformView.refresh()
                result.success(true)
                return
            }
        }

        // 降级到Manager
        dramaCardManager.refreshDramaCard(call, result)
    }

    fun destroyDramaCard(call: MethodCall, result: MethodChannel.Result) {
        dramaCardManager.destroyDramaCard(call, result)
    }

    fun isDramaCardPlaying(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                result.success(platformView.isPlaying())
                return
            }
        }

        // 降级到Manager
        dramaCardManager.isDramaCardPlaying(call, result)
    }

    fun getDramaCardInfo(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                result.success(platformView.getInfo())
                return
            }
        }

        // 降级到Manager
        dramaCardManager.getDramaCardInfo(call, result)
    }

    fun getDramaCardGid(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                result.success(platformView.getGid())
                return
            }
        }

        // 降级到Manager
        dramaCardManager.getDramaCardGid(call, result)
    }

    fun getDramaCardTitle(call: MethodCall, result: MethodChannel.Result) {
        val cardId = call.argument<String>("cardId")

        // 优先查找PlatformView实例
        if (cardId != null) {
            val platformView = com.zhecent.pangrowth_content.views.DramaCardPlatformView.findView(cardId)
            if (platformView != null) {
                result.success(platformView.getTitle())
                return
            }
        }

        // 降级到Manager
        dramaCardManager.getDramaCardTitle(call, result)
    }

    fun createDramaPlayer(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.createDramaPlayer(call, result)
    }

    fun showDramaPlayer(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.showDramaPlayer(call, result)
    }

    fun seekTo(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.seekTo(call, result)
    }

    fun setSpeedPlay(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.setSpeedPlay(call, result)
    }

    fun setCurrentEpisode(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.setCurrentEpisode(call, result)
    }

    fun getCurrentEpisode(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.getCurrentEpisode(call, result)
    }

    fun openMoreDialog(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.openMoreDialog(call, result)
    }

    fun openEpisodePanel(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.openEpisodePanel(call, result)
    }

    fun refreshPlayer(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.refreshPlayer(call, result)
    }

    fun destroyDramaPlayer(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.destroyDramaPlayer(call, result)
    }

    fun setCustomAdOnShow(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.setCustomAdOnShow(call, result)
    }

    fun setCustomAdOnReward(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.setCustomAdOnReward(call, result)
    }

    fun unlockDrama(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.unlockDrama(call, result)
    }

    fun confirmUnlock(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.confirmUnlock(call, result)
    }

    fun cancelUnlock(call: MethodCall, result: MethodChannel.Result) {
        dramaPlayerManager.cancelUnlock(call, result)
    }

    fun generateDramaUnlockSign(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "短剧模块未启动", null)
            return
        }

        val serverKey = call.argument<String>("serverKey")
        val nonce = call.argument<String>("nonce")
        val timestamp = call.argument<Number>("timestamp")?.toLong()
        val payload = call.argument<Map<String, String>>("payload") ?: emptyMap()

        if (serverKey.isNullOrBlank() || nonce.isNullOrBlank() || timestamp == null) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "serverKey、nonce、timestamp 均不能为空", null)
            return
        }

        if (!payload.containsKey("ouid")) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "payload 必须包含 ouid", null)
            return
        }

        try {
            val sign = DJXSdk.service().getSignString(serverKey, nonce, timestamp, HashMap(payload))
            result.success(sign)
        } catch (error: Throwable) {
            logger.error("生成解锁签名失败", error)
            result.error("UNLOCK_SIGN_FAILED", error.message, null)
        }
    }

    fun loginDramaUnlock(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "短剧模块未启动", null)
            return
        }

        val params = call.argument<String>("params")
        val serverKey = call.argument<String>("serverKey")
        val nonce = call.argument<String>("nonce")
        val timestamp = call.argument<Number>("timestamp")?.toLong()
        val payload = call.argument<Map<String, String>>("payload") ?: emptyMap()

        val paramsString = if (!params.isNullOrBlank()) {
            params
        } else {
            if (serverKey.isNullOrBlank() || nonce.isNullOrBlank() || timestamp == null) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "请提供 params 或 serverKey/nonce/timestamp/payload", null)
                return
            }
            if (!payload.containsKey("ouid")) {
                result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "payload 必须包含 ouid", null)
                return
            }
            try {
                DJXSdk.service().getSignString(serverKey, nonce, timestamp, HashMap(payload))
            } catch (error: Throwable) {
                logger.error("生成解锁参数失败", error)
                result.error("UNLOCK_SIGN_FAILED", error.message, null)
                return
            }
        }

        DJXSdk.service().login(paramsString, object : IDJXService.IDJXCallback<DJXUser> {
            override fun onSuccess(data: DJXUser?, others: DJXOthers?) {
                result.success(
                    mapOf(
                        "success" to true,
                        "params" to paramsString,
                    ),
                )
            }

            override fun onError(error: DJXError) {
                val detail = mapOf(
                    "code" to error.code,
                    "message" to error.msg,
                    "subCode" to error.subCode,
                    "requestId" to error.requestId,
                )
                result.error("UNLOCK_LOGIN_FAILED", error.msg, detail)
            }
        })
    }

    fun logoutDramaUnlock(result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "短剧模块未启动", null)
            return
        }

        DJXSdk.service().logout(object : IDJXService.IDJXCallback<DJXUser> {
            override fun onSuccess(data: DJXUser?, others: DJXOthers?) {
                result.success(mapOf("success" to true))
            }

            override fun onError(error: DJXError) {
                val detail = mapOf(
                    "code" to error.code,
                    "message" to error.msg,
                    "subCode" to error.subCode,
                    "requestId" to error.requestId,
                )
                result.error("UNLOCK_LOGOUT_FAILED", error.msg, detail)
            }
        })
    }

    fun isDramaUnlockLogin(result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "短剧模块未启动", null)
            return
        }

        try {
            result.success(DJXSdk.service().isLogin())
        } catch (error: Throwable) {
            logger.error("查询解锁绑定状态失败", error)
            result.error("UNLOCK_STATUS_FAILED", error.message, null)
        }
    }

    fun getDramaList(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20
        val order = call.argument<Boolean>("order") ?: true

        try {
            DJXSdk.service().requestAllDrama(page, count, order, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama ->
                        DramaMapper.dramaToMap(drama as DJXDrama)
                    } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_DRAMA_LIST_FAILED", "获取短剧列表失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取短剧列表异常", throwable)
            result.error("GET_DRAMA_LIST_ERROR", "获取短剧列表异常: ${throwable.message}", null)
        }
    }

    fun getCategoryList(result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        try {
            DJXSdk.service().requestDramaCategoryList(object : IDJXService.IDJXCallback<MutableList<String>?> {
                override fun onSuccess(categoryList: MutableList<String>?, others: DJXOthers?) {
                    result.success(categoryList ?: emptyList<String>())
                }

                override fun onError(error: DJXError) {
                    result.error("GET_CATEGORY_LIST_FAILED", "获取分类列表失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取分类列表异常", throwable)
            result.error("GET_CATEGORY_LIST_ERROR", "获取分类列表异常: ${throwable.message}", null)
        }
    }

    fun searchDrama(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val keyword = call.argument<String>("query")
        if (keyword.isNullOrBlank()) {
            result.error(ContentConstants.ErrorCodes.INVALID_ARGUMENT, "query 不能为空", null)
            return
        }

        val isFuzzy = call.argument<Boolean>("isFuzzy") ?: true
        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        try {
            DJXSdk.service().searchDrama(keyword, isFuzzy, page, count, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama ->
                        DramaMapper.dramaToMap(drama as DJXDrama)
                    } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("SEARCH_DRAMA_FAILED", "搜索短剧失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("搜索短剧异常", throwable)
            result.error("SEARCH_DRAMA_ERROR", "搜索短剧异常: ${throwable.message}", null)
        }
    }

    fun getDramaHistory(call: MethodCall, result: MethodChannel.Result) {
        if (!isDramaModuleReady()) {
            result.error(ContentConstants.ErrorCodes.SDK_NOT_READY, "内容 SDK 未启动", null)
            return
        }

        val page = call.argument<Int>("page") ?: 1
        val count = call.argument<Int>("count") ?: 20

        try {
            DJXSdk.service().getDramaHistory(page, count, object : IDJXService.IDJXCallback<MutableList<out DJXDrama>?> {
                override fun onSuccess(dataList: MutableList<out DJXDrama>?, others: DJXOthers?) {
                    val list = dataList?.map { drama ->
                        DramaMapper.dramaToMap(drama as DJXDrama)
                    } ?: emptyList()
                    result.success(list)
                }

                override fun onError(error: DJXError) {
                    result.error("GET_DRAMA_HISTORY_FAILED", "获取短剧历史失败: ${error.msg}", mapOf("code" to error.code))
                }
            })
        } catch (throwable: Throwable) {
            logger.error("获取短剧历史异常", throwable)
            result.error("GET_DRAMA_HISTORY_ERROR", "获取短剧历史异常: ${throwable.message}", null)
        }
    }

    private fun setPersonalizationNative(enabled: Boolean): Boolean {
        val candidateClasses = listOf(
            "com.bytedance.sdk.djx.update.DJXUpdate",
            "com.bytedance.sdk.djx.update.DJXUpdateService"
        )

        var applied = false
        candidateClasses.forEach { className ->
            if (applied) return@forEach
            try {
                val clazz = Class.forName(className)
                clazz.methods.filter { it.name == "setPersonalRec" }.forEach { method ->
                    when (method.parameterTypes.size) {
                        1 -> {
                            method.invoke(null, enabled)
                            applied = true
                        }
                        2 -> {
                            val callbackType = method.parameterTypes[1]
                            val proxy = Proxy.newProxyInstance(
                                callbackType.classLoader,
                                arrayOf(callbackType)
                            ) { _, _, _ -> null }
                            method.invoke(null, enabled, proxy)
                            applied = true
                        }
                    }
                }
            } catch (_: Throwable) {
                // 尝试下一个类
            }
        }

        if (!applied) {
            applied = setVideoPersonalization(preference = enabled) || applied
        }
        return applied
    }

    private fun getPersonalizationNative(): Boolean? {
        val candidateClasses = listOf(
            "com.bytedance.sdk.djx.update.DJXUpdate",
            "com.bytedance.sdk.djx.update.DJXUpdateService"
        )

        candidateClasses.forEach { className ->
            try {
                val clazz = Class.forName(className)
                val method = clazz.methods.firstOrNull { it.name == "getPersonRec" && it.parameterTypes.isEmpty() }
                val value = method?.invoke(null) as? Boolean
                if (value != null) {
                    return value
                }
            } catch (_: Throwable) {
                // 尝试下一个类
            }
        }

        return try {
            val method = DPSdk::class.java.getMethod("personalizationRecommendation")
            method.invoke(null) as? Boolean
        } catch (_: Throwable) {
            logger.warn("未找到 DJXUpdate#getPersonRec，返回 null")
            null
        }
    }

    private fun startDramaModule(callback: (Boolean, Map<String, Any?>) -> Unit) {
        try {
            DJXSdk.start(DJXSdk.StartListener { isSuccess, message, error ->
                val extra = mutableMapOf<String, Any?>("message" to message)
                error?.let {
                    extra["code"] = it.code
                    extra["subCode"] = it.subCode
                    extra["errorMessage"] = it.msg
                }
                callback(isSuccess, extra)
            })
        } catch (throwable: Throwable) {
            logger.error("调用 DJXSdk.start 失败", throwable)
            callback(false, mapOf("exception" to (throwable.message ?: "unknown")))
        }
    }

    private fun startStoryModule(callback: (Boolean, Map<String, Any?>) -> Unit) {
        try {
            NovSdk.start(object : NovSdk.StartListener {
                override fun onStartComplete(isSuccess: Boolean, message: String?, error: DJXError?) {
                    val extra = mutableMapOf<String, Any?>("message" to message)
                    error?.let {
                        extra["code"] = it.code
                        extra["subCode"] = it.subCode
                        extra["errorMessage"] = it.msg
                    }
                    callback(isSuccess, extra)
                }
            })
        } catch (throwable: Throwable) {
            logger.error("调用 NovSdk.start 失败", throwable)
            callback(false, mapOf("exception" to (throwable.message ?: "unknown")))
        }
    }

    private fun startVideoModule(callback: (Boolean, Map<String, Any?>) -> Unit) {
        mainHandler.post {
            try {
                DPSdk.start { isSuccess, message ->
                    val extra = mutableMapOf<String, Any?>("message" to message)
                    callback(isSuccess, extra)
                }
            } catch (throwable: Throwable) {
                logger.error("调用 DPSdk.start 失败", throwable)
                callback(false, mapOf("exception" to (throwable.message ?: "unknown")))
            }
        }
    }

    private fun applyPersonalizationIfNeeded() {
        val preference = personalizationPreference ?: return
        eventHelper.sendEvent(
            "personal_rec_switch_pending",
            extra = mapOf("enabled" to preference),
        )
        setVideoPersonalization(preference)
        personalizationPreference = null
    }

    private fun setVideoPersonalization(preference: Boolean): Boolean {
        return try {
            val method = DPSdk::class.java.getMethod("setPersonalizationRecommendation", Boolean::class.javaPrimitiveType)
            method.invoke(null, preference)
            true
        } catch (throwable: Throwable) {
            logger.warn("设置小视频个性化推荐失败: ${throwable.message}")
            false
        }
    }

    private fun buildDramaConfig(options: ContentInitOptions): DJXSdkConfig {
        val builder = DJXSdkConfig.Builder()
        options.debugLog?.let { builder.debug(it) }
        options.isNewUser?.let { builder.newUser(it) }
        applyBuilderIfExists(builder, "imageCacheSize", options.imageCacheSize)
        applyBuilderIfExists(builder, "disableABTest", options.disableAbTest)
        applyBuilderIfExists(builder, "aliveSeconds", options.newUserAliveSeconds)

        val config = builder.build()
        applyPrivacyController(config, options.privacy)
        return config
    }

    private fun buildStoryConfig(options: ContentInitOptions): NovSdkConfig {
        val builder = NovSdkConfig.Builder()
        options.debugLog?.let { builder.debug(it) }
        options.isNewUser?.let { builder.newUser(it) }
        applyBuilderIfExists(builder, "aliveSeconds", options.newUserAliveSeconds)

        val config = builder.build()
        applyPrivacyController(config, options.privacy)
        return config
    }

    private fun buildVideoConfig(options: ContentInitOptions): DPSdkConfig {
        val builder = DPSdkConfig.Builder()
        options.debugLog?.let { builder.debug(it) }
        applyBuilderIfExists(builder, "disableABTest", options.disableAbTest)
        options.isNewUser?.let { builder.newUser(it) }
        applyBuilderIfExists(builder, "aliveSeconds", options.newUserAliveSeconds)

        val config = builder.build()
        applyVideoPrivacyController(config, options.privacy)
        return config
    }

    private fun applyVideoPrivacyController(config: DPSdkConfig, privacy: PrivacyOptions?) {
        if (privacy == null) {
            return
        }

        config.privacyController = object : IDPPrivacyController() {
            override fun isCanUsePhoneState(): Boolean {
                return privacy.allowPhoneState ?: super.isCanUsePhoneState()
            }

            override fun getImei(): String? {
                return privacy.imei ?: super.getImei()
            }

            override fun getImsi(): String? {
                return privacy.imsi ?: super.getImsi()
            }

            override fun isCanUseAndroidId(): Boolean {
                return privacy.allowAndroidId ?: super.isCanUseAndroidId()
            }

            override fun getAndroidId(): String? {
                return privacy.androidId ?: super.getAndroidId()
            }

            override fun isCanUseMac(): Boolean {
                return privacy.allowMac ?: super.isCanUseMac()
            }

            override fun isCanUseOAID(): Boolean {
                return privacy.allowOaid ?: super.isCanUseOAID()
            }

            override fun isCanUseICCID(): Boolean {
                return privacy.allowIccid ?: super.isCanUseICCID()
            }

            override fun isCanUseSerialNumber(): Boolean {
                return privacy.allowSerialNumber ?: super.isCanUseSerialNumber()
            }

            override fun isCanUseGAID(): Boolean {
                return privacy.allowGaid ?: super.isCanUseGAID()
            }

            override fun isCanUseOperatorInfo(): Boolean {
                return privacy.allowOperatorInfo ?: super.isCanUseOperatorInfo()
            }

            override fun isTeenagerMode(): Boolean {
                return privacy.teenagerMode ?: super.isTeenagerMode()
            }

        }
    }

    private fun applyPrivacyController(target: Any, privacy: PrivacyOptions?) {
        if (privacy == null) {
            return
        }

        val controller = object : IDJXPrivacyController() {
            override fun isCanUsePhoneState(): Boolean {
                return privacy.allowPhoneState ?: super.isCanUsePhoneState()
            }

            override fun getImei(): String? {
                return privacy.imei ?: super.getImei()
            }

            override fun getImsi(): String? {
                return privacy.imsi ?: super.getImsi()
            }

            override fun isCanUseAndroidId(): Boolean {
                return privacy.allowAndroidId ?: super.isCanUseAndroidId()
            }

            override fun getAndroidId(): String? {
                return privacy.androidId ?: super.getAndroidId()
            }

            override fun isCanUseMac(): Boolean {
                return privacy.allowMac ?: super.isCanUseMac()
            }

            override fun isCanUseOAID(): Boolean {
                return privacy.allowOaid ?: super.isCanUseOAID()
            }

            override fun isCanUseICCID(): Boolean {
                return privacy.allowIccid ?: super.isCanUseICCID()
            }

            override fun isCanUseSerialNumber(): Boolean {
                return privacy.allowSerialNumber ?: super.isCanUseSerialNumber()
            }

            override fun isCanUseGAID(): Boolean {
                return privacy.allowGaid ?: super.isCanUseGAID()
            }

            override fun isCanUseOperatorInfo(): Boolean {
                return privacy.allowOperatorInfo ?: super.isCanUseOperatorInfo()
            }

            override fun isTeenagerMode(): Boolean {
                return privacy.teenagerMode ?: super.isTeenagerMode()
            }

            override fun isOnlyICPNumber(): Boolean {
                return privacy.onlyIcpNumber ?: super.isOnlyICPNumber()
            }
        }

        try {
            val field = target::class.java.getField("privacyController")
            field.set(target, controller)
        } catch (_: NoSuchFieldException) {
            try {
                val method = target::class.java.getMethod("setPrivacyController", IDJXPrivacyController::class.java)
                method.invoke(target, controller)
            } catch (inner: Exception) {
                logger.warn("无法应用隐私控制器: ${inner.message}", inner)
            }
        } catch (error: Throwable) {
            logger.warn("设置隐私控制器失败: ${error.message}", error)
        }
    }

    private fun applyBuilderIfExists(builder: Any, methodName: String, value: Any?) {
        if (value == null) return
        val candidates: Array<Class<*>?> = when (value) {
            is Boolean -> arrayOf(Boolean::class.javaPrimitiveType, Boolean::class.java)
            is Number -> arrayOf(Int::class.javaPrimitiveType, Integer::class.java)
            else -> arrayOf(value::class.java)
        }

        for (candidate in candidates) {
            if (candidate == null) continue
            try {
                val method = builder::class.java.getMethod(methodName, candidate)
                val param = if (value is Number) value.toInt() else value
                method.invoke(builder, param)
                return
            } catch (_: NoSuchMethodException) {
                // 尝试下一个候选类型
            } catch (error: Throwable) {
                logger.warn("调用 $methodName 失败: ${error.message}", error)
                return
            }
        }

        logger.warn("配置项 $methodName 暂不被当前 SDK 版本支持")
    }

    private fun resolveConfigPath(input: String): ConfigResolution {
        val trimmed = input.trim()

        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            val file = writeTempConfig(trimmed)
            return ConfigResolution(
                argumentForSdk = file.absolutePath,
                pathForSdk = file.absolutePath,
                tempFile = file,
                source = "inline_json",
            )
        }

        if (trimmed.startsWith("file://")) {
            val uri = Uri.parse(trimmed)
            val file = File(uri.path ?: throw IllegalArgumentException("无效的 file:// 路径"))
            if (!file.exists()) {
                throw IllegalArgumentException("配置文件不存在: ${file.absolutePath}")
            }
            return ConfigResolution(
                argumentForSdk = file.absolutePath,
                pathForSdk = file.absolutePath,
                source = "file_uri",
            )
        }

        if (trimmed.startsWith("/")) {
            val file = File(trimmed)
            if (!file.exists()) {
                throw IllegalArgumentException("配置文件不存在: ${file.absolutePath}")
            }
            return ConfigResolution(
                argumentForSdk = file.absolutePath,
                pathForSdk = file.absolutePath,
                source = "absolute_path",
            )
        }

        val candidates = mutableListOf<String>()

        // 1. 尝试原始路径
        candidates += flutterAssets.getAssetFilePathByName(trimmed)
        candidates += trimmed

        // 2. 如果路径不以 assets/ 开头，自动尝试添加 assets/ 前缀
        // 这样用户可以直接使用文件名，符合 Flutter 资源引用规范
        if (!trimmed.startsWith("assets/")) {
            val withAssetsPrefix = "assets/$trimmed"
            candidates += flutterAssets.getAssetFilePathByName(withAssetsPrefix)
            candidates += withAssetsPrefix
        }

        candidates.distinct().forEach { candidate ->
            try {
                applicationContext.assets.open(candidate).use { /* no-op */ }
                val source = if (candidate.startsWith("flutter_assets/")) "flutter_asset" else "native_asset"
                return ConfigResolution(
                    argumentForSdk = candidate,
                    pathForSdk = candidate,
                    source = source,
                )
            } catch (_: Throwable) {
                // ignore and try next
            }
        }

        throw IllegalArgumentException("配置文件不存在: $trimmed")
    }

    private fun writeTempConfig(json: String): File {
        val cacheDir = File(applicationContext.cacheDir, "pangrowth")
        if (!cacheDir.exists()) {
            cacheDir.mkdirs()
        }
        val file = File(cacheDir, "config_${System.currentTimeMillis()}.json")
        FileOutputStream(file).use { output ->
            output.write(json.toByteArray(Charset.forName("UTF-8")))
        }
        return file
    }

    private data class ConfigResolution(
        val argumentForSdk: String,
        val pathForSdk: String,
        val tempFile: File? = null,
        val source: String,
    )
}
