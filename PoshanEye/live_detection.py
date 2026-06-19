# For webcam testing.

# import cv2

# from extract_landmarks import FaceLandmarkExtractor

# extractor = FaceLandmarkExtractor()

# cap = cv2.VideoCapture(0)

# while True:

#     success, frame = cap.read()

#     if not success:
#         break

#     landmarks = extractor.extract_from_frame(
#         frame
#     )

#     if landmarks:

#         for name, coords in landmarks.items():

#             x, y = coords

#             cv2.circle(
#                 frame,
#                 (x, y),
#                 5,
#                 (0, 255, 0),
#                 -1
#             )

#             cv2.putText(
#                 frame,
#                 name,
#                 (x + 5, y - 5),
#                 cv2.FONT_HERSHEY_SIMPLEX,
#                 0.4,
#                 (255, 0, 0),
#                 1
#             )

#     cv2.imshow(
#         "PoshanEye Live Detection",
#         frame
#     )

#     key = cv2.waitKey(1)

#     if key == 27:
#         break

# cap.release()
# cv2.destroyAllWindows()


#==================
#Face landmark
#==================


# import cv2
# import json
# import pandas as pd

# from datetime import datetime

# from face_landmarks import FaceLandmarkExtractor

# extractor = FaceLandmarkExtractor()

# cap = cv2.VideoCapture(0)

# print("Press S to save output")
# print("Press ESC to exit")

# while True:

#     success, frame = cap.read()

#     if not success:
#         break

#     landmarks = extractor.extract_from_frame(frame)

#     if landmarks:

#         for name, coords in landmarks.items():

#             x, y = coords

#             cv2.circle(
#                 frame,
#                 (x, y),
#                 5,
#                 (0, 255, 0),
#                 -1
#             )

#             cv2.putText(
#                 frame,
#                 name,
#                 (x + 5, y - 5),
#                 cv2.FONT_HERSHEY_SIMPLEX,
#                 0.4,
#                 (255, 0, 0),
#                 1
#             )

#     cv2.imshow(
#         "PoshanEye Live Detection",
#         frame
#     )

#     key = cv2.waitKey(1) & 0xFF

#     # -----------------------------
#     # Save Output When S Pressed
#     # -----------------------------
#     if key == ord("s"):

#         if landmarks is None:
#             print("No face detected")
#             continue

#         timestamp = datetime.now().strftime(
#             "%Y%m%d_%H%M%S"
#         )

#         # Save visualization image
#         image_path = (
#             f"outputs/visualizations/"
#             f"capture_{timestamp}.jpg"
#         )

#         cv2.imwrite(
#             image_path,
#             frame
#         )

#         # Save JSON
#         json_path = (
#             f"outputs/json/"
#             f"capture_{timestamp}.json"
#         )

#         with open(json_path, "w") as f:

#             json.dump(
#                 landmarks,
#                 f,
#                 indent=4
#             )

#         # Save CSV
#         rows = []

#         for name, coords in landmarks.items():

#             rows.append(
#                 [name, coords[0], coords[1]]
#             )

#         df = pd.DataFrame(
#             rows,
#             columns=["landmark", "x", "y"]
#         )

#         csv_path = (
#             f"outputs/csv/"
#             f"capture_{timestamp}.csv"
#         )

#         df.to_csv(
#             csv_path,
#             index=False
#         )

#         print("\nSaved Successfully")
#         print("Image :", image_path)
#         print("JSON  :", json_path)
#         print("CSV   :", csv_path)
#         print()

#     # ESC key
#     if key == 27:
#         break

# cap.release()
# cv2.destroyAllWindows()

#=================
#Face + Pose landmarks
#=================

# import cv2
# import json
# import pandas as pd

# from datetime import datetime

# from face_landmarks import FaceLandmarkExtractor
# from pose_landmarks import PoseLandmarkExtractor

# # ----------------------------------
# # Initialize Extractors
# # ----------------------------------

# face_extractor = FaceLandmarkExtractor()

# pose_extractor = PoseLandmarkExtractor()

# # ----------------------------------
# # Webcam
# # ----------------------------------

# cap = cv2.VideoCapture(0)

# print("Press S to save output")
# print("Press ESC to exit")

# while True:

#     success, frame = cap.read()

#     if not success:
#         break

#     # -----------------------------
#     # Extract Landmarks
#     # -----------------------------

#     face_landmarks = face_extractor.extract_from_frame(
#         frame
#     )

#     pose_landmarks = pose_extractor.extract_from_frame(
#         frame
#     )

#     # -----------------------------
#     # Draw Face Landmarks
#     # -----------------------------

#     if face_landmarks:

#         for name, coords in face_landmarks.items():

#             x, y = coords

#             cv2.circle(
#                 frame,
#                 (x, y),
#                 5,
#                 (0, 255, 0),
#                 -1
#             )

#             cv2.putText(
#                 frame,
#                 f"F:{name}",
#                 (x + 5, y - 5),
#                 cv2.FONT_HERSHEY_SIMPLEX,
#                 0.4,
#                 (0, 255, 0),
#                 1
#             )

#     # -----------------------------
#     # Draw Pose Landmarks
#     # -----------------------------

#     if pose_landmarks:

#         for name, coords in pose_landmarks.items():

#             x, y = coords

#             cv2.circle(
#                 frame,
#                 (x, y),
#                 5,
#                 (255, 0, 0),
#                 -1
#             )

#             cv2.putText(
#                 frame,
#                 f"P:{name}",
#                 (x + 5, y - 5),
#                 cv2.FONT_HERSHEY_SIMPLEX,
#                 0.4,
#                 (255, 0, 0),
#                 1
#             )

#     # -----------------------------
#     # Display Frame
#     # -----------------------------

#     cv2.imshow(
#         "PoshanEye Face + Pose Detection",
#         frame
#     )

#     key = cv2.waitKey(1) & 0xFF

#     # -----------------------------
#     # Save Output
#     # -----------------------------

#     if key == ord("s"):

#         if face_landmarks is None and pose_landmarks is None:

#             print("No landmarks detected")
#             continue

#         timestamp = datetime.now().strftime(
#             "%Y%m%d_%H%M%S"
#         )

#         # -------------------------
#         # Combined Result
#         # -------------------------

#         result = {

#             "face": face_landmarks,

#             "pose": pose_landmarks
#         }

#         # -------------------------
#         # Save Visualization
#         # -------------------------

#         image_path = (
#             f"outputs/visualizations/"
#             f"capture_face_pose_{timestamp}.jpg"
#         )

#         cv2.imwrite(
#             image_path,
#             frame
#         )

#         # -------------------------
#         # Save JSON
#         # -------------------------

#         json_path = (
#             f"outputs/json/"
#             f"capture_face_pose_{timestamp}.json"
#         )

#         with open(json_path, "w") as f:

#             json.dump(
#                 result,
#                 f,
#                 indent=4
#             )

#         # -------------------------
#         # Save CSV
#         # -------------------------

#         rows = []

#         if face_landmarks:

#             for name, coords in face_landmarks.items():

#                 rows.append(
#                     [
#                         f"face_{name}",
#                         coords[0],
#                         coords[1]
#                     ]
#                 )

#         if pose_landmarks:

#             for name, coords in pose_landmarks.items():

#                 rows.append(
#                     [
#                         f"pose_{name}",
#                         coords[0],
#                         coords[1]
#                     ]
#                 )

#         df = pd.DataFrame(
#             rows,
#             columns=[
#                 "feature",
#                 "x",
#                 "y"
#             ]
#         )

#         csv_path = (
#             f"outputs/csv/"
#             f"capture_face_pose_{timestamp}.csv"
#         )

#         df.to_csv(
#             csv_path,
#             index=False
#         )

#         print("\nSaved Successfully\n")

#         print("Visualization:")
#         print(image_path)

#         print("\nJSON:")
#         print(json_path)

#         print("\nCSV:")
#         print(csv_path)

#         print()

#     # -----------------------------
#     # Exit
#     # -----------------------------

#     if key == 27:
#         break

# cap.release()

# cv2.destroyAllWindows()

# # ----------------------------------
# # Success Message
# # ----------------------------------

# print("\nFiles Saved Successfully\n")

# print("Visualization:")
# print(image_path)

# print("\nJSON:")
# print(json_path)

# print("\nCSV:")
# print(csv_path)


# ==========================================
# Face + Pose + Hands Live Detection
# ==========================================

import cv2
import json
import pandas as pd

from datetime import datetime

from face_landmarks import FaceLandmarkExtractor
from pose_landmarks import PoseLandmarkExtractor
from hand_landmarks import HandLandmarkExtractor

# ----------------------------------
# Initialize Extractors
# ----------------------------------

face_extractor = FaceLandmarkExtractor()

pose_extractor = PoseLandmarkExtractor()

hand_extractor = HandLandmarkExtractor()

# ----------------------------------
# Webcam
# ----------------------------------

cap = cv2.VideoCapture(0)

print("Press S to save output")
print("Press ESC to exit")

while True:

    success, frame = cap.read()

    if not success:
        break

    # ----------------------------------
    # Extract Landmarks
    # ----------------------------------

    face_landmarks = face_extractor.extract_from_frame(
        frame
    )

    pose_landmarks = pose_extractor.extract_from_frame(
        frame
    )

    hand_landmarks = hand_extractor.extract_from_frame(
        frame
    )

    # ----------------------------------
    # Draw Face Landmarks
    # Green
    # ----------------------------------

    if face_landmarks:

        for name, coords in face_landmarks.items():

            x, y = coords

            cv2.circle(
                frame,
                (x, y),
                5,
                (0, 255, 0),
                -1
            )

            cv2.putText(
                frame,
                f"F:{name}",
                (x + 5, y - 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.4,
                (0, 255, 0),
                1
            )

    # ----------------------------------
    # Draw Pose Landmarks
    # Blue
    # ----------------------------------

    if pose_landmarks:

        for name, coords in pose_landmarks.items():

            x, y = coords

            cv2.circle(
                frame,
                (x, y),
                5,
                (255, 0, 0),
                -1
            )

            cv2.putText(
                frame,
                f"P:{name}",
                (x + 5, y - 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.4,
                (255, 0, 0),
                1
            )

    # ----------------------------------
    # Draw Hand Landmarks
    # Yellow
    # ----------------------------------

    if hand_landmarks:

        for hand_name, hand_points in hand_landmarks.items():

            for landmark_name, coords in hand_points.items():

                x, y = coords

                cv2.circle(
                    frame,
                    (x, y),
                    5,
                    (0, 255, 255),
                    -1
                )

                cv2.putText(
                    frame,
                    f"H:{landmark_name}",
                    (x + 5, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.4,
                    (0, 255, 255),
                    1
                )

    # ----------------------------------
    # Display Frame
    # ----------------------------------

    cv2.imshow(
        "PoshanEye Live Detection",
        frame
    )

    key = cv2.waitKey(1) & 0xFF

    # ----------------------------------
    # Save Output
    # ----------------------------------

    if key == ord("s"):

        if (
            face_landmarks is None
            and pose_landmarks is None
            and not hand_landmarks
        ):
            print("No landmarks detected")
            continue

        timestamp_iso = datetime.now().isoformat()

        timestamp_file = datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )

        # ----------------------------------
        # Combined Result
        # ----------------------------------

        result = {

            "image_name": "webcam_capture",

            "timestamp": timestamp_iso,

            "face": face_landmarks,

            "pose": pose_landmarks,

            "hands": hand_landmarks
        }

        # ----------------------------------
        # Save Visualization
        # ----------------------------------

        image_path = (
            f"outputs/visualizations/"
            f"capture_{timestamp_file}.jpg"
        )

        cv2.imwrite(
            image_path,
            frame
        )

        # ----------------------------------
        # Save JSON
        # ----------------------------------

        json_path = (
            f"outputs/json/"
            f"capture_{timestamp_file}.json"
        )

        with open(json_path, "w") as f:

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
                    "webcam_capture",
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
                    "webcam_capture",
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
                        "webcam_capture",
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
            f"capture_{timestamp_file}.csv"
        )

        df.to_csv(
            csv_path,
            index=False
        )

        print("\nSaved Successfully\n")

        print("Visualization:")
        print(image_path)

        print("\nJSON:")
        print(json_path)

        print("\nCSV:")
        print(csv_path)

        print()

    # ----------------------------------
    # Exit
    # ----------------------------------

    if key == 27:
        break

cap.release()

cv2.destroyAllWindows()