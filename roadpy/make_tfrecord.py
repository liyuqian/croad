import pdb
import cv2
import json
import tensorflow as tf
import threading

TARGET_W = 640
TARGET_H = 360


def get_resized(image_path: str, width: int, height: int):
    image = cv2.imread(image_path)
    old_height, old_width = image.shape[:2]

    # find the smaller ratio
    r = min(width / float(old_width), height / float(old_height))
    dim = (int(old_width * r), int(old_height * r))

    # resize the image
    resized_image = cv2.resize(image, dim, interpolation=cv2.INTER_AREA)

    # calculate deltas to center image
    delta_w = width - resized_image.shape[1]
    delta_h = height - resized_image.shape[0]
    top, bottom = delta_h // 2, delta_h - (delta_h // 2)
    left, right = delta_w // 2, delta_w - (delta_w // 2)

    # pad the image
    color = [0, 0, 0]
    padded_image = cv2.copyMakeBorder(
        resized_image, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color
    )

    return padded_image


with open("../data/label_result.json") as f:
    label_result = json.load(f)

writer = tf.io.TFRecordWriter("../data/labeled.tfrecord")


def process_label_result(label_result, start_index, end_index, thread_id: int):
    total: int = end_index - start_index
    for i in range(start_index, end_index):
        file_key = list(label_result.keys())[i]
        json_map = label_result[file_key]
        if not json_map:
            continue
        resized = get_resized(file_key, TARGET_W, TARGET_H)
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
                    ]
                )
            ),
        }
        tf_example = tf.train.Example(features=tf.train.Features(feature=features))
        writer.write(tf_example.SerializeToString())

        processed = i - start_index + 1
        if processed % 100 == 0:
            print(f"Thread {thread_id} processed {processed} / {total} files")


# Split label_result into 8 threads
num_threads = 8
total_files = len(label_result)
files_per_thread = total_files // num_threads

threads = []
for i in range(num_threads):
    start_index = i * files_per_thread
    end_index = start_index + files_per_thread if i < num_threads - 1 else total_files
    thread = threading.Thread(
        target=process_label_result, args=(label_result, start_index, end_index, i)
    )
    thread.start()
    threads.append(thread)

# Wait for all threads to finish
for thread in threads:
    thread.join()

writer.close()
