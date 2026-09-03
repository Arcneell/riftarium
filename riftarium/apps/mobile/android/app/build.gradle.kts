plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Gradle de Flutter doit venir après ceux d'Android et de Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "re.riftarium.app"
    // flutter_secure_storage 11 compile contre le SDK 37 (rétrocompatible) ;
    // Flutter 3.41 propose encore 36 par défaut.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identifiant figé (WORKFLOW.md §4) : le changer après publication
        // créerait une seconde application dans les stores.
        applicationId = "re.riftarium.app"
        // Versions du SDK et numéro de version : reprises de pubspec.yaml par
        // le plugin Gradle de Flutter, rien à figer ici.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signature de développement : suffisante pour `flutter run
            // --release` et pour les APK de test (scripts/apk.sh). Le keystore
            // de publication arrive en phase 8 (key.properties, hors git).
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
