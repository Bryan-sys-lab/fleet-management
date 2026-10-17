pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
    val flutterRoot = System.getenv("FLUTTER_ROOT")
        ?: rootProject.file("local.properties").let { lp ->
            if (lp.exists()) {
                Properties().apply { lp.inputStream().use { load(it) } }["flutter.sdk"]?.toString()
            } else null
        }
        ?: System.getenv("HOME")?.let { "$it/flutter" }
        ?: "/opt/flutter"
    includeBuild("$flutterRoot/packages/flutter_tools/gradle")
}

include(":app")
