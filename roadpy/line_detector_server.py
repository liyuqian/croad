from concurrent import futures
import traceback

import cv2
import grpc
import plotly.express as px
import plotly.graph_objs as go

from proto import label_pb2_grpc
from proto import label_pb2


PNG_PATH = "/tmp/line_detection.png"


class LineDetector(label_pb2_grpc.LineDetectorServicer):
    def DetectLines(self, request: label_pb2.LineRequest, context):
        print(f"Received request {request.video_path} {request.frame_index}")
        try:
            return self._detect(request)
        except Exception as e:
            print(f"Error: {e}")
            print(traceback.format_exc())
            raise

    def Plot(self, request: label_pb2.PlotRequest, context):
        print(f"Received plot request with {len(request.lines)} lines.")
        try:
            self._plot(request)
            return label_pb2.Empty()
        except Exception as e:
            print(f"Error: {e}")
            print(traceback.format_exc())
            raise

    def _plot(self, request: label_pb2.PlotRequest):
        for line in request.lines:
            self._fig.add_scatter(
                x=[line.x0, line.x1],
                y=[line.y0, line.y1],
                mode="lines",
                line=dict(color=request.color),
            )
        self._savePng()

    def _detect(self, request: label_pb2.LineRequest):
        cap = cv2.VideoCapture(request.video_path)
        cap.set(cv2.CAP_PROP_POS_FRAMES, request.frame_index)
        ret, bgr = cap.read()
        cap.release()
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        lines, _, _, _ = self._detector.detect(gray)
        detection = label_pb2.LineDetection(
            width=bgr.shape[1],
            height=bgr.shape[0],
        )
        for line in lines:
            x0, y0, x1, y1 = line[0]
            detection.lines.append(label_pb2.Line(x0=x0, y0=y0, x1=x1, y1=y1))

        self._fig = px.imshow(rgb)
        self._savePng()

        return detection

    def _savePng(self):
        # Image Viewer can show this png without smoothing and auto-reload.
        with open(PNG_PATH, "wb") as f:
            f.write(self._fig.to_image(format="png"))
        print(f"Saved {PNG_PATH}")

    _detector = cv2.createLineSegmentDetector()
    _fig: go.Figure = None


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    label_pb2_grpc.add_LineDetectorServicer_to_server(LineDetector(), server)
    server.add_insecure_port("unix:///tmp/line_detection.sock")
    server.start()
    print("Server started")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()