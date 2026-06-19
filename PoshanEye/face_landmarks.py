# Extract landmarks from facial images
# This module contains functions to extract facial landmarks

#This file contains reusable functions for:
#Image file
#Webcam frame
#Future Flutter image

import cv2
import mediapipe as mp

mp_face_mesh = mp.solutions.face_mesh


class FaceLandmarkExtractor:

    def __init__(self):

        self.face_mesh = mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

    

    #     self.landmark_ids = {
    #     "left_eye": 33,
    #     "right_eye": 263,

    #     "nose": 1,

    #     "mouth_left": 61,
    #     "mouth_right": 291,

    #     "chin": 152,

    #     "left_cheek": 234,
    #     "right_cheek": 454,

    #     "forehead": 10,

    #     "left_jaw": 172,
    #     "right_jaw": 397
    # }


        self.landmark_ids = {

        # Swapped to match Pose convention

        "left_eye": 263,
        "right_eye": 33,

        "nose": 1,

        "mouth_left": 291,
        "mouth_right": 61,

        "chin": 152,

        "left_cheek": 454,
        "right_cheek": 234,

        "forehead": 10,

        "left_jaw": 397,
        "right_jaw": 172
    }

    def extract_from_frame(self, frame):

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        h, w, _ = frame.shape

        results = self.face_mesh.process(rgb)

        if not results.multi_face_landmarks:
            return None

        face = results.multi_face_landmarks[0]

        landmarks = {}

        for name, idx in self.landmark_ids.items():

            point = face.landmark[idx]

            x = int(point.x * w)
            y = int(point.y * h)

            landmarks[name] = [x, y]

        return landmarks

    def extract_from_image(self, image_path):

        image = cv2.imread(image_path)

        if image is None:
            raise ValueError(
                f"Cannot load image: {image_path}"
            )

        return self.extract_from_frame(image)