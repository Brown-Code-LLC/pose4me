# Pose4Me 🧘 — stretch reminders with a camera coach

An iOS app that fights sedentary damage. Every hour (or whatever rhythm you pick) it
nudges you to take a 30–90 second stretch. The front camera opens, an **animated guide
figure** demonstrates the pose, and **on-device pose estimation** (YOLO26-pose via
CoreML, Apple Vision fallback) draws a live glowing skeleton over your body and tracks
you until the stretch is done.

> See [PLAN.md](PLAN.md) for the full architecture, execution plan, and SaaS roadmap.

## Features

- ⏰ **Customizable reminders** — interval (30 min–4 h), active hours, active weekdays,
  snooze length, with Start/Snooze actions right on the notification
- 📸 **Camera pose tracking** — 17-keypoint skeleton overlay, angle-based form matching,
  limb-level coaching cues ("Adjust your left arm"), all 100% on-device
- 🤸 **Animated guide figure** — a springing stick-figure coach morphs between pose
  keyframes for you to imitate
- 🧩 **12-stretch library** — neck, shoulders, back, arms, legs, full body; seated-friendly
  filter; difficulty levels; each authored as a compact set of limb angles
- 🔥 **Streaks & stats** — daily streak, 14-day activity chart (Swift Charts), form scores
- 💎 **Pro subscription** — StoreKit 2 paywall (monthly/yearly + trial), free tier keeps
  5 core stretches
- 🎛 **Everything customizable** — session length, form strictness, categories, difficulty,
  haptics, camera on/off

## Getting started

1. Open `pose-for-me.xcodeproj` in Xcode 26+
2. Run on a **physical iPhone** (the camera flow needs one; the simulator runs a demo
   mode with a synthetic body so you can still see the whole experience)
3. Optional — enable YOLO26: `pip install ultralytics && python tools/export_yolo26_pose.py`,
   then drag `yolo26n-pose.mlpackage` into the `pose-for-me` folder in Xcode. Settings →
   Pose tracking will show the active backend.

## Monetization status

Product IDs `pose4me.pro.monthly` / `pose4me.pro.yearly` are wired through StoreKit 2 but
not yet created in App Store Connect. Until they exist, the paywall clearly falls back to
a local developer unlock so the full app is testable.

## Project layout

| Path | What lives there |
|---|---|
| `pose-for-me/Models` | Exercise library, pose specs (forward kinematics), settings, history |
| `pose-for-me/Services` | Camera, YOLO26/Vision estimators, pose matcher, reminders, StoreKit |
| `pose-for-me/Views` | Onboarding, Today, Session (camera+overlay), Library, Progress, Settings, Paywall |
| `tools/` | YOLO26 → CoreML export script |
