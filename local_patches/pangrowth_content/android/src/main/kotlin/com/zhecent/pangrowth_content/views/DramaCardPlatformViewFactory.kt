package com.zhecent.pangrowth_content.views

import android.content.Context
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 短剧卡片 PlatformView 工厂类
 */
internal class DramaCardPlatformViewFactory(
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<*, *>

        return DramaCardPlatformView(
            context = context,
            eventHelper = eventHelper,
            logger = logger,
            creationParams = creationParams,
        )
    }
}
