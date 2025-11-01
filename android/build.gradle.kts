// lib/android/build.gradle.kts

// (★핵심 수정★) 이 buildscript 블록이 누락되었습니다.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // (★핵심 수정★) 구글 서비스 플러그인 자체를 추가합니다.
        classpath("com.google.gms:google-services:4.4.2") // (안전한 최신 버전)
    }
}
// (★여기까지 추가★)

allprojects {
    repositories {
        google()
        mavenCentral()
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