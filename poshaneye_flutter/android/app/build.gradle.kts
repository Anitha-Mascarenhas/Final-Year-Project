plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.poshaneye"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.poshaneye"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Android native side of the `poshaneye/landmarks` MethodChannel:
    // FaceLandmarker + PoseLandmarker (RunningMode.IMAGE) for the production
    // hybrid inference pipeline's CV feature extraction. API must stay compatible
    // with the Dart contract in lib/services/hybrid_landmark_bridge.dart.
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
    // EXIF orientation handling for camera/uploaded photos before MediaPipe.
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    // Instrumentation tests for the landmark bridge (androidTest).
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
    // TFLite runtime override. tflite_flutter 0.11.0 pins org.tensorflow:tensorflow-lite:2.11.0,
    // whose built-in kernels predate FULLY_CONNECTED v12 / CONV_2D v5 / DEPTHWISE_CONV_2D v6
    // ("Didn't find op for builtin opcode 'FULLY_CONNECTED' version '12'" on device).
    // The production models were converted with TF 2.19, so force the newest Maven TFLite
    // (2.16.1): same native library name and stable C API, fully backwards-compatible.
    implementation("org.tensorflow:tensorflow-lite:2.17.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.17.0")
}

flutter {
    source = "../.."
}
