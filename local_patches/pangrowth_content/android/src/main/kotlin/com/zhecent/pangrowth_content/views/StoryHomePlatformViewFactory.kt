package com.zhecent.pangrowth_content.views

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 短故事聚合页 PlatformView 工厂类
 *
 * 负责创建 StoryHomePlatformView 实例
 */
class StoryHomePlatformViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    private var activity: Activity? = null

    fun updateActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val fragmentActivity = activity as? FragmentActivity
            ?: throw IllegalStateException("Activity must be FragmentActivity")

        val creationParams = args as? Map<*, *>
        return StoryHomePlatformView(fragmentActivity, viewId, creationParams, messenger)
    }
}
