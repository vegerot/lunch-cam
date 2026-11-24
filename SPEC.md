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
| Inset | Starts in the top-left corner at a quarter of the photo, with rounded corners. A tap on it swaps which camera is the inset, and the two pictures ease into their new sizes over a quarter second (Max wants this animation kept). A drag moves it and a pinch resizes it, between 15% and half of the photo, always inside the photo (all added 2026-11-23). |
| Selfie | Mirrored, as the preview shows it. |
| Rear lens | Main wide lens only. |
| Controls | One shutter button. The volume buttons also fire the shutter. |
| After the shutter | The photo saves to the Photos library, then the iOS share sheet opens with it. |
| Permissions | Camera, and add-only Photos access (the app can save, not read). |
| Name | "Lunch Cam", bundle ID `com.vegerot.lunchcam`. |
| Icon | A bowl of ramen inside a camera lens, on orange. Made by `gpt-image-2.6-sunburst` on 2026-11-23 from prompt `b-lens` in `icon-candidates/prompts.json`; Max chose it from seven candidates. |
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

- One automated test run: `./dev test` checks the inset geometry (`LunchCam/Inset.swift`) and the screen layout (`LunchCam/Layout.swift`) on the Mac in about a second. Everything else is checked by hand on the phone.
- **Claude watches the phone's screen** through QuickTime Player (File ▸ New Movie Recording, with the iPhone as the camera). It shows the camera and is view only, so Max does the taps.
- **Claude checks** each layer through the app's console output: the app launches, the session runs, nothing crashes. iPhone Mirroring cannot show the camera: it replaces the app with the notice "iPhone camera is not available from Mac" (measured 2026-11-13). From layer 3 on, Claude copies the saved photo off the phone and looks at it.
- **Max checks** on the physical phone, with iPhone Mirroring disconnected: the layer 2 preview, the layer 3 photo, and the layer 4 volume buttons. Claude also analyzes it and gives an opinion.
- **Version 1 is done** when Max takes a real photo, sends it, and it looks right to him.

`AVCaptureMultiCamSession` cannot be tested on this Mac.
The macOS 27 SDK header `AVCaptureSession.h` marks it `API_AVAILABLE(ios(13.0), macCatalyst(14.0), tvos(17.0), visionos(2.1)) API_UNAVAILABLE(macos)`, and the iOS Simulator has no cameras.
A Mac test harness for the compositor is not built: the phone loop is one command, and Claude copies each photo off the phone to look at it.

## 🛠️ Build and install

`lunch-cam/dev` is one shell script with three subcommands:

- `./dev install` builds with `xcodebuild`, installs with `devicectl` (Apple's device command-line tool), and launches the app. Adding `--console` keeps showing the app's output; stopping it stops the app. This is also the weekly reinstall.
- **The tint.** Xcode's Device Hub gives apps blank camera frames while it controls the phone (Apple documents this in "Interacting with your app in Device Hub"), so the two pictures would be black on black. The app notices blank frames by itself and then draws a red layer with an F over the front camera's picture and a green layer with a B over the back camera's. A letter lying on its side means that camera's picture is not upright. Saved photos are not tinted. How it notices: once a second it samples the rear camera's frame; under Device Hub every sample has the same brightness (measured: 16, pure black), which a real sensor never delivers because of noise. Only real pixels are sampled: a row can hold spare bytes after the picture (measured: 1472 bytes for 1440 pixels) and those are not black; sampling them made the tint vanish whenever the picture was tall. Until 2026-11-23 evening this was a launch option, `--tint`.
- `./dev photo [file]` copies the last photo off the phone, for as long as the app keeps its debug copy.
- `./dev test` runs the inset and layout geometry tests on the Mac.

Max never needs to open Xcode.

### 🧰 Apple's agent skills

`lunch-cam/.agents/skills/` holds four skills that ship inside Xcode, copied unchanged from Xcode 27.2 (build 27B52) on 2026-11-23: `app-resizability`, `device-interaction`, `swiftui-specialist` and `swiftui-whats-new-27`. `.claude/skills/` links to them. Refresh them after an Xcode update with `xcrun agent skills export`, which writes all eleven of Xcode's skills to `./xcode-skills/`. The text is Apple's, so leave these folders out if this project ever becomes public.

The script was 34 lines then (41 now, with three subcommands). Max waived the 20-line limit for it after a Swift version was tried: Swift needed 64 lines (53 of code) against 29 (17 of code) for the two original shell scripts together, because running commands is what shell does natively.

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

### 🔄 Swap result (2026-11-23)

A tap on the inset swaps the two cameras in the preview and in the saved photo. One `swapped` flag feeds both, so they cannot disagree.

- Max checked the preview on the phone: "looks good".
- Console: `shot via screen button, swapped true: 1440x1920`, then `saved to Photos: true`.
- Claude looked at the photo copied off the phone: the selfie is the full frame, and the rear camera is the inset with keyboard labels readable left to right, so the rear camera is not mirrored.
- No automated test. A Mac test of the compositor was considered and cut in a five-step pass: for swap it would cover one line (which frame is drawn first) and needed the drawing rewritten from UIKit to Core Graphics. Raise it again for drag, pinch and rotation, where the compositor gets real geometry.

### 🤏 Drag and pinch result (2026-11-23)

The inset is a pure value, `Inset`: a center and a size, both fractions of the photo. The preview and the saved photo ask it for a rectangle at their own sizes, so they agree.

- Built test-first at that seam: six red-to-green cycles, eight checks against rectangles worked out by hand for a 1440x1920 photo.
- First build on the phone: Max reported that the inset "doesn't move all the way to my finger" and looked bad while moving. Cause: the drag was measured in the inset's own coordinates, and the inset moves during the drag, so the distance was undercounted. Fix: `DragGesture(coordinateSpace: .global)`. The tests could not catch this; they cover what a drag distance does, not how it is measured.
- Also turned off Core Animation's quarter-second easing of the camera layer, so the picture does not trail its frame during a pinch.
- After the fix, Max: "Looks great!"
- Claude compared a photo with the console: the log said center (0.708, 0.436), size 0.25, and the inset in the copied photo sits there.
- The top margin changed from 3% of the photo's width to 3% of its height (43.2 to 57.6 pixels), so the geometry does not depend on the photo's shape.

## 📱 iPhone Duo layout result (2026-11-23)

First step of "Optimize for iPhone Duo". Background and sources: `iphone-duo-notes.md`.

- **Rule** (`LunchCam/Layout.swift`, pure, tested): the shutter gets a strip of its own, 96 points wide, below the picture or beside it, whichever leaves the larger 3:4 picture. The picture and the strip are centered together. The shutter never covers the picture; in a space with no spare room the picture shrinks instead.
- **Orientation lock removed.** The project allowed portrait only. Apple says the inner display ignores that and scales such an app. All four orientations are now allowed, and the layout follows the space it is given.
- **Seen in Device Hub with the tint** (layout only, cameras are black there): closed, the shutter sits below the picture; open, it sits to the right of the picture. Before, it covered the picture's bottom edge in both.
- **Not done yet:** half-folded, the picture still crosses the fold (tabletop mode); the camera cutout of the open display covers a corner of the picture.

## 🔄 Rotation result (2026-11-23)

This is TODO's "Make rotation work". Max reported after the layout change that the cameras did not turn with the layout.

- **Cause:** each camera's upright angle was read once at startup. The phone asks for a new angle when it turns, and when it opens or closes.
- **Fix** (`Camera.swift`): each camera keeps its rotation coordinator and applies every new angle to its preview and to its saved frames. Both use the preview's angle, so the photo is what the screen showed.
- **The picture's shape follows the cameras.** The sensors are wide, so at 0 or 180 degrees the upright picture is 4:3, and `Layout` gets `landscape: true`. Measured on this phone: closed and upright 90 (rear) and 270 (front), a tall picture; open and upright 180 and 180, a wide picture; open after a quarter turn 270 and 90, a tall picture.
- **The tint shows this bug.** Each letter is turned by the angle its preview has minus the angle the phone asks for. Reproduced in Device Hub: with the angle frozen at its startup value, opening and turning the phone laid both letters on their side; with the fix they stay upright in every pose.
- **Limit of that check:** the letters compare two angles. They do not look at the pixels, which are black in Device Hub. Whether real pictures are upright, and the selfie mirrored the right way, in each pose needs Max holding the phone.
- **Slow and stuttering at first, then fixed.** Max's screen recordings showed the picture snapping to its new shape after the screen had finished rotating. Measured: turning a camera's saved frames takes about 0.3 seconds, and both cameras did it one after the other on the main thread, so the app froze for 0.6 seconds in every turn. Now the previews turn at once (5 ms after the screen's new size arrives; a preview is only a transform), the saved frames turn on the camera queue, and the picture eases into its new shape over 0.3 seconds starting 8 ms after the new size. A photo taken in the half second after a turn can still have the old orientation.
- **A deadlock, found and fixed on the way:** the main thread must not wait for the camera queue, because connecting a preview layer on the camera queue waits for the main thread. iOS killed the app at launch (signal 9).
- **Not applicable:** Apple's advice to turn off sensor-orientation compensation is a setting of `AVCapturePhotoOutput`, which the app does not use.

## ✂️ Five-step pass (2026-11-13)

One pass of the five-step engineering algorithm: question each requirement, delete, simplify, speed up the loop, automate last.

| Change | Reason |
| --- | --- |
| Deleted the Mac compositor test script. | Layer 3 tests the compositor on the phone anyway. A second harness is built only if the phone loop is slow. |
| Deleted "video can reuse the compositor" as the reason for frame grab. | That was a "we might need this later" reason. Frame grab stays because it is the least code for version 1. |
| Dropped the "truly simultaneous" requirement. | A few milliseconds between the two cameras cannot be seen in a lunch photo. |
| Relaxed the fixed 3:4 shape. | Claude chose 3:4 to match the Camera app. If the phone only offers 16:9 multi-camera formats, forcing 3:4 means cropping code and fewer pixels. |
| Merged six layers into four. | Rear preview plus inset is one session setup. Save and share are both a few lines after the composite. Fewer install cycles. |
| Kept the install command (now `dev install`) as the only automation. | The weekly reinstall is not scheduled. It is one manual command until it annoys Max. |

Added back by Max after the pass: the automatic save to Photos and the volume-button shutter. The pass had deleted both.
