import 'package:flutter_quill/flutter_quill.dart';

Document parseDocument(dynamic raw) {
  if (raw == null) return Document();
  if (raw is! List) {
    throw const FormatException('text_data must be a list of Delta operations');
  }

  // Flet's msgpack transport can produce maps with dynamic key types.
  final ops = raw.map((op) {
    if (op is! Map) {
      throw const FormatException('Each Delta operation must be a map');
    }
    return Map<String, dynamic>.from(op);
  }).toList();
  return Document.fromJson(ops);
}
