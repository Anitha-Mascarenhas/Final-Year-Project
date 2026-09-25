"""
Generates side-by-side visual predictions and overlays for 10 TEST images.
Outputs:
1. Original image
2. Ground-truth mask
3. Predicted mask
4. Ground-truth overlay
5. Prediction overlay
Saved under experiments/upper_arm_segmentation/deeplabv3/visualizations/
"""

import sys
from pathlib import Path
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from config import (
    TEST_CSV,
    IMAGES_DIR,
    MASKS_DIR,
    TEST_PREDICTIONS_DIR,
    VISUALIZATIONS_DIR,
    RANDOM_SEED
)


def create_visualizations(num_samples: int = 10):
    VISUALIZATIONS_DIR.mkdir(parents=True, exist_ok=True)
    df_test = pd.read_csv(TEST_CSV)
    
    # Select 10 test images deterministically with fixed seed
    sampled_test = df_test.sample(n=min(num_samples, len(df_test)), random_state=RANDOM_SEED).reset_index(drop=True)
    
    print(f"Generating visual validation overlays for {len(sampled_test)} test images...")
    
    for idx, row in sampled_test.iterrows():
        img_name = row["image_name"]
        mask_name = row["mask_name"]
        stem = Path(img_name).stem
        
        orig_img_p = IMAGES_DIR / img_name
        gt_mask_p = MASKS_DIR / mask_name
        pred_mask_p = TEST_PREDICTIONS_DIR / f"{stem}.png"
        
        if not orig_img_p.exists() or not gt_mask_p.exists() or not pred_mask_p.exists():
            print(f"Skipping {img_name}: missing file")
            continue
            
        # Load image & resize to 512x512 for consistent overlay display
        with Image.open(orig_img_p) as im:
            img_disp = np.array(im.convert("RGB").resize((512, 512), Image.Resampling.BILINEAR))
            
        # Load GT Mask (512x512 nearest)
        with Image.open(gt_mask_p) as m_gt:
            gt_disp = np.array(m_gt.resize((512, 512), Image.Resampling.NEAREST))
            
        # Load Pred Mask (512x512)
        with Image.open(pred_mask_p) as m_pr:
            pr_disp = np.array(m_pr.resize((512, 512), Image.Resampling.NEAREST))
            
        # Create overlays
        # GT Overlay: Green tint (0, 255, 0)
        gt_overlay = img_disp.copy()
        gt_mask_bool = (gt_disp == 1)
        gt_overlay[gt_mask_bool] = (gt_overlay[gt_mask_bool] * 0.4 + np.array([0, 255, 0]) * 0.6).astype(np.uint8)
        
        # Pred Overlay: Blue tint (0, 120, 255)
        pr_overlay = img_disp.copy()
        pr_mask_bool = (pr_disp == 1)
        pr_overlay[pr_mask_bool] = (pr_overlay[pr_mask_bool] * 0.4 + np.array([0, 120, 255]) * 0.6).astype(np.uint8)
        
        # Plot 1x5 figure
        fig, axes = plt.subplots(1, 5, figsize=(22, 5))
        
        axes[0].imshow(img_disp)
        axes[0].set_title(f"Original Test Image\n{img_name}\n({row['class']}, {row['age']}m)", fontsize=9)
        axes[0].axis("off")
        
        axes[1].imshow(gt_disp, cmap="gray", vmin=0, vmax=1)
        axes[1].set_title("Ground-Truth Mask\n(LabelMe Annotations)", fontsize=9)
        axes[1].axis("off")
        
        axes[2].imshow(pr_disp, cmap="gray", vmin=0, vmax=1)
        axes[2].set_title("Predicted Mask\n(DeepLabV3+ Output)", fontsize=9)
        axes[2].axis("off")
        
        axes[3].imshow(gt_overlay)
        axes[3].set_title("GT Overlay\n(Green = Annotation)", fontsize=9)
        axes[3].axis("off")
        
        axes[4].imshow(pr_overlay)
        axes[4].set_title("Prediction Overlay\n(Blue = DeepLabV3+)", fontsize=9)
        axes[4].axis("off")
        
        plt.tight_layout()
        out_fig_p = VISUALIZATIONS_DIR / f"test_pred_{idx+1:02d}_{stem}.png"
        fig.savefig(out_fig_p, dpi=130, bbox_inches="tight")
        plt.close(fig)
        
    print(f"All {len(sampled_test)} visual overlays saved to: {VISUALIZATIONS_DIR}")


if __name__ == "__main__":
    create_visualizations(10)
