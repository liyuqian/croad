import math
import tensorflow as tf
import cv2
import sys

from tfrecord_setting import TFRECORD_PATH, TARGET_W, TARGET_H


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
    for raw_record in raw_dataset.skip(int(sys.argv[1])).take(int(sys.argv[2])):
        example = tf.train.Example()
        example.ParseFromString(raw_record.numpy())
        image = example.features.feature["image"].bytes_list.value[0]
        label = example.features.feature["label"].float_list.value
        print(f"label={label}")
        image = tf.image.decode_png(image, channels=3)
        image_np = image.numpy()
        point = (int(label[0] * TARGET_W), int(label[1] * TARGET_H))
        cv2.drawMarker(
            image_np,
            point,
            (0, 0, 255),  # bgr
            markerType=cv2.MARKER_DIAMOND,
            markerSize=20,
            thickness=2,
        )

        LENGTH = 200
        left = label[2] * math.pi / 2
        cv2.line(
            image_np,
            point,
            (
                point[0] - int(LENGTH * math.sin(left)),
                point[1] + int(LENGTH * math.cos(left)),
            ),
            (255, 0, 0),  # bgr
            thickness=2,
        )

        right = label[3] * math.pi / 2
        cv2.line(
            image_np,
            point,
            (
                point[0] + int(LENGTH * math.sin(right)),
                point[1] + int(LENGTH * math.cos(right)),
            ),
            (255, 0, 0),  # bgr
            thickness=2,
        )

        cv2.imshow("image", image_np)
        cv2.waitKey(0)


check_tfrecord()
