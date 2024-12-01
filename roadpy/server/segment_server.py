from concurrent import futures
import os
import traceback
from typing import List
import cv2
import grpc
import numpy as np
import sys
import torch
import wget
import logging

from pathlib import Path
from segment_anything import SamAutomaticMaskGenerator, SamPredictor, sam_model_registry

from proto import label_pb2, label_pb2_grpc
from server.server_utils import flush_print

BOTTOM_RATIO = 1.0 - 80.0 / 360

class SamDetector(label_pb2_grpc.Segmenter):
    _mask_generator: SamAutomaticMaskGenerator
    _predictor: SamPredictor

    def __init__(self):
        model_path = Path(__file__).parent.parent / "ignore" / "sam_vit_h_4b8939.pth"
        if not model_path.exists():
            model_url = (
                "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
            )
            wget.download(model_url, out=str(model_path))
            print("\nModel downloaded.")
        # MPS is unfortunately unsupportee and slow for SAM...
        sam = sam_model_registry["default"](checkpoint=str(model_path))
        if torch.cuda.is_available():
            sam.to(device="cuda")
        self._mask_generator = SamAutomaticMaskGenerator(sam)
        self._predictor = SamPredictor(sam)

    def _generate_overlay(self, image: np.ndarray, masks: List[np.ndarray]):
        overlay = np.zeros_like(image)
        for mask in masks:
            color = np.random.randint(0, 255, size=3, dtype=np.uint8)
            overlay[mask]= color
        return overlay

    def detect_all(self, image: np.ndarray) -> np.ndarray:
        masks = self._mask_generator.generate(image)
        return self._generate_overlay(image, [mask['segmentation'] for mask in masks])

    def detect_one(self, image: np.ndarray, point: np.ndarray) -> np.ndarray:
        self._predictor.set_image(image)
        masks, _, _ = self._predictor.predict(point.reshape(1, 2), [1])
        masks = [masks[i] for i in range(masks.shape[0])]
        return self._generate_overlay(image, masks)

    def detect_one_from_all(self, image: np.ndarray, point: np.ndarray) -> np.ndarray:
        masks = self._mask_generator.generate(image)
        masks = [mask['segmentation'] for mask in masks]
        r, c = point.astype(int)
        masks = [mask for mask in masks if mask[r][c]]
        return self._generate_overlay(image, masks)

    def detect_and_save(self, input_path: str, output_path: str) -> None:
        # Read an image using cv2 into RGB
        image = cv2.imread(sys.argv[1])
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        logging.info("Segmenting...")
        point = np.multiply(image.shape[0:2], [BOTTOM_RATIO, 0.5])
        mask = self.detect_one_from_all(image, point)
        cv2.imwrite(output_path, mask)
        logging.info("Done.")

    def Segment(self, request: label_pb2.SegmentRequest, context):
        try:
            flush_print('Received segment request.')
            self.detect_and_save(request.input_path, request.output_path)
            flush_print('Finished segment request.')
        except Exception as e:
            print(f'Error: {e}')
            flush_print(traceback.format_exc())
            raise



def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(message)s",  # Include timestamp in log format
        datefmt="%H:%M:%S",  # Customize timestamp format
    )
    logging.info("Initializing SamDetector...")
    detector = SamDetector()
    logging.info("SamDetector initialized.")

    pid = os.getpid()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
    label_pb2_grpc.add_SegmenterServicer_to_server(detector, server)
    server.add_insecure_port(f"unix:///tmp/segmenter_{pid}.sock")
    server.start()
    flush_print(f"Server started with pid {pid}")
    server.wait_for_termination()


if __name__ == "__main__":
    main()
