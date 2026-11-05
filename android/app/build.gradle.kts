plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aayush.proalbums"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aayush.proalbums"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // ONNX Runtime finds its Java classes from native code by name.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Compress size / Convert to H.264: Android's Media3 Transformer (same
    // version as video_player's ExoPlayer, so they share media3-common).
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
    implementation("androidx.media3:media3-common:1.9.2")

    // Intelligent classification > People: ML Kit finds the faces (model
    // inside the app, no download), SFace (OpenCV Zoo, Apache-2.0, in
    // assets/models) tells who it is, run by ONNX Runtime.
    implementation("com.google.mlkit:face-detection:16.1.7")
    // ...and the things (Documents, Plants, Food, Cars…): ML Kit's image
    // labeler (model inside the app).
    implementation("com.google.mlkit:image-labeling:17.0.9")
    // Documents: how much text a picture has (Latin, model inside the app).
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")

    // Computer-side tests of the vault's encryption (android/app/src/test).
    testImplementation("junit:junit:4.13.2")
}
