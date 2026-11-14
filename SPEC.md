# 🍱 Lunch Cam: specification

Lunch Cam is a basic iPhone app that takes one photo with the rear camera and the front camera together.
The rear photo fills the frame. The selfie sits as a small inset in a corner.

**Why:** Max sends his girlfriend pictures of himself and his lunch. The app is done when that takes a few taps.

Status: agreed in a design interview on 2026-11-13, then cut down once with the five-step engineering algorithm (see the last section). All four layers run on the phone, and Max confirmed that the selfie is mirrored. Still open: Max's real lunch photo, which is what finishes version 1.

## 🎯 Version 1

| Topic | Decision |
| --- | --- |
| Stack | Native Swift and SwiftUI. Apple's `AVCaptureMultiCamSession` (the multi-camera capture session) called directly. No third-party dependencies. |
| Distribution | Installed on the phone from this Mac. No App Store, no TestFlight. |
| Output | One image: rear photo full-frame with the selfie baked into the corner, exactly as the preview shows. |
| Shape | Portrait only. The app does not rotate. The photo keeps the shape the camera format delivers, with no cropping: 3:4 if layer 1 finds a 4:3 format, otherwise 9:16. The inset has the same shape. |
| Inset | Top-left corner, about a quarter of the photo width, rounded corners, fixed in place. |
| Selfie | Mirrored, as the preview shows it. |
| Rear lens | Main wide lens only. |
| Controls | One shutter button. The volume buttons also fire the shutter. |
| After the shutter | The photo saves to the Photos library, then the iOS share sheet opens with it. |
| Permissions | Camera, and add-only Photos access (the app can save, not read). |
| Name | "Lunch Cam", bundle ID `com.vegerot.lunchcam`. |
| Location | `lunch-cam/` in the `ai-conversations` repository. It moves to its own repository later. |
| Signing | Max's Personal Team, `GWKJRP4KM9`. It is a free team, so the app expires after 7 days and needs a reinstall. |

### 📷 Capture pipeline

**Frame grab:** keep the latest live video frame from each camera. When the shutter fires, draw the two latest frames into one image: the rear frame, then the selfie clipped to a rounded rectangle.

It is the least code: there is no waiting for two separate photo captures to both finish.
The cost is resolution, which is roughly video quality. Layer 1 measures the real number.

**Fallback, only if the layer 3 photo looks soft on the phone:** one photo output per camera. Max and Claude both judge that photo.

## 🚫 Not in version 1

Version 1 builds nothing in advance for these.

- 🎥 Video and Live Photos.
- 🔄 Swap which camera is the inset.
- 🤏 Drag the inset and pinch to resize it.
- 🏷️ Photo metadata, such as location.
- 🔦 Flash, timer, zoom, lens switching, settings screen, in-app gallery.

## 🧱 Layers

Each layer is installed on the phone and checked by hand before the next layer starts.
Every milestone and every experiment gets its own Sapling commit that touches only `lunch-cam/`. Nothing is pushed unless Max asks.

1. 🧪 **Probe.** An app that installs, launches, and shows whether multi-camera capture is supported, plus the formats each camera offers in a multi-camera session.
2. 📷 **Preview.** The multi-camera session runs. The rear camera fills the screen and the mirrored front camera sits in the top-left corner.
3. 🔘 **Shutter.** The button composites the two latest frames into one image, saves it to Photos, and opens the share sheet with it.
4. 🔊 **Volume-button shutter.**

## ✅ Testing

- No automated unit tests.
- **Claude watches the phone's screen** through QuickTime Player (File ▸ New Movie Recording, with the iPhone as the camera). It shows the camera and is view only, so Max does the taps.
- **Claude checks** each layer through the app's console output: the app launches, the session runs, nothing crashes. iPhone Mirroring cannot show the camera: it replaces the app with the notice "iPhone camera is not available from Mac" (measured 2026-11-13). From layer 3 on, Claude copies the saved photo off the phone and looks at it.
- **Max checks** on the physical phone, with iPhone Mirroring disconnected: the layer 2 preview, the layer 3 photo, and the layer 4 volume buttons. Claude also analyzes it and gives an opinion.
- **Version 1 is done** when Max takes a real photo, sends it, and it looks right to him.

`AVCaptureMultiCamSession` cannot be tested on this Mac.
The macOS 27 SDK header `AVCaptureSession.h` marks it `API_AVAILABLE(ios(13.0), macCatalyst(14.0), tvos(17.0), visionos(2.1)) API_UNAVAILABLE(macos)`, and the iOS Simulator has no cameras.
A Mac test harness for the compositor is not built: the phone loop is one command, and Claude copies each photo off the phone to look at it.

## 🛠️ Build and install

`lunch-cam/dev.swift` is one Swift command-line script with two subcommands:

- `./dev.swift install` builds with `xcodebuild`, installs with `devicectl` (Apple's device command-line tool), and launches the app. Adding `--console` keeps showing the app's output; stopping it stops the app. This is also the weekly reinstall.
- `./dev.swift photo [file]` copies the last photo off the phone, for as long as the app keeps its debug copy.

Max never needs to open Xcode.
It is Swift, not shell, because the two commands together passed the 20-line limit set for a shell script.

## 📱 Environment (measured 2026-11-13)

- Phone: "iPhone Duo Max", model identifier `iPhone19,4`, iOS 27.2, wired, Developer Mode enabled.
- Xcode 27.2 (build 27B52), signed in to Max's Apple account.
- Multi-camera support on this phone: **yes** (layer 1, measured). The rear wide camera and the front camera are allowed together.

### 🧪 Layer 1 result: multi-camera formats

Printed by the probe app on the phone. Each row is a video size, its top frame rate, and the largest photo that format allows.

| Camera | Video size | Frames per second | Largest photo |
| --- | --- | --- | --- |
| Rear | 1920x1440 (4:3) | 60 | 4032x3024 |
| Rear | 3840x2160 (16:9) | 30 | 4224x2376 |
| Rear | 1920x1080 (16:9) | 60 | 4224x2376 |
| Front | 1920x1440 (4:3) | 60 | 2016x1512 |
| Front | 1920x1440 (4:3) | 30 | 3360x2520 |
| Front | 1920x1080 (16:9) | 60 | 4032x2268 |

Smaller formats (640x480 up to 1440x1080) also exist on both cameras.

What this decides:

- **Shape: 3:4.** Both cameras have a 4:3 format, 1920x1440, so nothing is cropped.
- **Frame grab gives a 1440x1920 photo, about 2.8 megapixels.** The selfie inset is a quarter of the width, so it is shrunk from its 1440x1920 frame.
- **The fallback would give a 3024x4032 rear photo, about 12 megapixels**, which is 2.1 times the width and height. That is the size of the gap layer 3 has to judge.

### 🔘 Layer 3 result: the first photo (2026-11-13)

Max pressed the shutter; Claude copied `Documents/last.jpg` off the phone with `devicectl device copy from`.

- The photo is 1440x1920, about 620 kB as a JPEG at quality 0.9.
- Rear frame upright. Selfie upright, top-left, 360x480 with rounded corners. It matches the preview.
- Sharpness, judged by Claude on a full-size crop: terminal text on a monitor about an arm's length away is readable but slightly soft, like a video still. Good enough for a chat message. Not yet tried in dim light, where grabbed video frames miss the iPhone's photo clean-up.
- The rotation API reports 90 degrees for the rear camera and 270 for the front on this phone.

### 🔊 Layer 4 result: both buttons, save and share (2026-11-13)

The app prints one line per event, read on the Mac with `devicectl device process launch --console`. Max took one shot with each button:

```
shot via hardware button: 1440x1920
share sheet shown
saved to Photos: true
shot via screen button: 1440x1920
share sheet shown
saved to Photos: true
```

The save uses the Photos framework's change request, because its completion reports success or failure.

## ✂️ Five-step pass (2026-11-13)

One pass of the five-step engineering algorithm: question each requirement, delete, simplify, speed up the loop, automate last.

| Change | Reason |
| --- | --- |
| Deleted the Mac compositor test script. | Layer 3 tests the compositor on the phone anyway. A second harness is built only if the phone loop is slow. |
| Deleted "video can reuse the compositor" as the reason for frame grab. | That was a "we might need this later" reason. Frame grab stays because it is the least code for version 1. |
| Dropped the "truly simultaneous" requirement. | A few milliseconds between the two cameras cannot be seen in a lunch photo. |
| Relaxed the fixed 3:4 shape. | Claude chose 3:4 to match the Camera app. If the phone only offers 16:9 multi-camera formats, forcing 3:4 means cropping code and fewer pixels. |
| Merged six layers into four. | Rear preview plus inset is one session setup. Save and share are both a few lines after the composite. Fewer install cycles. |
| Kept `install.sh` as the only automation. | The weekly reinstall is not scheduled. It is one manual command until it annoys Max. |

Added back by Max after the pass: the automatic save to Photos and the volume-button shutter. The pass had deleted both.
