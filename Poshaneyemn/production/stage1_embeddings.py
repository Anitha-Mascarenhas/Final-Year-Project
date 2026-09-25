"""Stage 1: cache the 128-d image embeddings for all splits (run once)."""

from __future__ import annotations

import numpy as np

from .config import ARTIFACT_DIR
from .dataset import build_dataset
from .image_branch import load_image_feature_extractor
from .train_production import compute_image_embeddings


def main() -> None:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    ds = build_dataset()
    extractor = load_image_feature_extractor()
    for name in ("train", "validation", "test"):
        df = ds.split(name)
        emb = compute_image_embeddings(df, extractor)
        np.save(ARTIFACT_DIR / f"image_embeddings_{name}.npy", emb)
        print(f"saved {name}: {emb.shape}")


if __name__ == "__main__":
    main()
