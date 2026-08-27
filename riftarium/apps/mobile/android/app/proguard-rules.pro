# google_mlkit_text_recognition référence les reconnaisseurs de tous les scripts
# mais seul le latin est embarqué : R8 doit ignorer les classes absentes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
