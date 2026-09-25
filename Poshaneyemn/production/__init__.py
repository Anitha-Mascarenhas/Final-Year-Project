"""PoshanEye production hybrid pipeline.

Child image -> [MobileNetV2 features | MediaPipe CV features | DeepLabV3+ segmentation
features] + anthropometric features -> fused vector -> existing RBF-SVM classifier
-> 4 nutritional classes.
"""
