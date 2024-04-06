import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:roadart/src/label_set.dart';
import 'package:roadart/src/labeler.dart';

const String kImageArg = 'image';
const String kVideoArg = 'video';
const String kFrameArg = 'frame';
const String kConcurrencyArg = 'concurrency';
const String kMaxTaskArg = 'max-task';
const String kResultArg = 'result';
const String kModelArg = 'model';

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
    ..addOption(kMaxTaskArg, help: 'max tasks per worker (for debugging)')
    ..addOption(kResultArg, help: 'Output json file for results')
    ..addOption(kModelArg, help: 'Keras model file for inference');
  final argResults = parser.parse(arguments);

  if (argResults[kConcurrencyArg] == '1') {
    if (argResults[kImageArg] != null) {
      await listenKeyForImage(argResults[kImageArg]!, argResults[kModelArg]);
    } else if (argResults[kVideoArg] != null) {
      await listenKeyForVideo(
          argResults[kVideoArg]!,
          int.parse(argResults[kFrameArg]!),
          argResults[kModelArg],
          argResults[kResultArg]);
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
  final labelSet = LabelSet(argResults[kResultArg]!);
  final int? maxTask = argResults[kMaxTaskArg] == null
      ? null
      : int.parse(argResults[kMaxTaskArg]!);
  for (int i = 0; i < concurrency; ++i) {
    workerCompletions
        .add(LabelSetWorker(files, i, labelSet, maxTask: maxTask).work());
  }
  await Future.wait(workerCompletions);
  labelSet.save();
}

Future<void> listenKeyForVideo(String videoPath, int frameIndex,
    String? modelPath, String? resultPath) async {
  final labeler = Labeler();
  await labeler.start();
  await labeler.labelVideo(videoPath, frameIndex, modelPath);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int frameDelta) async {
    print('frame: ${frameIndex += frameDelta}');
    await labeler.labelVideo(videoPath, frameIndex, modelPath);
  }

  LabelSet? labelSet = resultPath == null ? null : LabelSet(resultPath);

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
    } else if (key == 'f') {
      await labeler.exportLabel(labelSet!);
      print('');
    } else if (key == 'u') {
      await labeler.adjustUp();
    } else {
      print('Unknown key: $key');
    }
  });
}

Future<void> listenKeyForImage(String imageDirOrFile, String? modelPath) async {
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
  await labeler.labelImage(images[index], modelPath);
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
    await labeler.labelImage(images[index], modelPath);
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
