import cv2
import numpy as np
import sys
import wget
import logging

from pathlib import Path
from segment_anything import SamAutomaticMaskGenerator, sam_model_registry


class SamDetector:
    _mask_generator: SamAutomaticMaskGenerator

    def __init__(self):
        model_path = Path(__file__).parent / "ignore" / "sam_vit_h_4b8939.pth"
        if not model_path.exists():
            model_url = "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
            wget.download(model_url, out=str(model_path))
        # TODO: set device to cuda if available.
        # MPS is unfortunately unsupported and slow for SAM...
        sam = sam_model_registry['default'](checkpoint=str(model_path))
        self._mask_generator = SamAutomaticMaskGenerator(sam)

    def detect_all(self, image: np.ndarray):
        masks = self._mask_generator.generate(image)
        overlay = np.zeros_like(image)
        for mask in masks:
            color = np.random.randint(0, 255, size=3, dtype=np.uint8)  # Random color for each mask
            overlay[mask['segmentation']] = color
        return overlay

# TODO: implement the proto server so the labeler can use it.
def main():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(message)s',  # Include timestamp in log format
        datefmt='%H:%M:%S'  # Customize timestamp format
    )
    logging.info('Initializing SamDetector...')
    detector = SamDetector()

    # Read an image using cv2 into RGB
    image = cv2.imread(sys.argv[1])
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    logging.info('Segmenting...')
    layout = detector.detect_all(image)
    logging.info('Done.')

    # Save layout into /tmp/segment.png
    cv2.imwrite("/tmp/segment.png", layout)

if __name__ == "__main__":
    main()
