from face_landmarks import FaceLandmarkExtractor
from pose_landmarks import PoseLandmarkExtractor
from feature_engineering import FeatureEngineer


image_path = "sample.jpg"

face_extractor = FaceLandmarkExtractor()
pose_extractor = PoseLandmarkExtractor()
engineer = FeatureEngineer()

face = face_extractor.extract_from_image(image_path)
pose = pose_extractor.extract_from_image(image_path)

if face is None:
    print("Face not detected")
elif pose is None:
    print("Pose not detected")
else:
    features = engineer.generate_feature_vector(face, pose)
    print(features)