import cv2
import mediapipe as mp

mp_hands = mp.solutions.hands


class HandLandmarkExtractor:

    def __init__(self):

        self.hands = mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=2,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

        self.landmark_ids = {

            "thumb_mcp": 2,
            "thumb_tip": 4,

            "index_mcp": 5,
            "index_tip": 8,

            "middle_mcp": 9,
            "middle_tip": 12,

            "ring_mcp": 13,
            "ring_tip": 16,

            "pinky_mcp": 17,
            "pinky_tip": 20
        }

    def extract_from_frame(self, frame):

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        h, w, _ = frame.shape

        results = self.hands.process(rgb)

        if not results.multi_hand_landmarks:
            return {}

        hands_data = {}

        for hand_landmarks, handedness in zip(
            results.multi_hand_landmarks,
            results.multi_handedness
        ):

            hand_label = (
                handedness.classification[0]
                .label
                .lower()
            )

            # Swap handedness to match Face + Pose

            if hand_label == "left":
                hand_label = "right"

            elif hand_label == "right":
                hand_label = "left"


            hand_key = f"{hand_label}_hand"

            hand_points = {}

            for name, idx in self.landmark_ids.items():

                point = hand_landmarks.landmark[idx]

                x = int(point.x * w)
                y = int(point.y * h)

                hand_points[name] = [x, y]

            hands_data[hand_key] = hand_points

        return hands_data

    def extract_from_image(self, image_path):

        image = cv2.imread(image_path)

        if image is None:
            raise ValueError(
                f"Cannot load image: {image_path}"
            )

        return self.extract_from_frame(image)