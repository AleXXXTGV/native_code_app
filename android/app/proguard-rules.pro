# Сохранение доступа к классам для Flutter
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }

# Удаление логирования
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** w(...);
    public static *** e(...);
    public static *** i(...);
}

# Оставить основные аннотации и классы для работы с библиотеками
-keepattributes *Annotation*
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.Application

# Правила для сохранения всех классов из Google Play Core
-keep class com.google.android.play.** { *; }

# Правила для Flutter Deferred Components (если используете отложенные компоненты)
-keep class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager { *; }

# Сохранение классов местоположения
-keep class android.location.** { *; }
-keep class android.location.LocationManager { *; }
-keep class android.location.LocationListener { *; }