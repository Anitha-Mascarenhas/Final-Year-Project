# MobileNetV2 v2 image-classifier experiment

Isolated experiment. No production file, model artifact, backend file or Flutter
file was modified; everything is written under `experiments/image_model_v2/`.

## Split (project's existing stratified split, RANDOM_STATE=42)

- train: 1391 -- {'healthy': 974, 'stunted': 38, 'stunted and underweight': 148, 'underweight': 231}
- validation: 321 -- {'healthy': 225, 'stunted': 9, 'stunted and underweight': 34, 'underweight': 53}
- test (held out): 429 -- {'healthy': 301, 'stunted': 12, 'stunted and underweight': 45, 'underweight': 71}

Class index order (fitted `LabelEncoder`): ['healthy', 'stunted', 'stunted and underweight', 'underweight']

## Test-set comparison (TFLite interpreters, identical 429-image split)

| Model | Preprocessing | Class weighting | Accuracy | Balanced acc | Macro P | Macro R | Macro F1 | Weighted F1 | Healthy recall |
|---|---|---|---|---|---|---|---|---|---|
| production | div255 | none | 0.6993 | 0.2572 | 0.2701 | 0.2572 | 0.2247 | 0.5898 | 0.9867 |
| v1_balanced_alpha_1.00 | mobilenet | full balanced alpha=1.0 | 0.5012 | 0.2548 | 0.2655 | 0.2548 | 0.2576 | 0.5217 | 0.6478 |
| alpha_0.25 | mobilenet | damped alpha=0.25 | 0.6970 | 0.2483 | 0.1751 | 0.2483 | 0.2054 | 0.5763 | 0.9934 |
| alpha_0.50 | mobilenet | damped alpha=0.5 | 0.6014 | 0.2824 | 0.2789 | 0.2824 | 0.2741 | 0.5787 | 0.8007 |
| alpha_0.75 | mobilenet | damped alpha=0.75 | 0.6084 | 0.2565 | 0.2706 | 0.2565 | 0.2541 | 0.5680 | 0.8306 |

## Per-class recall (test)

| Model | healthy | stunted | stunted and underweight | underweight |
|---|---|---|---|---|
| production | 0.9867 | 0.0000 | 0.0000 | 0.0423 |
| v1_balanced_alpha_1.00 | 0.6478 | 0.0000 | 0.2444 | 0.1268 |
| alpha_0.25 | 0.9934 | 0.0000 | 0.0000 | 0.0000 |
| alpha_0.50 | 0.8007 | 0.0000 | 0.2444 | 0.0845 |
| alpha_0.75 | 0.8306 | 0.0000 | 0.1111 | 0.0845 |

## Confusion matrices (test)

Order: healthy, stunted, stunted and underweight, underweight

**production** (acc 0.6993, macro F1 0.2247)

```
[[297   0   0   4]
 [ 11   0   0   1]
 [ 45   0   0   0]
 [ 68   0   0   3]]
```

**v1_balanced_alpha_1.00** (acc 0.5012, macro F1 0.2576)

```
[[195  30  40  36]
 [  7   0   2   3]
 [ 25   5  11   4]
 [ 47   6   9   9]]
```

**alpha_0.25** (acc 0.6970, macro F1 0.2054)

```
[[299   0   2   0]
 [ 12   0   0   0]
 [ 45   0   0   0]
 [ 71   0   0   0]]
```

**alpha_0.50** (acc 0.6014, macro F1 0.2741)

```
[[241   8  31  21]
 [  9   0   0   3]
 [ 30   3  11   1]
 [ 49   0  16   6]]
```

**alpha_0.75** (acc 0.6084, macro F1 0.2541)

```
[[250   1  12  38]
 [  8   0   0   4]
 [ 33   2   5   5]
 [ 63   0   2   6]]
```

## Arm selection (validation only)

- `alpha_0.25` (alpha=0.25): val macro F1 0.2066, val balanced acc 0.2489, val healthy recall 0.9956 -- best guarded validation macro F1 at epoch 12
- `alpha_0.50` (alpha=0.5): val macro F1 0.2428, val balanced acc 0.2539, val healthy recall 0.8267 -- best guarded validation macro F1 at epoch 6
- `alpha_0.75` (alpha=0.75): val macro F1 0.2287, val balanced acc 0.2405, val healthy recall 0.8489 -- best guarded validation macro F1 at epoch 4

Selected arm by the predefined rule (validation macro F1, healthy-recall floor): **alpha_0.50**.

## Limitations

- The 4-class target (`multiclass_label`) is an anthropometric label definition, not an
  independent clinical diagnosis, and the class `stunted` has only 12 held-out images. Its
  recall is dominated by small-sample noise and cannot be reliably improved with this data.
- The test split has been inspected in earlier turns; treat these numbers as a fixed
  benchmark rather than a fresh unbiased estimate.
- Class weighting changes the decision threshold behaviour, not the separability of the
  features, so accuracy and macro F1 trade off directly.

## Files

- `results/model_comparison.csv`, `results/per_class_metrics.csv`
- `results/confusion_matrices/*.txt`, `results/tflite_evaluation.json`
- `artifacts/split_indices.json` (cached split), `artifacts/<arm>/` (keras + TFLite models)
