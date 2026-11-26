package com.zhecent.pangrowth_content.views

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class DramaHomePlatformViewFactory(
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Volatile
    private var activityRef: FragmentActivity? = null

    fun updateActivity(activity: Activity?) {
        activityRef = activity as? FragmentActivity
    }

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        if (context == null) {
            throw IllegalStateException("Context is null when creating DramaHomePlatformView")
        }

        val hostActivity = activityRef ?: (context as? FragmentActivity)
            ?: throw IllegalStateException("未获取到可用的 FragmentActivity，请确认当前 Activity 继承 FragmentActivity")

        val creationParams = args as? Map<*, *>
        return DramaHomePlatformView(
            context = context,
            activity = hostActivity,
            sdkManager = sdkManager,
            eventHelper = eventHelper,
            logger = logger,
            validationHelper = validationHelper,
            creationParams = creationParams,
        )
    }
}
