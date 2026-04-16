import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:convert';

// Top-level function so it can be used in a const QuillClipboardConfig.
// Returning null tells flutter_quill to discard the pasted binary image.
Future<String?> _rejectImagePaste(Uint8List _) async => null;

// Strips image/video embed ops from an HTML-parsed Delta before it is
// inserted. This blocks the pasteHTML() path that runs before onImagePaste.
Future<Delta?> _stripImagesFromDelta(Delta delta, bool isExternal) async {
  final ops = delta.toJson();
  final filtered = <dynamic>[];
  for (final op in ops) {
    final opMap = op as Map<String, dynamic>;
    final insert = opMap['insert'];
    if (insert is Map &&
        (insert.containsKey('image') || insert.containsKey('video'))) {
      continue; // drop the embed op entirely
    }
    filtered.add(opMap);
  }
  return Delta.fromJson(filtered);
}

// ---------------------------------------------------------------------------
// Shared controller registry — lets a toolbar and multiple editors share the
// same QuillController by matching a string controller_id.
// ---------------------------------------------------------------------------
class QuillControllerRegistry extends ChangeNotifier {
  static final QuillControllerRegistry _instance =
      QuillControllerRegistry._internal();
  factory QuillControllerRegistry() => _instance;
  QuillControllerRegistry._internal();

  final Map<String, QuillController> _controllers = {};

  QuillController getOrCreate(String id, {Document? initialDocument}) {
    if (!_controllers.containsKey(id)) {
      _controllers[id] = QuillController(
        document: initialDocument ?? Document(),
        selection: const TextSelection.collapsed(offset: 0),
        config: const QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(
            onImagePaste: _rejectImagePaste,
            onRichTextPaste: _stripImagesFromDelta,
          ),
        ),
      );
      // Notify toolbar widgets that a new controller is available.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
    return _controllers[id]!;
  }

  QuillController? get(String id) => _controllers[id];
}

// ---------------------------------------------------------------------------
// Helper: parse text_data JSON string into a Document.
// ---------------------------------------------------------------------------
Document _parseDocument(String? textData) {
  if (textData == null) return Document();
  try {
    final ops = (jsonDecode(textData) as List).cast<Map<String, dynamic>>();
    return Document.fromJson(ops);
  } catch (_) {
    return Document();
  }
}

// ---------------------------------------------------------------------------
// FletQuill — combined toolbar + editor (original API, preserved for compat).
// ---------------------------------------------------------------------------
class FletQuillControl extends StatefulWidget {
  final Control control;

  const FletQuillControl({super.key, required this.control});

  @override
  State<FletQuillControl> createState() => _FletQuillControlState();
}

class _FletQuillControlState extends State<FletQuillControl> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    final textData = widget.control.getString('text_data', null);
    _controller = QuillController(
      document: _parseDocument(textData),
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          onImagePaste: _rejectImagePaste,
          onRichTextPaste: _stripImagesFromDelta,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholderText =
        widget.control.getString('placeholder_text', '')!;
    final showToolbarDivider =
        widget.control.getBool('show_toolbar_divider', true)!;
    final centerToolbar =
        widget.control.getBool('center_toolbar', false)!;

    final Widget myControl = Localizations.override(
      context: context,
      delegates: const [FlutterQuillLocalizations.delegate],
      child: Column(
        crossAxisAlignment: centerToolbar
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              showDividers: showToolbarDivider,
              showSearchButton: false,
              showFontFamily: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showLink: false,
            ),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: _controller,
              config: QuillEditorConfig(
                placeholder: placeholderText,
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutControl(control: widget.control, child: myControl);
  }
}

// ---------------------------------------------------------------------------
// FletQuillEditor — standalone editor that participates in the shared registry.
// ---------------------------------------------------------------------------
class FletQuillEditorControl extends StatefulWidget {
  final Control control;

  const FletQuillEditorControl({super.key, required this.control});

  @override
  State<FletQuillEditorControl> createState() =>
      _FletQuillEditorControlState();
}

class _FletQuillEditorControlState extends State<FletQuillEditorControl> {
  QuillController? _controller;
  String? _currentControllerId;

  void _syncController() {
    final id = widget.control.getString('controller_id', 'default')!;
    if (id == _currentControllerId) return;
    _currentControllerId = id;
    final textData = widget.control.getString('text_data', null);
    _controller = QuillControllerRegistry()
        .getOrCreate(id, initialDocument: _parseDocument(textData));
  }

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(FletQuillEditorControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.control.getString('placeholder_text', '')!;

    return LayoutControl(
      control: widget.control,
      child: Localizations.override(
        context: context,
        delegates: const [FlutterQuillLocalizations.delegate],
        child: QuillEditor.basic(
          controller: _controller!,
          config: QuillEditorConfig(
            placeholder: placeholder,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FletQuillToolbar — standalone toolbar that drives a registered controller.
// Listens to both the Flet control (for controller_id changes from Python)
// and the registry (for new editors registering), so it always reflects the
// active editor.
// ---------------------------------------------------------------------------
class FletQuillToolbarControl extends StatefulWidget {
  final Control control;

  const FletQuillToolbarControl({super.key, required this.control});

  @override
  State<FletQuillToolbarControl> createState() =>
      _FletQuillToolbarControlState();
}

class _FletQuillToolbarControlState extends State<FletQuillToolbarControl> {
  @override
  void initState() {
    super.initState();
    widget.control.addListener(_onChanged);
    QuillControllerRegistry().addListener(_onChanged);
  }

  @override
  void didUpdateWidget(FletQuillToolbarControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.control != widget.control) {
      oldWidget.control.removeListener(_onChanged);
      widget.control.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.control.removeListener(_onChanged);
    QuillControllerRegistry().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controllerId =
        widget.control.getString('controller_id', 'default')!;
    final showDividers =
        widget.control.getBool('show_toolbar_divider', true)!;
    final centerToolbar =
        widget.control.getBool('center_toolbar', false)!;

    final controller = QuillControllerRegistry().get(controllerId);

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Localizations.override(
      context: context,
      delegates: const [FlutterQuillLocalizations.delegate],
      child: Align(
        alignment:
            centerToolbar ? Alignment.center : Alignment.centerLeft,
        child: QuillSimpleToolbar(
          key: ValueKey(controllerId),
          controller: controller,
          config: QuillSimpleToolbarConfig(
            showDividers: showDividers,
            showSearchButton: false,
            showFontFamily: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showLink: false,
          ),
        ),
      ),
    );
  }
}
