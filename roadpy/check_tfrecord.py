import os
import glob
import click
import cv2

from tfrecord_utils import (
    TFRECORD_PATH,
    draw_label,
    draw_prediction,
    resize_image,
    split_dataset,
)

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

import keras  # noqa: E402
import tensorflow as tf  # noqa: E402


@click.command()
@click.option("--tfrecord_path", type=str, default=TFRECORD_PATH)
@click.option("--model_file", type=str, default=None)
@click.argument("skip_count", type=int)
@click.argument("take_count", type=int)
def check_tfrecord(
    tfrecord_path: str, model_file: str, skip_count: int, take_count: int
):
    """
    This script reads a TFRecord file containing labeled images and displays them.

    Usage:
    python check_tfrecord.py <skip_count> <take_count>

    - skip_count: The number of records to skip before starting to read.
    - take_count: The number of records to read and display.

    Example:
    python check_tfrecord.py 0 10
    This will skip 0 records and display the first 10 records.
    """

    raw_dataset = tf.data.TFRecordDataset(glob.glob(tfrecord_path))
    test_set, train_set = split_dataset(raw_dataset)
    model = keras.models.load_model(model_file) if model_file else None
    for raw_record in test_set.skip(skip_count).take(int(take_count)):
        example = tf.train.Example()
        example.ParseFromString(raw_record[0].numpy())
        image = example.features.feature["image"].bytes_list.value[0]
        label = example.features.feature["label"].float_list.value
        print(f"label={label}")
        if "debug_image_path" in example.features.feature:
            path = (
                example.features.feature["debug_image_path"]
                .bytes_list.value[0]
                .decode()
            )
            print(f"debug_image_path={path}")
        image = tf.image.decode_png(image, channels=3)
        image_bgr = resize_image(image.numpy())
        original_canvas = image_bgr.copy()
        draw_label(original_canvas, label)
        cv2.imshow("original", original_canvas)

        if model:
            cv2.imshow("test", draw_prediction(model, image_bgr))

        print()
        key = cv2.waitKey(0)
        if key == ord("q"):
            break


if __name__ == "__main__":
    check_tfrecord()
