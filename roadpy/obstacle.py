from typing import List
from transformers import DetrImageProcessor, DetrForObjectDetection

from proto.label_pb2 import Obstacle

DETR_MODEL_PATH = "facebook/detr-resnet-50"


class ObstacleDetector:
    THRESHOLD = 0.6

    _processor: DetrImageProcessor
    _model: DetrForObjectDetection

    def __init__(self):
        kwargs = {"revision": "no_timm"}
        self._processor = DetrImageProcessor.from_pretrained(DETR_MODEL_PATH, **kwargs)
        self._model = DetrForObjectDetection.from_pretrained(DETR_MODEL_PATH, **kwargs)

    def detect(self, image) -> List[Obstacle]:
        inputs = self._processor(images=image, return_tensors="pt")
        outputs = self._model(**inputs)
        results = self._processor.post_process_object_detection(
            outputs, threshold=self.THRESHOLD
        )[0]

        obstacles: List[Obstacle] = []
        for score, label, box in zip(
            results["scores"], results["labels"], results["boxes"]
        ):
            ltrb = box.tolist()
            obstacles.append(
                Obstacle(
                    l=ltrb[0],
                    t=ltrb[1],
                    r=ltrb[2],
                    b=ltrb[3],
                    label=self._model.config.id2label[label.item()],
                    confidence=score.item(),
                )
            )
        return obstacles
