from concurrent import futures
import traceback

import cv2
import grpc

from proto import label_pb2_grpc
from proto import label_pb2


class LineDetector(label_pb2_grpc.LineDetectorServicer):
    def DetectLines(self, request: label_pb2.LineRequest, context):
        print(f"Received request {request.video_path} {request.frame_index}")
        try:
            return self._Detect(request)
        except Exception as e:
            print(f"Error: {e}")
            print(traceback.format_exc())
            raise

    def _Detect(self, request: label_pb2.LineRequest):
        cap = cv2.VideoCapture(request.video_path)
        cap.set(cv2.CAP_PROP_POS_FRAMES, request.frame_index)
        ret, frame = cap.read()
        cap.release()
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        lines, _, _, _ = self._detector.detect(gray)
        detection = label_pb2.LineDetection(
            width=frame.shape[1],
            height=frame.shape[0],
        )
        for line in lines:
            detection.lines.append(
                label_pb2.Line(
                    x0=line[0][0], y0=line[0][1], x1=line[0][2], y1=line[0][3]
                )
            )
        return detection

    _detector = cv2.createLineSegmentDetector()


server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
label_pb2_grpc.add_LineDetectorServicer_to_server(LineDetector(), server)
server.add_insecure_port("unix:///tmp/line_detection.sock")
server.start()
print("Server started")
server.wait_for_termination()
