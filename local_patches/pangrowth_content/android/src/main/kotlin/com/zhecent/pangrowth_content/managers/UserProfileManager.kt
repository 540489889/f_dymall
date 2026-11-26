package com.zhecent.pangrowth_content.managers

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.bytedance.sdk.dp.DPSdk
import com.bytedance.sdk.dp.DPWidgetUserProfileParam
import com.bytedance.sdk.dp.IDPWidget
import com.zhecent.pangrowth_content.utils.ContentEventHelper
import com.zhecent.pangrowth_content.utils.ContentLogger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal class UserProfileManager(
    private val context: Context,
    private val eventHelper: ContentEventHelper,
    private val logger: ContentLogger,
) {

    companion object {
        private const val TAG = "UserProfileManager"
        private const val LOG_PREFIX_PROFILE = "[PC][ProfileNative]"
    }

    private var activity: Activity? = null
    private val profileWidgets = ConcurrentHashMap<String, IDPWidget>()

    data class UserProfileSession(
        val profileId: String,
        val widget: IDPWidget,
    )

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun cleanup() {
        profileWidgets.keys.toList().forEach { destroyProfileInternal(it) }
    }

    private fun removeFragmentByTag(tag: String) {
        val fragmentActivity = activity as? FragmentActivity ?: return
        val fragmentManager = fragmentActivity.supportFragmentManager
        val fragment = fragmentManager.findFragmentByTag(tag) ?: return
        fragmentManager.beginTransaction()
            .remove(fragment)
            .commitAllowingStateLoss()
    }

    @Throws(IllegalStateException::class)
    internal fun createProfile(
        configMap: Map<String, Any>?,
        specifiedId: String? = null,
    ): UserProfileSession {
        logger.debug(
            "$LOG_PREFIX_PROFILE createProfile specifiedId=$specifiedId config=${configMap.orEmpty()}",
            TAG,
        )
        if (!DPSdk.isStartSuccess()) {
            throw IllegalStateException("DPSdk is not started. Please call start() first.")
        }

        val fragmentActivity = activity as? FragmentActivity
            ?: throw IllegalStateException("Activity must be FragmentActivity")

        val params = createUserProfileParams(configMap)
        val profileId = specifiedId ?: UUID.randomUUID().toString()

        val widget = DPSdk.factory().create(params)
            ?: throw IllegalStateException("Failed to create user profile widget")

        profileWidgets[profileId] = widget

        logger.debug("$LOG_PREFIX_PROFILE createProfile success id=$profileId", TAG)
        return UserProfileSession(profileId, widget)
    }

    private fun createUserProfileParams(configMap: Map<String, Any>?): DPWidgetUserProfileParam {
        val params = DPWidgetUserProfileParam.get()

        if (configMap != null) {
            if (configMap.containsKey("hideCloseIcon")) {
                val hide = configMap["hideCloseIcon"] as? Boolean
                if (hide != null) {
                    params.hideCloseIcon(hide)
                }
            }

            if (configMap.containsKey("width")) {
                val width = (configMap["width"] as? Number)?.toInt()
                if (width != null && width > 0) {
                    params.width(width)
                }
            }

            if (configMap.containsKey("height")) {
                val height = (configMap["height"] as? Number)?.toInt()
                if (height != null && height > 0) {
                    params.height(height)
                }
            }

            if (configMap.containsKey("scene")) {
                val scene = configMap["scene"] as? String
                if (!scene.isNullOrEmpty()) {
                    params.scene(scene)
                }
            }

            if (configMap.containsKey("pageType")) {
                val raw = (configMap["pageType"] as? String)?.uppercase()
                val pageType = when (raw) {
                    "USER_FAVORITE_VIDEO_PAGE" -> DPWidgetUserProfileParam.PageType.USER_FAVORITE_VIDEO_PAGE
                    "USER_FOCUS_PAGE" -> DPWidgetUserProfileParam.PageType.USER_FOCUS_PAGE
                    else -> DPWidgetUserProfileParam.PageType.USER_HOME_PAGE
                }
                params.pageType(pageType)
            }
        }

        return params
    }

    internal fun attachProfile(profileId: String, containerId: Int, tag: String? = null): Boolean {
        val fragmentActivity = activity as? FragmentActivity ?: return false
        val widget = profileWidgets[profileId] ?: return false
        val fragment = widget.fragment ?: return false

        fragmentActivity.supportFragmentManager.beginTransaction()
            .replace(containerId, fragment, tag ?: "user_profile_fragment_$profileId")
            .commitAllowingStateLoss()

        return true
    }

    private inline fun <T> withProfileWidget(
        profileId: String,
        noinline onMissing: (() -> Unit)? = null,
        action: (IDPWidget) -> T,
    ): T? {
        val widget = profileWidgets[profileId]
        return if (widget != null) {
            action(widget)
        } else {
            onMissing?.invoke()
            null
        }
    }

    private fun refreshInternal(profileId: String): Boolean {
        return withProfileWidget(profileId) {
            logger.debug("$LOG_PREFIX_PROFILE refresh profileId=$profileId", TAG)
            it.refresh()
            true
        } ?: false
    }

    private fun backRefreshInternal(profileId: String): Boolean {
        return withProfileWidget(profileId) {
            logger.debug("$LOG_PREFIX_PROFILE backRefresh profileId=$profileId", TAG)
            it.backRefresh()
            true
        } ?: false
    }

    private fun canBackPressInternal(profileId: String): Boolean? {
        logger.debug("$LOG_PREFIX_PROFILE canBackPress profileId=$profileId", TAG)
        return withProfileWidget(profileId) {
            it.canBackPress()
        }
    }

    private fun destroyProfileInternal(profileId: String): Pair<Boolean, String?> {
        logger.debug("$LOG_PREFIX_PROFILE destroy profileId=$profileId", TAG)
        val widget = profileWidgets.remove(profileId)
        removeFragmentByTag("user_profile_fragment_$profileId")
        return if (widget != null) {
            try {
                widget.destroy()
                logger.debug("$LOG_PREFIX_PROFILE destroy success profileId=$profileId", TAG)
                true to null
            } catch (error: Throwable) {
                logger.error("$LOG_PREFIX_PROFILE destroy failed profileId=$profileId", error, TAG)
                false to (error.message ?: "destroy failed")
            }
        } else {
            logger.warn("$LOG_PREFIX_PROFILE destroy miss profileId=$profileId", tag = TAG)
            false to "User profile not found"
        }
    }

    fun createUserProfile(call: MethodCall, result: Result) {
        try {
            val configMap = call.argument<Map<String, Any>>("config")
            val session = createProfile(configMap)
            result.success(
                mapOf(
                    "profileId" to session.profileId,
                    "success" to true,
                ),
            )
        } catch (e: Exception) {
            logger.error("Error creating user profile", e, TAG)
            result.error("CREATE_ERROR", e.message, null)
        }
    }

    fun showUserProfile(call: MethodCall, result: Result) {
        try {
            val profileId = call.argument<String>("profileId")
            if (profileId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "profileId cannot be null or empty", null)
                return
            }
            val containerId = call.argument<Int>("containerId") ?: android.R.id.content
            if (!attachProfile(profileId, containerId)) {
                result.error("PROFILE_NOT_FOUND", "User profile with ID $profileId not found", null)
                return
            }
            result.success(
                mapOf(
                    "profileId" to profileId,
                    "shown" to true,
                ),
            )
        } catch (e: Exception) {
            logger.error("Error showing user profile", e, TAG)
            result.error("SHOW_ERROR", e.message, null)
        }
    }

    fun refreshUserProfile(call: MethodCall, result: Result) {
        try {
            val profileId = call.argument<String>("profileId")
            if (profileId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "profileId cannot be null or empty", null)
                return
            }
            if (!refreshInternal(profileId)) {
                result.error("PROFILE_NOT_FOUND", "User profile with ID $profileId not found", null)
                return
            }
            result.success(
                mapOf(
                    "profileId" to profileId,
                    "refreshed" to true,
                ),
            )
        } catch (e: Exception) {
            logger.error("Error refreshing user profile", e, TAG)
            result.error("REFRESH_ERROR", e.message, null)
        }
    }

    fun backRefreshUserProfile(call: MethodCall, result: Result) {
        try {
            val profileId = call.argument<String>("profileId")
            if (profileId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "profileId cannot be null or empty", null)
                return
            }
            if (!backRefreshInternal(profileId)) {
                result.error("PROFILE_NOT_FOUND", "User profile with ID $profileId not found", null)
                return
            }
            result.success(
                mapOf(
                    "profileId" to profileId,
                    "refreshed" to true,
                ),
            )
        } catch (e: Exception) {
            logger.error("Error backRefresh user profile", e, TAG)
            result.error("BACK_REFRESH_ERROR", e.message, null)
        }
    }

    fun canBackPressUserProfile(call: MethodCall, result: Result) {
        try {
            val profileId = call.argument<String>("profileId")
            if (profileId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "profileId cannot be null or empty", null)
                return
            }
            val value = canBackPressInternal(profileId)
            if (value == null) {
                result.error("PROFILE_NOT_FOUND", "User profile with ID $profileId not found", null)
                return
            }
            result.success(value)
        } catch (e: Exception) {
            logger.error("Error canBackPress user profile", e, TAG)
            result.error("BACK_PRESS_ERROR", e.message, null)
        }
    }

    fun destroyUserProfile(call: MethodCall, result: Result) {
        try {
            val profileId = call.argument<String>("profileId")
            if (profileId.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "profileId cannot be null or empty", null)
                return
            }

            val (destroyed, message) = destroyProfileInternal(profileId)
            val response = mutableMapOf<String, Any?>(
                "profileId" to profileId,
                "destroyed" to destroyed,
            )
            message?.let { response["message"] = it }
            result.success(response)
        } catch (e: Exception) {
            logger.error("Error destroying user profile", e, TAG)
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    internal fun refreshUserProfileDirect(profileId: String): Boolean = refreshInternal(profileId)

    internal fun backRefreshUserProfileDirect(profileId: String): Boolean = backRefreshInternal(profileId)

    internal fun canBackPressUserProfileDirect(profileId: String): Boolean? = canBackPressInternal(profileId)

    internal fun destroyUserProfileDirect(profileId: String): Pair<Boolean, String?> = destroyProfileInternal(profileId)
}
