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

// Plugin modules (e.g. share_plus, shared_preferences_android,
// sqflite_android) each declare their own `compileSdk =
// flutter.compileSdkVersion` in their own build scripts, *after* the
// android library plugin is applied — so setting it eagerly here (via
// plugins.withId) just gets overwritten right after by their own
// script. afterEvaluate runs once a subproject's own script has
// finished, so it wins instead. :app is excluded: it's already forced
// to evaluate early by evaluationDependsOn above, so by the time this
// block reaches it, it's already evaluated and afterEvaluate would
// throw — and :app already sets compileSdk directly in its own file
// anyway.
subprojects {
    if (project.name == "app") return@subprojects
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
            android.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
