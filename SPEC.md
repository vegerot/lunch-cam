# 🍱 Lunch Cam: specification

Lunch Cam is a basic iPhone app that takes one photo with the rear camera and the front camera at the same moment.
The rear photo fills the frame. The selfie sits as a small inset in a corner.

**Why:** Max sends his girlfriend pictures of himself and his lunch.

Status: agreed in a design interview on 2026-11-13. Nothing is built yet.

## 🎯 Version 1

| Topic | Decision |
| --- | --- |
| Stack | Native Swift and SwiftUI. Apple's `AVCaptureMultiCamSession` (the multi-camera capture session) called directly. No third-party dependencies. |
| Distribution | Installed on the phone from this Mac. No App Store, no TestFlight. |
| Output | One image: rear photo full-frame with the selfie baked into the corner, exactly as the preview shows. No separate front and rear files. |
| Shape | Portrait only, 3:4. The inset is also 3:4. The app does not rotate. |
| Inset | Top-left corner, about a quarter of the screen width, rounded corners, fixed in place. |
| Selfie | Saved mirrored, as the preview shows it. |
| Rear lens | Main wide lens only. No zoom, no lens switching. |
| Controls | One shutter button. The volume buttons also fire the shutter. No flash, timer, settings screen, or in-app gallery. |
| After the shutter | The photo saves to the Photos library, then the iOS share sheet opens. |
| Permissions | Camera, and add-only Photos access (the app can save, not read). |
| Metadata | None. No location stamp. |
| Name | "Lunch Cam", bundle ID `com.vegerot.lunchcam`. |
| Location | `lunch-cam/` in the `ai-conversations` repository. It moves to its own repository later. |
| Signing | The existing identity, team `MV276V5B7J`. If it is a free team, the app expires after 7 days and needs a reinstall. |

### 📷 Capture pipeline (tentative)

- **Plan A, frame grab:** take one live video frame from each camera at the same instant and composite them.
  The two frames are truly simultaneous, and video recording can later reuse the same compositor.
  The cost is resolution: roughly video quality. The real number is measured in layer 1.
- **Plan B, two photo outputs:** sharper stills taken a few milliseconds apart. Video would later need a second pipeline.

Plan A stays unless the layer 4 photo looks soft on the phone. Max and Claude both judge that photo.

## 🚫 Not in version 1

These are planned for later. Version 1 does not pre-build anything for them, except choosing plan A.

- 🎥 Video and Live Photos.
- 🔄 Swap which camera is the inset.
- 🤏 Drag the inset and pinch to resize it.
- 🏷️ Photo metadata, such as location.

## 🧱 Layers

Each layer is installed on the phone and checked by hand before the next layer starts.
Each working layer is one Sapling commit that touches only `lunch-cam/`. Nothing is pushed unless Max asks.

1. 🧪 **Probe.** An empty app that installs, launches, and shows whether multi-camera capture is supported, plus the formats each camera offers in a multi-camera session.
2. 📷 **Rear preview.** The multi-camera session runs. The rear camera fills the screen in 3:4.
3. 🤳 **Selfie inset.** The front camera is live in the top-left corner, mirrored.
4. 🔘 **Shutter.** The button grabs both frames, composites one image, and saves it to Photos. Plan A or plan B is decided here.
5. 📤 **Share sheet.** It opens right after the save.
6. 🔊 **Volume-button shutter.**

## ✅ Testing

- No automated unit tests.
- **Claude checks** through iPhone Mirroring what is visible there: the app launches, the layout is right, nothing crashes. Not yet verified: whether the camera feed shows inside iPhone Mirroring.
- **Max checks** what needs the physical phone: the layer 4 photo and the layer 6 volume buttons. Claude also analyzes those results and gives an opinion.
- **Version 1 is done** when Max takes a real photo, sends it, and it looks right to him.

### 💻 What this Mac can test

`AVCaptureMultiCamSession` does not exist in native macOS apps.
The macOS 27 SDK header `AVCaptureSession.h` marks it `API_AVAILABLE(ios(13.0), macCatalyst(14.0), tvos(17.0), visionos(2.1)) API_UNAVAILABLE(macos)`.
The iOS Simulator has no cameras. So the capture session is tested only on the phone.

The compositor is different. It takes two images and returns one, using Core Image, which runs on macOS.
It is kept free of camera code so that a small Swift script on this Mac can feed it two still images and write out the result.
That checks the layout, the mirroring, and the rounded corners without the phone.

## 🛠️ Build and install

One command builds with `xcodebuild` and installs with `devicectl` (Apple's device command-line tool).
Max never needs to open Xcode. The same command is the weekly reinstall.

The command is `lunch-cam/install.sh` if it stays under 20 lines. Otherwise it is a Swift command-line script.

## 📱 Environment (measured 2026-11-13)

- Phone: "iPhone Duo Max", model identifier `iPhone19,4`, paired and available.
- Xcode 27.2 (build 27B52).
- Multi-camera support on this phone: **not yet verified**. Layer 1 answers it.
