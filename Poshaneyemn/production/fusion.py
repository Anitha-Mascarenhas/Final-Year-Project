"""Feature fusion and the portable RBF-SVM classifier.

The classifier is the EXISTING repo implementation choice: ``sklearn.svm.SVC(kernel='rbf',
class_weight='balanced')`` — the same family already used by
``experiments/cv_multimodal_baseline`` and ``experiments/segmentation_feature_baseline``.
SVC cannot be exported to TFLite, so it is serialized into a plain-JSON "portable SVM"
(support vectors + dual coefficients + RBF gamma) that the Flutter app evaluates in
Dart — fully offline, no Python needed at inference.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.svm import SVC

from .config import (
    ANTHROPOMETRIC_COLUMNS,
    CV_FEATURE_COLUMNS,
    RANDOM_STATE,
    SEGMENTATION_FEATURE_COLUMNS,
    SVM_C,
    SVM_KERNEL,
)

GROUP_SIZES = {
    "image": None,  # set at fit time (128)
    "cv": len(CV_FEATURE_COLUMNS),
    "segmentation": len(SEGMENTATION_FEATURE_COLUMNS),
    "anthropometric": len(ANTHROPOMETRIC_COLUMNS),
}


def group_slice(image_dim: int) -> dict[str, slice]:
    """Contiguous slices of the fused vector: [image | cv | segmentation | anthropometric]."""
    sizes = {
        "image": image_dim,
        "cv": GROUP_SIZES["cv"],
        "segmentation": GROUP_SIZES["segmentation"],
        "anthropometric": GROUP_SIZES["anthropometric"],
    }
    slices, start = {}, 0
    for name, size in sizes.items():
        slices[name] = slice(start, start + size)
        start += size
    return slices


def fuse_vectors(image_features: np.ndarray, cv_features: np.ndarray,
                 seg_features: np.ndarray, anthro_features: np.ndarray) -> np.ndarray:
    """Concatenate the four modality blocks in the fixed production order."""
    image_features = np.atleast_2d(np.asarray(image_features, dtype=np.float64))
    blocks = [image_features]
    for arr in (cv_features, seg_features, anthro_features):
        arr = np.asarray(arr, dtype=np.float64)
        if arr.ndim == 1:
            arr = arr.reshape(1, -1)
        blocks.append(arr)
    return np.hstack(blocks)


class PortableSVM:
    """JSON-serializable multiclass RBF-SVM (one-vs-one), runnable without sklearn.

    The reconstruction follows libsvm's ``svm_predict_values`` exactly (see
    ``sklearn/svm/src/libsvm/svm.cpp``): support vectors are grouped by class, and the
    decision value for pair (i, j) is

        sum( sv_coef[j-1][class-i block] * k ) + sum( sv_coef[i][class-j block] * k )
        + intercept_[pair]

    where ``k`` is the RBF kernel row of the sample against every support vector.
    The final class is ``argmax`` of sklearn's ``_ovr_decision_function`` (votes plus a
    confidence tie-breaker), which is what ``SVC.predict`` computes.
    """

    def __init__(self, support_vectors: np.ndarray, dual_coefs: np.ndarray,
                 intercepts: np.ndarray, gamma: float, classes: list[int],
                 n_support: list[int]):
        self.support_vectors = np.asarray(support_vectors, dtype=np.float64)
        self.dual_coefs = np.asarray(dual_coefs, dtype=np.float64)   # [n_classes-1, n_sv]
        self.intercepts = np.asarray(intercepts, dtype=np.float64)   # [n_binary]
        self.gamma = float(gamma)
        self.classes = list(classes)
        self.n_support = [int(v) for v in n_support]
        self._starts = np.cumsum([0] + self.n_support).tolist()

    # ------------------------------------------------------------------ sklearn bridge
    @classmethod
    def from_sklearn(cls, svc: SVC) -> "PortableSVM":
        if svc.kernel != "rbf":
            raise ValueError(f"Only RBF SVC can be exported; got kernel={svc.kernel!r}")
        gamma = float(svc._gamma if hasattr(svc, "_gamma") else svc.gamma)
        return cls(
            support_vectors=svc.support_vectors_,
            dual_coefs=svc.dual_coef_,
            intercepts=svc.intercept_,
            gamma=gamma,
            classes=[int(c) for c in svc.classes_],
            n_support=[int(v) for v in svc.n_support_],
        )

    # ------------------------------------------------------------------ inference
    def _kernel_row(self, x: np.ndarray) -> np.ndarray:
        diffs = self.support_vectors - x
        sq = np.einsum("ij,ij->i", diffs, diffs)
        return np.exp(-self.gamma * sq)

    def decision_function_one(self, x: np.ndarray) -> np.ndarray:
        """Raw one-vs-one decision values (libsvm order: pairs (i,j), i<j)."""
        k = self._kernel_row(np.asarray(x, dtype=np.float64))
        n = len(self.classes)
        dec = np.zeros(n * (n - 1) // 2)
        p = 0
        for i in range(n):
            for j in range(i + 1, n):
                si, sj = self._starts[i], self._starts[j]
                ci, cj = self.n_support[i], self.n_support[j]
                coef1 = self.dual_coefs[j - 1]
                coef2 = self.dual_coefs[i]
                s = float(np.dot(coef1[si:si + ci], k[si:si + ci]))
                s += float(np.dot(coef2[sj:sj + cj], k[sj:sj + cj]))
                dec[p] = s + self.intercepts[p]  # intercept_ == -rho_internal
                p += 1
        return dec

    def ovr_decision_function_one(self, x: np.ndarray) -> np.ndarray:
        """sklearn's _ovr_decision_function for one sample (votes + tie-breaker)."""
        dec = self.decision_function_one(x)
        n = len(self.classes)
        votes = np.zeros(n)
        soc = np.zeros(n)  # sum of confidences
        p = 0
        for i in range(n):
            for j in range(i + 1, n):
                soc[i] -= -dec[p]
                soc[j] += -dec[p]
                votes[i if dec[p] > 0 else j] += 1
                p += 1
        transformed = soc / (3 * (np.abs(soc) + 1))
        return votes + transformed

    def predict_one(self, x: np.ndarray) -> int:
        scores = self.ovr_decision_function_one(x)
        return self.classes[int(np.argmax(scores))]

    def predict(self, X: np.ndarray) -> np.ndarray:
        return np.array([self.predict_one(row) for row in np.atleast_2d(X)], dtype=int)

    # ------------------------------------------------------------------ persistence
    def to_dict(self) -> dict[str, Any]:
        return {
            "type": "rbf_svm_one_vs_one",
            "gamma": self.gamma,
            "classes": self.classes,
            "n_support": self.n_support,
            "support_vectors": self.support_vectors.tolist(),
            "dual_coefs": self.dual_coefs.tolist(),
            "intercepts": self.intercepts.tolist(),
        }

    def save(self, path: Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict()), encoding="utf-8")

    @classmethod
    def load(cls, path: Path) -> "PortableSVM":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return cls(
            support_vectors=np.array(data["support_vectors"], dtype=np.float64),
            dual_coefs=np.array(data["dual_coefs"], dtype=np.float64),
            intercepts=np.array(data["intercepts"], dtype=np.float64),
            gamma=data["gamma"],
            classes=data["classes"],
            n_support=data["n_support"],
        )


def fit_production_svm(X_train: np.ndarray, y_train: np.ndarray) -> tuple[SVC, PortableSVM]:
    """Fit the existing RBF-SVM family classifier and derive its portable form."""
    svc = SVC(C=SVM_C, kernel=SVM_KERNEL, class_weight="balanced", random_state=RANDOM_STATE)
    svc.fit(X_train, y_train)
    portable = PortableSVM.from_sklearn(svc)
    return svc, portable
