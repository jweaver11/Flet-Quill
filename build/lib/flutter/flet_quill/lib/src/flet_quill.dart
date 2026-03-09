import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';

class FletQuillControl extends StatelessWidget {
  final Control control;

  const FletQuillControl({
    super.key,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    String placeholder_text = control.getString("placeholder_text", "")!;
    //String file_path = control.getString("file_path", "")!;
    final show_toolbar_divider = control.getBool("show_toolbar_divider", true)!;
    final center_toolbar = control.getBool("center_toolbar", false)!;

    final rawTextData = control.getString('text_data');

    final ops = rawTextData == null || rawTextData.isEmpty
        ? <Map<String, dynamic>>[
            {'insert': '\n'}
          ]
        : (jsonDecode(rawTextData) as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    final document = Document.fromJson(ops);
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    Widget myControl = Localizations(
      locale: const Locale('en'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      child: Column(
        crossAxisAlignment: center_toolbar
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
        children: [
          QuillSimpleToolbar(
            controller: controller,
            config: QuillSimpleToolbarConfig(
              showDividers: show_toolbar_divider,
              //customButtons: toolbarButtons,
              showSearchButton: false, // Broken buttons
              showFontFamily: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showLink: false,
            ),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: controller,
              config: QuillEditorConfig(
                
                placeholder: placeholder_text
              ),
            ),
          )
        ]
      )
    );

    return LayoutControl(control: control, child: myControl);
  }
}
