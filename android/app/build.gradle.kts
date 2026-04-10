import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.theripper.slowmail"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        //sourceCompatibility = JavaVersion.VERSION_11
        //targetCompatibility = JavaVersion.VERSION_11

        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        // Sets Java compatibility to Java 17
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // sourceCompatibility = JavaVersion.VERSION_17
        // targetCompatibility = JavaVersion.VERSION_17

        // Suppress deprecation warnings
        // compilerArgs.addAll(arrayOf("-Xlint:-options", "-Xlint:-deprecation", "-Xlint:-unchecked"))
    }

    kotlinOptions {
        //jvmTarget = JavaVersion.VERSION_11.toString()
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.theripper.slowmail"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
        manifestPlaceholders.putAll(
            mapOf(
                "appAuthRedirectScheme" to "com.theripper.slowmail"
            )
        )

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Suppress Java compiler warnings
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation", "-Xlint:-unchecked"))
    }

    buildFeatures {
        buildConfig = true
    }

}


dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("com.android.support:multidex:1.0.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}



flutter {
    source = "../.."
}
