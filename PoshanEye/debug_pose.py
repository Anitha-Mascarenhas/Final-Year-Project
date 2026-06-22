print("start")

from pose_landmarks import PoseLandmarkExtractor
print("import done")

extractor = PoseLandmarkExtractor()
print("object created")

import cv2
img = cv2.imread("sample.jpg")

print("image loaded", img is not None)

result = extractor.extract_from_frame(img)

print("extraction finished")
print(result)