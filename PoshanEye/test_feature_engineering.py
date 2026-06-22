from feature_engineering import FeatureEngineer

face = {
    "left_eye": [100, 100],
    "right_eye": [150, 100],
    "mouth_left": [110, 150],
    "mouth_right": [145, 150],
    "chin": [125, 200],
    "left_cheek": [90, 130],
    "right_cheek": [160, 130],
    "forehead": [125, 50],
    "left_jaw": [100, 180],
    "right_jaw": [150, 180]
}

pose = {
    "left_shoulder": [80, 250],
    "right_shoulder": [170, 250],
    "left_elbow": [70, 300],
    "right_elbow": [180, 300],
    "left_wrist": [60, 350],
    "right_wrist": [190, 350]
}

engineer = FeatureEngineer()

features = engineer.generate_feature_vector(face, pose)

print(features)