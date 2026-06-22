print("start")

from hand_landmarks import HandLandmarkExtractor
print("import done")

extractor = HandLandmarkExtractor()
print("object created")

import cv2
img = cv2.imread("sample.jpg")

print("image loaded", img is not None)

result = extractor.extract_from_frame(img)

print("extraction finished")
print(result)