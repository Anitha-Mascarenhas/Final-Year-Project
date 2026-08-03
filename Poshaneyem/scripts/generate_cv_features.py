from __future__ import annotations

from pathlib import Path
import math
import sys
import time

import cv2
import pandas as pd

try:
    import mediapipe as mp
except ImportError as exc:
    raise ImportError(
        "mediapipe is required to generate CV landmark features. Install it using `python -m pip install mediapipe==0.10.13` on Python 3.11 or earlier."
    ) from exc

if not hasattr(mp, "solutions"):
    raise ImportError(
        "Installed mediapipe does not expose mp.solutions. "
        "Use a Solutions-compatible MediaPipe release, e.g. `pip install mediapipe==0.10.13`, "
        "and run it under Python 3.11 or 3.10."
    )


REQUIRED_COLUMNS = [
    "image_name",
    "face_width",
    "face_height",
    "eye_distance",
    "mouth_width",
    "jaw_width",
    "shoulder_width",
    "left_arm_length",
    "right_arm_length",
    "face_ratio",
    "eye_ratio",
    "mouth_ratio",
]

FACE_LANDMARKS = {
    "left_face": 234,
    "right_face": 454,
    "forehead": 10,
    "chin": 152,
    "left_eye": 33,
    "right_eye": 263,
    "mouth_left": 61,
    "mouth_right": 291,
    "left_jaw": 127,
    "right_jaw": 356,
}

POSE_LANDMARKS = {
    "left_shoulder": 11,
    "right_shoulder": 12,
    "left_elbow": 13,
    "right_elbow": 14,
    "left_wrist": 15,
    "right_wrist": 16,
}


def euclidean_distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.dist(a, b)


def compute_features(face_landmarks, pose_landmarks, image_shape: tuple[int, int]) -> dict[str, float] | None:
    height, width = image_shape

    def get_point(landmarks, index: int, check_visibility: bool) -> tuple[float, float] | None:
        if index < 0 or index >= len(landmarks.landmark):
            return None
        lm = landmarks.landmark[index]
        if check_visibility and lm.visibility is not None and lm.visibility < 0.2:
            return None
        return (lm.x * width, lm.y * height)

    face_points: dict[str, tuple[float, float]] = {}
    for name, idx in FACE_LANDMARKS.items():
        point = get_point(face_landmarks, idx, check_visibility=False)
        if point is None:
            return None
        face_points[name] = point

    pose_points: dict[str, tuple[float, float]] = {}
    for name, idx in POSE_LANDMARKS.items():
        point = get_point(pose_landmarks, idx, check_visibility=True)
        if point is None:
            return None
        pose_points[name] = point

    face_width = euclidean_distance(face_points["left_face"], face_points["right_face"])
    face_height = euclidean_distance(face_points["forehead"], face_points["chin"])
    eye_distance = euclidean_distance(face_points["left_eye"], face_points["right_eye"])
    mouth_width = euclidean_distance(face_points["mouth_left"], face_points["mouth_right"])
    jaw_width = euclidean_distance(face_points["left_jaw"], face_points["right_jaw"])
    shoulder_width = euclidean_distance(pose_points["left_shoulder"], pose_points["right_shoulder"])

    left_arm_length = euclidean_distance(pose_points["left_shoulder"], pose_points["left_elbow"])
    left_arm_length += euclidean_distance(pose_points["left_elbow"], pose_points["left_wrist"])
    right_arm_length = euclidean_distance(pose_points["right_shoulder"], pose_points["right_elbow"])
    right_arm_length += euclidean_distance(pose_points["right_elbow"], pose_points["right_wrist"])

    if face_height == 0 or face_width == 0:
        return None

    return {
        "face_width": face_width,
        "face_height": face_height,
        "eye_distance": eye_distance,
        "mouth_width": mouth_width,
        "jaw_width": jaw_width,
        "shoulder_width": shoulder_width,
        "left_arm_length": left_arm_length,
        "right_arm_length": right_arm_length,
        "face_ratio": face_width / face_height,
        "eye_ratio": eye_distance / face_width,
        "mouth_ratio": mouth_width / face_width,
    }


def is_frontal_image(path: Path) -> bool:
    return "frontal" in path.name.lower()


def is_back_image(path: Path) -> bool:
    return "back" in path.name.lower()


def find_images(root: Path) -> list[Path]:
    all_images = sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png"}
    )
    frontal_images = [path for path in all_images if is_frontal_image(path)]
    back_images = [path for path in all_images if not is_frontal_image(path) and is_back_image(path)]
    other_images = [path for path in all_images if not is_frontal_image(path) and not is_back_image(path)]
    return frontal_images + back_images + other_images


def main() -> None:
    dataset_root = Path(__file__).resolve().parent.parent / "dataset" / "ANTHROVISION"
    output_path = Path(__file__).resolve().parent.parent / "dataset" / "cv_features.csv"

    image_paths = find_images(dataset_root)
    total_images = len(image_paths)
    print(f"Total images: {total_images}")

    mp_holistic = mp.solutions.holistic
    results = []
    processed = 0
    skipped = 0
    start_time = time.time()

    def _format_rate(count: int, elapsed: float) -> float:
        return count / elapsed if elapsed > 0 else 0.0

    def _format_eta(processed_count: int, elapsed: float, total_count: int) -> float:
        if processed_count == 0 or elapsed <= 0:
            return float("inf")
        rate = processed_count / elapsed
        remaining = total_count - processed_count
        return remaining / rate

    def _save_checkpoint(rows: list[dict[str, float]]) -> None:
        checkpoint_df = pd.DataFrame(rows, columns=REQUIRED_COLUMNS)
        checkpoint_df.to_csv(output_path, index=False)

    # Use the faster Holistic configuration without refined face landmarks.
    # This preserves the existing feature extraction logic but improves speed
    # because the pipeline does not require iris or refined face landmarks.
    with mp_holistic.Holistic(
        static_image_mode=True,
        model_complexity=1,
        refine_face_landmarks=False,
    ) as holistic:
        for idx, image_path in enumerate(image_paths, start=1):
            if idx % 50 == 0:
                # Report liveness and visited count before inference every 50 images.
                print(f"Processing image {idx}/{total_images}...")

            try:
                image = cv2.imread(str(image_path))
                if image is None:
                    skipped += 1
                    continue

                image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                res = holistic.process(image_rgb)
                if res.face_landmarks is None:
                    print(f"[DEBUG] No face landmarks: {image_path.name}")
                    skipped += 1
                    continue
                if res.pose_landmarks is None:
                    print(f"[DEBUG] No pose landmarks: {image_path.name}")
                    skipped += 1
                    continue

                feature_values = compute_features(res.face_landmarks, res.pose_landmarks, image.shape[:2])
                if feature_values is None:
                    print(f"[DEBUG] compute_features returned None: {image_path.name}")
                    skipped += 1
                    continue

                results.append({"image_name": image_path.name, **feature_values})
                processed += 1
                print(f"[SUCCESS] {processed}: {image_path.name}")

                if idx % 500 == 0:
                    elapsed = time.time() - start_time
                    images_per_sec = _format_rate(idx, elapsed)
                    eta_seconds = _format_eta(idx, elapsed, total_images)
                    print("------------------------------------------------")
                    print(f"Visited: {idx}/{total_images}")
                    print(f"Processed: {processed}")
                    print(f"Skipped: {skipped}")
                    print(f"Images/sec: {images_per_sec:.2f}")
                    print(f"ETA: {eta_seconds / 60:.1f} min")
                    print("------------------------------------------------")
                elif idx % 50 == 0:
                    print("------------------------------------------------")
                    print(f"Visited: {idx}/{total_images}")
                    print(f"Processed: {processed}")
                    print(f"Skipped: {skipped}")
                    print("------------------------------------------------")

                if processed % 500 == 0:
                    _save_checkpoint(results)

            except Exception as exc:
                skipped += 1
                print(f"[ERROR] {image_path.name}: {exc}")
                continue

    # Final checkpoint to ensure latest results are saved.
    _save_checkpoint(results)

    elapsed_total = time.time() - start_time
    average_rate = _format_rate(processed, elapsed_total)

    df = pd.DataFrame(results, columns=REQUIRED_COLUMNS)
    df.to_csv(output_path, index=False)

    print("\nFinal summary:")
    print(f"  Total images: {total_images}")
    print(f"  Successfully processed: {processed}")
    print(f"  Skipped: {skipped}")
    print(f"  Total execution time: {elapsed_total:.2f} sec")
    print(f"  Average speed: {average_rate:.2f} img/s")
    print(f"  Output file: {output_path}")


if __name__ == "__main__":
    main()
