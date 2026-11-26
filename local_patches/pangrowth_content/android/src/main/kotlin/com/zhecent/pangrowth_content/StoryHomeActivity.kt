package com.zhecent.pangrowth_content

import android.os.Bundle
import android.util.Log
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity

/**
 * 短故事聚合页展示 Activity
 */
class StoryHomeActivity : FragmentActivity() {

    companion object {
        private const val TAG = "StoryHomeActivity"

        private val fragmentMap = mutableMapOf<String, Fragment>()

        fun setFragment(widgetId: String, fragment: Fragment) {
            fragmentMap[widgetId] = fragment
            Log.d(TAG, "Fragment set for widgetId: $widgetId")
        }

        fun clearFragment(widgetId: String) {
            fragmentMap.remove(widgetId)
            Log.d(TAG, "Fragment cleared for widgetId: $widgetId")
        }
    }

    private var widgetId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = FrameLayout(this).apply {
            id = android.R.id.content
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        setContentView(container)

        widgetId = intent.getStringExtra("widgetId")
        if (widgetId == null) {
            Log.e(TAG, "widgetId is null, finish activity")
            finish()
            return
        }

        val fragment = fragmentMap[widgetId]
        if (fragment == null) {
            Log.e(TAG, "Fragment not found for widgetId: $widgetId")
            finish()
            return
        }

        supportFragmentManager.beginTransaction()
            .replace(android.R.id.content, fragment)
            .commitAllowingStateLoss()
    }

    override fun onDestroy() {
        super.onDestroy()
        widgetId?.let { clearFragment(it) }
    }
}
