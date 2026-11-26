package com.zhecent.pangrowth_content

import android.os.Bundle
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.zhecent.pangrowth_content.managers.DramaSwipeCoordinator

/**
 * 全屏展示短剧滑滑流的容器 Activity
 */
class DramaSwipeActivity : FragmentActivity() {

    companion object {
        const val EXTRA_WIDGET_ID = "widgetId"

        private val fragmentMap = mutableMapOf<String, Fragment>()
        private val coordinatorMap = mutableMapOf<String, DramaSwipeCoordinator>()

        fun registerFragment(widgetId: String, fragment: Fragment) {
            fragmentMap[widgetId] = fragment
        }

        fun attachCoordinator(widgetId: String, coordinator: DramaSwipeCoordinator) {
            coordinatorMap[widgetId] = coordinator
        }

        fun clearFragment(widgetId: String) {
            fragmentMap.remove(widgetId)
            coordinatorMap.remove(widgetId)
        }
    }

    private var widgetId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = FrameLayout(this).apply {
            id = android.R.id.content
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        setContentView(layout)

        val id = intent.getStringExtra(EXTRA_WIDGET_ID)
        if (id.isNullOrEmpty()) {
            finish()
            return
        }
        widgetId = id

        val fragment = fragmentMap[id]
        if (fragment == null) {
            finish()
            return
        }

        coordinatorMap[id]?.bindActivity(id, this)
        supportFragmentManager.beginTransaction()
            .replace(android.R.id.content, fragment)
            .commitNowAllowingStateLoss()
    }

    override fun onDestroy() {
        widgetId?.let { coordinatorMap[it]?.bindActivity(it, null) }
        super.onDestroy()
    }

    override fun onBackPressed() {
        val id = widgetId
        if (id == null) {
            super.onBackPressed()
            return
        }
        val coordinator = coordinatorMap[id]
        val canFinish = coordinator?.onBackPressed(id) ?: true
        if (canFinish) {
            super.onBackPressed()
        }
    }
}
