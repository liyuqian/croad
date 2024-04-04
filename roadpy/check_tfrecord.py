import os
import pdb

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

import math
import keras
import tensorflow as tf
import cv2
import sys

from tfrecord_utils import TFRECORD_PATH, draw_label, draw_prediction


def check_tfrecord():
    """
    This script reads a TFRecord file containing labeled images and displays them.

    Usage:
    python check_tfrecord.py <skip_count> <take_count>

    - skip_count: The number of records to skip before starting to read.
    - take_count: The number of records to read and display.

    Example:
    python check_tfrecord.py 0 10
    This will skip 0 records and display the first 10 records.

    Note: The TFRecord file path is hardcoded as TFRECORD_PATH.
    """

    raw_dataset = tf.data.TFRecordDataset(TFRECORD_PATH)
    model_file = sys.argv[3] if len(sys.argv) > 3 else None
    model = keras.models.load_model(model_file) if model_file else None
    for raw_record in raw_dataset.skip(int(sys.argv[1])).take(int(sys.argv[2])):
        example = tf.train.Example()
        example.ParseFromString(raw_record.numpy())
        image = example.features.feature["image"].bytes_list.value[0]
        label = example.features.feature["label"].float_list.value
        print(f"label={label}")
        if "debug_image_path" in example.features.feature:
            path = example.features.feature["debug_image_path"].bytes_list.value[0].decode()
            print(f"debug_image_path={path}")
        image = tf.image.decode_png(image, channels=3)
        image_bgr = image.numpy()
        original_canvas = image_bgr.copy()
        draw_label(original_canvas, label)
        cv2.imshow("original", original_canvas)

        if model:
            cv2.imshow("test", draw_prediction(model, image_bgr))

        print()
        cv2.waitKey(0)


check_tfrecord()
