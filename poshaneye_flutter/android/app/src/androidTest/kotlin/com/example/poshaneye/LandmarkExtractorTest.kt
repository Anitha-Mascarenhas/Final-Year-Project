package com.example.poshaneye

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * On-device integration test for the `poshaneye/landmarks` native bridge.
 *
 * Loads a real frontal child photo (same dataset the production pipeline was
 * trained on), runs LandmarkExtractor, and verifies:
 *  - all 10 required face indices are present when a face is detected
 *  - pose indices present when visible (>= 0.3 MediaPipe visibility)
 *  - every coordinate is normalized in [0,1]
 *  - no extra face landmarks are returned (Dart contract)
 *  - invalid bytes raise InvalidImageException, not a crash
 */
@RunWith(AndroidJUnit4::class)
class LandmarkExtractorTest {
    private val context: Context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun loadTestImageBytes(): ByteArray =
        javaClass.getResourceAsStream("/test_face.jpg")?.readBytes()
            ?: throw AssertionError("test_face.jpg not found in androidTest resources")

    @Test
    fun extractReturnsExactlyRequiredFaceIndicesWithNormalizedCoordinates() {
        val extractor = LandmarkExtractor.create(context)
        try {
            val payload = extractor.extract(loadTestImageBytes())

            @Suppress("UNCHECKED_CAST")
            val face = payload["face"] as? Map<String, List<Double>>
                ?: throw AssertionError("face map missing")
            @Suppress("UNCHECKED_CAST")
            val pose = payload["pose"] as? Map<String, List<Double>>
                ?: throw AssertionError("pose map missing")
            @Suppress("UNCHECKED_CAST")
            val vis = payload["pose_visibility"] as? Map<String, Double>
                ?: throw AssertionError("visibility map missing")

            if (face.isNotEmpty()) {
                // EXACTLY the 10 required indices — no extras (Dart checks count == 10).
                assertEquals(LandmarkExtractor.FACE_INDICES.toSet(), face.keys.toSet())
                for ((_, point) in face) {
                    assertEquals(2, point.size)
                    assertTrue("face x not in [0,1]: ${point[0]}", point[0] in 0.0..1.0)
                    assertTrue("face y not in [0,1]: ${point[1]}", point[1] in 0.0..1.0)
                }
            }

            // Pose: every returned index must be a required one, visible, normalized.
            for ((key, point) in pose) {
                assertTrue("unexpected pose index $key", key.toInt() in LandmarkExtractor.POSE_INDICES)
                assertEquals(2, point.size)
                assertTrue(point[0] in 0.0..1.0)
                assertTrue(point[1] in 0.0..1.0)
                val v = vis[key]
                assertNotNull("visibility missing for $key", v)
                assertTrue(v!!.toDouble() >= LandmarkExtractor.MIN_POSE_VISIBILITY.toDouble())
            }
            assertEquals(pose.keys, vis.keys)
        } finally {
            extractor.close()
        }
    }

    @Test
    fun invalidImageThrowsInvalidImageExceptionNotCrash() {
        val extractor = LandmarkExtractor.create(context)
        try {
            val garbage = "this is not an image".toByteArray()
            try {
                extractor.extract(garbage)
                fail("expected InvalidImageException")
            } catch (expected: InvalidImageException) {
                // success
            }
        } finally {
            extractor.close()
        }
    }
}
