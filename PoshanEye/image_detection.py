# Face detection module
# This module contains functions for detecting faces in images
# For uploaded images, it detects the face and returns the bounding box coordinates

# import json
# import pandas as pd

# from extract_landmarks import FaceLandmarkExtractor

# IMAGE_PATH = "data/sample_images/child1.jpg"

# extractor = FaceLandmarkExtractor()

# landmarks = extractor.extract_from_image(
#     IMAGE_PATH
# )

# if landmarks is None:
#     print("No face detected")
#     exit()

# print(landmarks)



# # Visualization Code Here

# import cv2

# image = cv2.imread(IMAGE_PATH)

# for name, coords in landmarks.items():

#     x, y = coords

#     cv2.circle(image, (x, y), 4, (0, 255, 0), -1)

#     cv2.putText(
#         image,
#         name,
#         (x + 5, y - 5),
#         cv2.FONT_HERSHEY_SIMPLEX,
#         0.4,
#         (255, 0, 0),
#         1
#     )

# # Save visualized image
# cv2.imwrite(
#     "outputs/visualized_landmarks.jpg",
#     image
# )

# cv2.imshow("Landmarks", image)

# cv2.waitKey(0)
# cv2.destroyAllWindows()



# # Save JSON

# with open(
#     "outputs/json/image_landmarks.json",
#     "w"
# ) as f:

#     json.dump(
#         landmarks,
#         f,
#         indent=4
#     )

# # Save CSV

# rows = []

# for name, coords in landmarks.items():

#     rows.append(
#         [name, coords[0], coords[1]]
#     )

# df = pd.DataFrame(
#     rows,
#     columns=["landmark", "x", "y"]
# )

# df.to_csv(
#     "outputs/csv/image_landmarks.csv",
#     index=False
# )

# print("Saved")



#==============
#Only Face
#==============

# import cv2
# import json
# import pandas as pd

# from datetime import datetime

# from face_landmarks import FaceLandmarkExtractor

# # ----------------------------------
# # Image Path
# # ----------------------------------

# IMAGE_PATH = "data/sample_images/child1.jpg"

# # ----------------------------------
# # Landmark Extraction
# # ----------------------------------

# extractor = FaceLandmarkExtractor()

# landmarks = extractor.extract_from_image(
#     IMAGE_PATH
# )

# if landmarks is None:

#     print("No face detected")
#     exit()

# print("\nDetected Landmarks:")
# print(landmarks)

# # ----------------------------------
# # Timestamp
# # ----------------------------------

# timestamp = datetime.now().strftime(
#     "%Y%m%d_%H%M%S"
# )

# # ----------------------------------
# # Visualization
# # ----------------------------------

# image = cv2.imread(IMAGE_PATH)

# for name, coords in landmarks.items():

#     x, y = coords

#     cv2.circle(
#         image,
#         (x, y),
#         4,
#         (0, 255, 0),
#         -1
#     )

#     cv2.putText(
#         image,
#         name,
#         (x + 5, y - 5),
#         cv2.FONT_HERSHEY_SIMPLEX,
#         0.4,
#         (255, 0, 0),
#         1
#     )

# # ----------------------------------
# # Save Visualization Image
# # ----------------------------------

# image_path = (
#     f"outputs/visualizations/"
#     f"image_landmarks_{timestamp}.jpg"
# )

# cv2.imwrite(
#     image_path,
#     image
# )

# # ----------------------------------
# # Display Visualization
# # ----------------------------------

# cv2.imshow(
#     "Landmarks",
#     image
# )

# cv2.waitKey(0)

# cv2.destroyAllWindows()

# # ----------------------------------
# # Save JSON
# # ----------------------------------

# json_path = (
#     f"outputs/json/"
#     f"image_landmarks_{timestamp}.json"
# )

# with open(
#     json_path,
#     "w"
# ) as f:

#     json.dump(
#         landmarks,
#         f,
#         indent=4
#     )

# # ----------------------------------
# # Save CSV
# # ----------------------------------

# rows = []

# for name, coords in landmarks.items():

#     rows.append(
#         [name, coords[0], coords[1]]
#     )

# df = pd.DataFrame(
#     rows,
#     columns=[
#         "landmark",
#         "x",
#         "y"
#     ]
# )

# csv_path = (
#     f"outputs/csv/"
#     f"image_landmarks_{timestamp}.csv"
# )

# df.to_csv(
#     csv_path,
#     index=False
# )

# # ----------------------------------
# # Success Message
# # ----------------------------------

# print("\nFiles Saved Successfully")

# print("Visualization :", image_path)
# print("JSON          :", json_path)
# print("CSV           :", csv_path)


#==================
#Face + Pose
#==================

# import cv2
# import json
# import pandas as pd

# from datetime import datetime

# from face_landmarks import FaceLandmarkExtractor
# from pose_landmarks import PoseLandmarkExtractor

# # ----------------------------------
# # Image Path
# # ----------------------------------

# IMAGE_PATH = "data/sample_images/child1.jpg"

# # ----------------------------------
# # Initialize Extractors
# # ----------------------------------

# face_extractor = FaceLandmarkExtractor()

# pose_extractor = PoseLandmarkExtractor()

# # ----------------------------------
# # Extract Landmarks
# # ----------------------------------

# face_landmarks = face_extractor.extract_from_image(
#     IMAGE_PATH
# )

# pose_landmarks = pose_extractor.extract_from_image(
#     IMAGE_PATH
# )

# # ----------------------------------
# # Combined Result
# # ----------------------------------

# result = {
#     "face": face_landmarks,
#     "pose": pose_landmarks
# }

# print("\nDetected Landmarks:\n")

# print(
#     json.dumps(
#         result,
#         indent=4
#     )
# )

# # ----------------------------------
# # Visualization
# # ----------------------------------

# image = cv2.imread(IMAGE_PATH)

# # Face Landmarks

# if face_landmarks:

#     for name, coords in face_landmarks.items():

#         x, y = coords

#         cv2.circle(
#             image,
#             (x, y),
#             4,
#             (0, 255, 0),
#             -1
#         )

#         cv2.putText(
#             image,
#             f"F:{name}",
#             (x + 5, y - 5),
#             cv2.FONT_HERSHEY_SIMPLEX,
#             0.4,
#             (0, 255, 0),
#             1
#         )

# # Pose Landmarks

# if pose_landmarks:

#     for name, coords in pose_landmarks.items():

#         x, y = coords

#         cv2.circle(
#             image,
#             (x, y),
#             4,
#             (255, 0, 0),
#             -1
#         )

#         cv2.putText(
#             image,
#             f"P:{name}",
#             (x + 5, y - 5),
#             cv2.FONT_HERSHEY_SIMPLEX,
#             0.4,
#             (255, 0, 0),
#             1
#         )

# # ----------------------------------
# # Timestamp
# # ----------------------------------

# timestamp = datetime.now().strftime(
#     "%Y%m%d_%H%M%S"
# )

# # ----------------------------------
# # Save Visualization
# # ----------------------------------

# visualization_path = (
#     f"outputs/visualizations/"
#     f"face_pose_{timestamp}.jpg"
# )

# cv2.imwrite(
#     visualization_path,
#     image
# )

# # ----------------------------------
# # Display Visualization
# # ----------------------------------

# cv2.imshow(
#     "Face + Pose Detection",
#     image
# )

# cv2.waitKey(0)

# cv2.destroyAllWindows()

# # ----------------------------------
# # Save JSON
# # ----------------------------------

# json_path = (
#     f"outputs/json/"
#     f"face_pose_{timestamp}.json"
# )

# with open(
#     json_path,
#     "w"
# ) as f:

#     json.dump(
#         result,
#         f,
#         indent=4
#     )

# # ----------------------------------
# # Save CSV
# # ----------------------------------

# rows = []

# # Face

# if face_landmarks:

#     for name, coords in face_landmarks.items():

#         rows.append([
#             f"face_{name}",
#             coords[0],
#             coords[1]
#         ])

# # Pose

# if pose_landmarks:

#     for name, coords in pose_landmarks.items():

#         rows.append([
#             f"pose_{name}",
#             coords[0],
#             coords[1]
#         ])

# df = pd.DataFrame(
#     rows,
#     columns=[
#         "feature",
#         "x",
#         "y"
#     ]
# )

# csv_path = (
#     f"outputs/csv/"
#     f"face_pose_{timestamp}.csv"
# )

# df.to_csv(
#     csv_path,
#     index=False
# )

# # ----------------------------------
# # Success Message
# # ----------------------------------

# print("\nFiles Saved Successfully\n")

# print("Visualization:")
# print(visualization_path)

# print("\nJSON:")
# print(json_path)

# print("\nCSV:")
# print(csv_path)


# ==========================================
# Face + Pose + Hands Detection
# ==========================================
print("Script started")
import cv2
import json
import pandas as pd
import os

from datetime import datetime

from face_landmarks import FaceLandmarkExtractor
from pose_landmarks import PoseLandmarkExtractor
from hand_landmarks import HandLandmarkExtractor

# ----------------------------------
# Image Path
# ----------------------------------

IMAGE_PATH = "D:\Final-Year-Project\PoshanEye\sample.jpg"

# ----------------------------------
# Initialize Extractors
# ----------------------------------

face_extractor = FaceLandmarkExtractor()

pose_extractor = PoseLandmarkExtractor()

hand_extractor = HandLandmarkExtractor()

# ----------------------------------
# Extract Landmarks
# ----------------------------------

face_landmarks = face_extractor.extract_from_image(
    IMAGE_PATH
)
print("Face done")
pose_landmarks = pose_extractor.extract_from_image(
    IMAGE_PATH
)
print("pose done")
hand_landmarks = hand_extractor.extract_from_image(
    IMAGE_PATH
)
print("hand done")
# ----------------------------------
# Metadata
# ----------------------------------

image_name = os.path.basename(
    IMAGE_PATH
)

timestamp_iso = datetime.now().isoformat()

timestamp_file = datetime.now().strftime(
    "%Y%m%d_%H%M%S"
)

# ----------------------------------
# Combined Result
# ----------------------------------

result = {

    "image_name": image_name,

    "timestamp": timestamp_iso,

    "face": face_landmarks,

    "pose": pose_landmarks,

    "hands": hand_landmarks
}

# ----------------------------------
# Print Result
# ----------------------------------

print("\nDetected Landmarks:\n")

print(
    json.dumps(
        result,
        indent=4
    )
)

# ----------------------------------
# Visualization
# ----------------------------------

image = cv2.imread(
    IMAGE_PATH
)

# ----------------------------------
# Face Landmarks
# Green
# ----------------------------------

if face_landmarks:

    for name, coords in face_landmarks.items():

        x, y = coords

        cv2.circle(
            image,
            (x, y),
            4,
            (0, 255, 0),
            -1
        )

        cv2.putText(
            image,
            f"F:{name}",
            (x + 5, y - 5),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.4,
            (0, 255, 0),
            1
        )

# ----------------------------------
# Pose Landmarks
# Blue
# ----------------------------------

if pose_landmarks:

    for name, coords in pose_landmarks.items():

        x, y = coords

        cv2.circle(
            image,
            (x, y),
            4,
            (255, 0, 0),
            -1
        )

        cv2.putText(
            image,
            f"P:{name}",
            (x + 5, y - 5),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.4,
            (255, 0, 0),
            1
        )

# ----------------------------------
# Hand Landmarks
# Yellow
# ----------------------------------

if hand_landmarks:

    for hand_name, hand_points in hand_landmarks.items():

        for landmark_name, coords in hand_points.items():

            x, y = coords

            cv2.circle(
                image,
                (x, y),
                4,
                (0, 255, 255),
                -1
            )

            cv2.putText(
                image,
                f"H:{landmark_name}",
                (x + 5, y - 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.4,
                (0, 255, 255),
                1
            )

# ----------------------------------
# Save Visualization
# ----------------------------------

visualization_path = (
    f"outputs/visualizations/"
    f"face_pose_hand_{timestamp_file}.jpg"
)

cv2.imwrite(
    visualization_path,
    image
)

# ----------------------------------
# Display Visualization
# ----------------------------------
print("Visualization ready")
# cv2.imshow(
#     "PoshanEye Detection",
#     image
# )

# cv2.waitKey(0)

# cv2.destroyAllWindows()

# ----------------------------------
# Save JSON
# ----------------------------------

json_path = (
    f"outputs/json/"
    f"face_pose_hand_{timestamp_file}.json"
)

with open(
    json_path,
    "w"
) as f:

    json.dump(
        result,
        f,
        indent=4
    )

# ----------------------------------
# Save CSV
# ----------------------------------

rows = []

# Face

if face_landmarks:

    for name, coords in face_landmarks.items():

        rows.append([
            image_name,
            timestamp_iso,
            "face",
            name,
            coords[0],
            coords[1]
        ])

# Pose

if pose_landmarks:

    for name, coords in pose_landmarks.items():

        rows.append([
            image_name,
            timestamp_iso,
            "pose",
            name,
            coords[0],
            coords[1]
        ])

# Hands

if hand_landmarks:

    for hand_name, hand_points in hand_landmarks.items():

        for name, coords in hand_points.items():

            rows.append([
                image_name,
                timestamp_iso,
                hand_name,
                name,
                coords[0],
                coords[1]
            ])

df = pd.DataFrame(
    rows,
    columns=[
        "image_name",
        "timestamp",
        "category",
        "landmark",
        "x",
        "y"
    ]
)

csv_path = (
    f"outputs/csv/"
    f"face_pose_hand_{timestamp_file}.csv"
)

df.to_csv(
    csv_path,
    index=False
)

# ----------------------------------
# Success Message
# ----------------------------------

print("\nFiles Saved Successfully\n")

print("Visualization:")
print(visualization_path)

print("\nJSON:")
print(json_path)

print("\nCSV:")
print(csv_path)