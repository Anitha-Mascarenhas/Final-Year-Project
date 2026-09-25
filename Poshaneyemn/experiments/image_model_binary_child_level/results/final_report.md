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
| image level (Keras) | 1527 | 0.5115 | 0.5102 | 0.5147 | 0.3004 | 0.3794 | 0.7201 | 0.5441 |
| child level (Keras) | 193 | 0.4974 | 0.4961 | 0.4898 | 0.2500 | 0.3310 | 0.7423 | 0.552 |
| image level (TFLite) | 1527 | 0.5115 | 0.5102 | 0.5147 | 0.3004 | 0.3794 | 0.7201 | 0.5441 |

Confusion matrix, image level (rows = truth, columns = predicted; order healthy, malnourished):

```
[[553 215]
 [531 228]]
```

Confusion matrix, child level:

```
[[72 25]
 [72 24]]
```

## Recall by original malnutrition subgroup (held-out test children)

| subgroup | test children | test images | child-level recall | image-level recall | mean probability |
|---|---|---|---|---|---|
| underweight | 57 | 452 | 0.19298245614035087 | 0.23672566371681417 | 0.4306740420952178 |
| stunted | 7 | 51 | 0.42857142857142855 | 0.4117647058823529 | 0.4882837874548776 |
| stunted and underweight | 32 | 256 | 0.3125 | 0.390625 | 0.46865665819495916 |
| healthy (control) | 97 | 768 | - | - | 0.4258089540238233 |

## Selection and training

- selection metric: validation balanced_accuracy with healthy-recall floor 0.5 -> best guarded validation balanced_accuracy at epoch 1
- class weights (train, balanced): {0: 0.9962131837307153, 1: 1.003815715093273}
- augmentation (train only): {'random_flip': 'horizontal', 'random_contrast': 0.1, 'random_translation_height': 0.05, 'random_translation_width': 0.05, 'random_zoom_height': 0.05, 'random_zoom_width': 0.05}
- epochs run: 10 of 25, early stopping patience 5

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
