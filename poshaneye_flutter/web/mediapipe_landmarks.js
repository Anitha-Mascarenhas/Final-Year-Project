(() => {
  const packageRoot =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';
  let initialization;
  let faceLandmarker;
  let poseLandmarker;

  function decodeBase64(value) {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  async function initialize(faceModelBase64, poseModelBase64) {
    if (initialization) return initialization;
    initialization = (async () => {
      const vision = await import(`${packageRoot}/vision_bundle.mjs`);
      const files = await vision.FilesetResolver.forVisionTasks(
        `${packageRoot}/wasm`,
      );
      faceLandmarker = await vision.FaceLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetBuffer: decodeBase64(faceModelBase64) },
        runningMode: 'IMAGE',
        numFaces: 1,
        minFaceDetectionConfidence: 0.35,
        minFacePresenceConfidence: 0.35,
      });
      poseLandmarker = await vision.PoseLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetBuffer: decodeBase64(poseModelBase64) },
        runningMode: 'IMAGE',
        numPoses: 1,
        minPoseDetectionConfidence: 0.3,
        minPosePresenceConfidence: 0.3,
      });
    })();
    return initialization;
  }

  async function detect(jpegBase64) {
    await initialization;
    const image = await createImageBitmap(
      new Blob([decodeBase64(jpegBase64)], { type: 'image/jpeg' }),
    );
    try {
      const faceResult = faceLandmarker.detect(image);
      const poseResult = poseLandmarker.detect(image);
      const face = {};
      const pose = {};
      const poseVisibility = {};
      const faceIndices = [234, 454, 10, 152, 33, 263, 61, 291, 127, 356];
      const facePoints = faceResult.faceLandmarks?.[0] ?? [];
      for (const index of faceIndices) {
        const point = facePoints[index];
        if (point) face[index] = [point.x, point.y];
      }
      const posePoints = poseResult.landmarks?.[0] ?? [];
      for (const index of [11, 12, 13, 14, 15, 16]) {
        const point = posePoints[index];
        if (point) {
          pose[index] = [point.x, point.y];
          poseVisibility[index] = point.visibility ?? 0;
        }
      }
      return {
        face,
        pose,
        pose_visibility: poseVisibility,
        image_width: image.width,
        image_height: image.height,
      };
    } finally {
      image.close();
    }
  }

  window.PoshanEyeLandmarks = { initialize, detect };
})();
