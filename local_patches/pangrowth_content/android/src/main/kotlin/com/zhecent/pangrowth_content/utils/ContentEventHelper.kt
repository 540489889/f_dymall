package com.zhecent.pangrowth_content.utils

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * 统一管理内容 SDK 的事件下发
 */
class ContentEventHelper {

    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun updateEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun sendEvent(
        action: String,
        contentId: String = "sdk",
        extra: Map<String, Any?>? = null,
    ) {
        val payload = mutableMapOf<String, Any?>(
            "type" to action,
            "action" to action,
            "contentId" to contentId,
            "timestamp" to System.currentTimeMillis(),
        )
        if (!extra.isNullOrEmpty()) {
            payload["extra"] = extra
            // 展开一份 extra 方便 Dart 端快速读取
            extra.forEach { (key, value) ->
                if (key !in payload) {
                    payload[key] = value
                }
            }
        }

        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    fun sendError(action: String, code: String, message: String, detail: Map<String, Any?>? = null) {
        val extra = mutableMapOf<String, Any?>(
            "code" to code,
            "message" to message,
        )
        if (detail != null) {
            extra.putAll(detail)
        }
        sendEvent(action, extra = extra)
    }
}
