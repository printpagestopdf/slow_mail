import org.gradle.api.tasks.compile.JavaCompile
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


android {
    namespace = "com.theripper.slowmail"
    compileSdk = flutter.compileSdkVersion
    //ndkVersion = flutter.ndkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        // Sets Java compatibility to Java 21
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21

    }

    kotlinOptions {
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
            //abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
        manifestPlaceholders.putAll(
            mapOf(
                "appAuthRedirectScheme" to "com.theripper.slowmail"
            )
        )

    }

    signingConfigs {
        create("release") {
        val propsFile = rootProject.file("key.properties")
        if (propsFile.exists()) {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
        }
    }

    buildTypes {
        release {
        val propsFile = rootProject.file("key.properties")
        if (propsFile.exists()) {
            signingConfig = signingConfigs.getByName("release")
        }
            // wichtig für reproduzierbarkeit
            isMinifyEnabled = true
            isShrinkResources = true
            vcsInfo.include = false

            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
          }
        debug {
            // TODO: Add your own signing config for the release build.
            // Signing with release keys.
            signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Suppress Java compiler warnings
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation", "-Xlint:-unchecked"))
    }

    buildFeatures {
        buildConfig = true
    }

    // applicationVariants.all {
    //     if (buildType.name == "release") {
    //         outputs.all {
    //             (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
    //                 .outputFileName = "app-release.apk"
    //         }
    //     }
    // }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

}


dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.13.0")
    //implementation("com.android.support:multidex:1.0.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")  
}



flutter {
    source = "../.."
}
