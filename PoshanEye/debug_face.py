print("start")

from face_landmarks import FaceLandmarkExtractor
print("import done")

extractor = FaceLandmarkExtractor()
print("object created")

import cv2
img = cv2.imread("sample.jpg")

print("image loaded", img is not None)

result = extractor.extract_from_frame(img)

print("extraction finished")
print(result)