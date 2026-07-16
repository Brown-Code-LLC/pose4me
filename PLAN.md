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
├── Core/         Theme (design system), Haptics
├── Models/       Exercise + PoseSpec keyframes (forward-kinematics builder),
│                 UserSettings (every feature customizable), SessionStore (history/streaks)
├── Services/
│   ├── CameraManager          AVCaptureSession, front camera, frame stream
│   ├── PoseEstimator          protocol + BodyPose (17 COCO keypoints)
│   ├── YOLO26PoseEstimator    CoreML (yolo26n-pose.mlpackage) — used when bundled
│   ├── VisionPoseEstimator    VNDetectHumanBodyPoseRequest — always-available fallback
│   ├── PoseMatcher            joint-angle scoring: detected pose vs. target keyframe
│   ├── ReminderScheduler      UNUserNotificationCenter, interval/active-hours/days
│   └── Entitlements           Pro subscription (StoreKit 2 + graceful mock in dev)
└── Views/        Home (countdown ring), Session (camera + overlay + guide),
                  Library, Stats (Swift Charts), Settings, Paywall
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

## 4. Monetization (SaaS)

Free: 5 core stretches, 1 daily schedule, 7-day history.
Pro ($6.99/mo, $39.99/yr, 7-day trial): full library, custom routines, multiple schedules,
unlimited stats, strict-form coaching. StoreKit 2 in `Entitlements.swift`; product IDs are
placeholders until App Store Connect is configured — a dev toggle unlocks Pro locally.

## 5. Path to scale (post-prototype roadmap)

1. **v1.0 ship:** real StoreKit products, App Store review assets, watchOS reminder mirror.
2. **Retention:** streak freezes, weekly recap notifications, share cards.
3. **B2B SaaS wedge:** team/corporate-wellness dashboards (companies pay per seat — this is
   where the real SaaS revenue is), Slack/Teams integration for desk workers.
4. **Model quality:** YOLO26-pose fine-tuned on stretch poses; 3D lift (depth from
   TrueDepth) for form scoring; rep counting for dynamic moves.
5. **Platform:** Android (same YOLO26 → TFLite), HealthKit (stand hours, mindful minutes).

## 6. Verification

Built from the CLI: `xcodebuild -project pose-for-me.xcodeproj -scheme pose-for-me
-destination 'generic/platform=iOS Simulator' build` — must compile clean. Camera/pose flow
requires a physical device (simulator has no camera; a demo mode animates a synthetic body).
