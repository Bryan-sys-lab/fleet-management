pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
    val flutterRoot = System.getenv("FLUTTER_ROOT")
        ?: System.getenv("HOME")?.let { "$it/flutter" }
        ?: "/opt/flutter"
    includeBuild("$flutterRoot/packages/flutter_tools/gradle")
}

include(":app")
