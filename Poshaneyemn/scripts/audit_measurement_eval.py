import sys
from pathlib import Path

sys.path.append('src')

from data_loader import DatasetLoader
from preprocessing import DataPreprocessor
from features import MeasurementFeaturePipeline
from sklearn.model_selection import train_test_split
from config import TEST_SIZE, VALIDATION_SIZE, RANDOM_STATE

# Load and preprocess
loader = DatasetLoader()
pre = DataPreprocessor()

anthro = loader.load_anthrovision()
anthro = pre.clean_anthrovision(anthro)
anthro = pre.encode_labels(anthro)

aran = loader.load_aran()
aran = pre.clean_aran(aran)
labeled_aran = None
if pre.target_column in aran.columns:
    labeled_aran = pre.encode_labels(aran)

labeled_dfs = [anthro]
if labeled_aran is not None:
    labeled_dfs.append(labeled_aran)

merged = ( 
    __import__('pandas').concat(labeled_dfs, ignore_index=True, sort=False)
)
merged = merged.drop_duplicates(subset=['image_path'], keep='first').reset_index(drop=True)

# Filter missing image paths
image_paths = merged['image_path'].astype(str).str.strip()
valid_mask = image_paths.apply(lambda p: bool(p) and Path(p).exists())
valid_df = merged[valid_mask].reset_index(drop=True)

total_samples = len(merged)
valid_samples = len(valid_df)
removed_samples = total_samples - valid_samples

print('TOTAL_SAMPLES', total_samples)
print('VALID_SAMPLES', valid_samples)
print('REMOVED_SAMPLES', removed_samples)

# Split into train/val/test
train_val, test = train_test_split(
    valid_df,
    test_size=TEST_SIZE,
    random_state=RANDOM_STATE,
    stratify=valid_df['label'] if 'label' in valid_df.columns else None,
)
val_size = VALIDATION_SIZE / (1.0 - TEST_SIZE)
train, val = train_test_split(
    train_val,
    test_size=val_size,
    random_state=RANDOM_STATE,
    stratify=train_val['label'] if 'label' in train_val.columns else None,
)

print('TRAIN_COUNT', len(train))
print('VALID_COUNT', len(val))
print('TEST_COUNT', len(test))

# Features used
features = MeasurementFeaturePipeline().feature_columns
print('FEATURE_COLUMNS', features)
