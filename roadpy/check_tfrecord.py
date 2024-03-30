import tensorflow as tf
import cv2

raw_dataset = tf.data.TFRecordDataset("../data/labeled.tfrecord")
print(raw_dataset.cardinality())
for raw_record in raw_dataset.take(100):
    example = tf.train.Example()
    example.ParseFromString(raw_record.numpy())
    image = example.features.feature["image"].bytes_list.value[0]
    label = example.features.feature["label"].float_list.value
    print(f"label={label}")
    image = tf.image.decode_png(image, channels=3)
    image = tf.cast(image, tf.uint8)
    cv2.imshow("image", image.numpy())
    cv2.waitKey(0)
