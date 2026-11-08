import 'package:flet_quill/src/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('omitted content creates an empty document', () {
    expect(parseDocument(null).toDelta().toJson(), [
      {'insert': '\n'}
    ]);
  });

  test('loads Delta operations with dynamic map keys and attributes', () {
    final ops = <dynamic>[
      <dynamic, dynamic>{
        'insert': 'Hello',
        'attributes': <dynamic, dynamic>{'bold': true},
      },
      <dynamic, dynamic>{'insert': '\n'},
    ];
    expect(parseDocument(ops).toDelta().toJson(), ops);
  });

  test('rejects JSON strings and other non-list content', () {
    for (final input in ['[{"insert":"Hello\\n"}]', 'hello', 42, {}]) {
      expect(() => parseDocument(input), throwsFormatException);
    }
  });

  test('rejects invalid operations rather than creating a blank document', () {
    expect(() => parseDocument(['hello']), throwsFormatException);
    expect(
        () => parseDocument([
              <dynamic, dynamic>{1: 'hello'}
            ]),
        throwsA(isA<TypeError>()));
    expect(
        () => parseDocument([
              {'invalid': 'hello'}
            ]),
        throwsA(anything));
  });
}
