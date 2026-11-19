import 'package:flet/flet.dart';
import 'package:flet_quill/src/flet_quill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('combined editor has no built-in page break button',
      (tester) async {
    final backend = FletBackend(
      pageUri: Uri.parse('uri'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    );
    final control = Control(
      id: 3,
      type: 'FletQuill',
      properties: {
        'text_data': [
          {'insert': 'Hello\n'}
        ],
      },
      backend: backend,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FletQuillControl(control: control)),
    ));

    final toolbar = tester.widget<QuillSimpleToolbar>(
      find.byType(QuillSimpleToolbar),
    );
    expect(toolbar.config.customButtons, isEmpty);
    expect(find.byIcon(Icons.insert_page_break), findsNothing);
    expect(toolbar.controller.document.toPlainText(), 'Hello\n');
  });

  testWidgets('standalone toolbar has no built-in page break button',
      (tester) async {
    final backend = FletBackend(
      pageUri: Uri.parse('uri'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    );
    final editor = Control(
      id: 3,
      type: 'FletQuillEditor',
      properties: {
        'controller_id': 'standalone-test',
        'text_data': [
          {'insert': 'Hello\n'}
        ],
      },
      backend: backend,
    );
    final toolbar = Control(
      id: 4,
      type: 'FletQuillToolbar',
      properties: {'controller_id': 'standalone-test'},
      backend: backend,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            FletQuillToolbarControl(control: toolbar),
            Expanded(child: FletQuillEditorControl(control: editor)),
          ],
        ),
      ),
    ));
    await tester.pump();

    final quillToolbar = tester.widget<QuillSimpleToolbar>(
      find.byType(QuillSimpleToolbar),
    );
    expect(quillToolbar.config.customButtons, isEmpty);
    expect(find.byIcon(Icons.insert_page_break), findsNothing);
    expect(quillToolbar.controller.document.toPlainText(), 'Hello\n');
  });
}
