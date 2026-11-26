package com.zhecent.pangrowth_content.managers

import org.json.JSONObject

internal data class PrivacyOptions(
    val allowPhoneState: Boolean? = null,
    val imei: String? = null,
    val imsi: String? = null,
    val allowAndroidId: Boolean? = null,
    val androidId: String? = null,
    val allowMac: Boolean? = null,
    val allowOaid: Boolean? = null,
    val allowIccid: Boolean? = null,
    val allowSerialNumber: Boolean? = null,
    val allowGaid: Boolean? = null,
    val allowOperatorInfo: Boolean? = null,
    val teenagerMode: Boolean? = null,
    val onlyIcpNumber: Boolean? = null,
)

internal data class ContentInitOptions(
    val configPath: String,
    val enableDrama: Boolean = true,
    val enableStory: Boolean = false,
    val enableVideo: Boolean = false,
    val debugLog: Boolean? = null,
    val imageCacheSize: Int? = null,
    val disableAbTest: Boolean? = null,
    val isNewUser: Boolean? = null,
    val newUserAliveSeconds: Int? = null,
    val personalizationEnabled: Boolean? = null,
    val userId: String? = null,
    val channel: String? = null,
    val privacy: PrivacyOptions? = null,
    val extra: Map<String, Any?>? = null,
) {
    val signature: String = buildSignature()

    private fun buildSignature(): String {
        val json = JSONObject()
        json.put("configPath", configPath)
        json.put("enableDrama", enableDrama)
        json.put("enableStory", enableStory)
        json.put("enableVideo", enableVideo)
        debugLog?.let { json.put("debugLog", it) }
        imageCacheSize?.let { json.put("imageCacheSize", it) }
        disableAbTest?.let { json.put("disableAbTest", it) }
        isNewUser?.let { json.put("isNewUser", it) }
        newUserAliveSeconds?.let { json.put("newUserAliveSeconds", it) }
        personalizationEnabled?.let { json.put("personalizationEnabled", it) }
        userId?.let { json.put("userId", it) }
        channel?.let { json.put("channel", it) }
        privacy?.let { privacyOptions ->
            val privacyJson = JSONObject()
            privacyOptions.allowPhoneState?.let { privacyJson.put("allowPhoneState", it) }
            privacyOptions.imei?.let { privacyJson.put("imei", it) }
            privacyOptions.imsi?.let { privacyJson.put("imsi", it) }
            privacyOptions.allowAndroidId?.let { privacyJson.put("allowAndroidId", it) }
            privacyOptions.androidId?.let { privacyJson.put("androidId", it) }
            privacyOptions.allowMac?.let { privacyJson.put("allowMac", it) }
            privacyOptions.allowOaid?.let { privacyJson.put("allowOaid", it) }
            privacyOptions.allowIccid?.let { privacyJson.put("allowIccid", it) }
            privacyOptions.allowSerialNumber?.let { privacyJson.put("allowSerialNumber", it) }
            privacyOptions.allowGaid?.let { privacyJson.put("allowGaid", it) }
            privacyOptions.allowOperatorInfo?.let { privacyJson.put("allowOperatorInfo", it) }
            privacyOptions.teenagerMode?.let { privacyJson.put("teenagerMode", it) }
            privacyOptions.onlyIcpNumber?.let { privacyJson.put("onlyIcpNumber", it) }
            json.put("privacy", privacyJson)
        }
        if (!extra.isNullOrEmpty()) {
            json.put("extra", JSONObject(extra))
        }
        return json.toString()
    }

    fun isCompatibleWith(other: ContentInitOptions): Boolean {
        return signature == other.signature
    }

    companion object {
        fun from(rawConfigPath: String, map: Map<String, Any?>?): ContentInitOptions {
            if (map == null) {
                return ContentInitOptions(configPath = rawConfigPath)
            }

            return ContentInitOptions(
                configPath = rawConfigPath,
                enableDrama = map["enableDrama"] as? Boolean ?: true,
                enableStory = map["enableStory"] as? Boolean ?: false,
                enableVideo = map["enableVideo"] as? Boolean ?: true,
                debugLog = map["debugLog"] as? Boolean?,
                imageCacheSize = coerceInt(map["imageCacheSize"]),
                disableAbTest = map["disableAbTest"] as? Boolean?,
                isNewUser = map["isNewUser"] as? Boolean?,
                newUserAliveSeconds = coerceInt(map["newUserAliveSeconds"]),
                personalizationEnabled = map["personalizationEnabled"] as? Boolean?,
                userId = map["userId"] as? String?,
                channel = map["channel"] as? String?,
                privacy = (map["privacy"] as? Map<*, *>)?.let { parsePrivacy(it) },
                extra = (map["extra"] as? Map<*, *>)?.mapNotNull {
                    val key = it.key as? String ?: return@mapNotNull null
                    key to it.value
                }?.toMap(),
            )
        }

        private fun parsePrivacy(map: Map<*, *>): PrivacyOptions {
            fun bool(key: String): Boolean? = (map[key] as? Boolean?)
            fun string(key: String): String? = (map[key] as? String?)

            return PrivacyOptions(
                allowPhoneState = bool("allowPhoneState"),
                imei = string("imei"),
                imsi = string("imsi"),
                allowAndroidId = bool("allowAndroidId"),
                androidId = string("androidId"),
                allowMac = bool("allowMac"),
                allowOaid = bool("allowOaid"),
                allowIccid = bool("allowIccid"),
                allowSerialNumber = bool("allowSerialNumber"),
                allowGaid = bool("allowGaid"),
                allowOperatorInfo = bool("allowOperatorInfo"),
                teenagerMode = bool("teenagerMode"),
                onlyIcpNumber = bool("onlyIcpNumber"),
            )
        }

        private fun coerceInt(value: Any?): Int? {
            return when (value) {
                null -> null
                is Int -> value
                is Number -> value.toInt()
                else -> value.toString().toIntOrNull()
            }
        }
    }
}
