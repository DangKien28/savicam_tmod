// FILE: apps/relap/android/build.gradle.kts
// OWNER: DEV-04 (TASK-D04-DEV04-01)
// Project-level Gradle build file for Relap Android module

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
        // FCM — google-services plugin (TASK-D04-DEV04-01)
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
