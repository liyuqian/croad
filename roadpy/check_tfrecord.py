import os
import pdb

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

import math
import keras
import tensorflow as tf
import cv2
import sys

from tfrecord_utils import TFRECORD_PATH, IMAGE_W, IMAGE_H, bgr_to_input


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
        image = tf.image.decode_png(image, channels=3)
        image_bgr = image.numpy()
        original_canvas = image_bgr.copy()
        draw_label(original_canvas, label)
        cv2.imshow("original", original_canvas)
        cv2.waitKey(0)

        if model:
            input = bgr_to_input(image_bgr)
            input = tf.expand_dims(input, 0)
            prediction = model.predict(input)
            print(f"prediction={prediction}")
            test_canvas = image_bgr.copy()
            draw_label(test_canvas, prediction[0], (0, 255, 255), (0, 255, 0))
            cv2.imshow("test", test_canvas)
            cv2.waitKey(0)


# Colors are in BGR format
def draw_label(image_bgr, label, point_color=(0, 0, 255), line_color=(255, 0, 0)):
    point = (int(label[0] * IMAGE_W), int(label[1] * IMAGE_H))
    cv2.drawMarker(
        image_bgr,
        point,
        point_color,
        markerType=cv2.MARKER_DIAMOND,
        markerSize=20,
        thickness=2,
    )

    LENGTH = 200
    left = label[2] * math.pi / 2
    cv2.line(
        image_bgr,
        point,
        (
            point[0] - int(LENGTH * math.sin(left)),
            point[1] + int(LENGTH * math.cos(left)),
        ),
        line_color,
        thickness=2,
    )

    right = label[3] * math.pi / 2
    cv2.line(
        image_bgr,
        point,
        (
            point[0] + int(LENGTH * math.sin(right)),
            point[1] + int(LENGTH * math.cos(right)),
        ),
        line_color,
        thickness=2,
    )

check_tfrecord()
