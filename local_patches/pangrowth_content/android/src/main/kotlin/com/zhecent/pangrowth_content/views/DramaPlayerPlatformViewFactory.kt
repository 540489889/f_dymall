package com.zhecent.pangrowth_content.views

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import com.zhecent.pangrowth_content.utils.ContentValidationHelper
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

internal class DramaPlayerPlatformViewFactory(
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val validationHelper: ContentValidationHelper,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Volatile
    private var activity: FragmentActivity? = null

    fun updateActivity(activity: Activity?) {
        this.activity = activity as? FragmentActivity
    }

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val hostActivity = activity
            ?: throw IllegalStateException("DramaPlayerPlatformView 需要在 Activity 上下文中创建")
        val safeContext = context ?: hostActivity
        val params = args as? Map<*, *>
        return DramaPlayerPlatformView(
            safeContext,
            hostActivity,
            sdkManager,
            eventHelper,
            logger,
            validationHelper,
            params,
        )
    }
}
