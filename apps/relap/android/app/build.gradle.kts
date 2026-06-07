// FILE: apps/relap/android/app/build.gradle.kts
// OWNER: DEV-04 (TASK-D04-DEV04-01)
// App-level Gradle build file for Relap Android module

plugins {
    id("com.android.application")
    id("kotlin-android")
    // FCM — must be applied last (TASK-D04-DEV04-01)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.savicam.relap"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.savicam.relap"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Firebase BoM — version-manages all Firebase libraries (TASK-D04-DEV04-01)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
}
