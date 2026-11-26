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
 * 短剧剧场 PlatformView 工厂类
 */
internal class DramaSwipeFlowPlatformViewFactory(
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    private var activity: Activity? = null

    fun updateActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val fragmentActivity = activity as? FragmentActivity
            ?: throw IllegalStateException("Activity must be FragmentActivity")

        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<*, *>

        return DramaSwipeFlowPlatformView(
            context = context,
            activity = fragmentActivity,
            eventHelper = eventHelper,
            logger = logger,
            creationParams = creationParams,
        )
    }
}