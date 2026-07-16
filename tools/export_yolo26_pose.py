#!/usr/bin/env python3
"""Export an Ultralytics YOLO26-pose model to CoreML for Pose4Me.

Usage:
    pip install ultralytics
    python tools/export_yolo26_pose.py [model]

`model` defaults to yolo26n-pose.pt. If YOLO26 pose weights are not yet published
on your ultralytics version, the script falls back to yolo11n-pose.pt — the app's
YOLO26PoseEstimator loads either automatically.

After export, drag the produced .mlpackage into the `pose-for-me` folder in Xcode
(check "Copy items if needed" + the app target). The app detects it at launch and
switches from the Apple Vision fallback to YOLO26.
"""

import sys
from pathlib import Path


def main() -> None:
    try:
        from ultralytics import YOLO
    except ImportError:
        sys.exit("ultralytics is not installed. Run: pip install ultralytics")

    requested = sys.argv[1] if len(sys.argv) > 1 else "yolo26n-pose.pt"
    candidates = [requested, "yolo11n-pose.pt"]

    model = None
    used = None
    for name in candidates:
        try:
            print(f"Loading {name} ...")
            model = YOLO(name)
            used = name
            break
        except Exception as err:  # weights not published / download failed
            print(f"  could not load {name}: {err}")

    if model is None:
        sys.exit("No pose weights could be loaded. Check your ultralytics version.")

    print(f"Exporting {used} to CoreML (imgsz=640, half precision, NMS-free) ...")
    path = model.export(format="coreml", imgsz=640, half=True, nms=False)

    out = Path(path)
    print("\nDone!")
    print(f"  Exported: {out.resolve()}")
    print("  Next: drag the .mlpackage into the pose-for-me folder in Xcode")
    print("  (Copy items if needed + add to the pose-for-me target).")
    print("  The Settings screen will then show 'YOLO26-pose (CoreML)' as the model.")


if __name__ == "__main__":
    main()
