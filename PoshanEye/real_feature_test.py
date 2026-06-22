from face_landmarks import FaceLandmarkExtractor
from pose_landmarks import PoseLandmarkExtractor
from feature_engineering import FeatureEngineer

IMAGE_PATH = "D:\Final-Year-Project\PoshanEye\sample.jpg"

face_extractor = FaceLandmarkExtractor()
pose_extractor = PoseLandmarkExtractor()
engineer = FeatureEngineer()

face = face_extractor.extract_from_image(IMAGE_PATH)
pose = pose_extractor.extract_from_image(IMAGE_PATH)

features = engineer.generate_feature_vector(face, pose)

print("\nFEATURE VECTOR:")
print(features)