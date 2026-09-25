"""
DeepLabV3+ with MobileNetV2 Backbone for Upper-Arm Segmentation.
"""

import tensorflow as tf
from tensorflow.keras import layers, models


def build_deeplabv3plus(input_shape=(512, 512, 3), num_classes=2):
    """
    Constructs DeepLabV3+ with MobileNetV2 backbone pretrained on ImageNet.
    - Low-level features: block_3_expand_relu (1/4 resolution, 128x128)
    - High-level features: out_relu (1/32 resolution, 16x16)
    - Atrous Spatial Pyramid Pooling (ASPP) with dilation rates [6, 12, 18] + Image Pooling
    - Decoder fuses low-level spatial detail with ASPP representation.
    - Output: logits of shape (None, 512, 512, num_classes)
    """
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=input_shape, include_top=False, weights="imagenet"
    )

    # Low-level features from block 3 (128x128x144 for 512x512 input)
    low_level_features = base_model.get_layer("block_3_expand_relu").output

    # High-level features from last layer (16x16x1280 for 512x512 input)
    high_level_features = base_model.get_layer("out_relu").output

    # --- ASPP Module ---
    # 1x1 conv
    b0 = layers.Conv2D(256, (1, 1), padding="same", use_bias=False, name="aspp_b0")(high_level_features)
    b0 = layers.BatchNormalization(name="aspp_b0_bn")(b0)
    b0 = layers.ReLU(name="aspp_b0_relu")(b0)

    # 3x3 conv rate=6
    b1 = layers.Conv2D(256, (3, 3), dilation_rate=(6, 6), padding="same", use_bias=False, name="aspp_b1")(high_level_features)
    b1 = layers.BatchNormalization(name="aspp_b1_bn")(b1)
    b1 = layers.ReLU(name="aspp_b1_relu")(b1)

    # 3x3 conv rate=12
    b2 = layers.Conv2D(256, (3, 3), dilation_rate=(12, 12), padding="same", use_bias=False, name="aspp_b2")(high_level_features)
    b2 = layers.BatchNormalization(name="aspp_b2_bn")(b2)
    b2 = layers.ReLU(name="aspp_b2_relu")(b2)

    # 3x3 conv rate=18
    b3 = layers.Conv2D(256, (3, 3), dilation_rate=(18, 18), padding="same", use_bias=False, name="aspp_b3")(high_level_features)
    b3 = layers.BatchNormalization(name="aspp_b3_bn")(b3)
    b3 = layers.ReLU(name="aspp_b3_relu")(b3)

    # Global Image Pooling
    b4 = layers.GlobalAveragePooling2D(name="aspp_pooling")(high_level_features)
    b4 = layers.Reshape((1, 1, 1280), name="aspp_pooling_reshape")(b4)
    b4 = layers.Conv2D(256, (1, 1), padding="same", use_bias=False, name="aspp_pooling_conv")(b4)
    b4 = layers.BatchNormalization(name="aspp_pooling_bn")(b4)
    b4 = layers.ReLU(name="aspp_pooling_relu")(b4)
    b4 = layers.UpSampling2D(size=(16, 16), interpolation="bilinear", name="aspp_pooling_up")(b4)

    # Concatenate ASPP branches
    x = layers.Concatenate(name="aspp_concat")([b0, b1, b2, b3, b4])
    x = layers.Conv2D(256, (1, 1), padding="same", use_bias=False, name="aspp_proj")(x)
    x = layers.BatchNormalization(name="aspp_proj_bn")(x)
    x = layers.ReLU(name="aspp_proj_relu")(x)

    # Upsample ASPP output by 8 to 128x128 to match low-level features
    x = layers.UpSampling2D(size=(8, 8), interpolation="bilinear", name="aspp_upsample_8x")(x)

    # Low-level feature projection (reduce channels to 48)
    low_proj = layers.Conv2D(48, (1, 1), padding="same", use_bias=False, name="low_level_proj")(low_level_features)
    low_proj = layers.BatchNormalization(name="low_level_proj_bn")(low_proj)
    low_proj = layers.ReLU(name="low_level_proj_relu")(low_proj)

    # Decoder: Concatenate upsampled ASPP features with projected low-level features
    x = layers.Concatenate(name="decoder_concat")([x, low_proj])
    x = layers.Conv2D(256, (3, 3), padding="same", use_bias=False, name="decoder_conv1")(x)
    x = layers.BatchNormalization(name="decoder_bn1")(x)
    x = layers.ReLU(name="decoder_relu1")(x)

    x = layers.Conv2D(256, (3, 3), padding="same", use_bias=False, name="decoder_conv2")(x)
    x = layers.BatchNormalization(name="decoder_bn2")(x)
    x = layers.ReLU(name="decoder_relu2")(x)

    # Final upsampling by 4 to original resolution (128x128 -> 512x512)
    x = layers.UpSampling2D(size=(4, 4), interpolation="bilinear", name="decoder_upsample_4x")(x)

    # Final 1x1 conv to produce logits for num_classes
    logits = layers.Conv2D(num_classes, (1, 1), padding="same", name="logits")(x)

    model = models.Model(inputs=base_model.input, outputs=logits, name="DeepLabV3Plus_MobileNetV2")
    return model
