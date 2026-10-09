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
    // flutter_plugin_android_lifecycle requires compiling against API 36+.
    // This must run AFTER each plugin's own build script (e.g. file_picker
    // hardcodes compileSdk 34), so defer per-project as needed.
    if (project.state.executed) {
        project.enforceCompileSdk36()
    } else {
        project.afterEvaluate { project.enforceCompileSdk36() }
    }
}

fun Project.enforceCompileSdk36() {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
