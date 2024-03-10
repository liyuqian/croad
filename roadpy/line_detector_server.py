from concurrent import futures

import grpc

from proto import label_pb2_grpc
from proto import label_pb2

class LineDetector(label_pb2_grpc.LineDetectorServicer):
  def DetectLines(self, request, context):
    print('Received request')
    return label_pb2.LineDetection(lines = [])

server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
label_pb2_grpc.add_LineDetectorServicer_to_server(LineDetector(), server)
server.add_insecure_port('unix:///tmp/line_detection.sock')
server.start()
print('Server started')
server.wait_for_termination()
