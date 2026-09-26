# Vendored camera_android_camerax (PoshanEye patch)

Fork of `camera_android_camerax 0.6.30` (pinned by `camera 0.11.4`).

## Why this exists
The stock plugin always binds **Preview + ImageCapture + ImageAnalysis** in
`initializeCamera` (`lib/src/android_camera_camerax.dart`). PoshanEye never
consumes a frame stream, but ImageAnalysis was bound anyway. On several
devices — confirmed on OPPO CPH2603 (ColorOS) — that 3-use-case combination is
not in the camera's supported surface combinations and CameraX throws:

```
java.lang.IllegalArgumentException: No supported surface combination is found
for androidx.camera.core.impl.SurfaceCombination
```

## The patch (2 small changes in lib/src/android_camera_camerax.dart)
1. `initializeCamera` instantiates and binds `ImageAnalysis` **only** when
   `_imageOutputFormatRequested` is true (set by `onStreamedFrameAvailable`).
   Otherwise the camera binds the minimal `Preview + ImageCapture`.
2. No other behaviour changed: video capture, streaming, rotation handling are
   untouched, and any app that does listen to the frame stream gets the
   original 3-use-case binding.

## Maintenance
If `camera_android_camerax` is ever upgraded past this fork, re-check whether
the stock plugin still force-binds ImageAnalysis and re-apply if needed.
Remove the vendored fork and the pubspec override when upstream fixes it.
