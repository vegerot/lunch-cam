#!/usr/bin/env bash

# Copy the last photo Lunch Cam took off the paired iPhone, and print its size.
# Lunch Cam keeps that debug copy in its own folder. Delete this script when the copy goes.
set -euo pipefail
OUT="${1:-last.jpg}"

xcrun devicectl device copy from --device "00008160-0001393420434036" \
  --domain-type appDataContainer --domain-identifier com.vegerot.lunchcam \
  --source Documents/last.jpg --destination "$OUT" >/dev/null
sips --getProperty pixelWidth --getProperty pixelHeight "$OUT"
