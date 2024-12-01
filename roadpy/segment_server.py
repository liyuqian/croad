from typing import Any, Dict, List
import cv2
import numpy as np
import sys
import torch
import wget
import logging

from pathlib import Path
from segment_anything import SamAutomaticMaskGenerator, SamPredictor, sam_model_registry

BOTTOM_RATIO = 1.0 - 80.0 / 360

class SamDetector:
    _mask_generator: SamAutomaticMaskGenerator
    _predictor: SamPredictor

    def __init__(self):
        model_path = Path(__file__).parent / "ignore" / "sam_vit_h_4b8939.pth"
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

    def detect_all(self, image: np.ndarray):
        masks = self._mask_generator.generate(image)
        return self._generate_overlay(image, [mask['segmentation'] for mask in masks])

    def detect_one(self, image: np.ndarray, point: np.ndarray):
        self._predictor.set_image(image)
        masks, _, _ = self._predictor.predict(point.reshape(1, 2), [1])
        masks = [masks[i] for i in range(masks.shape[0])]
        return self._generate_overlay(image, masks)

    def detect_one_from_all(self, image: np.ndarray, point: np.ndarray):
        masks = self._mask_generator.generate(image)
        masks = [mask['segmentation'] for mask in masks]
        r, c = point.astype(int)
        masks = [mask for mask in masks if mask[r][c]]
        return self._generate_overlay(image, masks)


# TODO: implement the proto server so the labeler can use it.
def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(message)s",  # Include timestamp in log format
        datefmt="%H:%M:%S",  # Customize timestamp format
    )
    logging.info("Initializing SamDetector...")
    detector = SamDetector()

    # Read an image using cv2 into RGB
    image = cv2.imread(sys.argv[1])
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    logging.info("Segmenting...")
    # mask = detector.detect_all(image)
    point = np.multiply(image.shape[0:2], [BOTTOM_RATIO, 0.5])
    mask = detector.detect_one_from_all(image, point)
    logging.info("Done.")

    # Save mask into /tmp/segment.png
    cv2.imwrite("/tmp/segment.png", mask)


if __name__ == "__main__":
    main()
