# DeepLabV3+ Upper-Arm Segmentation Experiment

**Architecture:** DeepLabV3+ with MobileNetV2 Backbone  
**Pretraining:** ImageNet pre-trained feature extractor  
**Target:** Binary Upper-Arm Segmentation (`0 = background`, `1 = upper_arm`)  
**Resolution:** 512 x 512  
**Dataset:** 246 manually annotated AnthroVision frontal images  

---

## 1. Dataset & Split Design

- **Train Set:** 172 images (172 unique children)
- **Validation Set:** 37 images (37 unique children)
- **Test Set:** 37 images (37 unique children)
- **Strict Child-Level Isolation:** Zero overlap of children across splits (audited in `experiments/upper_arm_segmentation/splits/split_summary.md`).
- **Stratified by Malnutrition Class:** Balanced representation of healthy, underweight, stunted, and stunted & underweight classes across splits.

---

## 2. Model Architecture & Preprocessing

- **Backbone:** MobileNetV2 (ImageNet pre-trained weights loaded into low-level and high-level feature extraction stages).
- **Atrous Spatial Pyramid Pooling (ASPP):** Dilations = [6, 12, 18] with 256 channels + Global Average Pooling branch.
- **Decoder:** Low-level feature projection (48 channels from 1/4 resolution stage) fused with 8x upsampled ASPP features, followed by 3x3 convolutions and final 4x upsampling to 512x512.
- **Output:** 2 class logits (0: Background, 1: Upper-Arm).
- **Image Preprocessing:** Bilinear resize to 512x512, scaled to [0, 1] and standardized with ImageNet mean `[0.485, 0.456, 0.406]` and std `[0.229, 0.224, 0.225]`.
- **Mask Preprocessing:** Nearest-neighbor resize to 512x512, integer class IDs in `{0, 1}`.

---

## 3. Loss & Optimization

- **Objective Function:** `0.5 * CrossEntropyLoss + 0.5 * DiceLoss` (with numerical epsilon smoothing).
- **Optimizer:** AdamW (`learning_rate = 1e-4`, `weight_decay = 1e-4`).
- **Batch Size:** 4.
- **Regularization & Augmentation:** Light horizontal flip (50% probability) during training only. No augmentation on validation or test sets.
- **Early Stopping:** Monitored on validation foreground Dice coefficient with patience = 10 epochs.

---

## 4. Evaluation Protocol

- Primary evaluation metrics computed on held-out test split (N=37):
  - **Foreground Dice Coefficient**
  - **Foreground Intersection-over-Union (IoU / Jaccard)**
  - **Precision**
  - **Recall**
  - **Pixel Accuracy**
