import 'dart:convert';
import 'dart:io';

import 'labeler.dart';

class LabelSet {
  LabelSet(this.jsonPath) {
    if (File(jsonPath).existsSync()) {
      final json = File(jsonPath).readAsStringSync();
      final Map<String, dynamic> jsonMap = jsonDecode(json);
      for (final entry in jsonMap.entries) {
        _imageToLabel[entry.key] =
            entry.value == null ? null : LabelResult.fromJson(entry.value);
      }
    }
  }

  bool has(String imagePath) => _imageToLabel.containsKey(imagePath);
  void add(String imagePath, LabelResult? label) =>
      _imageToLabel[imagePath] = label;
  LabelResult? operator [](String imagePath) => _imageToLabel[imagePath];

  void save() {
    final Map<String, dynamic> jsonMap = {};
    for (final entry in _imageToLabel.entries) {
      jsonMap[entry.key] = entry.value?.toJson();
    }
    final String json = JsonEncoder.withIndent('  ').convert(jsonMap);
    File(jsonPath).writeAsStringSync(json);
  }

  final String jsonPath;

  // A null label means that we failed to generate a label.
  final Map<String, LabelResult?> _imageToLabel = {};
}

/// Multiple [LabelSetWorker]s still run in the same thread/isolate. Therefore
/// they can access and mutate [files] and [labelSet]. The concurrency mainly
/// comes from asynchronously calling multiple line detector servers. Most (more
/// than 99%) time seems to be consumed by the server.
class LabelSetWorker {
  // Save the whole LabelSet for every kCountPerSave labelings. It's Ok to
  // rewrite the whole json since a 50K dataset likely only has 50MB json.
  static const int kCountPerSave = 100;

  LabelSetWorker(this.files, this.workerIndex, this.labelSet, {this.maxTask});
  final List<FileSystemEntity> files;
  final int workerIndex;
  final int? maxTask;
  final LabelSet labelSet;

  Future<void> work() async {
    final String outPath = '/tmp/label_worker_$workerIndex.out';
    final IOSink out = File(outPath).openWrite();
    final labeler = Labeler(out: out);
    await labeler.start();
    print('Worker $workerIndex started (out=$outPath)');
    int count = 0;
    final total = files.length;
    while (files.isNotEmpty) {
      final file = files.removeLast();
      if (labelSet.has(file.path)) continue;
      final maskFile = File(file.path.replaceAll('imgs', 'masks'));
      if (file is File && maskFile.lengthSync() >= kMinImageSize) {
        ++count;
        if (maxTask != null && count > maxTask!) break;
        print('Worker $workerIndex labels $count (${files.length}/$total left):'
            ' ${file.path}');
        LabelResult? result = await labeler.labelImage(file.path, null);
        labelSet.add(file.path, result);
        if (workerIndex == 0 && count % kCountPerSave == 0) {
          print('Checkpoint saving...');
          labelSet.save();
          print('Checkpoint saved.');
        }
      }
    }
    await labeler.shutdown();
    await out.close();
  }
}
