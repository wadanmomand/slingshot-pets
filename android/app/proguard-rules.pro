# WorkManager / Room keep rules.
# WorkManager arrives transitively with the Google Mobile Ads SDK and is
# initialized at app startup via androidx.startup. Room loads
# WorkDatabase_Impl reflectively; if R8 strips or renames it, the app
# crashes before Flutter starts:
#   RuntimeException: Unable to get provider androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
# (Release shrinking is currently disabled in build.gradle.kts; these rules
# stay as protection if it is ever re-enabled.)
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.room.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**
