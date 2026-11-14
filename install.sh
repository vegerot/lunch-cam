#!/usr/bin/env bash

# Build Lunch Cam, install it on the paired iPhone, and launch it. The phone must be unlocked.
# With --console, keep showing the app's output; Ctrl-C then stops the app too.
set -euo pipefail
cd "$(dirname "$0")"
DEVICE="00008160-0001393420434036" # "iPhone Duo Max"

# The filter drops lines Xcode prints on every build for this phone. They are not errors.
xcodebuild -project LunchCam.xcodeproj -scheme LunchCam -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath build \
  -allowProvisioningUpdates -quiet build 2>&1 |
  { grep --invert-match --extended-regexp 'DVTDevice|IDERunDestination|headermap' || true; }

xcrun devicectl device install app --device "$DEVICE" \
  build/Build/Products/Debug-iphoneos/LunchCam.app
xcrun devicectl device process launch --device "$DEVICE" \
  --terminate-existing ${1:+"$1"} com.vegerot.lunchcam
