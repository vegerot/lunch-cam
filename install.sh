#!/bin/bash
# Build Lunch Cam, install it on the paired iPhone, and launch it with its output shown here.
set -euo pipefail
cd "$(dirname "$0")"
DEVICE="00008160-0001393420434036" # "iPhone Duo Max"

xcodebuild -project LunchCam.xcodeproj -scheme LunchCam -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath build \
  -allowProvisioningUpdates -quiet build

xcrun devicectl device install app --device "$DEVICE" \
  build/Build/Products/Debug-iphoneos/LunchCam.app
# The phone must be unlocked for the launch. Press Ctrl-C to stop watching the output.
xcrun devicectl device process launch --device "$DEVICE" \
  --terminate-existing --console com.vegerot.lunchcam
