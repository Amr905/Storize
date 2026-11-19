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
- Callers must only pass URIs returned by `insert`. For `content://` the plugin accepts only
  `content://media/<volume>/(images|video)/media/<id>` with a positive integer id and no query string or fragment;
  anything else (collection URIs, `.../media/0`, `?limit=1`, `#x`, other providers) fails with `INVALID_ARGUMENT`.
  `delete` is one selection-scoped call on that item (`_id` = id AND the path is under `Pictures/Storize/` or
  `Movies/Storize/`, compared as a plain range, no `LIKE`), so it can never touch another row.
- `delete`, `exists`, `size` and `videoThumbnail(uri)` only act on rows under `Pictures/Storize/` or `Movies/Storize/`
  (`RELATIVE_PATH` on API 29+, `DATA` on API <= 28). A foreign row gives `PERMISSION_DENIED` for delete, `false` for exists,
  `null` for size, `INVALID_ARGUMENT` for the thumbnail. `videoThumbnail(path)` accepts only the Storize folders or the app cache.
- `insert` returns the final `displayName` (it can become `name (1).ext`).
- The manifest has no components, so nothing is exported.

## Tests

- Dart (runs anywhere): `flutter test` in this folder.
- Kotlin JVM tests: `android/src/test/kotlin` (pure helpers).
- Instrumentation tests: `android/src/androidTest/kotlin` (insert, delete, exists, size on a real MediaStore).

The test-only dependencies (JUnit, androidx.test) and the instrumentation runner are declared in `android/build.gradle.kts`.
CI runs the JVM tests with `:storize_platform_android:testDebugUnitTest`.

Run on a device or emulator (not verified from this sandbox; start emulators at API 28, 29 and 34+, or plug in the P-4 phones), from a Flutter app
that depends on this plugin (library modules have no wrapper of their own):

```
cd app/android && ./gradlew :storize_platform_android:connectedDebugAndroidTest
./gradlew :storize_platform_android:testDebugUnitTest      # JVM tests
```

Test files land in `Pictures/Storize/storize_test/` and are deleted afterwards.
