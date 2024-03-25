import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:roadart/src/labeler.dart';

const String kImageArg = 'image';
const String kVideoArg = 'video';
const String kFrameArg = 'frame';
const String kConcurrencyArg = 'concurrency';
const String kMaxTaskArg = 'max-task';

const int kMinImageSize = 5000; // Ignore images smaller than 5KB

Future<void> main(List<String> arguments) async {
  Glob('/tmp/line_detection*.sock').listSync().forEach((f) => f.deleteSync());
  Glob('/tmp/line_detect*.out').listSync().forEach((f) => f.deleteSync());
  Glob('/tmp/line_detect*.err').listSync().forEach((f) => f.deleteSync());

  final parser = ArgParser()
    ..addOption(kImageArg, help: 'Image file or directory')
    ..addOption(kVideoArg, help: 'Video file')
    ..addOption(kFrameArg, help: 'Frame index', defaultsTo: '0')
    ..addOption(kConcurrencyArg,
        help: 'Number of concurrent labelers', defaultsTo: '1')
    ..addOption(kMaxTaskArg, help: 'max tasks per worker (for debugging)');
  final argResults = parser.parse(arguments);

  if (argResults[kConcurrencyArg] == '1') {
    if (argResults[kImageArg] != null) {
      await listenKeyForImage(argResults[kImageArg]!);
    } else if (argResults[kVideoArg] != null) {
      await listenKeyForVideo(
          argResults[kVideoArg]!, int.parse(argResults[kFrameArg]!));
    } else {
      print(parser.usage);
    }
    return;
  }

  final concurrency = int.parse(argResults[kConcurrencyArg]!);
  if (argResults[kImageArg] == null) {
    throw Exception('An image directory is required for concurrent labeling.');
  }

  final List<FileSystemEntity> files =
      Directory(argResults[kImageArg]!).listSync();
  final List<Future> workerCompletions = [];
  for (int i = 0; i < concurrency; ++i) {
    workerCompletions
        .add(labelFilesByOneWorker(files, i, argResults[kMaxTaskArg]));
  }
  await Future.wait(workerCompletions);
}

Future<void> labelFilesByOneWorker(
    List<FileSystemEntity> files, int workerIndex, String? maxTaskArg) async {
  int? maxTask = maxTaskArg == null ? null : int.parse(maxTaskArg);
  final String outPath = '/tmp/label_worker_$workerIndex.out';
  final IOSink out = File(outPath).openWrite();
  final labeler = Labeler(out: out);
  await labeler.start();
  print('Worker $workerIndex started (out=$outPath)');
  int count = 0;
  while (files.isNotEmpty) {
    final file = files.removeLast();
    final maskFile = File(file.path.replaceAll('imgs', 'masks'));
    if (file is File && maskFile.lengthSync() >= kMinImageSize) {
      if (maxTask != null && ++count > maxTask) break;
      print('Worker $workerIndex labels ${file.path}');
      await labeler.labelImage(file.path);
    }
  }
  await labeler.shutdown();
  await out.close();
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
  await labeler.labelImage(images[index]);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int delta) async {
    while (true) {
      index = (index + delta) % images.length;
      if (index < 0) {
        index = images.length - 1;
      }
      if (File(images[index]).lengthSync() >= kMinImageSize) {
        break;
      }
    }
    print('image: ${images[index]}');
    if (images[index].contains('masks')) {
      print('original: ${images[index].replaceAll('masks', 'imgs')}');
    }
    await labeler.labelImage(images[index]);
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
