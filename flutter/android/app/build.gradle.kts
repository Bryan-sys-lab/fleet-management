import java.util.Properties
import java.io.File

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterVersionCode = (localProperties.getProperty("flutterVersionCode") ?: "1").toInt()
val flutterVersionName = localProperties.getProperty("flutterVersionName") ?: "1.0.0"

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.helix.helix"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.helix.helix"
        minSdk = 21
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }
    signingConfigs {
        create("release") {
            if (keyProperties.containsKey("storeFile")) {
                storeFile = file(keyProperties.getProperty("storeFile") ?: "")
                storePassword = keyProperties.getProperty("storePassword") ?: ""
                keyAlias = keyProperties.getProperty("keyAlias") ?: ""
                keyPassword = keyProperties.getProperty("keyPassword") ?: ""
            } else {
                storeFile = file("debug.keystore")
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.2.20")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.annotation:annotation:1.7.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.2")
    implementation("androidx.activity:activity:1.9.0")
}

flutter {
    source = "../.."
}
