import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:roadart/src/labeler.dart';

Future<void> main(List<String> arguments) async {
  Glob('/tmp/line_detection*.sock').listSync().forEach((f) => f.delete());
  if (arguments.length == 1) {
    await listenKeyForImage(arguments[0]);
  } else {
    await listenKeyForVideo(arguments[0], int.parse(arguments[1]));
  }
}

Future<void> listenKeyForVideo(String videoPath, int frameIndex) async {
  final labeler = Labeler();
  await labeler.start();
  await labeler.labelVideo(videoPath, frameIndex);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int frameDelta) async {
    print('frame: ${frameIndex += frameDelta}');
    await labeler.labelVideo(videoPath, frameIndex);
  }

  late StreamSubscription sub;
  sub = stdin.map<String>(String.fromCharCodes).listen((String key) async {
    const int kFrameStep = 30;
    if (key == 'q') {
      print('Quitting...');
      sub.cancel();
      await labeler.shutdown();
    } else if (key == 'l') {
      await update(kFrameStep);
    } else if (key == 'h') {
      await update(-kFrameStep);
    } else if (key == 'k') {
      await update(1);
    } else if (key == 'j') {
      await update(-1);
    } else {
      print('Unknown key: $key');
    }
  });
}

Future<void> listenKeyForImage(String imageDirOrFile) async {
  final labeler = Labeler();
  await labeler.start();
  late String imageDir;
  late String imageFile;
  if (!FileSystemEntity.isDirectorySync(imageDirOrFile)) {
    imageDir = File(imageDirOrFile).parent.path;
    imageFile = p.basename(File(imageDirOrFile).path);
  } else {
    imageDir = imageDirOrFile;
    imageFile = '';
  }
  final images = Directory(imageDir)
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .toList();
  int index = 0;
  for (int i = 0; i < images.length; ++i) {
    if (p.basename(images[i]) == imageFile) {
      index = i;
      break;
    }
  }
  await labeler.labelCommaMask(images[index]);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int delta) async {
    while (true) {
      index = (index + delta) % images.length;
      if (index < 0) {
        index = images.length - 1;
      }
      const int kMinSize = 5000; // Ignore images smaller than 5KB
      if (File(images[index]).lengthSync() >= kMinSize) {
        break;
      }
    }
    print('image: ${images[index]}');
    if (images[index].contains('masks')) {
      print('original: ${images[index].replaceAll('masks', 'imgs')}');
    }
    await labeler.labelCommaMask(images[index]);
  }

  late StreamSubscription sub;
  sub = stdin.map<String>(String.fromCharCodes).listen((String key) async {
    if (key == 'q') {
      print('Quitting...');
      sub.cancel();
      await labeler.shutdown();
    } else if (key == 'l') {
      await update(1);
    } else if (key == 'h') {
      await update(-1);
    } else {
      print('Unknown key: $key');
    }
  });
}
