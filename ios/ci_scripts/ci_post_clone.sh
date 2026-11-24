#!/bin/sh
# Xcode Cloud prepares Flutter/CocoaPods; Xcode owns archive and signing.
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud repository path is required}"
: "${PAPIGIRAS_API_URL:?Set the official HTTPS API origin in the workflow}"
# Match the build number Xcode Cloud records in App Store Connect.
export PAPIGIRAS_BUILD_NUMBER="${CI_BUILD_NUMBER:?Xcode Cloud build number is required}"
set -- "--build-number=$PAPIGIRAS_BUILD_NUMBER"
if [ -n "${PAPIGIRAS_BUILD_NAME:-}" ]; then
  case "$PAPIGIRAS_BUILD_NAME" in
    *[!0-9.]*) echo 'PAPIGIRAS_BUILD_NAME must be MAJOR.MINOR.PATCH.' >&2; exit 1 ;;
  esac
  if ! printf '%s\n' "$PAPIGIRAS_BUILD_NAME" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo 'PAPIGIRAS_BUILD_NAME must be MAJOR.MINOR.PATCH.' >&2
    exit 1
  fi
  set -- "$@" "--build-name=$PAPIGIRAS_BUILD_NAME"
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"
test -f pubspec.yaml
test -d ios/Runner.xcworkspace

# Pin the exact SDK already used for this candidate's local tests and APK.
flutter_revision=c6f67dede3d4aa1aa7a69dd56a3494a5cde6cc80
papigiras_temp="$(mktemp -d "${TMPDIR:-/tmp}/papigiras-flutter.XXXXXX")"
papigiras_sdk="$papigiras_temp/sdk"
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

# Flutter prepares the exact release defines and uses CocoaPods when needed.
cp ios/Podfile.lock "$papigiras_temp/expected-Podfile.lock"
configure() {
  flutter build ios --release --config-only --no-codesign \
    --dart-define="PAPIGIRAS_API_URL=$PAPIGIRAS_API_URL" "$@"
}
if configure "$@" > "$papigiras_temp/configure.log" 2>&1; then
  cat "$papigiras_temp/configure.log"
else
  cat "$papigiras_temp/configure.log"
  # A cached CocoaPods CDN index can miss a pinned pod such as libwebp.
  # Retry once, only for that known failure class, not for compile errors.
  if ! grep -Fq "CocoaPods's specs repository is too out-of-date" "$papigiras_temp/configure.log" ||
     [ ! -s ios/Flutter/Generated.xcconfig ]; then
    exit 1
  fi
  (cd ios && pod install --repo-update)
  configure "$@"
fi

# Preserve locked dependency versions; allow only CocoaPods tool-version metadata.
sed '/^COCOAPODS:/d' "$papigiras_temp/expected-Podfile.lock" > "$papigiras_temp/expected-normalized"
sed '/^COCOAPODS:/d' ios/Podfile.lock > "$papigiras_temp/actual-normalized"
if ! cmp -s "$papigiras_temp/expected-normalized" "$papigiras_temp/actual-normalized"; then
  echo 'CocoaPods changed the locked dependency graph; update Podfile.lock deliberately.' >&2
  exit 1
fi
cmp -s ios/Podfile.lock ios/Pods/Manifest.lock

# Check the requested origin and build number really reached Xcode's settings.
config=ios/Flutter/Generated.xcconfig
grep -Fxq "FLUTTER_BUILD_NUMBER=$PAPIGIRAS_BUILD_NUMBER" "$config"
if [ -n "${PAPIGIRAS_BUILD_NAME:-}" ]; then
  grep -Fxq "FLUTTER_BUILD_NAME=$PAPIGIRAS_BUILD_NAME" "$config"
fi
encoded_origin="$(printf '%s' "PAPIGIRAS_API_URL=$PAPIGIRAS_API_URL" | base64 | tr -d '\n')"
defines="$(sed -n 's/^DART_DEFINES=//p' "$config")"
case ",$defines," in
  *",$encoded_origin,"*) ;;
  *) echo 'The generated Xcode configuration is missing the requested API origin.' >&2; exit 1 ;;
esac
printf '%s\n' 'Connected Flutter configuration prepared; Xcode will archive and sign.'
