import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:roadart/proto/label.pbgrpc.dart';

void main(List<String> arguments) async {
  final udsAddress = InternetAddress('/tmp/line_detection.sock',
      type: InternetAddressType.unix);
  final channel = ClientChannel(
    udsAddress,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  final client = LineDetectorClient(channel);

  try {
    final response = await client.detectLines(LabelRequest());
    print('Response: $response');
  } catch (e) {
    print('Caught error: $e');
  }

  await channel.shutdown();
}
