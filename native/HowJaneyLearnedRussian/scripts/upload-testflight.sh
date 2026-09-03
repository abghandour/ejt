#!/usr/bin/env bash
# Archive the Release build and upload it to App Store Connect / TestFlight.
# Uses the Apple ID signed into Xcode (Settings > Accounts) for auth.
# Usage: scripts/upload-testflight.sh
set -euo pipefail
# App Store Connect rejects uploads from beta Xcode; force the release Xcode.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
ARCHIVE="build/HowJaneyLearnedRussian.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild -project HowJaneyLearnedRussian.xcodeproj \
  -scheme HowJaneyLearnedRussian \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive | grep -E "error:|warning: .*deprecat|\*\* " || true
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates
