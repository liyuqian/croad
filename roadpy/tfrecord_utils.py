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
