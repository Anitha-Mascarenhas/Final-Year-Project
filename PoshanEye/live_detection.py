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
    # Status Panel
    # ----------------------------------

    face_status = "Detected" if face_landmarks else "Not Detected"
    pose_status = "Detected" if pose_landmarks else "Not Detected"
    hand_status = "Detected" if hand_landmarks else "Not Detected"

    cv2.rectangle(frame, (10, 10), (360, 230), (0, 0, 0), -1)

    cv2.putText(
        frame,
        "PoshanEye Live Detection",
        (20, 35),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (255, 255, 255),
        2
    )

    cv2.putText(
        frame,
        f"Face: {face_status}",
        (20, 70),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Pose: {pose_status}",
        (20, 100),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (255, 0, 0),
        2
    )

    cv2.putText(
        frame,
        f"Hands: {hand_status}",
        (20, 130),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 255, 255),
        2
    )

    if face_landmarks and "left_cheek" in face_landmarks and "right_cheek" in face_landmarks:
        face_width = abs(
            face_landmarks["left_cheek"][0] -
            face_landmarks["right_cheek"][0]
        )

        cv2.putText(
            frame,
            f"Face Width: {face_width}",
            (20, 170),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 255, 255),
            2
        )

    if face_landmarks and "left_eye" in face_landmarks and "right_eye" in face_landmarks:
        eye_distance = abs(
            face_landmarks["left_eye"][0] -
            face_landmarks["right_eye"][0]
        )

        cv2.putText(
            frame,
            f"Eye Distance: {eye_distance}",
            (20, 200),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 255, 255),
            2
        )

    if pose_landmarks and "left_shoulder" in pose_landmarks and "right_shoulder" in pose_landmarks:
        shoulder_width = abs(
            pose_landmarks["left_shoulder"][0] -
            pose_landmarks["right_shoulder"][0]
        )

        cv2.putText(
            frame,
            f"Shoulder Width: {shoulder_width}",
            (20, 230),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 255, 255),
            2
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