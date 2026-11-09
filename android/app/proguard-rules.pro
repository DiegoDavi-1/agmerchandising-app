# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Local auth (biometria)
-keep class androidx.biometric.** { *; }

# Mobile scanner / ML Kit barcode
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# Evita quebra de classes carregadas via reflexão em plugins nativos
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
