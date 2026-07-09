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

// isar_flutter_libs 3.1.0+1 predates AGP's mandatory `namespace` requirement
// (only declares a manifest `package` attribute) and hardcodes compileSdk 30,
// which is now too old for the AndroidX versions other plugins pull in.
// Backfill both reflectively (no compile-time AGP API dependency) so newer
// AGP versions don't fail configuration. evaluationDependsOn(":app") above
// can force some subprojects to finish evaluating before this block runs for
// them, so afterEvaluate would throw for those - apply immediately in that
// case instead.
subprojects {
    if (project.name != "isar_flutter_libs") return@subprojects

    val applyIsarCompatFix = {
        val android = extensions.findByName("android")
        if (android != null) {
            val methods = android::class.java.methods

            val getNamespace = methods.find { it.name == "getNamespace" }
            if (getNamespace != null && getNamespace.invoke(android) == null) {
                methods.find { it.name == "setNamespace" && it.parameterCount == 1 }
                    ?.invoke(android, "dev.isar.isar_flutter_libs")
            }

            methods.find { it.name == "setCompileSdkVersion" && it.parameterTypes.contentEquals(arrayOf(Int::class.java)) }
                ?.invoke(android, 36)
        }
    }
    if (state.executed) {
        applyIsarCompatFix()
    } else {
        afterEvaluate { applyIsarCompatFix() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
