package com.zhecent.pangrowth_content.managers

import com.bytedance.sdk.nov.api.model.NovCategory
import com.bytedance.sdk.nov.api.model.NovStory

internal object StoryMapper {

    fun storyToMap(story: NovStory): Map<String, Any?> {
        val extras = DramaMapper.reflectToMap(story)

        val contentPreview = story.content ?: extras["contentTruncation"]?.toString()

        val map = hashMapOf<String, Any?>(
            "storyId" to story.id.toString(),
            "id" to story.id,
            "title" to story.title,
            "description" to (story.desc ?: ""),
            "desc" to (story.desc ?: ""),
            "author" to story.author,
            "coverUrl" to story.coverImage,
            "coverImage" to story.coverImage,
            "imageType" to story.imageType,
            "categoryId" to story.categoryId,
            "categoryName" to story.categoryName,
            "total" to story.total,
            "createTime" to story.createTime,
            "index" to story.index,
            "currentIndex" to story.index,
            "progress" to story.progress,
            "statsCount" to story.statsCount,
            "isFavorited" to story.isFavorite,
            "favoriteState" to story.isFavorite,
            "favoriteTime" to parseFavoriteTime(story.favoriteTime),
            "contentPreview" to (contentPreview ?: ""),
            "content" to (story.content ?: contentPreview ?: ""),
        )

        map["extras"] = extras
        return map
    }

    fun categoryToMap(category: NovCategory): Map<String, Any?> {
        val children = category.children?.map { child -> categoryToMap(child) } ?: emptyList()
        return mapOf(
            "id" to category.id,
            "name" to (category.name ?: ""),
            "level" to category.level,
            "children" to children,
        )
    }

    private fun parseFavoriteTime(raw: Any?): Long {
        return when (raw) {
            null -> 0L
            is Long -> raw
            is Int -> raw.toLong()
            is Number -> raw.toLong()
            else -> raw.toString().toLongOrNull() ?: 0L
        }
    }
}
