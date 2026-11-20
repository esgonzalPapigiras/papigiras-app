#!/bin/sh
# Xcode Cloud prepares Flutter/CocoaPods; Xcode owns archive and signing.
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud repository path is required}"
: "${PAPIGIRAS_API_URL:?Set the official HTTPS API origin in the workflow}"
: "${PAPIGIRAS_BUILD_NUMBER:?Set an unused App Store Connect build number}"

cd "$CI_PRIMARY_REPOSITORY_PATH"
test -f pubspec.yaml
test -d ios/Runner.xcworkspace

# Pin the exact SDK already used for this candidate's local tests and APK.
flutter_revision=c6f67dede3d4aa1aa7a69dd56a3494a5cde6cc80
papigiras_sdk="$(mktemp -d "${TMPDIR:-/tmp}/papigiras-flutter.XXXXXX")/sdk"
git clone --depth 1 --branch 3.38.10 https://github.com/flutter/flutter.git "$papigiras_sdk"
test "$(git -C "$papigiras_sdk" rev-parse HEAD)" = "$flutter_revision"
export PATH="$papigiras_sdk/bin:$PATH"
export CI=true
export COCOAPODS_DISABLE_STATS=true
export HOMEBREW_NO_AUTO_UPDATE=1

flutter --version
dart tool/validate_connected_build.dart
flutter precache --ios
flutter pub get --enforce-lockfile

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi
pod --version

# --config-only also installs the required Pods in Flutter 3.38.10. This
# generates the connected Dart defines consumed by Xcode's archive action.
flutter build ios --release --config-only --no-codesign \
  --dart-define="PAPIGIRAS_API_URL=$PAPIGIRAS_API_URL" \
  --build-number="$PAPIGIRAS_BUILD_NUMBER"

# Fail closed if the native build would otherwise compile the LAB reference.
test -s ios/Flutter/Generated.xcconfig
grep -q '^DART_DEFINES=.' ios/Flutter/Generated.xcconfig
printf '%s\n' 'Connected Flutter configuration prepared; Xcode will archive and sign.'
