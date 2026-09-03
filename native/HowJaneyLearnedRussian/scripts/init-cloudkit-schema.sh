#!/usr/bin/env bash
# Push the SwiftData schema to the CloudKit Development environment.
# Requires an iPhone that is plugged in / paired AND signed into iCloud.
# Afterwards: CloudKit Console -> iCloud.com.mokotti-solutions.howjaneylearnedrussian
#             -> Deploy Schema Changes... (Development -> Production).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEVICE="${1:-iPhonePorra}"
BUNDLE_ID=com.mokotti-solutions.howjaneylearnedrussian

xcodebuild -project HowJaneyLearnedRussian.xcodeproj -scheme HowJaneyLearnedRussian \
  -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/dev \
  -allowProvisioningUpdates build | grep -E "error:|\*\* " || true
APP=build/dev/Build/Products/Debug-iphoneos/HowJaneyLearnedRussian.app
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" --console \
  "$BUNDLE_ID" --init-cloudkit-schema 2>&1 | grep -E "CloudKitSchema|error" || true
