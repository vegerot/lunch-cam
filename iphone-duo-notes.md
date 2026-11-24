# 📱 iPhone Duo: what Apple says, and what it means for Lunch Cam

Read on 2026-11-23. These are notes in my own words, with the address of each source.
Every "Apple says" item is documented by Apple; "Lunch Cam today" items are read from our code; nothing here is measured on the phone unless it says so.

## 📚 Sources, all read in full

| Source | Address |
| --- | --- |
| Design guidelines: Designing for iPhone Duo | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo |
| Developer overview: Preparing your app for iPhone Duo | https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo |
| Three steps to make your app shine on iPhone Duo | https://developer.apple.com/iphone-duo/prepare/ |
| Article: Choosing a camera by the direction it faces | https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces |
| Article: Registering a camera capture accessory on iPhone Duo | https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo |
| Tech Talk 111461: Prepare your app for iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111461/ |
| Tech Talk 111462: Raise the bar with iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111462/ |
| Tech Talk 111463: Strike a pose with adaptive layouts | https://developer.apple.com/videos/play/tech-talks/111463/ |
| Tech Talk 111464: Leverage multiple displays and scenes | https://developer.apple.com/videos/play/tech-talks/111464/ |
| Tech Talk 111465: Build a great camera experience | https://developer.apple.com/videos/play/tech-talks/111465/ |
| Tech Talk 111466: Design for iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111466/ |
| Xcode's `app-resizability` agent skill | `xcrun agent skills export` writes it to `xcode-skills/app-resizability/` |

Not read: Apple Design Resources (design templates to download, not text), and the article "Supporting device rotation in your camera app".

How to read them again: the documentation pages are JavaScript apps, but each has a data file at `https://developer.apple.com/tutorials/data/documentation/<path>.json`. The Tech Talk pages carry their transcript in the page, in `<section id="transcript-content">`. Xcode's offline documentation index has the design guidelines and the two camera articles, but not the developer overview.

## 🧱 The device

- Two displays. The **outer** one is used closed; it is wider and shorter than other iPhones. The **inner** one is used open.
- Size classes: outer portrait is compact width, regular height. Inner is regular width and regular height.
- Poses: closed, open, partially folded like a book, folded like a laptop on a table, standing like a tent.
- **Controls sit on the side**, not top and bottom: on the outer display always, and on the inner display in landscape. The status bar and the Dynamic Island are in that side strip too. Only the inner display in portrait keeps horizontal bars.
- The side strip is on the hardware's side: it does not flip for right-to-left languages. In Split View, the left app has it on the left.

## 🏗️ Which SDK you build with decides how much screen you get

| Built with | Result on iPhone Duo |
| --- | --- |
| iOS 26 SDK or older | Runs in a familiar iPhone shape, with empty space around it. |
| iOS 27 SDK | Resizes to fill most of the display, but stays clear of the status strip. |
| iOS 27.1 SDK or newer | Uses the full display; standard bars go vertical under the status bar. |

Lunch Cam today: built with Xcode 27.2, so the third row applies.

## 📐 Layout rules

- Lay out from the **space you are given** (the view's size, size classes, safe areas). Never from the screen's size, the device type, or the interface orientation.
- To know whether you are wide or tall, compare the width and height you have.
- Safe areas are **asymmetric** on this phone. Handle each side on its own.
- The size can change in the middle of a session, when the phone folds. Re-read it; do not read it once.
- **The inner display does not honor an app's supported orientations.** A portrait-only app is scaled there.
- Reserved regions (`ReservedRegion`, from a `GeometryProxy`): the fold is a *division*, active only when partially folded; a camera is an *occlusion*. The outer camera always occludes. The inner camera occludes only while it is active.
- `toolbarVerticalEdge` (SwiftUI environment) says whether the system is showing bars on the side.
- `ArrangementView` holds a primary and a secondary view. Its *overlay* style layers them, and moves them to the two halves when the phone is partially folded. Apple names media with controls as the example.
- Partially folded on a table: content on the top half, controls on the bottom half. Keep the same controls in every pose.
- `onHingeChange` gives the hinge status (closed, partially open, fully open) and angle. Apple says to use it for effects, and the arrangement and region APIs for layout.

## 📷 Camera rules

- There are **two front cameras**, one above each display. Both have square sensors and an ultra wide view. The inner one is under the display.
- Asking for the front camera the usual way returns a **virtual front camera**. It streams from the camera above whichever display the app is on, and switches when the phone opens or closes. Apps need no change for this.
- The virtual front camera offers only what both cameras share: at most 1080p at 60 frames per second, no depth. The outer camera alone goes to 4K and 120; the inner one to 1080p and 60.
- `position` says where a camera sits, not where it points. With the phone open and turned around, the rear cameras face you. `AVCaptureDeviceDirectionCoordinator` (AVKit) reports which cameras face the same way as a view.
- Mirroring should follow direction, not position: mirror a rear camera that faces you.
- **The rotation coordinator's angle changes when the app moves between displays.** A rotation coordinator belongs to one camera; make a new one after a camera switch.
- After adopting the rotation coordinator, turn off camera-sensor-orientation compensation, which is on for all front cameras on this phone and costs performance.
- A camera switch takes time; cover the preview until the new camera delivers frames.
- Apple's advice to reconfigure one input instead of using a multi-camera session is for apps that show one camera at a time.
- On the inner display a full-view rear preview leaves spare room. Offset the preview and group the controls in that room, or fill the display.
- `dynamicAspectRatio` lets a square-sensor front camera deliver a landscape picture without turning the phone.
- With the phone open and the rear camera in use, a *camera capture accessory* can show content on the outer display to the person being photographed. The system decides when it appears.

## 🍱 What this means for Lunch Cam

| # | Gap | Evidence | Size |
| --- | --- | --- | --- |
| 1 | ✅ Fixed 2026-11-23 (`Layout.swift`). The shutter sat on the picture's bottom edge on the outer display. | Seen in Max's recording of 2026-11-23. The outer display is nearly the photo's 3:4 shape, so nothing is left below. | Small |
| 2 | ✅ Lock removed 2026-11-23; the shutter moves beside the picture when open. Tabletop layout still open. The app was portrait-only, so it was scaled on the inner display. | `UISupportedInterfaceOrientations = Portrait` in the project; Apple's rule above. Not looked at on the phone. | Small to remove the lock; medium to lay out well |
| 3 | ✅ Fixed 2026-11-23: every new angle is applied. The upright angle was read once at startup. | `Camera.swift` reads `videoRotationAngleForHorizonLevelPreview` once. Apple says it changes between displays. Not tested by opening the phone. | Medium. Same work as "Make rotation work". |
| 4 | Does not apply: it is a setting of `AVCapturePhotoOutput`, which we do not use. Sensor-orientation compensation is left on. | Not set anywhere in our code. | Small, after 3 |
| 5 | The front camera is the virtual one, capped at 1080p. | We ask for `.builtInWideAngleCamera` at `.front`. We use 1920x1440, which layer 1 measured as available. | No action. The cap does not bind us. |

Already fine, checked against the `app-resizability` skill's list: no use of the main screen, device type, or interface orientation; sizes come from `GeometryReader`; a launch screen is declared; no full-screen opt-out.

Ideas, not gaps:

- 🪑 **Tabletop mode.** Half-folded on the table: picture on the top half, shutter on the bottom half. An overlay `ArrangementView` is Apple's tool for exactly this.
- 🤳 **Rear-camera selfie.** Open and turned around, the rear cameras face you and the outer display can be the viewfinder. Higher quality than either front camera. It changes what "front" and "rear" mean for a dual photo, so it needs thought.
- 🪞 **Outer display for the subject.** No use while the subject is lunch.

## 🧪 How to test without the phone

Xcode 27.2 on this Mac knows the device type "iPhone Duo" (`xcrun simctl list devicetypes`), but no simulator runtime is installed (`xcrun simctl list runtimes` is empty). With a runtime, Device Hub can open, close, rotate and fold a simulated Duo. The simulator has no cameras, so it shows layout only.
