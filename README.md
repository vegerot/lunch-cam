# 🍱 Lunch Cam

An iPhone app that takes one photo with the rear and the front camera at the same moment: one camera fills the frame, the other is a small inset. Max built it to send lunch photos in a few taps.

- 📷 Tap the inset to swap the cameras; drag, pinch or flick it to place it.
- 📱 Lays itself out for every pose of the iPhone Duo: closed, open, half-folded, and split view.
- 🏷️ Saves a HEIC file with the date, the camera's own exposure details and the place.

## 🗺️ Where things are

| File | What it is |
| --- | --- |
| [SPEC.md](SPEC.md) | The living description: decisions, measurements and results, each with its evidence |
| [TODO.md](TODO.md) | The backlog |
| [iphone-duo-notes.md](iphone-duo-notes.md) | What Apple says about the iPhone Duo, with sources |
| `LunchCam/` | The app: `Camera.swift`, `LunchCamApp.swift`, and the pure types `Inset`, `Layout` and `Metadata` |
| `Tests/` | Tests for the pure types, run on the Mac |
| [dev](dev) | The developer commands |

## 🛠️ Commands

```sh
./dev test                 # run the tests on the Mac, no phone needed
./dev install --console    # build, install and launch on the paired iPhone, and show the app's output
./dev photo                # copy the last photo the app took to last.heic
```

## 🕰️ History

The project lived in the folder `lunch-cam/` of the private `ai-conversations` repository until 2026-11-24. Its commits were carried over with their dates and messages. The notes of the conversations that built it stayed there, in `lunch-cam/` of that repository.

`.agents/skills/` holds four agent skills copied from Xcode. Their text is Apple's: remove them before making this repository public.
