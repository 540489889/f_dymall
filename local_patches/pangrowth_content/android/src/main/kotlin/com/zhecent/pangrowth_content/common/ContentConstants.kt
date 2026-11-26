package com.zhecent.pangrowth_content.common

/**
 * 内容 SDK 常量定义
 */
object ContentConstants {

    const val TAG = "PangrowthContent"

    object Events {
        // SDK 初始化
        const val SDK_INIT_START = "sdk_init_start"
        const val SDK_INIT_SUCCESS = "sdk_init_success"
        const val SDK_INIT_FAIL = "sdk_init_fail"
        const val SDK_INIT_REUSED = "sdk_init_reused"

        // SDK 启动
        const val SDK_START_START = "sdk_start_start"
        const val SDK_START_SUCCESS = "sdk_start_success"
        const val SDK_START_FAIL = "sdk_start_fail"

        // 短剧卡片
        const val DRAMA_CARD = "drama_card"

        // 其他统一事件
        const val ERROR = "sdk_error"
    }

    object ErrorCodes {
        const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
        const val CONFIG_NOT_FOUND = "CONFIG_NOT_FOUND"
        const val SDK_NOT_READY = "SDK_NOT_READY"
        const val SDK_NOT_INITIALIZED = "SDK_NOT_INITIALIZED"
        const val INIT_INCOMPATIBLE = "INIT_INCOMPATIBLE"
        const val START_ALREADY_RUNNING = "START_ALREADY_RUNNING"
    }
}
