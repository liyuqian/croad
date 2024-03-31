import os

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

import cv2

# TensorFlow needs to be imported before keras to avoid some errors.
import tensorflow as tf
import keras

from tfrecord_utils import IMAGE_W, IMAGE_H, TFRECORD_PATH, bgr_to_input

print(f"keras backend: {keras.backend.backend()}")

dataset = tf.data.TFRecordDataset(TFRECORD_PATH)


# The decoded png has a BGR format.
def decode_png(example):
    features = {
        "image": tf.io.FixedLenFeature([], tf.string),
        "label": tf.io.FixedLenFeature([4], tf.float32),
    }
    example = tf.io.parse_single_example(example, features)
    image = tf.image.decode_png(example["image"], channels=3)
    return image, example["label"]


def bgr_to_rgb_float16(image, label):
    return bgr_to_input(image), label


def load_dataset_rgb_float16(check: bool = False):
    dataset = tf.data.TFRecordDataset(TFRECORD_PATH)
    decoded = dataset.map(decode_png)
    rgb_float_dataset = decoded.map(bgr_to_rgb_float16)
    if check:
        for record in decoded.take(1):
            image, label = record
            print(f"label={label}")
            print(f"image.shape={image.shape}")
            print(f"image.dtype={image.dtype}")
            cv2.imshow("image", image.numpy())
            cv2.waitKey(0)
        for record in rgb_float_dataset.take(1):
            image, label = record
            print(f"label={label}")
            print(f"image.shape={image.shape}")
            print(f"image.dtype={image.dtype}")
            print(f"image[100][100]={image[100][100]}")
    return rgb_float_dataset


def make_block(x, channels: int):
    conv = keras.layers.Conv2D(channels, kernel_size=(3, 3), padding="same")(x)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    conv = keras.layers.Conv2D(channels, kernel_size=(3, 3), padding="same")(conv)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    return keras.layers.MaxPool2D(pool_size=(2, 2))(conv)


def make_compiled_model() -> keras.Model:
    input = keras.layers.Input(shape=(IMAGE_H, IMAGE_W, 3))
    x = input
    h, w, c = IMAGE_H, IMAGE_W, 8
    while w > 5:
        x = make_block(x, c)
        h, w, c = h // 2, w // 2, c * 2
    x = keras.layers.Flatten()(x)
    x = keras.layers.Dense(1024, activation="relu")(x)
    x = keras.layers.Dense(128, activation="relu")(x)
    output = keras.layers.Dense(4, activation="sigmoid")(x)
    model = keras.Model(inputs=input, outputs=output)
    model.compile(optimizer=keras.optimizers.Adam(learning_rate=1e-4), loss="mse")
    return model


dataset = load_dataset_rgb_float16().shuffle(1024).batch(32)

# Split the dataset into train and test datasets
test_size = 10  # 10 x 32 = 320
test_dataset = dataset.take(test_size)
train_dataset = dataset.skip(test_size)

model: keras.Model = make_compiled_model()
print(model.summary())

model.fit(
    train_dataset,
    epochs=10,
    validation_data=test_dataset,
    callbacks=[
        keras.callbacks.ModelCheckpoint(filepath="ignore/model_at_epoch_{epoch}.keras"),
    ],
)
