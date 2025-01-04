import os
import sys
import glob
import cv2

from tfrecord_utils import (
    LABEL_SIZE,
    IMAGE_W,
    IMAGE_H,
    TFRECORD_PATH,
    bgr_to_rgb,
    split_dataset,
)

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

# TensorFlow needs to be imported before keras to avoid some errors.
import tensorflow as tf  # noqa: E402
import keras  # noqa: E402

IGNORE_LEFT = True

print(f"keras backend: {keras.backend.backend()}")

dataset = tf.data.TFRecordDataset(TFRECORD_PATH)

# The decoded png has a BGR format.
def decode_png(example):
    features = {
        "image": tf.io.FixedLenFeature([], tf.string),
        "label": tf.io.FixedLenFeature([LABEL_SIZE], tf.float32),
    }
    example = tf.io.parse_single_example(example, features)
    image = tf.image.decode_png(example["image"], channels=3)
    image = tf.image.resize(image, [IMAGE_H, IMAGE_W])
    return image, example["label"]


def bgr_to_input(image, label: tf.Tensor):
    # TODO: use obstacle labels (labels[4:9])
    sliced = label[:4]
    return bgr_to_rgb(image), tf.multiply(sliced, [1, 1, 0 if IGNORE_LEFT else 1, 1])


def load_dataset_rgb_int8(check: bool = False):
    dataset = tf.data.TFRecordDataset(glob.glob("../data/*.tfrecord"))
    decoded = dataset.map(decode_png)
    rgb_float_dataset = decoded.map(bgr_to_input)
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
    conv = keras.layers.DepthwiseConv2D(kernel_size=(3, 3), padding="same")(x)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    conv = keras.layers.Conv2D(channels, kernel_size=(1, 1), padding="same")(conv)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    return keras.layers.MaxPool2D(pool_size=(2, 2))(conv)

    # The following uses full Conv2D, which is about 10x slower than DepthwiseConv2D.
    conv = keras.layers.Conv2D(channels, kernel_size=(3, 3), padding="same")(x)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    conv = keras.layers.Conv2D(channels, kernel_size=(3, 3), padding="same")(conv)
    conv = keras.layers.BatchNormalization()(conv)
    conv = keras.layers.ReLU()(conv)
    return keras.layers.MaxPool2D(pool_size=(2, 2))(conv)


def make_output_layers(x):
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Flatten()(x)
    x = keras.layers.Dense(256, activation="relu")(x)
    x = keras.layers.Dense(128, activation="relu")(x)
    output = keras.layers.Dense(4, activation="sigmoid")(x)
    return output


def compile_model(input, output):
    model = keras.Model(inputs=input, outputs=output)
    model.compile(optimizer=keras.optimizers.Adam(learning_rate=1e-4), loss="mse")
    return model


def make_compiled_model() -> keras.Model:
    input = keras.layers.Input(shape=(IMAGE_H, IMAGE_W, 3), dtype=tf.uint8)
    x = input
    x = keras.layers.Rescaling(1 / 255.0, dtype=tf.float32)(x)  # no fp16 in tflite
    h, w, c = IMAGE_H, IMAGE_W, 8
    while w > 5:
        x = make_block(x, c)
        h, w, c = h // 2, w // 2, c * 2

    output = make_output_layers(x)
    return compile_model(input, output)


def make_mobilenet_pretrained() -> keras.Model:
    input = keras.layers.Input(shape=(IMAGE_H, IMAGE_W, 3), dtype=tf.uint8)
    base_model = keras.applications.MobileNetV3Small(
        include_top=False, input_shape=(IMAGE_H, IMAGE_W, 3), input_tensor=input
    )

    base_model.trainable = True
    output = make_output_layers(base_model.output)
    return compile_model(base_model.input, output)


dataset = load_dataset_rgb_int8()

# Split the dataset into train and test datasets
test_dataset, train_dataset = split_dataset(dataset)

if len(sys.argv) > 1:
    model: keras.Model = keras.models.load_model(sys.argv[1])
    model.evaluate(test_dataset)
else:
    # model: keras.Model = make_compiled_model()
    model: keras.Model = make_mobilenet_pretrained()
    print(model.summary())

    # Create a callback that saves the best model weights
    cp_callback = tf.keras.callbacks.ModelCheckpoint(
        filepath="ignore/best_check.keras",
        save_best_only=True,
    )
    board_callback = keras.callbacks.TensorBoard(log_dir="ignore/logs")

    model.fit(
        train_dataset,
        epochs=2000,
        validation_data=test_dataset,
        callbacks=[cp_callback, board_callback],
    )
