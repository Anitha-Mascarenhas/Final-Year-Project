# PoshanEye AIML Pipeline

PoshanEye is an AI-powered child malnutrition detection system. This repository contains a production-quality, modular machine learning pipeline designed to integrate with an existing Computer Vision module and a Flutter frontend.

## Architecture

- `src/`
  - `config.py` — global paths, dataset constants, and training defaults
  - `data_loader.py` — AnthroVision, ARAN, and computer vision feature ingestion
  - `preprocessing.py` — dataset cleaning, encoding, and train/validation/test splitting
  - `features.py` — reusable measurement, CV feature, and image preprocessing pipelines
  - `measurement_models.py` — Random Forest, XGBoost, LightGBM, and MLP baselines
  - `image_model.py` — MobileNetV2 transfer learning image branch
  - `hybrid_model.py` — multimodal fusion model for image + measurements + CV features
  - `evaluation.py` — metric calculation, confusion matrix, training curve charts, and reports
  - `predictor.py` — inference utilities and TFLite wrapper
  - `tf_data.py` — TensorFlow dataset builders for image and hybrid training
  - `serving.py` — export utilities for Flutter and label map generation
  - `train.py` — pipeline orchestration entrypoint
  - `utils.py` — helpers for path normalization, serialization, and directory creation

## Installation

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Training

```bash
python src\train.py --cv-features-csv dataset\cv_features.csv
```

If a computer vision features file is not available yet, omit `--cv-features-csv`. The system will still train the measurement and image branches.

## Output

- `models/` — saved model artifacts and pipelines
- `outputs/` — evaluation metrics, visualizations, and label maps
- `outputs/label_map.json` — class id to name mapping for Flutter inference
- `models/best_model.tflite` — exported TFLite model for mobile deployment

## Supported modalities

- raw images
- anthropometric measurements
- engineered computer vision features

## Requirements

See `requirements.txt` for package dependencies.
