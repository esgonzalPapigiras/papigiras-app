# Pilo QR stability patch

This is a project-local copy of `qr_code_scanner_plus` 2.1.2. The upstream LICENSE, README and CHANGELOG are preserved. Only Pilo resolves this package through a path dependency; the shared pub cache and other applications are unchanged.

## Cause and changes

On iOS, camera startup can fail (including a simulator without a camera). Upstream passes the native `NSError` as `FlutterError.details`. FlutterStandardCodec cannot serialize that object, causing a native abort before Dart receives the error. QRView.swift now sends the localized error string, completes startup results on success and permission denial, completes stopCamera, and avoids a scanner closure retain cycle.

The Dart QRView adds optional `ValueChanged<String>? onCameraError`. Startup and dimension-update errors are caught and invoke it at most once while mounted, with the fixed message `Camera is not available.` The app owns localized fallback UI. Deferred startup checks disposal before accessing the native view. Cleanup detaches method callbacks and consumes asynchronous stop failures.

Android native sources are unchanged. Public scanner controls and QR decoding are unchanged. No backend, schema, credentials, network destinations or native preflight channel are added.

## Provenance and verification

Upstream hosted archive SHA-256: `2bcf9df32aa639fba07c183b1ab9c3f03eb6b1d688ab4f4f6bc868a75afd824d`.

The Pilo record at `registro-local/PILO-QR-ESTABLE/` contains original file hashes (`qr-upstream-manifest.json`), the runtime diff (`qr-plugin.patch`), dependency diffs, original pubspec snapshots, and validation hashes (`qr-fork-validation.json`). The original cache files were rechecked against the manifest after the changes.

From the Pilo project root, `flutter pub get --offline` changes only this dependency from hosted 2.1.2 to the local copy, without upgrading package versions. `flutter test third_party/qr_code_scanner_plus/test/camera_start_failure_test.dart --reporter expanded` passes 6 tests: native error callback, successful startup, permission denial, late failure after disposal, closing before startup, and repeated resize failures.

Mock-channel tests verify Flutter lifecycle/error handling, not the actual camera. The parent task separately builds and checks iOS. Physical-device camera capture remains a separate validation step.

## Integration and reversal

Keep the path dependency together with this folder and its license. A native rebuild is necessary; hot reload alone cannot replace the Swift fix. To remove the fork after an upstream fix is verified, remove app usages of the optional callback or adopt its supported replacement, then switch the dependency. Returning directly to hosted 2.1.2 reintroduces the crash. Do not blindly restore pubspec snapshots if later dependency changes exist; use the recorded diffs.
