"""
This script converts a Keras model to TensorFlow Lite format (.tflite).

Usage:
    python to_tflite.py <model_path>

Arguments:
    <model_path>: The path to the Keras model file to be converted.

Output:
    - A TensorFlow SavedModel is created in the "ignore/tf_saved_model" directory.
    - The converted TensorFlow Lite model is saved as "ignore/model.tflite".
"""

import sys

import tensorflow as tf
import keras


if len(sys.argv) > 1:
    model: keras.Model = keras.models.load_model(sys.argv[1])
    tf_saved_path = "ignore/tf_saved_model"
    model.export(tf_saved_path)
    converted = tf.lite.TFLiteConverter.from_saved_model(tf_saved_path).convert()

    with open("ignore/model.tflite", "wb") as f:
        f.write(converted)
