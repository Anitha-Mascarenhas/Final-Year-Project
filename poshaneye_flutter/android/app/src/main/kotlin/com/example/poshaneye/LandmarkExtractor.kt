package com.example.poshaneye

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import java.io.ByteArrayInputStream

/**
 * Android native side of the `poshaneye/landmarks` MethodChannel.
 *
 * Runs the official MediaPipe Tasks Vision FaceLandmarker + PoseLandmarker
 * (RunningMode.IMAGE) over one JPEG/PNG byte array and returns ONLY the landmark
 * indices required by the production CV features (see
 * lib/services/hybrid_feature_extractor.dart, MediaPipeFeatureMath):
 *
 *   face: 234, 454, 10, 152, 33, 263, 61, 291, 127, 356   (exactly 10, no extras)
 *   pose: 11, 12, 13, 14, 15, 16
 *
 * Coordinates are NORMALIZED [0,1] (MediaPipe native output) — the Dart side
 * performs pixel scaling itself. Visibility is passed through unmodified; the
 * Dart side applies the same 0.3 threshold as the training pipeline
 * (experiments/cv_features_clean/run_experiment.py).
 *
 * No feature math happens here: geometry stays in Dart so the formulas cannot
 * drift from the Python training extraction.
 */
class LandmarkExtractor private constructor(
    private val faceLandmarker: FaceLandmarker,
    private val poseLandmarker: PoseLandmarker,
) {
    companion object {
        const val FACE_ASSET = "face_landmarker.task"
        const val POSE_ASSET = "pose_landmarker.task"

        /** Exact face landmark indices required by MediaPipeFeatureMath (10). */
        val FACE_INDICES = listOf(234, 454, 10, 152, 33, 263, 61, 291, 127, 356)

        /** Exact pose landmark indices required by MediaPipeFeatureMath (6). */
        val POSE_INDICES = listOf(11, 12, 13, 14, 15, 16)

        /** Same visibility threshold as the training pipeline. */
        const val MIN_POSE_VISIBILITY = 0.3f

        /** Largest input side fed to MediaPipe; bounds memory on large photos. */
        private const val MAX_SIDE = 1024

        /**
         * Create the extractors. Throws [IllegalStateException]/[IllegalArgumentException]
         * (MediaPipe) if model assets are missing or invalid — callers translate this
         * into a `model_init` PlatformException.
         */
        fun create(context: Context): LandmarkExtractor {
            val faceOptions = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(FACE_ASSET)
                        .setDelegate(Delegate.CPU)
                        .build()
                )
                .setRunningMode(RunningMode.IMAGE)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .build()

            val poseOptions = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath(POSE_ASSET)
                        .setDelegate(Delegate.CPU)
                        .build()
                )
                .setRunningMode(RunningMode.IMAGE)
                .setNumPoses(1)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .build()

            return LandmarkExtractor(
                faceLandmarker = FaceLandmarker.createFromOptions(context, faceOptions),
                poseLandmarker = PoseLandmarker.createFromOptions(context, poseOptions),
            )
        }
    }

    /**
     * Full extraction over JPEG/PNG bytes.
     *
     * Returns the StandardMessageCodec map expected by hybrid_landmark_bridge.dart:
     *   { "face":   { "234": [x,y], ... },
     *     "pose":   { "11": [x,y], ... },
     *     "pose_visibility": { "11": v, ... } }
     *
     * Face map is EMPTY when no face is detected (the Dart bridge turns that into
     * the "No face detected" error). Pose keys are only present for landmarks whose
     * MediaPipe visibility is >= 0.3, matching the training visibility filter.
     */
    fun extract(imageBytes: ByteArray): Map<String, Any> {
        val bitmap = decodeUprightBitmap(imageBytes)
        val mpImage = BitmapImageBuilder(bitmap).build()

        val faceMap = LinkedHashMap<String, Any>()
        val faceResult = faceLandmarker.detect(mpImage)
        val faceLandmarks = faceResult.faceLandmarks()
        if (faceLandmarks.isNotEmpty()) {
            val normalized = faceLandmarks[0]
            for (index in FACE_INDICES) {
                if (index < normalized.size) {
                    val lm = normalized[index]
                    // Normalized [0,1] coordinates, exactly as the Dart side expects.
                    faceMap[index.toString()] = listOf(lm.x().toDouble(), lm.y().toDouble())
                }
            }
        }

        val poseMap = LinkedHashMap<String, Any>()
        val visMap = LinkedHashMap<String, Any>()
        val poseResult = poseLandmarker.detect(mpImage)
        val poseLandmarks = poseResult.landmarks()
        if (poseLandmarks.isNotEmpty()) {
            val normalized = poseLandmarks[0]
            for (index in POSE_INDICES) {
                if (index < normalized.size) {
                    val lm = normalized[index]
                    if (lm.visibility().isPresent && lm.visibility().get() >= MIN_POSE_VISIBILITY) {
                        poseMap[index.toString()] = listOf(lm.x().toDouble(), lm.y().toDouble())
                        visMap[index.toString()] = lm.visibility().get().toDouble()
                    }
                }
            }
        }

        return linkedMapOf(
            "face" to faceMap,
            "pose" to poseMap,
            "pose_visibility" to visMap,
        )
    }

    /** Release MediaPipe resources. Call from MainActivity.onDestroy() or on engine detach. */
    fun close() {
        try {
            faceLandmarker.close()
        } catch (_: Exception) {
        }
        try {
            poseLandmarker.close()
        } catch (_: Exception) {
        }
    }

    /**
     * Decode bytes to a Bitmap with EXIF orientation applied, then downscale so the
     * largest side is <= [MAX_SIDE] (keeps MediaPipe latency and memory bounded).
     * Landmarks are normalized, so downscaling does not affect the returned values.
     */
    private fun decodeUprightBitmap(imageBytes: ByteArray): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw InvalidImageException("Not a decodable JPEG/PNG image")
        }

        val exifRotation = try {
            when (
                ExifInterface(ByteArrayInputStream(imageBytes)).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> 0f
                else -> 0f
            }
        } catch (_: Exception) {
            0f
        }

        val sample = Integer.highestOneBit(
            maxOf(bounds.outWidth, bounds.outHeight) / MAX_SIDE
        ).coerceAtLeast(1)
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        var bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts)
            ?: throw InvalidImageException("Failed to decode image bytes")

        if (exifRotation != 0f) {
            val matrix = Matrix().apply { postRotate(exifRotation) }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) bitmap.recycle()
            bitmap = rotated
        }
        return bitmap
    }
}

/** Thrown for undecodable images; MainActivity maps it to an `invalid_image` error. */
class InvalidImageException(message: String) : Exception(message)
