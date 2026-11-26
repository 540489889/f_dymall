package com.zhecent.pangrowth_content.views

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 小视频 PlatformView 工厂
 */
internal class VideoPlatformViewFactory(
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Volatile
    private var activity: FragmentActivity? = null

    fun updateActivity(activity: Activity?) {
        this.activity = activity as? FragmentActivity
    }

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val hostActivity = activity
            ?: throw IllegalStateException("VideoPlatformView 需要在 Activity 上下文中创建")
        val safeContext = context ?: hostActivity
        val creationParams = args as? Map<*, *>
        return VideoPlatformView(
            context = safeContext,
            activity = hostActivity,
            eventHelper = eventHelper,
            logger = logger,
            creationParams = creationParams,
        )
    }
}