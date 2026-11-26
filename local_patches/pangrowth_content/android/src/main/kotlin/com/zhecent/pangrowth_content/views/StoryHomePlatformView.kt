package com.zhecent.pangrowth_content.views

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.bytedance.sdk.djx.IDJXWidget
import com.bytedance.sdk.nov.api.NovSdk
import com.bytedance.sdk.nov.api.params.NovReaderConfig
import com.bytedance.sdk.nov.api.params.NovWidgetHomeParams
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import com.zhecent.pangrowth_content.utils.ContentLogger
import java.lang.ref.WeakReference

/**
 * 短故事聚合页 PlatformView (Android 实现)
 *
 * 使用 NovSdk.factory().createStoryHome() 创建短故事聚合页Widget，
 * 并将其Fragment嵌入到Flutter PlatformView中。
 *
 * 关键技术点：
 * 1. 使用 OnAttachStateChangeListener 延迟初始化Widget
 * 2. 使用 add 而不是 replace 添加Fragment
 * 3. 使用 commitNowAllowingStateLoss 同步提交Fragment事务
 * 4. 使用 WeakReference 缓存实例，避免内存泄漏
 */
class StoryHomePlatformView(
    private val activity: FragmentActivity,
    private val viewId: Int,
    private val creationParams: Map<*, *>?,
    private val messenger: BinaryMessenger
) : PlatformView {

    companion object {
        // 使用 WeakReference 缓存实例，方便查找和避免内存泄漏
        private val activeViews = mutableMapOf<Int, WeakReference<StoryHomePlatformView>>()

        fun find(viewId: Int): StoryHomePlatformView? {
            return activeViews[viewId]?.get()
        }
    }

    private lateinit var container: FrameLayout
    private var widget: IDJXWidget? = null
    private var isDisposed = false

    init {
        // 添加到活跃视图缓存
        activeViews[viewId] = WeakReference(this)

        // 创建容器
        container = FrameLayout(activity).apply {
            id = View.generateViewId()
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            visibility = View.VISIBLE
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }

        // 核心修复：等待容器附加后再初始化Widget
        container.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                container.removeOnAttachStateChangeListener(this)
                container.post {
                    initializeWidget()
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
            }
        })
    }

    override fun getView(): View = container

    private fun initializeWidget() {
        if (isDisposed) return

        try {
            // 解析配置参数
            val canPullRefresh = creationParams?.get("canPullRefresh") as? Boolean ?: false
            val topOffset = creationParams?.get("topOffset") as? Int ?: -1
            val recPageSize = creationParams?.get("recPageSize") as? Int ?: 9
            val readerConfigMap = creationParams?.get("readerConfig") as? Map<*, *>

            // 创建阅读器配置
            val readerConfig = NovReaderConfig()

            // 应用阅读器配置
            if (readerConfigMap != null) {
                // 这里可以根据需要配置 NovReaderConfig 的属性
                // 例如：endPageRecSize, defaultTextSize 等
            }

            // 创建聚合页参数
            val homeParams = NovWidgetHomeParams(readerConfig).apply {
                this.canPullRefresh = canPullRefresh
                this.topOffset = topOffset
                this.recPageSize = recPageSize
            }

            // 创建短故事聚合页Widget
            widget = NovSdk.factory()?.createStoryHome(homeParams) ?: return

            // 将 Fragment 添加到容器
            val fragmentManager = activity.supportFragmentManager
            if (!fragmentManager.isStateSaved) {
                fragmentManager
                    .beginTransaction()
                    .add(container.id, widget!!.fragment, "story_home_$viewId")
                    .commitNowAllowingStateLoss()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true

        try {
            // 销毁Widget
            widget?.destroy()
            widget = null

            // 从缓存中移除
            activeViews.remove(viewId)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 刷新聚合页
     */
    fun refresh() {
        widget?.refresh()
    }

    /**
     * 回到顶部
     */
    fun scrollToTop() {
        widget?.scrollToTop()
    }
}
