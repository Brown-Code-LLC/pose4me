# Pose4Me — Project Execution Plan

**Product:** iOS app that fights sedentary damage. Every 1–2 hours (fully customizable) it
nudges you to do a 30s–90s guided stretch. The front camera opens, an animated guide figure
demonstrates the pose, and an on-device pose-estimation model (YOLO26-pose via CoreML, with
Apple Vision as a zero-setup fallback) draws a live skeleton over your body and tracks you
until the stretch is complete.

## 1. Architecture

```
pose-for-me/                    (app target — file-system synchronized group)
├── App/          pose_for_meApp.swift, RootView (tab shell), Onboarding gate
├── Core/         Theme (design system), Haptics, WidgetBridge
├── Models/       Exercise + PoseSpec keyframes (forward-kinematics builder), Routine
│                 (curated multi-stretch breaks), UserSettings (every feature
│                 customizable), SessionStore (history/streaks/shields)
├── Services/
│   ├── CameraManager          AVCaptureSession, front camera, frame stream
│   ├── PoseEstimator          protocol + BodyPose (17 COCO keypoints)
│   ├── YOLO26PoseEstimator    CoreML (yolo26n-pose.mlpackage) — used when bundled
│   ├── VisionPoseEstimator    VNDetectHumanBodyPoseRequest — always-available fallback
│   ├── PoseMatcher            joint-angle scoring: detected pose vs. target keyframe
│   ├── ReminderScheduler      UNUserNotificationCenter, interval/active-hours/days
│   ├── VoiceCoach             AVSpeechSynthesizer spoken cues + corrections
│   ├── WatchSyncService       WCSession application-context push to the watch
│   └── TipJar                 StoreKit 2 tip jar (three consumables)
└── Views/        Home (countdown ring + routines), Session (camera + overlay + guide),
                  RoutineSession (chained stretches), Library, Stats (Swift Charts),
                  Settings, TipJar
Pose4MeWidget/    iOS widgets · Pose4MeWatch/ + Pose4MeWatchWidget/  watchOS companion
tools/            export_yolo26_pose.py — Ultralytics → CoreML export
```

**Key design decision — one pose spec, three uses.** Each exercise keyframe is authored as
a compact set of limb angles. A forward-kinematics builder turns those angles into 17
normalized keypoints. The same spec therefore drives:
1. the animated guide figure (SwiftUI spring/keyframe animation between keyframes),
2. the matching target (PoseMatcher compares the user's joint angles to the spec), and
3. the library thumbnails. Adding an exercise = adding one data literal.

## 2. Pose pipeline

Camera frame → PoseEstimator (YOLO26 CoreML if `yolo26n-pose.mlpackage` is bundled,
otherwise Vision) → `BodyPose` (17 COCO keypoints, normalized + confidence) → published to
UI → `SkeletonOverlay` (Canvas) draws bones/joints, `PoseMatcher` computes per-joint angle
error → match score ≥ threshold accumulates hold time → progress ring fills → next keyframe
→ session complete → streak + history recorded.

YOLO26 model is not committed (weights are large); run `tools/export_yolo26_pose.py` and
drop the `.mlpackage` into the app folder. The app auto-detects it at launch.

## 3. Customization surface (Settings)

- Reminder interval: 30 min – 4 h stepper
- Active hours (start/end) and active weekdays
- Session length: 30 / 60 / 90 s or custom
- Difficulty, enabled categories, seated-friendly-only mode
- Reminder style: standard / time-sensitive, snooze length
- Camera tracking on/off (timer-only fallback), match strictness, haptics/sound

## 4. Monetization

Shipped model: **fully free app, tip jar only.** No paywall, no subscription, no locked
content. `TipJar.swift` + `TipJarView.swift` sell three StoreKit 2 consumables
(`pose4me.tip.espresso` $1.99 / `.latte` $4.99 / `.carafe` $9.99), live in App Store
Connect since 1.0. The earlier Pro-subscription plan was dropped before launch.

## 5. Roadmap

Shipped: v1.0 (App Store, July 2026), 1.1 (voice guidance, always-on screen), routines,
streak shields, smarter suggestions, per-category stats.

1. **Retention:** weekly recap notifications + share cards, Live Activity during
   sessions, interactive "Start stretch" widget (App Intents / Siri).
2. **Data safety:** iCloud backup of session history (streaks survive a new phone).
3. **Watch:** run timer-tracked stretches directly on the wrist with haptic cues.
4. **Model quality:** YOLO26-pose fine-tuned on stretch poses; 3D lift (depth from
   TrueDepth) for form scoring; rep counting for dynamic moves.
5. **Platform:** HealthKit (mindful minutes/workouts); possibly Android
   (same YOLO26 → TFLite).

## 6. Verification

Built from the CLI: `xcodebuild -project pose-for-me.xcodeproj -scheme pose-for-me
-destination 'generic/platform=iOS Simulator' build` — must compile clean. Camera/pose flow
requires a physical device (simulator has no camera; a demo mode animates a synthetic body).
