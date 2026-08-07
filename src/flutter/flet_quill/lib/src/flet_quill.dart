import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:convert';

// ---------------------------------------------------------------------------
// Image paste blocking — top-level so they work in const QuillClipboardConfig.
// ---------------------------------------------------------------------------
Future<String?> _rejectImagePaste(Uint8List _) async => null;

Future<Delta?> _stripImagesFromDelta(Delta delta, bool isExternal) async {
  final ops = delta.toJson();
  final filtered = <dynamic>[];
  for (final op in ops) {
    final opMap = op;
    final insert = opMap['insert'];
    if (insert is Map &&
        (insert.containsKey('image') || insert.containsKey('video'))) {
      continue;
    }
    filtered.add(opMap);
  }
  return Delta.fromJson(filtered);
}

// Font size items shown in the toolbar dropdown (display label → stored value).
const _kFontSizeItems = {
  '8': '8',
  '10': '10',
  '12': '12',
  '14': '14',
  '16': '16',
  '20': '20',
  '24': '24',
  '32': '32',
  '48': '48',
  '64': '64',
};

// Parse a font_sizes list from the control (e.g. [8, 10, 12, 16]) into the
// Map<String, String> format expected by QuillToolbarFontSizeButtonOptions.
Map<String, String> _parseFontSizes(Control control) {
  final raw = control.get('font_sizes');
  if (raw == null) return _kFontSizeItems;
  final list = raw is List ? raw : <dynamic>[];
  if (list.isEmpty) return _kFontSizeItems;
  return {for (final s in list) s.toString(): s.toString()};
}

// ---------------------------------------------------------------------------
// Registry entry — a controller + focus node for one logical editor.
// ---------------------------------------------------------------------------
class _EditorEntry {
  final QuillController controller;
  final FocusNode focusNode;
  _EditorEntry({required this.controller, required this.focusNode});
}

// ---------------------------------------------------------------------------
// Shared registry — lets toolbar and editors pair via a controller_id string.
// ---------------------------------------------------------------------------
class QuillControllerRegistry extends ChangeNotifier {
  static final QuillControllerRegistry _instance =
      QuillControllerRegistry._internal();
  factory QuillControllerRegistry() => _instance;
  QuillControllerRegistry._internal();

  final Map<String, _EditorEntry> _entries = {};

  _EditorEntry getOrCreate(String id, {Document? initialDocument}) {
    if (!_entries.containsKey(id)) {
      final controller = QuillController(
        document: initialDocument ?? Document(),
        selection: const TextSelection.collapsed(offset: 0),
        config: const QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(
            onImagePaste: _rejectImagePaste,
            onRichTextPaste: _stripImagesFromDelta,
          ),
        ),
      );
      _entries[id] = _EditorEntry(
        controller: controller,
        focusNode: FocusNode(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
    return _entries[id]!;
  }

  QuillController? getController(String id) => _entries[id]?.controller;
  FocusNode? getFocusNode(String id) => _entries[id]?.focusNode;
}

// ---------------------------------------------------------------------------
// Document parsing.
//
// Flet's Python→Dart msgpack transport sends list[dict] fields as a raw
// Dart List<dynamic> where each dict is Map<dynamic, dynamic> (NOT
// Map<String, dynamic>). Using .cast<Map<String,dynamic>>() throws at
// runtime. We must convert each entry explicitly with Map.from().
// ---------------------------------------------------------------------------
Document _parseDocument(Control control) {
  final raw = control.get('text_data');
  if (raw == null) return Document();
  try {
    final List<dynamic> ops;
    if (raw is List) {
      ops = raw;
    } else if (raw is String) {
      ops = jsonDecode(raw) as List;
    } else {
      return Document();
    }
    final typed = ops.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Document.fromJson(typed);
  } catch (_) {
    return Document();
  }
}

// ---------------------------------------------------------------------------
// Shared toolbar config builder.
// ---------------------------------------------------------------------------
QuillSimpleToolbarConfig _toolbarConfig({
  required bool showDividers,
  Map<String, String> fontSizeItems = _kFontSizeItems,
  VoidCallback? afterButtonPressed,
}) {
  return QuillSimpleToolbarConfig(
    showDividers: showDividers,
    showSearchButton: false,
    showFontFamily: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showLink: false,
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        afterButtonPressed: afterButtonPressed,
      ),
      fontSize: QuillToolbarFontSizeButtonOptions(items: fontSizeItems),
    ),
  );
}

// Post-frame focus request helper.
void _requestFocus(FocusNode node) {
  WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
}

List<Widget> _buildToolbarButtons(Control control) {
  return control.buildWidgets('toolbar_buttons');
}

// ---------------------------------------------------------------------------
// Page break embed.
// Stored in Delta as: {"insert": {"page_break": "<height>"}}
// The height string is the logical-pixel height set at insertion time.
// ---------------------------------------------------------------------------
class PageBreakEmbedBuilder extends EmbedBuilder {
  const PageBreakEmbedBuilder();

  @override
  String get key => 'page_break';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final height =
        double.tryParse(embedContext.node.value.data.toString()) ?? 40.0;
    return _PageBreakWidget(height: height);
  }
}

class _PageBreakWidget extends StatelessWidget {
  const _PageBreakWidget({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: height);
  }
}

// ---------------------------------------------------------------------------
// FletQuill — combined toolbar + editor (original single-widget API).
// ---------------------------------------------------------------------------
class FletQuillControl extends StatefulWidget {
  final Control control;

  const FletQuillControl({super.key, required this.control});

  @override
  State<FletQuillControl> createState() => _FletQuillControlState();
}

class _FletQuillControlState extends State<FletQuillControl> {
  late QuillController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: _parseDocument(widget.control),
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          onImagePaste: _rejectImagePaste,
          onRichTextPaste: _stripImagesFromDelta,
        ),
      ),
    );
    _focusNode = FocusNode();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name == 'get_delta') {
      return jsonEncode(_controller.document.toDelta().toJson());
    }
    if (name == 'insert_page_break') {
      final height = widget.control.getDouble('page_break_height') ?? 40.0;
      final index = _controller.selection.baseOffset;
      final len = _controller.selection.extentOffset - index;
      _controller.replaceText(
        index,
        len,
        BlockEmbed('page_break', height.toString()),
        TextSelection.collapsed(offset: index + 1),
      );
      return null;
    }
    throw Exception('Unknown FletQuill method: $name');
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholderText = widget.control.getString('placeholder_text', '')!;
    final showToolbarDivider = widget.control.getBool(
      'show_toolbar_divider',
      true,
    )!;
    final centerToolbar = widget.control.getBool('center_toolbar', false)!;
    final fontSizeItems = _parseFontSizes(widget.control);
    final toolbarButtons = _buildToolbarButtons(widget.control);

    return LayoutControl(
      control: widget.control,
      child: Localizations.override(
        context: context,
        delegates: const [FlutterQuillLocalizations.delegate],
        child: Column(
          crossAxisAlignment: centerToolbar
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuillSimpleToolbar(
                  controller: _controller,
                  config: _toolbarConfig(
                    showDividers: showToolbarDivider,
                    fontSizeItems: fontSizeItems,
                    afterButtonPressed: () => _requestFocus(_focusNode),
                  ),
                ),
                ...toolbarButtons,
              ],
            ),
            Expanded(
              child: QuillEditor.basic(
                focusNode: _focusNode,
                controller: _controller,
                config: QuillEditorConfig(
                  placeholder: placeholderText,
                  embedBuilders: const [PageBreakEmbedBuilder()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FletQuillEditor — standalone editor participating in the shared registry.
// ---------------------------------------------------------------------------
class FletQuillEditorControl extends StatefulWidget {
  final Control control;

  const FletQuillEditorControl({super.key, required this.control});

  @override
  State<FletQuillEditorControl> createState() => _FletQuillEditorControlState();
}

class _FletQuillEditorControlState extends State<FletQuillEditorControl> {
  _EditorEntry? _entry;
  String? _currentControllerId;

  void _syncEntry() {
    final id = widget.control.getString('controller_id', 'default')!;
    if (id == _currentControllerId) return;
    _currentControllerId = id;
    _entry = QuillControllerRegistry().getOrCreate(
      id,
      initialDocument: _parseDocument(widget.control),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncEntry();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name == 'get_delta') {
      return jsonEncode(_entry!.controller.document.toDelta().toJson());
    }
    if (name == 'insert_page_break') {
      final height = widget.control.getDouble('page_break_height') ?? 40.0;
      final controller = _entry!.controller;
      final index = controller.selection.baseOffset;
      final len = controller.selection.extentOffset - index;
      controller.replaceText(
        index,
        len,
        BlockEmbed('page_break', height.toString()),
        TextSelection.collapsed(offset: index + 1),
      );
      return null;
    }
    throw Exception('Unknown FletQuillEditor method: $name');
  }

  @override
  void didUpdateWidget(FletQuillEditorControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntry();
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.control.getString('placeholder_text', '')!;

    return LayoutControl(
      control: widget.control,
      child: Localizations.override(
        context: context,
        delegates: const [FlutterQuillLocalizations.delegate],
        child: QuillEditor.basic(
          focusNode: _entry!.focusNode,
          controller: _entry!.controller,
          config: QuillEditorConfig(
            placeholder: placeholder,
            embedBuilders: const [PageBreakEmbedBuilder()],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FletQuillToolbar — standalone toolbar driving a registry controller.
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
    final controllerId = widget.control.getString('controller_id', 'default')!;
    final showDividers = widget.control.getBool('show_toolbar_divider', true)!;
    final centerToolbar = widget.control.getBool('center_toolbar', false)!;

    final fontSizeItems = _parseFontSizes(widget.control);
    final toolbarButtons = _buildToolbarButtons(widget.control);
    final controller = QuillControllerRegistry().getController(controllerId);
    final focusNode = QuillControllerRegistry().getFocusNode(controllerId);

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Localizations.override(
      context: context,
      delegates: const [FlutterQuillLocalizations.delegate],
      child: Row(
        mainAxisAlignment:
            centerToolbar ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          QuillSimpleToolbar(
            key: ValueKey(controllerId),
            controller: controller,
            config: _toolbarConfig(
              showDividers: showDividers,
              fontSizeItems: fontSizeItems,
              afterButtonPressed:
                  focusNode != null ? () => _requestFocus(focusNode) : null,
            ),
          ),
          ...toolbarButtons,
        ],
      ),
    );
  }
}
