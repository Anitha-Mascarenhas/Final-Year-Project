import math


class FeatureEngineer:
    def __init__(self):
        pass

    def distance(self, p1, p2):
        return math.sqrt(
            (p2[0] - p1[0]) ** 2 +
            (p2[1] - p1[1]) ** 2
        )

    # ---------------- FACE FEATURES ---------------- #

    def calculate_face_width(self, face):
        return self.distance(
            face["left_cheek"],
            face["right_cheek"]
        )

    def calculate_face_height(self, face):
        return self.distance(
            face["forehead"],
            face["chin"]
        )

    def calculate_eye_distance(self, face):
        return self.distance(
            face["left_eye"],
            face["right_eye"]
        )

    def calculate_mouth_width(self, face):
        return self.distance(
            face["mouth_left"],
            face["mouth_right"]
        )

    def calculate_jaw_width(self, face):
        return self.distance(
            face["left_jaw"],
            face["right_jaw"]
        )

    # ---------------- POSE FEATURES ---------------- #

    def calculate_shoulder_width(self, pose):
        if "left_shoulder" not in pose or "right_shoulder" not in pose:
            return 0

        return self.distance(
            pose["left_shoulder"],
            pose["right_shoulder"]
        )

    def calculate_left_arm_length(self, pose):
        if "left_shoulder" not in pose or "left_elbow" not in pose:
            return 0

        upper = self.distance(
            pose["left_shoulder"],
            pose["left_elbow"]
        )

        if "left_wrist" in pose:
            lower = self.distance(
                pose["left_elbow"],
                pose["left_wrist"]
            )
            return upper + lower

        return upper

    def calculate_right_arm_length(self, pose):
        if "right_shoulder" not in pose or "right_elbow" not in pose:
            return 0

        upper = self.distance(
            pose["right_shoulder"],
            pose["right_elbow"]
        )

        if "right_wrist" in pose:
            lower = self.distance(
                pose["right_elbow"],
                pose["right_wrist"]
            )
            return upper + lower

        return upper

    # ---------------- RATIOS ---------------- #

    def calculate_face_ratio(self, face):
        width = self.calculate_face_width(face)
        height = self.calculate_face_height(face)

        if height == 0:
            return 0

        return width / height

    def calculate_eye_ratio(self, face):
        eye_distance = self.calculate_eye_distance(face)
        face_width = self.calculate_face_width(face)

        if face_width == 0:
            return 0

        return eye_distance / face_width

    def calculate_mouth_ratio(self, face):
        mouth_width = self.calculate_mouth_width(face)
        face_width = self.calculate_face_width(face)

        if face_width == 0:
            return 0

        return mouth_width / face_width

    # ---------------- FINAL FEATURE VECTOR ---------------- #

    def generate_feature_vector(self, face, pose):
        features = {
            "face_width": self.calculate_face_width(face),
            "face_height": self.calculate_face_height(face),
            "eye_distance": self.calculate_eye_distance(face),
            "mouth_width": self.calculate_mouth_width(face),
            "jaw_width": self.calculate_jaw_width(face),
            "shoulder_width": self.calculate_shoulder_width(pose),
            "left_arm_length": self.calculate_left_arm_length(pose),
            "right_arm_length": self.calculate_right_arm_length(pose),
            "face_ratio": self.calculate_face_ratio(face),
            "eye_ratio": self.calculate_eye_ratio(face),
            "mouth_ratio": self.calculate_mouth_ratio(face)
        }

        return features