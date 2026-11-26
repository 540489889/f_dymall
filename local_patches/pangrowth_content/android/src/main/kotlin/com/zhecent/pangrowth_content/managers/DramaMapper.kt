package com.zhecent.pangrowth_content.managers

import com.bytedance.sdk.djx.model.DJXDrama
import com.bytedance.sdk.djx.model.DJXEpisodeStatus
import com.bytedance.sdk.djx.model.DJXOthers

internal object DramaMapper {

    fun dramaToMap(drama: DJXDrama): Map<String, Any?> {
        val episodeStatus = drama.episodeStatusList?.map { status ->
            mapOf(
                "index" to status.index,
                "isLocked" to status.isLocked,
            )
        }

        return hashMapOf(
            "id" to drama.id,
            "title" to drama.title,
            "coverImage" to drama.coverImage,
            "desc" to drama.desc,
            "total" to drama.total,
            "index" to drama.index,
            "type" to drama.type,
            "typeId" to drama.typeId,
            "status" to drama.status,
            "freeSet" to drama.freeSet,
            "lockSet" to drama.lockSet,
            "createTime" to drama.createTime,
            "actionTime" to drama.actionTime,
            "scriptName" to drama.scriptName,
            "scriptAuthor" to drama.scriptAuthor,
            "icpNumber" to drama.icpNumber,
            "isFavor" to drama.isFavor,
            "favoriteTime" to drama.favoriteTime,
            "favoriteCount" to drama.favoriteCount,
            "levelLabel" to drama.levelLabel,
            "isPotential" to drama.isPotential,
            "groupId" to drama.groupId,
            "episodeStatusList" to episodeStatus,
        )
    }

    fun episodeStatusMap(list: List<DJXEpisodeStatus>?): List<Map<String, Any?>> {
        if (list == null) return emptyList()
        return list.map { status ->
            mapOf(
                "index" to status.index,
                "isLocked" to status.isLocked,
            )
        }
    }

    fun othersToMap(others: DJXOthers?): Map<String, Any?> {
        if (others == null) return emptyMap()
        return try {
            val keySetMethod = others::class.java.methods.firstOrNull { it.name == "keySet" && it.parameterCount == 0 }
            val getMethod = others::class.java.methods.firstOrNull { it.name == "get" && it.parameterCount == 1 }
            if (keySetMethod != null && getMethod != null) {
                val keys = keySetMethod.invoke(others) as? Set<*>
                if (keys != null) {
                    val map = mutableMapOf<String, Any?>()
                    keys.forEach { key ->
                        val safeKey = key?.toString() ?: return@forEach
                        val value = getMethod.invoke(others, key)
                        map[safeKey] = sanitize(value)
                    }
                    map.toMap()
                } else emptyMap()
            } else {
                emptyMap()
            }
        } catch (_: Throwable) {
            emptyMap()
        }
    }

    fun reflectToMap(instance: Any?): Map<String, Any?> {
        if (instance == null) return emptyMap()
        val clazz = instance::class.java
        val result = mutableMapOf<String, Any?>()
        clazz.declaredFields.forEach { field ->
            try {
                field.isAccessible = true
                result[field.name] = sanitize(field.get(instance))
            } catch (_: Throwable) {
                // ignore
            }
        }
        return result
    }

    fun sanitize(value: Any?): Any? {
        return when (value) {
            null -> null
            is String, is Number, is Boolean -> value
            is DJXDrama -> dramaToMap(value)
            is DJXEpisodeStatus -> mapOf(
                "index" to value.index,
                "isLocked" to value.isLocked,
            )
            is Map<*, *> -> {
                val map = mutableMapOf<String, Any?>()
                value.entries.forEach { entry ->
                    val key = entry.key?.toString() ?: return@forEach
                    map[key] = sanitize(entry.value)
                }
                map
            }
            is List<*> -> value.map { sanitize(it) }
            else -> value.toString()
        }
    }
}
