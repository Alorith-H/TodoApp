allprojects {
    repositories {
        // 华为云镜像（已验证可用）
        maven { url = uri("https://repo.huaweicloud.com/repository/maven") }
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
