# Keep Firebase model reflection conservative during the first migration.
-keep class com.google.firebase.** { *; }
-dontwarn javax.annotation.**
