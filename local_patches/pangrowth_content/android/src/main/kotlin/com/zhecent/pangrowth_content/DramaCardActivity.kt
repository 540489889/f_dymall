package com.zhecent.pangrowth_content

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.djx.IDJXElement
import com.zhecent.pangrowth_content.managers.DramaCardManager

/**
 * 展示短剧卡片的全屏容器 Activity
 */
class DramaCardActivity : Activity() {

    companion object {
        const val EXTRA_CARD_ID = "cardId"

        private val elementMap = mutableMapOf<String, IDJXElement>()
        private val managerMap = mutableMapOf<String, DramaCardManager>()

        fun registerElement(cardId: String, element: IDJXElement) {
            elementMap[cardId] = element
        }

        fun attachManager(cardId: String, manager: DramaCardManager) {
            managerMap[cardId] = manager
        }

        fun clear(cardId: String) {
            elementMap.remove(cardId)
            managerMap.remove(cardId)
        }
    }

    private var cardId: String? = null

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

        val id = intent.getStringExtra(EXTRA_CARD_ID)
        if (id.isNullOrEmpty()) {
            finish()
            return
        }
        cardId = id

        val element = elementMap[id]
        if (element == null) {
            finish()
            return
        }

        managerMap[id]?.bindActivity(id, this)

        val view = element.view ?: run {
            finish()
            return
        }

        (view.parent as? ViewGroup)?.removeView(view)
        container.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun onDestroy() {
        cardId?.let { managerMap[it]?.bindActivity(it, null) }
        cardId?.let { clear(it) }
        super.onDestroy()
    }
}
