package com.chongloutech.lehui

import android.graphics.Matrix
import android.util.Log
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import java.util.Collections
import java.util.WeakHashMap

/**
 * 短剧(穿山甲 DJX)视频比例修正。
 *
 * 背景:
 *   DJX 3.0.0.2 的短剧播放器把视频按「屏幕尺寸」以 fill(非等比) 方式渲染 —— 9:16 的源被
 *   拉伸到 20:9 的手机上, 纵向多拉长约 24%, 人物明显变形。而 3.0.0.2 是 Android 16(API36)
 *   上唯一能初始化成功的版本(它修掉了 DJX 侧的 TLSv1 问题), 低版本(2.6.0.0)虽比例正常但
 *   在这台机器上初始化直接失败, 所以不能靠降级回避, 只能在原生侧修正渲染。
 *
 * 原理:
 *   SDK 的视频承载 View 是 TextureView / SurfaceView, 尺寸 = 整屏(w×h)。
 *   按其当前尺寸反算一个「等比 + 覆盖(centerCrop)」的变换, 把被 fill 变形的画面反向缩放
 *   回 9:16。代价是左右各裁掉一点, 观感与主流短视频的 centerCrop 一致(画面铺满不变形)。
 *
 * 作用域:
 *   只处理「Flutter 平台视图容器内的」视频 View —— 短剧滑滑流是 PlatformView(插件把 SDK 的
 *   Fragment 塞进 FrameLayout)。不会影响 Flutter 自身的渲染 View, 也不会影响 video_player
 *   这类纯纹理播放器(它们的 TextureView 不在平台视图树里)。
 *
 * 查看日志: adb logcat -s DramaAspectFix
 */
object DramaAspectFixer {
    private const val TAG = "DramaAspectFix"

    /** 总开关: 置 false 可快速回到 SDK 原始表现做 A/B 对比 */
    private const val ENABLED = true

    /** 短剧源视频宽高比: 主流竖屏短剧为 9:16 */
    private const val SRC_RATIO = 9f / 16f

    /** 已处理过的 View(弱引用, 随 View 回收), 仅用于收敛日志 */
    private val logged = Collections.newSetFromMap(WeakHashMap<View, Boolean>())

    /**
     * 监听整棵视图树的布局变化并修正其中的视频 View。
     * 滑滑流滚动会不断创建新的 item(视频 View), 布局变化时会再次触发扫描。
     */
    fun attach(decorView: View) {
        decorView.viewTreeObserver.addOnGlobalLayoutListener(
            object : ViewTreeObserver.OnGlobalLayoutListener {
                override fun onGlobalLayout() {
                    if (!ENABLED) return
                    try {
                        scan(decorView)
                    } catch (t: Throwable) {
                        Log.w(TAG, "扫描视图树失败(忽略): $t")
                    }
                }
            }
        )
    }

    private fun scan(view: View) {
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val child = view.getChildAt(i)
                if (child != null) scan(child)
            }
        }
        when (view) {
            is TextureView -> fixTextureView(view)
            is SurfaceView -> fixSurfaceView(view)
        }
    }

    /** 该 View 是否位于 Flutter 平台视图容器内(短剧滑滑流) */
    private fun inPlatformView(view: View): Boolean {
        var parent = view.parent
        while (parent is View) {
            val name = parent.javaClass.name
            if (name.contains("MutatorView") || name.contains("PlatformViewWrapper")) return true
            parent = parent.parent
        }
        return false
    }

    /**
     * 反算 centerCrop 缩放: 让被 fill 变形的画面回到源比例且铺满容器。
     * @return [scaleX, scaleY, 目标宽, 目标高]; 比例本来就匹配时返回 null(无需处理)
     */
    private fun computeScale(w: Float, h: Float): FloatArray? {
        if (w <= 0f || h <= 0f) return null
        var dw = w
        var dh = w / SRC_RATIO
        if (dh < h) { // 宽度撑满时高度不够 -> 改成以高度为准, 宽度溢出(左右裁掉)
            dh = h
            dw = h * SRC_RATIO
        }
        val sx = dw / w
        val sy = dh / h
        if (sx <= 1.001f && sy <= 1.001f) return null
        return floatArrayOf(sx, sy, dw, dh)
    }

    private fun fixTextureView(tv: TextureView) {
        val w = tv.width.toFloat()
        val h = tv.height.toFloat()
        val r = computeScale(w, h) ?: return
        if (!inPlatformView(tv)) return
        val sx = r[0]
        val sy = r[1]
        val dw = r[2]
        val dh = r[3]
        val m = Matrix()
        m.setScale(sx, sy)
        m.postTranslate((w - dw) / 2f, (h - dh) / 2f) // 缩放后居中
        tv.setTransform(m)
        logOnce(tv, "TextureView", w, h, sx, sy, dw, dh)
    }

    private fun fixSurfaceView(sv: SurfaceView) {
        val w = sv.width.toFloat()
        val h = sv.height.toFloat()
        val r = computeScale(w, h) ?: return
        if (!inPlatformView(sv)) return
        val sx = r[0]
        val sy = r[1]
        val dw = r[2]
        val dh = r[3]
        sv.scaleX = sx
        sv.scaleY = sy
        sv.translationX = (w - dw) / 2f
        sv.translationY = (h - dh) / 2f
        // 缩放后的画面会超出自身 bounds, 让父容器裁掉溢出部分, 避免糊到相邻 item
        (sv.parent as? ViewGroup)?.clipChildren = true
        logOnce(sv, "SurfaceView", w, h, sx, sy, dw, dh)
    }

    private fun logOnce(
        view: View,
        kind: String,
        w: Float,
        h: Float,
        sx: Float,
        sy: Float,
        dw: Float,
        dh: Float,
    ) {
        if (!logged.add(view)) return
        Log.d(
            TAG,
            "修正 $kind: view=${w.toInt()}x${h.toInt()} -> 画面=${dw.toInt()}x${dh.toInt()}, " +
                "scaleX=$sx, scaleY=$sy (屏幕比=${"%.2f".format(h / w)}, 源比=${"%.2f".format(1f / SRC_RATIO)})"
        )
    }
}
