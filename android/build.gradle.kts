allprojects {
    repositories {
        google()
        mavenCentral()
        // 穿山甲/GroMore 融合SDK与 adapter 依赖仓库
        maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
        // 穿山甲内容SDK(短剧/小视频)仓库: pangrowth_content 必须, 缺了会找不到依赖
        maven { url = uri("https://artifact.bytedance.com/repository/Volcengine") }
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
