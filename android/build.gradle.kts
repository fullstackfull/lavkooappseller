import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Move build output to parent build folder
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Some transitive Flutter plugins still hardcode an old compileSdk (for
// example flutter_keyboard_visibility targets android-31), which fails the AAR
// metadata check against AndroidX libraries that require 34+. Pin every
// Android library subproject to the same SDK level the app uses.
// This must stay ABOVE the evaluationDependsOn block below: once that forces
// evaluation, afterEvaluate can no longer be registered. The override has to
// run after each plugin's own build.gradle sets its (stale) compileSdk.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            if (android is com.android.build.gradle.LibraryExtension) {
                android.compileSdk = 36
                if ((android.defaultConfig.minSdk ?: 0) < 24) {
                    android.defaultConfig.minSdk = 24
                }
            }
        }
    }
}

// Ensure :app is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}


// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
