# Lull for iPhone

The native app version of Lull. The lamp is the same lava engine as the web app (in `Lull/Web/index.html`),
wrapped in a native app that adds what a website can't do:

- **Background audio**: soundscapes, music and tones keep playing with the screen locked, with play/pause on the Lock Screen
- **Sleep fade** that still works with the screen off
- **Apple Health**: finished sessions are saved as Mindful Minutes
- **Live Activity**: session timer on the Lock Screen and in the Dynamic Island
- **Widgets**: a lava-lamp widget in your colours (Home Screen and StandBy) and a Lock Screen "Quick calm"
- **Siri & Shortcuts**: "Start Unwind in Lull"
- **Haptics**: bubbles, merges, splits and each breath
- **Shake & tilt** with no permission prompt
- **Nightly reminder** that opens straight into "Drift to sleep"
- Keeps the screen awake while the lamp is showing

## First build
1. Install Xcode from the Mac App Store and open it once.
2. In Terminal: `bash ~/path/to/lull-ios/setup.sh` (or drag `setup.sh` into Terminal and press Return).
3. In Xcode, select the **Lull** project, then for **both** targets (Lull and LullWidgets) open *Signing & Capabilities*
   and choose your Team.
4. Plug in your iPhone (turn on Developer Mode when it asks), choose it at the top of Xcode, and press ▶.

## Updating the lamp
Copy the newest `index.html` from the web repo into `Lull/Web/` and build again.

## Files
- `Lull/App` — app entry and the lamp view (+ the bridge that talks to the lamp)
- `Lull/Native` — audio engine, haptics, motion, Health, Live Activity, Now Playing, reminders, Siri
- `LullWidgets` — widgets and the Live Activity UI
- `Shared` — code used by both
- `project.yml` — project definition (XcodeGen builds `Lull.xcodeproj` from it)
