pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
    val flutterRoot = findProperty("flutter.sdk")?.toString() ?: System.getenv("FLUTTER_ROOT") ?: "/opt/hostedtoolcache/flutter/stable-3.47.5-x64/flutter"
    includeBuild("$flutterRoot/packages/flutter_tools/gradle")
}

include(":app")
