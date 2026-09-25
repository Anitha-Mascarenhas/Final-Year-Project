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

// Plugin subprojects that set Java source/target but no Kotlin jvmTarget (e.g. the
// tflite_flutter plugin: Java 1.8, Kotlin defaults to the JDK's 21) make Gradle fail
// with "Inconsistent JVM-target compatibility". Configure the Kotlin compile tasks
// lazily (configureEach runs after all project evaluation, so nothing re-defaults it)
// and mirror each such subproject's own Java target; :app sets a consistent 17/17.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        if (project.name == "tflite_flutter" || project.name == "jni") {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget("1.8"))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
