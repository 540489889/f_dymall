package com.zhecent.pangrowth_content.views

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.managers.ContentSdkManager
import com.zhecent.pangrowth_content.managers.UserProfileManager
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.platform.PlatformView
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

internal class UserProfilePlatformView(
    context: Context,
    private val activity: FragmentActivity,
    private val sdkManager: ContentSdkManager,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
    private val creationParams: Map<*, *>?,
) : PlatformView {

    companion object {
        private const val LOG_PREFIX = "[PC][ProfileNative]"
        private val activeViews = ConcurrentHashMap<String, WeakReference<UserProfilePlatformView>>()

        fun findView(profileId: String): UserProfilePlatformView? {
            return activeViews[profileId]?.get()
        }
    }

    private val container: FrameLayout = FrameLayout(context).apply {
        id = View.generateViewId()
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    private val profileId: String = (creationParams?.get("profileId") as? String)
        ?: "user_profile_${System.currentTimeMillis()}"
    private val configMap: Map<String, Any>? = creationParams?.get("config") as? Map<String, Any>

    private var session: UserProfileManager.UserProfileSession? = null
    private var disposed = false

    init {
        activeViews[profileId] = WeakReference(this)
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                container.removeOnAttachStateChangeListener(this)
                container.post { initializeWidget() }
            }

            override fun onViewDetachedFromWindow(v: View) {
                // no-op
            }
        })
    }

    private fun initializeWidget() {
        if (disposed || session != null) return
        try {
            val extraMap = (creationParams?.get("extra") as? Map<String, Any>) ?: emptyMap()
            val mergedConfig = configMap?.toMutableMap() ?: mutableMapOf()
            if (extraMap.isNotEmpty()) {
                mergedConfig.putAll(extraMap)
            }

            val sdkSession = sdkManager.createUserProfileSession(mergedConfig, profileId)
            session = sdkSession

            if (!sdkManager.attachUserProfile(profileId, container.id)) {
                throw IllegalStateException("Failed to attach user profile")
            }

            logger.debug("$LOG_PREFIX PlatformView init profileId=$profileId", "UserProfilePlatformView")
        } catch (error: Throwable) {
            logger.error("$LOG_PREFIX PlatformView init failed", error, "UserProfilePlatformView")
            sendError("INIT_ERROR", error.message ?: "initialize failed")
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true
        logger.debug("$LOG_PREFIX PlatformView dispose profileId=$profileId", "UserProfilePlatformView")
        activeViews.remove(profileId)
        session = null
        sdkManager.destroyUserProfileDirect(profileId)
    }

    fun refresh(): Boolean = sdkManager.refreshUserProfileDirect(profileId)

    fun backRefresh(): Boolean = sdkManager.backRefreshUserProfileDirect(profileId)

    fun canBackPress(): Boolean? = sdkManager.canBackPressUserProfileDirect(profileId)

    private fun sendError(code: String, message: String) {
        val payload = mapOf(
            "code" to code,
            "message" to message,
            "profileId" to profileId,
        )
        eventHelper.sendEvent("onUserProfileError", contentId = profileId, extra = payload)
    }
}
