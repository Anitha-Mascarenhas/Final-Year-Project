import cv2
import mediapipe as mp

mp_pose = mp.solutions.pose


class PoseLandmarkExtractor:

    def __init__(self):

        self.pose = mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            smooth_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

        self.landmark_ids = {

            # Upper Body
            "left_shoulder": 11,
            "right_shoulder": 12,

            "left_elbow": 13,
            "right_elbow": 14,

            "left_wrist": 15,
            "right_wrist": 16,

            # Torso
            "left_hip": 23,
            "right_hip": 24,

            # Lower Body
            "left_knee": 25,
            "right_knee": 26,

            "left_ankle": 27,
            "right_ankle": 28,

            
        }

    def extract_from_frame(self, frame):

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        h, w, _ = frame.shape

        results = self.pose.process(rgb)

        if not results.pose_landmarks:
            return None

        pose = results.pose_landmarks.landmark

        landmarks = {}

        for name, idx in self.landmark_ids.items():

            point = pose[idx]

            # Skip landmarks with low visibility

            if point.visibility < 0.6:
                continue

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

    def get_raw_pose(self, frame):

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        results = self.pose.process(rgb)

        return results