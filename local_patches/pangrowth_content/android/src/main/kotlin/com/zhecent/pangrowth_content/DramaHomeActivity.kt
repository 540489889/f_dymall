package com.zhecent.pangrowth_content

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.bytedance.sdk.djx.IDJXWidget

/**
 * 短剧聚合页展示Activity
 * 用于全屏展示短剧聚合页Fragment
 */
class DramaHomeActivity : FragmentActivity() {

    companion object {
        private const val TAG = "DramaHomeActivity"

        // 静态存储Fragment，避免序列化问题
        private val fragmentMap = mutableMapOf<String, Fragment>()

        /**
         * 设置当前要展示的Fragment
         */
        fun setCurrentFragment(widgetId: String, fragment: Fragment) {
            fragmentMap[widgetId] = fragment
            Log.d(TAG, "Fragment set for widgetId: $widgetId")
        }

        /**
         * 清理Fragment
         */
        fun clearFragment(widgetId: String) {
            fragmentMap.remove(widgetId)
            Log.d(TAG, "Fragment cleared for widgetId: $widgetId")
        }
    }

    private var widgetId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "DramaHomeActivity onCreate")

        // 创建简单的布局容器
        val frameLayout = FrameLayout(this).apply {
            id = android.R.id.content
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(frameLayout)

        // 获取传入的widgetId
        widgetId = intent.getStringExtra("widgetId")
        if (widgetId == null) {
            Log.e(TAG, "widgetId is null, finishing activity")
            finish()
            return
        }

        Log.d(TAG, "Loading fragment for widgetId: $widgetId")

        // 获取对应的Fragment
        val fragment = fragmentMap[widgetId]
        if (fragment == null) {
            Log.e(TAG, "Fragment not found for widgetId: $widgetId, finishing activity")
            finish()
            return
        }

        try {
            // 将Fragment添加到容器中
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, fragment)
                .commitAllowingStateLoss()

            Log.d(TAG, "Fragment added successfully for widgetId: $widgetId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add fragment for widgetId: $widgetId", e)
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DramaHomeActivity onDestroy")

        // 清理Fragment引用
        widgetId?.let { id ->
            clearFragment(id)
        }
    }

    /**
     * 处理返回键，让聚合页自己处理返回逻辑
     */
    override fun onBackPressed() {
        val fragment = widgetId?.let { fragmentMap[it] }

        // 首先尝试让Fragment处理返回事件
        if (fragment != null) {
            // 检查Fragment是否能处理返回事件
            // 这里可以根据需要调用聚合页的backRefresh()方法
            try {
                // 如果Fragment无法处理返回事件，则关闭Activity
                Log.d(TAG, "Handling back press, finishing activity")
                super.onBackPressed()
            } catch (e: Exception) {
                Log.e(TAG, "Error handling back press", e)
                super.onBackPressed()
            }
        } else {
            super.onBackPressed()
        }
    }
}