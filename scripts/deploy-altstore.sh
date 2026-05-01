#!/bin/bash
# AltStore Deployment Script for AppForge Studio
# Requires: Xcode 16.1, AltStore CLI (altool), Apple Developer account

set -euo pipefail

SCHEME="AppForgeStudio"
PROJECT_DIR="../ios-app"
ARCHIVE_PATH="./build/AppForgeStudio.xcarchive"
IPA_PATH="./build/AppForgeStudio.ipa"
EXPORT_OPTIONS="./export-options.plist"

# Step 1: Clean and archive
xcodebuild clean archive \
  -scheme "$SCHEME" \
  -project "$PROJECT_DIR/AppForgeStudio.xcodeproj" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_STYLE="Manual" \
  PROVISIONING_PROFILE_SPECIFIER="AltStore" \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Step 2: Export IPA for AltStore
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
  <key>compileBitcode</key>
  <false/>
  <key>uploadSymbols</key>
  <false/>
</dict>
</plist>' > "$EXPORT_OPTIONS"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "./build" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

# Step 3: Sign with AltStore
altool --sign \
  --type ios \
  --file "$IPA_PATH" \
  --output "$IPA_PATH.signed"

echo "---"
echo "Deploy complete! Share AppForgeStudio.ipa.signed via AltStore."