-keep class com.fasterxml.jackson.** { *; }
-keepclassmembers class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

-keep class io.opentelemetry.** { *; }
-keepclassmembers class io.opentelemetry.** { *; }
-dontwarn io.opentelemetry.**

-keep class com.google.auto.value.** { *; }
-keepclassmembers class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**

-keep class org.osgi.** { *; }
-keepclassmembers class org.osgi.** { *; }
-dontwarn org.osgi.**
