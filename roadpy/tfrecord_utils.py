import math
import os
import cv2

os.environ["KERAS_BACKEND"] = "jax"
import keras  # noqa: E402
import tensorflow as tf  # noqa: E402


LABEL_SIZE = 9
IMAGE_W = 320  # 640
IMAGE_H = 240  # 360

RESULT_JSON_PATH = "../data/label_result.json"
TFRECORD_PATH = "../data/labeled_bgr.tfrecord"


def split_dataset(dataset):
    """
    Splits the given dataset into test and train datasets.

    Args:
        dataset: The input dataset to be split.

    Returns:
        A tuple containing the test dataset and train dataset.
    """
    shuffled = dataset.shuffle(1024, seed=0, reshuffle_each_iteration=False)
    test_size = 500
    test_dataset = shuffled.take(test_size).batch(1)
    train_dataset = (
        shuffled.skip(test_size).shuffle(1024, reshuffle_each_iteration=True).batch(32)
    )
    return test_dataset, train_dataset


def resize_image(image, width: int = IMAGE_W, height: int = IMAGE_H):
    old_height, old_width = image.shape[:2]

    if old_height == height and old_width == width:
        return image

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


def bgr_to_rgb(image):
    image = tf.reverse(image, axis=[-1])
    return image


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

    if label.shape[0] >= LABEL_SIZE - 1:
        obs_b = label[5] * IMAGE_H
        obs_l = label[6] * IMAGE_W
        obs_r = label[7] * IMAGE_W
        cv2.line(
            image_bgr,
            (int(obs_l), int(obs_b)),
            (int(obs_r), int(obs_b)),
            (0, 255, 0),  # Green
            thickness=2,
        )


# Return a new bgr image with the prediction lines
def draw_prediction(model: keras.Model, image_bgr):
    resized = resize_image(image_bgr, IMAGE_W, IMAGE_H)
    input = bgr_to_rgb(resized)
    input = tf.expand_dims(input, 0)
    prediction = model.predict(input)
    print(f"prediction={prediction}")
    result = resized.copy()
    draw_label(result, prediction[0], (0, 255, 255), (0, 255, 0))
    return result
