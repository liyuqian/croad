import math
import os

os.environ["KERAS_BACKEND"] = "jax"
import keras

import cv2
import tensorflow as tf


IMAGE_W = 640
IMAGE_H = 360

RESULT_JSON_PATH = "../data/label_result.json"
TFRECORD_PATH = "../data/labeled_bgr.tfrecord"


def resize_image(image, width: int, height: int):
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

def bgr_to_input(image):
    image = tf.cast(image, tf.float16)
    image = tf.reverse(image, axis=[-1])
    return image / 255

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

# Return a new bgr image with the prediction lines
def draw_prediction(model: keras.Model, image_bgr):
    resized = resize_image(image_bgr, IMAGE_W, IMAGE_H)
    input = bgr_to_input(resized)
    input = tf.expand_dims(input, 0)
    prediction = model.predict(input)
    print(f"prediction={prediction}")
    result = resized.copy()
    draw_label(result, prediction[0], (0, 255, 255), (0, 255, 0))
    return result
