# Child-level balanced BINARY image experiment (AnthroVision only)

Isolated experiment. No production file, TFLite model, Keras model, backend file or
Flutter file was modified; everything is written under
`experiments/image_model_binary_child_level/`.

## Task

`healthy` (AnthroVision healthy) vs `malnourished` (underweight,
stunted, stunted and underweight), balanced on the number of CHILDREN, with every view of
a child kept in the same split and zero child overlap between splits.

## Children

- children with at least one usable image: 2141 (unique tags 2139; 2 duplicated tags are kept as 2 children each)
- images (all views): 16937
- balanced dataset: 641 healthy + 641 malnourished = 1282 children
- images per child: min 3, max 8, mean 7.91

## Split (child level, stratified, seed 42)

| split | children | healthy | malnourished | images | images/child |
|---|---|---|---|---|---|
| train | 897 | 448 | 449 | 7103 | 7.92 |
| validation | 192 | 96 | 96 | 1519 | 7.91 |
| test | 193 | 97 | 96 | 1527 | 7.91 |

Child overlap between splits: {'train_inter_validation': 0, 'train_inter_test': 0, 'validation_inter_test': 0} (all zero). Image overlap: {'train_inter_validation': 0, 'train_inter_test': 0, 'validation_inter_test': 0} (all zero).

## Test-set results (held-out children)

| level | n | accuracy | balanced accuracy | precision[malnourished] | recall[malnourished] | F1[malnourished] | recall[healthy] | ROC-AUC |
|---|---|---|---|---|---|---|---|---|
| image level (Keras) | 1527 | 0.5265 | 0.5259 | 0.5299 | 0.4203 | 0.4688 | 0.6315 | 0.5516 |
| child level (Keras) | 193 | 0.5130 | 0.5124 | 0.5132 | 0.4062 | 0.4535 | 0.6186 | 0.5534 |
| image level (TFLite) | 1527 | 0.5265 | 0.5259 | 0.5299 | 0.4203 | 0.4688 | 0.6315 | 0.5516 |

Confusion matrix, image level (rows = truth, columns = predicted; order healthy, malnourished):

```
[[485 283]
 [440 319]]
```

Confusion matrix, child level:

```
[[60 37]
 [57 39]]
```

## Recall by original malnutrition subgroup (held-out test children)

| subgroup | test children | test images | child-level recall | image-level recall | mean probability |
|---|---|---|---|---|---|
| underweight | 57 | 452 | 0.3333333333333333 | 0.36283185840707965 | 0.4681575219882162 |
| stunted | 7 | 51 | 0.5714285714285714 | 0.5294117647058824 | 0.527270896094186 |
| stunted and underweight | 32 | 256 | 0.5 | 0.5 | 0.5009979205206037 |
| healthy (control) | 97 | 768 | - | - | 0.45794783670877676 |

## Selection and training

- selection metric: validation balanced_accuracy with healthy-recall floor 0.5 -> best guarded validation balanced_accuracy at epoch 1
- class weights (train, balanced): {0: 0.9962131837307153, 1: 1.003815715093273}
- augmentation (train only): {'random_flip': 'horizontal', 'random_contrast': 0.1, 'random_translation_height': 0.05, 'random_translation_width': 0.05, 'random_zoom_height': 0.05, 'random_zoom_width': 0.05}
- epochs run: 6 of 25, early stopping patience 5

## Limitations

- The `malnourished` target is the AnthroVision anthropometric label definition
  (hfa/wfa z-score rule), not an independent clinical assessment. High accuracy here
  means the images correlate with that label, not that the model diagnoses malnutrition.
- `stunted` has far fewer children than the other subgroups, so its per-subgroup recall
  is the noisiest number in this report.
- One experiment, one seed; treat the numbers as a single measurement.

## Files

- `results/binary_child_level_metrics.json`, `results/per_subgroup_test_metrics.csv`
- `results/confusion_matrices/*.txt`, `artifacts/split_children.json`
- `artifacts/epoch_history.json`, `artifacts/binary_child_level.tflite`
