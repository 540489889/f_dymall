package com.chongloutech.lehui

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// 穿山甲内容SDK(pangrowth_content)的短剧原生视图要求宿主 Activity 必须是 FragmentActivity,
// 因此这里用 FlutterFragmentActivity(而非 FlutterActivity), 否则创建 DramaHome 视图会抛
// "未获取到可用的 FragmentActivity" 进而导致短剧页空白。
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 让 Flutter 内容绘制到状态栏之下, 启动图才能铺满状态栏区域;
        // 同时状态栏完全透明, 避免 windowTranslucentStatus 带来的半透明黑蒙层。
        // 只处理状态栏, 导航栏保持系统默认占位。
        window.apply {
            addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
            statusBarColor = Color.TRANSPARENT
        }
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
    }
}
