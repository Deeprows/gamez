# Penalty Kings — Version 3.4.0

A polished, offline-first football penalty shootout game built with Flutter.

## Gameplay
- **Quick Shootout:** five penalties; beat your personal best.
- **Golden Goal:** first to three goals or three goalkeeper saves decides the duel.
- **Training Ground:** ten attempts to sharpen your finishing.
- Three goalkeeper difficulty levels: Amateur, Pro and World Class.
- Drag on the pitch to aim, set shot power, then shoot.
- Animated shot outcomes, horizontal and vertical goalkeeper dives, and haptic feedback.
- Shot power now affects shot speed versus control and the goalkeeper's chance of saving.
- Match-by-match scoring history distinguishes goals, saves and misses.
- Match-end conversion rate and best streak are calculated for the match, not the lifetime career.
- Goalkeeper difficulty is saved between sessions.
- **King’s Cup:** a three-round knockout tournament against CPU opponents, with a trophy-winning final.
- **Local leaderboard:** your five highest quick-shootout and tournament scores are saved on the device.
- **Club and national team selection:** choose your favourite side and opponent from 20 clubs or 20 national teams, including Nigeria, Egypt, England, Brazil, Argentina and more.
- **Saved team preferences:** your selected side and opponent are remembered on the device and shown on match and result screens.
- **Keeper kits:** choose from four goalkeeper kit colours; your choice persists between sessions.

## Career system
- Persistent career record: matches, shots, goals and goalkeeper saves.
- Goal conversion percentage.
- Six unlockable achievements with live progress.
- Personal best score and best scoring streak.
- All progress is stored locally on the device with `shared_preferences`.

## Build an Android APK
1. Create a GitHub repository and upload the contents of this project folder.
2. The repository-root workflow is at `.github/workflows/android-apk.yml` and builds the app from this `penalty-kings/` folder.
3. Push to `main` (or `master`).
4. Open **Actions → Android APK** and wait for the workflow to finish.
5. Open the completed run and download the `penalty-kings-android-apk` artifact. Extract the APK from the downloaded artifact ZIP.

You can also build locally with Flutter:
```bash
flutter pub get
flutter analyze
flutter build apk --release
```

## Notes
- The game works offline after installation.
- Career statistics are local to the device; there is no online leaderboard or cloud account in this version.
- The sound-effects preference remains available in settings, but a custom sound-effects pack has not been added yet.
- The project uses GitHub Actions to generate the Android platform folder when it is not present.


## Version 3.4.0 — PES-style controls
- Added an on-screen left analogue joystick for aiming across the goal.
- Added a dedicated circular SHOOT action button on the right.
- Kept the shot-power slider and existing pitch drag aiming as a fallback.
- Updated the in-game tutorial to explain joystick aiming.
