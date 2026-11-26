package com.zhecent.pangrowth_content.utils

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/**
 * 内容 SDK 公共校验逻辑
 */
class ContentValidationHelper private constructor(private val applicationContext: Context) {

    fun isNetworkAvailable(): Boolean {
        return try {
            val connectivityManager =
                applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return false
            val capability = connectivityManager.getNetworkCapabilities(network) ?: return false
            capability.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capability.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                capability.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        } catch (_: Exception) {
            true
        }
    }

    fun ensureActivity(activity: Activity?): String? {
        return if (activity == null) {
            "Activity 不可用"
        } else {
            null
        }
    }

    fun isAdSdkReady(): Boolean {
        return try {
            val clazz = Class.forName("com.bytedance.sdk.openadsdk.TTAdSdk")
            val method = clazz.getMethod("isSdkReady")
            (method.invoke(null) as? Boolean) ?: true
        } catch (_: Throwable) {
            true
        }
    }

    companion object {
        @Volatile
        private var INSTANCE: ContentValidationHelper? = null

        fun getInstance(context: Context): ContentValidationHelper {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ContentValidationHelper(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}
