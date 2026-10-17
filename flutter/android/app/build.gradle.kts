val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterVersionCode = (localProperties.getProperty("flutterVersionCode") ?: "1").toInt()
val flutterVersionName = localProperties.getProperty("flutterVersionName") ?: "1.0.0"

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
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.2.20")
    implementation("androidx.core:core-ktx:+")
    implementation("androidx.annotation:annotation:+")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:+")
    implementation("androidx.activity:activity:+")
}

flutter {
    source = "../.."
}
EOF
echo "app/build.gradle.kts updated - removed flutterRoot dependency"
