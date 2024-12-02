import sys

import cv2

def flush_print(msg: str):
    print(msg)
    sys.stdout.flush()

def read_video_bgr(video_path: str, frame_index: int):
    cap = cv2.VideoCapture(video_path)
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
    _, bgr = cap.read()
    cap.release()
    return bgr
