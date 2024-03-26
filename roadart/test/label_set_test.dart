import 'dart:io';

import 'package:roadart/src/label_set.dart';
import 'package:test/test.dart';

void main() {
  test('LabelSet handles null LabelResult', () {
    const String kTestJsonPath = '/tmp/label_set_test.json';
    if (File(kTestJsonPath).existsSync()) {
      File(kTestJsonPath).deleteSync();
    }
    final labelSet = LabelSet(kTestJsonPath);
    expect(labelSet.has('test.jpg'), isFalse);
    labelSet.add('test.jpg', null);
    expect(labelSet.has('test.jpg'), isTrue);
    labelSet.save();
    final labelSet2 = LabelSet(kTestJsonPath);
    expect(labelSet2.has('test.jpg'), isTrue);
    expect(labelSet2['test.jpg'], isNull);
  });
}
