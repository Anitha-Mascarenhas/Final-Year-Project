# Child-level balanced binary image experiment (AnthroVision only)

Isolated experiment. **Nothing under `models/`, `src/`, the Flutter app or the backend is
touched.** Every file this experiment writes lives under
`experiments/image_model_binary_child_level/`.

## The question

The 4-class image model (69% accuracy, 0% minority recall in production) and the
class-balanced 4-class retrain (50% accuracy) both mixed several photos of *the same
child* across train and test, and both trained on a 1659:89 class ratio. This experiment
removes both confounds:

* **The child is the unit of splitting.** Every view of a child (`frontal1..4`, `back`,
  `lateralleft`, `lateralright`, `selfie`) stays in one split. Child overlap between
  train/validation/test is asserted to be zero, and the run aborts otherwise.
* **The two classes contain an equal number of children.** All malnourished children are
  kept and an equal number of healthy children is sampled once (seed 42). No child is
  duplicated, no child is synthesised, nothing is oversampled.

## Labels

| | definition |
|---|---|
| `healthy` | AnthroVision `multiclass_label == "healthy"` |
| `malnourished` | `multiclass_label in {underweight, stunted, stunted and underweight}` |

The three original subgroups are retained for the held-out analysis, so the report shows
recall for `underweight`, `stunted` and `stunted and underweight` separately.

## Child identity

The child key is the CSV `tag`. Two tags (`1044`, `1045`) appear twice with different
anthropometry **and** different photos, i.e. two different children sharing an id; each
row is therefore kept as its own child (`1044#1`, `1044#2`, ...). Verified independently:
the measurements of the two rows for those tags do not match each other.

## Pipeline

1. `DatasetLoader.load_anthrovision()` resolves all eight view columns to real files;
   rows with no usable image are dropped (2,141 children of 2,389 rows have photos).
2. Balance on children, split 70/15/15 stratified by binary label (`seed 42`).
3. Decode all images once into a uint8 cache (`cache/`) so epochs are not JPEG-bound.
4. Train MobileNetV2 (ImageNet, **frozen** base, dropout 0.3, dense 128, sigmoid) with
   `preprocess_input` ([-1, 1]), Adam 1e-4, batch 32.
5. Augmentation on **training images only**: horizontal flip, contrast 0.1, translation
   0.05, zoom 0.05. Validation/test images are never augmented.
6. `class_weight` is computed with `compute_class_weight('balanced', ...)` from the
   training children only. On this balanced dataset it lands at ~1.0 by construction, so
   the balancing comes from the dataset rather than from the loss -- weights alone are
   not relied on.
7. Early stopping (val_loss, patience 5), LR reduction (patience 3, factor 0.5) and a
   per-epoch checkpoint. Model selection = **validation balanced accuracy** among epochs
   that keep healthy recall >= 0.5, so no epoch can win by predicting one class.
8. Export TFLite and score the held-out children with both the Keras model and the TFLite
   interpreter as a consistency check.

The run is resumable: every epoch appends to `artifacts/epoch_history.json` and saves
`artifacts/last.keras`, so an interrupted run continues with `--resume`.

## Metrics

Reported at two levels, because with eight views per child an image-level number
double-counts children:

* **image level** -- every view is a sample (comparable with the previous experiments)
* **child level** -- a child's view probabilities are averaged first, then the child is
  classified (the honest number for a screening decision)

## Usage

```powershell
cd D:\Final-Year-Project\Poshaneyemn
..\.venv\Scripts\python.exe experiments\image_model_binary_child_level\run_experiment.py
..\.venv\Scripts\python.exe experiments\image_model_binary_child_level\run_experiment.py --smoke
..\.venv\Scripts\python.exe experiments\image_model_binary_child_level\run_experiment.py --resume
..\.venv\Scripts\python.exe experiments\image_model_binary_child_level\run_experiment.py --max-views 3
```

## Outputs

| Path | Contents |
|---|---|
| `results/final_report.md` | full report: counts, metrics, confusion matrices, subgroup recall |
| `results/binary_child_level_metrics.json` | every number, plus the per-epoch history |
| `results/per_subgroup_test_metrics.csv` | recall per original malnutrition subgroup |
| `results/confusion_matrices/*.txt` | image-level (Keras + TFLite) and child-level matrices |
| `artifacts/split_children.json` | the exact children, labels, subgroups and images per split |
| `artifacts/binary_child_level.tflite` | exported experiment model (never production) |
| `artifacts/epoch_history.json` | per-epoch metrics (resume state) |

## What this experiment can and cannot show

**Can show:** whether the image branch contains *any* learnable signal for the
healthy-vs-malnourished distinction once child leakage and class imbalance are removed.

**Cannot show:** clinical validity. The `malnourished` target is still the AnthroVision
anthropometric label definition (the WHO `hfa`/`wfa` z-score rule supplied in the CSV),
not an independent clinician assessment. Good performance would mean the photos correlate
with that label definition, not that the model diagnoses malnutrition. `stunted` is by far
the smallest subgroup, so its per-subgroup recall is the noisiest number in the report.
