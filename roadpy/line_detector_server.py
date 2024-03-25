from concurrent import futures
import sys
import os
import traceback

import cv2
import grpc
import numpy as np
import plotly.express as px
import plotly.graph_objs as go

from proto import label_pb2_grpc
from proto import label_pb2


PNG_PATH = "/tmp/line_detection.png"


class LineDetector(label_pb2_grpc.LineDetectorServicer):
    def DetectLines(self, request: label_pb2.LineRequest, context):
        try:
            print(f"Detecting {request.video_path} {request.frame_index}")
            return self._detect(request)
        except Exception as e:
            print(f"Error: {e}")
            print(traceback.format_exc())
            raise

    def Plot(self, request: label_pb2.PlotRequest, context):
        try:
            n_lines, n_points = len(request.lines), len(request.points)
            print(f"Plotting {n_lines} lines and {n_points} points.")
            self._plot(request)
            return label_pb2.Empty()
        except Exception as e:
            print(f"Error: {e}")
            print(traceback.format_exc())
            raise

    def ExportPng(self, request, context):
        try:
            print(f"Exporting {PNG_PATH}")
            self._savePng()
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
                line=dict(color=request.line_color),
            )
        if len(request.points) > 0:
            self._fig.add_scatter(
                x=[p.x for p in request.points],
                y=[p.y for p in request.points],
                mode="markers",
                marker=dict(color=request.point_color),
            )

    def _detect(self, request: label_pb2.LineRequest):
        if request.video_path:
            return self._detectVideo(request)
        else:
            return self._detectImage(request)

    def _hex2bgr(self, hex):
        return tuple(int(hex[i:i+2], 16) for i in (5, 3, 1))

    def _detectImage(self, request: label_pb2.LineRequest):
        bgr = cv2.imread(request.image_path)
        for mapping in request.color_mappings:
            from_color = self._hex2bgr(mapping.fromHex)
            to_color = self._hex2bgr(mapping.toHex)
            mask = cv2.inRange(bgr, from_color, from_color)
            rest = cv2.bitwise_and(bgr, bgr, mask=~mask)
            full = np.full(bgr.shape, to_color, dtype=np.uint8)
            new = cv2.bitwise_and(full, full, mask=mask)
            bgr = cv2.bitwise_or(rest, new)
        return self._detectBgr(bgr)

    def _detectVideo(self, request: label_pb2.LineRequest):
        cap = cv2.VideoCapture(request.video_path)
        cap.set(cv2.CAP_PROP_POS_FRAMES, request.frame_index)
        ret, bgr = cap.read()
        cap.release()
        return self._detectBgr(bgr)

    def _detectBgr(self, bgr):
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        lines, _, _, _ = self._detector.detect(gray)
        detection = label_pb2.LineDetection(
            width=bgr.shape[1],
            height=bgr.shape[0],
        )
        if lines is not None:
            for line in lines:
                x0, y0, x1, y1 = line[0]
                detection.lines.append(label_pb2.Line(x0=x0, y0=y0, x1=x1, y1=y1))

        self._fig = px.imshow(rgb)

        return detection

    def _savePng(self):
        # Image Viewer can show this png without smoothing and auto-reload.
        with open(PNG_PATH, "wb") as f:
            f.write(self._fig.to_image(format="png"))
        print(f"Saved {PNG_PATH}")

    _detector = cv2.createLineSegmentDetector()
    _fig: go.Figure = None


def serve():
    pid = os.getpid()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    label_pb2_grpc.add_LineDetectorServicer_to_server(LineDetector(), server)
    server.add_insecure_port(f"unix:///tmp/line_detection_{pid}.sock")
    server.start()
    print(f"Server started with pid {pid}")
    sys.stdout.flush()
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
