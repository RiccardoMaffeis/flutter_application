# Mantieni tutte le classi Sceneform e ARCore
-keep class com.google.ar.sceneform.** { *; }
-keep class com.google.ar.core.** { *; }
-dontwarn com.google.ar.sceneform.**
-dontwarn com.google.ar.core.**

# (Solo per ridurre rumore; non “crea” la classe mancata)
-dontwarn com.google.devtools.build.android.desugar.runtime.**
