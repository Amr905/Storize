# storize_platform_android

In-repo Flutter plugin (Kotlin) behind `GalleryStore` and the battery guide (ADR-0011).
The Dart API is `StorizePlatformAndroid`; T-010 adapts it to the domain port.

## Channels

| Channel | Methods |
|---------|---------|
| `storize/media` | `insert`, `delete`, `exists`, `size`, `videoThumbnail` |
| `storize/system` | `isIgnoringBatteryOptimizations`, `openBatterySettings`, `manufacturer`, `lastStopReasons` |

Errors come back as `PlatformException` codes and map to `StorizePlatformException.kind`:
`INVALID_ARGUMENT`, `UNSUPPORTED_MIME`, `SOURCE_NOT_FOUND`, `PERMISSION_DENIED`, `STORAGE_FULL`,
`IO_ERROR`, `INSERT_FAILED`, `THUMBNAIL_FAILED`, `UNAVAILABLE`, `UNKNOWN` (and `BAD_RESPONSE`, raised on the Dart side).

## Behaviour notes

- **API 29+:** `insert` uses MediaStore with `IS_PENDING`, path `Pictures/Storize/<dir>/`. The video collection may
  refuse `Pictures`; the plugin then retries with `Movies/Storize/<dir>/` and returns the folder used in `relativePath`.
  Check this on a real phone (P-4).
- **API <= 28:** direct write under `Pictures/Storize/<dir>/`, then a MediaScanner scan. The returned URI is the
  `content://media/...` URI from the scan, or `file://` if the scan does not answer in 5 s. The app must hold the
  runtime permission `WRITE_EXTERNAL_STORAGE` (the manifest declares it with `maxSdkVersion=28`); without it `insert`
  fails with `PERMISSION_DENIED`.
- **`lastStopReasons`:** reads `ApplicationExitInfo` (API 30+), empty below. It reports why the process was stopped, not
  per-work `WorkInfo.stopReason`, because that needs a `work-runtime` dependency.
- **`openBatterySettings`:** tries the ignore-optimizations request (skipped if already exempt), then the OEM screens,
  then app details. Returns `request_ignore`, `oem_<name>`, `app_details` or `none`. OEM class names are best effort.
- The manifest has no components, so nothing is exported.

## Tests

- Dart (runs anywhere): `flutter test` in this folder.
- Kotlin JVM tests: `android/src/test/kotlin` (pure helpers).
- Instrumentation tests: `android/src/androidTest/kotlin` (insert, delete, exists, size on a real MediaStore).

The two Kotlin test folders need these test-only dependencies in `android/build.gradle.kts`, which are not added yet
(they await Lead approval):

```kotlin
android { defaultConfig { testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" } }
dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
```

Run on a device or emulator (not verified from this sandbox; start emulators at API 28, 29 and 34+, or plug in the P-4 phones), from a Flutter app
that depends on this plugin (library modules have no wrapper of their own):

```
cd app/android && ./gradlew :storize_platform_android:connectedDebugAndroidTest
./gradlew :storize_platform_android:testDebugUnitTest      # JVM tests
```

Test files land in `Pictures/Storize/storize_test/` and are deleted afterwards.
