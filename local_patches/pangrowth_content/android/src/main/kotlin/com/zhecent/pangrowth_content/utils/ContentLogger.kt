package com.zhecent.pangrowth_content.utils

import android.util.Log
import com.zhecent.pangrowth_content.common.ContentConstants

/**
 * 简单的日志辅助工具，便于统一输出
 */
class ContentLogger private constructor() {

    fun info(message: String, tag: String = ContentConstants.TAG) {
        Log.i(tag, message)
    }

    fun debug(message: String, tag: String = ContentConstants.TAG) {
        Log.d(tag, message)
    }

    fun warn(message: String, throwable: Throwable? = null, tag: String = ContentConstants.TAG) {
        if (throwable != null) {
            Log.w(tag, message, throwable)
        } else {
            Log.w(tag, message)
        }
    }

    fun error(message: String, throwable: Throwable? = null, tag: String = ContentConstants.TAG) {
        if (throwable != null) {
            Log.e(tag, message, throwable)
        } else {
            Log.e(tag, message)
        }
    }

    companion object {
        @Volatile
        private var INSTANCE: ContentLogger? = null

        fun getInstance(): ContentLogger {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ContentLogger().also { INSTANCE = it }
            }
        }
    }
}
