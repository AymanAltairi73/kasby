allprojects {
    repositories {
        maven { setUrl("https://maven.aliyun.com/repository/google") }
        maven { setUrl("https://maven.aliyun.com/repository/public") }
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
    project.plugins.withId("com.android.library") {
        project.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        project.dependencies.add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
        (project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.let { android ->
            android.defaultConfig {
                multiDexEnabled = true
                ndk {
                    abiFilters.clear()
                    abiFilters.add("arm64-v8a")
                }
            }
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
                isCoreLibraryDesugaringEnabled = true
            }
        }
    }
    project.plugins.withId("com.android.application") {
        project.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        project.dependencies.add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
