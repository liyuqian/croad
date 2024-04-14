import os
import sys
import tf2onnx

from tfrecord_utils import IMAGE_H, IMAGE_W

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["KERAS_BACKEND"] = "jax"

# TensorFlow needs to be imported before keras to avoid some errors.
import tensorflow as tf
import keras

def convert_model_to_onnx(model_path, output_path):
    """
    Converts a Keras model to ONNX format.

    Args:
        model_path (str): The path to the Keras model file.
        output_path (str): The path to save the converted ONNX model.

    Returns:
        None
    """
    model = keras.models.load_model(model_path)

    spec = (tf.TensorSpec([None, IMAGE_H, IMAGE_W, 3], tf.uint8, name="input"),)
    model_proto, _ = tf2onnx.convert.from_keras(
        model, input_signature=spec, output_path=output_path
    )

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python to_onnx.py <keras_model_path> <output_path>")
        sys.exit(1)

    convert_model_to_onnx(sys.argv[1], sys.argv[2])
