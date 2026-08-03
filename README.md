# Pose4Me App 🧘 — stretch reminders with a camera coach

An iOS app that fights sedentary damage. Every hour (or whatever rhythm you pick) it
nudges you to take a 30–120 second stretch. The front camera opens, an **animated guide
figure** demonstrates the pose, and **on-device pose estimation** (YOLO26-pose via
CoreML, Apple Vision fallback) draws a live glowing skeleton over your body and tracks
you until the stretch is done.

Shipped on the [App Store](https://apps.apple.com/app/pose4me/id6793132419) — fully
free, tip-jar supported.

> See [PLAN.md](PLAN.md) for the full architecture and roadmap.

## Features

- ⏰ **Customizable reminders** — interval (30 min–4 h), active hours, active weekdays,
  snooze length, with Start/Snooze actions right on the notification
- 📸 **Camera pose tracking** — 17-keypoint skeleton overlay, angle-based form matching,
  limb-level coaching cues ("Adjust your left arm"), all 100% on-device
- 🗣 **Voice guidance** — spoken cues for each phase, plus a spoken correction when
  you've been off-target for a while
- 🤸 **Animated guide figure** — a springing stick-figure coach morphs between pose
  keyframes for you to imitate
- 🧩 **20-stretch library** — neck, shoulders, back, arms, legs, full body; seated-friendly
  filter; difficulty levels; each authored as a compact set of limb angles
- 🔁 **Routines** — curated multi-stretch breaks (Desk Break, Posture Reset, Energy
  Boost) chained back-to-back in one session flow
- 🔥 **Streaks & stats** — daily streak with earned streak shields (one per 7 stretches
  auto-covers a missed day), 14-day activity chart, per-category breakdown, personal
  bests, form scores
- 🧠 **Smart suggestions** — the suggested stretch avoids recent repeats and favors
  the focus area you've neglected longest
- 📱 **Widgets & watch** — next-stretch countdown widgets/complications and a watchOS
  companion mirroring streak and schedule
- 🎛 **Everything customizable** — session length, form strictness, categories, difficulty,
  haptics, voice, appearance, camera on/off

## Getting started

1. Open `pose-for-me.xcodeproj` in Xcode 26+
2. Run on a **physical iPhone** (the camera flow needs one; the simulator runs a demo
   mode with a synthetic body so you can still see the whole experience)
3. Optional — enable YOLO26: `pip install ultralytics && python tools/export_yolo26_pose.py`,
   then drag `yolo26n-pose.mlpackage` into the `pose-for-me` folder in Xcode. Settings →
   Pose tracking will show the active backend.

## Monetization

The whole app is free — no paywall, no subscription, no locked content. Support comes
from a StoreKit 2 **tip jar** (three consumables: `pose4me.tip.espresso` / `.latte` /
`.carafe`), live in App Store Connect.

## Project layout

| Path | What lives there |
|---|---|
| `pose-for-me/Models` | Exercise library, routines, pose specs (forward kinematics), settings, history |
| `pose-for-me/Services` | Camera, YOLO26/Vision estimators, pose matcher, reminders, voice coach, tip jar |
| `pose-for-me/Views` | Onboarding, Today, Session (camera+overlay), Library, Progress, Settings, Tip jar |
| `Pose4MeWidget/` | iOS home/lock-screen widgets (next-stretch countdown) |
| `Pose4MeWatch/` + `Pose4MeWatchWidget/` | watchOS companion + complications |
| `tools/` | YOLO26 → CoreML export script |
