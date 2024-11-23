import os
import click
import cv2
import json
import tensorflow as tf
import threading
import random

from tfrecord_utils import (
    IMAGE_W,
    IMAGE_H,
    TFRECORD_PATH,
    RESULT_JSON_PATH,
    resize_image,
)

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"


def get_resized(image_path: str, width: int, height: int):
    if image_path.endswith(".png") or image_path.endswith(".jpg"):
        image = cv2.imread(image_path)
    else:
        split: int = image_path.rfind(":")
        video_path = image_path[:split]
        frame_index = int(image_path[split + 1 :])
        cap = cv2.VideoCapture(video_path)
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        _, image = cap.read()
        cap.release()
    return resize_image(image, width, height)


def process_label_result(
    tfrecord_path: str, result_list, start_index, end_index, thread_id: int
):
    writer = tf.io.TFRecordWriter(
        tfrecord_path.replace(".tfrecord", f"_{thread_id}.tfrecord")
    )
    total: int = end_index - start_index
    for i in range(start_index, end_index):
        json_map = result_list[i]
        if not json_map:
            continue
        image_path = json_map["imagePath"]
        resized = get_resized(image_path, IMAGE_W, IMAGE_H)
        features = {
            "image": tf.train.Feature(
                bytes_list=tf.train.BytesList(value=[tf.io.encode_png(resized).numpy()])
            ),
            "label": tf.train.Feature(
                float_list=tf.train.FloatList(
                    value=[
                        json_map["xRatio"],
                        json_map["yRatio"],
                        json_map["leftRatio"],
                        json_map["rightRatio"],
                        json_map["yRatioObstacleMax"],
                        json_map["xRatioObstacleMin"],
                        json_map["xRatioObstacleMax"],
                    ]
                )
            ),
            "debug_image_path": tf.train.Feature(
                bytes_list=tf.train.BytesList(value=[image_path.encode()])
            ),
        }
        tf_example = tf.train.Example(features=tf.train.Features(feature=features))
        writer.write(tf_example.SerializeToString())

        processed = i - start_index + 1
        if processed % 100 == 0:
            print(f"Thread {thread_id} processed {processed} / {total} images")
    writer.close()


@click.command()
@click.option("--json_path", default=RESULT_JSON_PATH, help="Path to JSON file")
@click.option("--tfrecord_path", default=TFRECORD_PATH, help="Path to TFRecord file")
@click.option("--num_threads", default=8, help="Number of threads to use")
def make_tfrecord(json_path: str, tfrecord_path: str, num_threads: int):
    print(f"Converting {json_path} to {tfrecord_path} using {num_threads} threads")

    with open(json_path) as f:
        label_result = json.load(f)

    # Shuffle
    result_list = list(label_result.values())
    random.shuffle(result_list)

    # Split label_result into 8 threads
    num_threads = 8
    total_files = len(result_list)
    files_per_thread = total_files // num_threads

    threads = []
    for i in range(num_threads):
        start_index = i * files_per_thread
        end_index = (
            start_index + files_per_thread if i < num_threads - 1 else total_files
        )
        thread = threading.Thread(
            target=process_label_result,
            args=(tfrecord_path, result_list, start_index, end_index, i),
        )
        thread.start()
        threads.append(thread)

    # Wait for all threads to finish
    for thread in threads:
        thread.join()


if __name__ == "__main__":
    make_tfrecord()
