allprojects {
    repositories {
        google()
        mavenCentral()
        // 穿山甲/GroMore 融合SDK与 adapter 依赖仓库
        maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
        // 穿山甲内容SDK(短剧/小视频)仓库: pangrowth_content 必须, 缺了会找不到依赖
        maven { url = uri("https://artifact.bytedance.com/repository/Volcengine") }
        // 华为 HMS / 厂商通道(离线推送)依赖仓库: 华为 push SDK 由此解析
        maven { url = uri("https://developer.huawei.com/repo/") }
        // 阿里云移动推送(离线推送)依赖仓库: alicloud-android-push 等由此解析
        maven { url = uri("https://maven.aliyun.com/nexus/content/repositories/releases/") }
        // 荣耀厂商通道依赖仓库
        maven { url = uri("https://developer.hihonor.com/repo") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
