import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:async';
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

double _resolvePageHeight(Control control) {
  return control.getDouble('page_height') ??
      control.getDouble('page_break_height') ??
      40.0;
}

double _resolvePageGap(Control control) {
  return control.getDouble('page_spacing') ??
      control.getDouble('page_break_gap') ??
      0.0;
}

double? _resolvePageWidth(Control control) {
  return control.getDouble('page_width');
}

class PageSlice {
  final int startOffset;
  final int endOffset;
  final double contentHeight;

  const PageSlice({
    required this.startOffset,
    required this.endOffset,
    required this.contentHeight,
  });
}

class PaginatedLayout {
  final List<PageSlice> pages;
  const PaginatedLayout(this.pages);
}

class _LayoutBlock {
  final int startOffset;
  final int endOffset;
  final String text;
  final bool isManualBreak;

  const _LayoutBlock({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.isManualBreak,
  });
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

Color? _parseColor(dynamic value) {
  if (value == null) return null;
  if (value is int) return Color(value);
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) {
      final hex = s.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    if (s.startsWith('0x') || s.startsWith('0X')) {
      return Color(int.parse(s.substring(2), radix: 16));
    }

    final named = _parseNamedColor(s);
    if (named != null) {
      return named;
    }
  }
  return null;
}

Color? _parseNamedColor(String token) {
  final key = token.toLowerCase();
  const named = <String, Color>{
    'black': Colors.black,
    'white': Colors.white,
    'transparent': Colors.transparent,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'brown': Colors.brown,
    'grey': Colors.grey,
    'gray': Colors.grey,
  };
  return named[key];
}

Color? _parseThemeColorToken(BuildContext context, String token) {
  final c = Theme.of(context).colorScheme;
  switch (token.toLowerCase()) {
    case 'primary':
      return c.primary;
    case 'on_primary':
      return c.onPrimary;
    case 'primary_container':
      return c.primaryContainer;
    case 'on_primary_container':
      return c.onPrimaryContainer;
    case 'secondary':
      return c.secondary;
    case 'on_secondary':
      return c.onSecondary;
    case 'secondary_container':
      return c.secondaryContainer;
    case 'on_secondary_container':
      return c.onSecondaryContainer;
    case 'tertiary':
      return c.tertiary;
    case 'on_tertiary':
      return c.onTertiary;
    case 'tertiary_container':
      return c.tertiaryContainer;
    case 'on_tertiary_container':
      return c.onTertiaryContainer;
    case 'error':
      return c.error;
    case 'on_error':
      return c.onError;
    case 'error_container':
      return c.errorContainer;
    case 'on_error_container':
      return c.onErrorContainer;
    case 'surface':
      return c.surface;
    case 'on_surface':
      return c.onSurface;
    case 'surface_dim':
      return c.surfaceDim;
    case 'surface_bright':
      return c.surfaceBright;
    case 'surface_container_lowest':
      return c.surfaceContainerLowest;
    case 'surface_container_low':
      return c.surfaceContainerLow;
    case 'surface_container':
      return c.surfaceContainer;
    case 'surface_container_high':
      return c.surfaceContainerHigh;
    case 'surface_container_highest':
      return c.surfaceContainerHighest;
    case 'surface_variant':
      return c.surfaceVariant;
    case 'on_surface_variant':
      return c.onSurfaceVariant;
    case 'outline':
      return c.outline;
    case 'outline_variant':
      return c.outlineVariant;
    case 'shadow':
      return c.shadow;
    case 'scrim':
      return c.scrim;
    case 'inverse_surface':
      return c.inverseSurface;
    case 'on_inverse_surface':
      return c.onInverseSurface;
    case 'inverse_primary':
      return c.inversePrimary;
    default:
      return null;
  }
}

Color? _parseColorWithContext(BuildContext context, dynamic value) {
  final direct = _parseColor(value);
  if (direct != null) return direct;
  if (value is String) {
    return _parseThemeColorToken(context, value.trim());
  }
  return null;
}

Color _resolvePageColor(BuildContext context, Control control) {
  return _parseColorWithContext(context, control.get('page_color')) ??
      Theme.of(context).colorScheme.surface;
}

EdgeInsets _resolvePagePadding(Control control) {
  final raw = control.get('padding');
  if (raw == null) return EdgeInsets.zero;
  if (raw is num || raw is String) {
    final all = _asDouble(raw);
    return EdgeInsets.all(all);
  }
  if (raw is Map) {
    final left = _asDouble(raw['l'] ?? raw['left']);
    final top = _asDouble(raw['t'] ?? raw['top']);
    final right = _asDouble(raw['r'] ?? raw['right']);
    final bottom = _asDouble(raw['b'] ?? raw['bottom']);
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }
  return EdgeInsets.zero;
}

BorderSide _parseBorderSide(BuildContext context, dynamic rawSide) {
  if (rawSide is Map) {
    final width = _asDouble(rawSide['w'] ?? rawSide['width'], 1.0);
    final color =
        _parseColorWithContext(context, rawSide['c'] ?? rawSide['color']) ??
            Theme.of(context).colorScheme.outlineVariant;
    return BorderSide(width: width, color: color);
  }
  return BorderSide(
    color: Theme.of(context).colorScheme.outlineVariant,
    width: 1,
  );
}

Border? _resolvePageBorder(BuildContext context, Control control) {
  final raw = control.get('border');
  if (raw == null) return null;
  if (raw is num || raw is String) {
    final color = _parseColorWithContext(context, raw) ??
        Theme.of(context).colorScheme.outlineVariant;
    return Border.all(width: _asDouble(raw, 1.0), color: color);
  }
  if (raw is Map) {
    if (raw.containsKey('l') ||
        raw.containsKey('t') ||
        raw.containsKey('r') ||
        raw.containsKey('b') ||
        raw.containsKey('left') ||
        raw.containsKey('top') ||
        raw.containsKey('right') ||
        raw.containsKey('bottom')) {
      return Border(
        left: _parseBorderSide(context, raw['l'] ?? raw['left']),
        top: _parseBorderSide(context, raw['t'] ?? raw['top']),
        right: _parseBorderSide(context, raw['r'] ?? raw['right']),
        bottom: _parseBorderSide(context, raw['b'] ?? raw['bottom']),
      );
    }
    final width = _asDouble(raw['w'] ?? raw['width'], 1.0);
    final color = _parseColorWithContext(context, raw['c'] ?? raw['color']) ??
        Theme.of(context).colorScheme.outlineVariant;
    return Border.all(width: width, color: color);
  }
  return null;
}

BorderRadius? _resolvePageBorderRadius(Control control) {
  final raw = control.get('border_radius');
  if (raw == null) return null;
  if (raw is num || raw is String) {
    return BorderRadius.circular(_asDouble(raw));
  }
  if (raw is Map) {
    final tl = _asDouble(raw['tl'] ?? raw['topLeft']);
    final tr = _asDouble(raw['tr'] ?? raw['topRight']);
    final bl = _asDouble(raw['bl'] ?? raw['bottomLeft']);
    final br = _asDouble(raw['br'] ?? raw['bottomRight']);
    return BorderRadius.only(
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomLeft: Radius.circular(bl),
      bottomRight: Radius.circular(br),
    );
  }
  return null;
}

List<_LayoutBlock> _buildLayoutBlocks(Document document) {
  final blocks = <_LayoutBlock>[];
  final ops = document.toDelta().toJson();
  var offset = 0;
  var blockStart = 0;
  var textBuffer = StringBuffer();

  void flushTextBlock() {
    if (textBuffer.isEmpty) return;
    blocks.add(
      _LayoutBlock(
        startOffset: blockStart,
        endOffset: offset,
        text: textBuffer.toString(),
        isManualBreak: false,
      ),
    );
    textBuffer = StringBuffer();
    blockStart = offset;
  }

  for (final rawOp in ops) {
    final op = rawOp as Map;
    final insert = op['insert'];
    if (insert is String) {
      if (textBuffer.isEmpty) {
        blockStart = offset;
      }
      for (var i = 0; i < insert.length; i++) {
        final ch = insert[i];
        textBuffer.write(ch);
        offset += 1;
        if (ch == '\n') {
          flushTextBlock();
        }
      }
      continue;
    }

    flushTextBlock();

    if (insert is Map && insert.containsKey('page_break')) {
      blocks.add(
        _LayoutBlock(
          startOffset: offset,
          endOffset: offset + 1,
          text: '',
          isManualBreak: true,
        ),
      );
      offset += 1;
      blockStart = offset;
      continue;
    }

    blocks.add(
      _LayoutBlock(
        startOffset: offset,
        endOffset: offset + 1,
        text: '\uFFFC',
        isManualBreak: false,
      ),
    );
    offset += 1;
    blockStart = offset;
  }

  flushTextBlock();
  return blocks;
}

double _measureBlockHeight({
  required String text,
  required TextStyle baseStyle,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text.isEmpty ? ' ' : text, style: baseStyle),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

PaginatedLayout _paginateDocument({
  required Document document,
  required double usableHeight,
  required double contentWidth,
  required TextStyle baseStyle,
}) {
  if (usableHeight <= 0 || contentWidth <= 0) {
    return const PaginatedLayout([
      PageSlice(startOffset: 0, endOffset: 0, contentHeight: 0),
    ]);
  }

  final blocks = _buildLayoutBlocks(document);
  if (blocks.isEmpty) {
    return const PaginatedLayout([
      PageSlice(startOffset: 0, endOffset: 0, contentHeight: 0),
    ]);
  }

  final pages = <PageSlice>[];
  var pageStart = 0;
  var currentEnd = 0;
  var usedHeight = 0.0;

  for (final block in blocks) {
    if (block.isManualBreak) {
      if (currentEnd > pageStart || usedHeight > 0) {
        pages.add(
          PageSlice(
            startOffset: pageStart,
            endOffset: currentEnd,
            contentHeight: usedHeight,
          ),
        );
      }
      pageStart = block.endOffset;
      currentEnd = block.endOffset;
      usedHeight = 0;
      continue;
    }

    final blockHeight = _measureBlockHeight(
      text: block.text,
      baseStyle: baseStyle,
      maxWidth: contentWidth,
    );

    final fitsCurrentPage = usedHeight + blockHeight <= usableHeight;
    if (fitsCurrentPage) {
      usedHeight += blockHeight;
      currentEnd = block.endOffset;
      continue;
    }

    if (usedHeight > 0) {
      pages.add(
        PageSlice(
          startOffset: pageStart,
          endOffset: currentEnd,
          contentHeight: usedHeight,
        ),
      );
      pageStart = currentEnd;
      usedHeight = 0;
    }

    usedHeight = blockHeight;
    currentEnd = block.endOffset;

    if (blockHeight > usableHeight) {
      pages.add(
        PageSlice(
          startOffset: pageStart,
          endOffset: currentEnd,
          contentHeight: usedHeight,
        ),
      );
      pageStart = currentEnd;
      usedHeight = 0;
    }
  }

  if (currentEnd > pageStart || usedHeight > 0) {
    pages.add(
      PageSlice(
        startOffset: pageStart,
        endOffset: currentEnd,
        contentHeight: usedHeight,
      ),
    );
  }

  if (pages.isEmpty) {
    final endOffset = document.length > 0 ? document.length - 1 : 0;
    pages.add(
      PageSlice(startOffset: 0, endOffset: endOffset, contentHeight: 0),
    );
  }

  return PaginatedLayout(pages);
}

bool _samePaginatedLayout(PaginatedLayout a, PaginatedLayout b) {
  if (a.pages.length != b.pages.length) return false;
  for (var i = 0; i < a.pages.length; i++) {
    final ap = a.pages[i];
    final bp = b.pages[i];
    if (ap.startOffset != bp.startOffset || ap.endOffset != bp.endOffset) {
      return false;
    }
    if ((ap.contentHeight - bp.contentHeight).abs() > 0.5) {
      return false;
    }
  }
  return true;
}

class _PageSurfaceStack extends StatelessWidget {
  const _PageSurfaceStack({
    required this.pageCount,
    required this.pageHeight,
    required this.pageGap,
    required this.pageWidth,
    required this.pageColor,
    required this.pageBorder,
    required this.pageBorderRadius,
    required this.pagePadding,
    required this.child,
  });

  final int pageCount;
  final double pageHeight;
  final double pageGap;
  final double? pageWidth;
  final Color pageColor;
  final Border? pageBorder;
  final BorderRadius? pageBorderRadius;
  final EdgeInsets pagePadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(pageCount, (index) {
              final page = Container(
                width: pageWidth,
                height: pageHeight,
                decoration: BoxDecoration(
                  color: pageColor,
                  borderRadius: pageBorderRadius,
                  border: pageBorder,
                ),
              );

              if (index == pageCount - 1 || pageGap <= 0) {
                return page;
              }
              return Padding(
                padding: EdgeInsets.only(bottom: pageGap),
                child: page,
              );
            }),
          ),
        ),
        SizedBox(
          width: pageWidth,
          child: Padding(
            padding: pagePadding,
            child: child,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page break embed.
// Stored in Delta as: {"insert": {"page_break": "auto:<pageHeight>:<gap>"}}
// Older documents may store a raw numeric value; that is treated as page
// height for backward compatibility.
// ---------------------------------------------------------------------------
class PageBreakEmbedBuilder extends EmbedBuilder {
  const PageBreakEmbedBuilder();

  @override
  String get key => 'page_break';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: 16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FletQuillControl extends StatefulWidget {
  final Control control;

  const FletQuillControl({super.key, required this.control});

  @override
  State<FletQuillControl> createState() => _FletQuillControlState();
}

class _FletQuillControlState extends State<FletQuillControl> {
  late QuillController _controller;
  late FocusNode _focusNode;
  PaginatedLayout _layout = const PaginatedLayout([
    PageSlice(startOffset: 0, endOffset: 0, contentHeight: 0),
  ]);
  StreamSubscription? _changeSubscription;
  Timer? _paginationDebounce;
  bool _paginationScheduled = false;
  double _contentWidth = 0.0;
  double _usableHeight = 0.0;
  TextStyle _baseStyle = const TextStyle(fontSize: 16);

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
    _changeSubscription = _controller.changes.listen((_) {
      _schedulePagination();
    });
    _schedulePagination();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name == 'get_delta') {
      return jsonEncode(_controller.document.toDelta().toJson());
    }
    if (name == 'insert_page_break') {
      final index = _controller.selection.baseOffset;
      final len = _controller.selection.extentOffset - index;
      _controller.replaceText(
        index,
        len,
        BlockEmbed('page_break', 'manual'),
        TextSelection.collapsed(offset: index + 1),
      );
      return null;
    }
    throw Exception('Unknown FletQuill method: $name');
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _changeSubscription?.cancel();
    _paginationDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _schedulePagination() {
    _paginationDebounce?.cancel();
    _paginationDebounce = Timer(const Duration(milliseconds: 80), () {
      if (_paginationScheduled) return;
      _paginationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _paginationScheduled = false;
        _rebuildPagination();
      });
    });
  }

  void _updatePaginationInputs({
    required double contentWidth,
    required double usableHeight,
    required TextStyle baseStyle,
  }) {
    final widthChanged = (contentWidth - _contentWidth).abs() > 0.5;
    final heightChanged = (usableHeight - _usableHeight).abs() > 0.5;
    final styleChanged = _baseStyle != baseStyle;
    if (!widthChanged && !heightChanged && !styleChanged) {
      return;
    }
    _contentWidth = contentWidth;
    _usableHeight = usableHeight;
    _baseStyle = baseStyle;
    _schedulePagination();
  }

  void _rebuildPagination() {
    if (!mounted || _contentWidth <= 0 || _usableHeight <= 0) {
      return;
    }
    final nextLayout = _paginateDocument(
      document: _controller.document,
      usableHeight: _usableHeight,
      contentWidth: _contentWidth,
      baseStyle: _baseStyle,
    );
    if (!_samePaginatedLayout(_layout, nextLayout)) {
      setState(() {
        _layout = nextLayout;
      });
    }
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
    final pageHeight = _resolvePageHeight(widget.control);
    final pageGap = _resolvePageGap(widget.control);
    final pageWidth = _resolvePageWidth(widget.control);
    final pageColor = _resolvePageColor(context, widget.control);
    final pageBorder = _resolvePageBorder(context, widget.control);
    final pageBorderRadius = _resolvePageBorderRadius(widget.control);
    final pagePadding = _resolvePagePadding(widget.control);
    final usableHeight = (pageHeight - pagePadding.vertical)
        .clamp(1.0, double.infinity)
        .toDouble();

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final resolvedPageWidth = pageWidth ?? constraints.maxWidth;
                  final contentWidth =
                      (resolvedPageWidth - pagePadding.horizontal)
                          .clamp(1.0, double.infinity)
                          .toDouble();
                  _updatePaginationInputs(
                    contentWidth: contentWidth,
                    usableHeight: usableHeight,
                    baseStyle: DefaultTextStyle.of(context).style,
                  );

                  return _PageSurfaceStack(
                    pageCount: _layout.pages.isEmpty ? 1 : _layout.pages.length,
                    pageHeight: pageHeight,
                    pageGap: pageGap,
                    pageWidth: pageWidth,
                    pageColor: pageColor,
                    pageBorder: pageBorder,
                    pageBorderRadius: pageBorderRadius,
                    pagePadding: pagePadding,
                    child: QuillEditor.basic(
                      focusNode: _focusNode,
                      controller: _controller,
                      config: QuillEditorConfig(
                        placeholder: placeholderText,
                        embedBuilders: const [PageBreakEmbedBuilder()],
                      ),
                    ),
                  );
                },
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
  PaginatedLayout _layout = const PaginatedLayout([
    PageSlice(startOffset: 0, endOffset: 0, contentHeight: 0),
  ]);
  StreamSubscription? _changeSubscription;
  Timer? _paginationDebounce;
  bool _paginationScheduled = false;
  double _contentWidth = 0.0;
  double _usableHeight = 0.0;
  TextStyle _baseStyle = const TextStyle(fontSize: 16);

  void _syncEntry() {
    final id = widget.control.getString('controller_id', 'default')!;
    if (id == _currentControllerId) return;
    final oldController = _entry?.controller;
    _currentControllerId = id;
    _entry = QuillControllerRegistry().getOrCreate(
      id,
      initialDocument: _parseDocument(widget.control),
    );
    if (oldController != _entry?.controller) {
      _changeSubscription?.cancel();
      _changeSubscription = _entry?.controller.changes.listen((_) {
        _schedulePagination();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _syncEntry();
    widget.control.addInvokeMethodListener(_invokeMethod);
    _schedulePagination();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name == 'get_delta') {
      return jsonEncode(_entry!.controller.document.toDelta().toJson());
    }
    if (name == 'insert_page_break') {
      final controller = _entry!.controller;
      final index = controller.selection.baseOffset;
      final len = controller.selection.extentOffset - index;
      controller.replaceText(
        index,
        len,
        BlockEmbed('page_break', 'manual'),
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
    _schedulePagination();
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    _changeSubscription?.cancel();
    _paginationDebounce?.cancel();
    super.dispose();
  }

  void _schedulePagination() {
    _paginationDebounce?.cancel();
    _paginationDebounce = Timer(const Duration(milliseconds: 80), () {
      if (_paginationScheduled) return;
      _paginationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _paginationScheduled = false;
        _rebuildPagination();
      });
    });
  }

  void _updatePaginationInputs({
    required double contentWidth,
    required double usableHeight,
    required TextStyle baseStyle,
  }) {
    final widthChanged = (contentWidth - _contentWidth).abs() > 0.5;
    final heightChanged = (usableHeight - _usableHeight).abs() > 0.5;
    final styleChanged = _baseStyle != baseStyle;
    if (!widthChanged && !heightChanged && !styleChanged) {
      return;
    }
    _contentWidth = contentWidth;
    _usableHeight = usableHeight;
    _baseStyle = baseStyle;
    _schedulePagination();
  }

  void _rebuildPagination() {
    final controller = _entry?.controller;
    if (!mounted ||
        controller == null ||
        _contentWidth <= 0 ||
        _usableHeight <= 0) {
      return;
    }
    final nextLayout = _paginateDocument(
      document: controller.document,
      usableHeight: _usableHeight,
      contentWidth: _contentWidth,
      baseStyle: _baseStyle,
    );
    if (!_samePaginatedLayout(_layout, nextLayout)) {
      setState(() {
        _layout = nextLayout;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.control.getString('placeholder_text', '')!;
    final pageHeight = _resolvePageHeight(widget.control);
    final pageGap = _resolvePageGap(widget.control);
    final pageWidth = _resolvePageWidth(widget.control);
    final pageColor = _resolvePageColor(context, widget.control);
    final pageBorder = _resolvePageBorder(context, widget.control);
    final pageBorderRadius = _resolvePageBorderRadius(widget.control);
    final pagePadding = _resolvePagePadding(widget.control);
    final usableHeight = (pageHeight - pagePadding.vertical)
        .clamp(1.0, double.infinity)
        .toDouble();

    return LayoutControl(
      control: widget.control,
      child: Localizations.override(
        context: context,
        delegates: const [FlutterQuillLocalizations.delegate],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final resolvedPageWidth = pageWidth ?? constraints.maxWidth;
            final contentWidth = (resolvedPageWidth - pagePadding.horizontal)
                .clamp(1.0, double.infinity)
                .toDouble();
            _updatePaginationInputs(
              contentWidth: contentWidth,
              usableHeight: usableHeight,
              baseStyle: DefaultTextStyle.of(context).style,
            );

            return _PageSurfaceStack(
              pageCount: _layout.pages.isEmpty ? 1 : _layout.pages.length,
              pageHeight: pageHeight,
              pageGap: pageGap,
              pageWidth: pageWidth,
              pageColor: pageColor,
              pageBorder: pageBorder,
              pageBorderRadius: pageBorderRadius,
              pagePadding: pagePadding,
              child: QuillEditor.basic(
                focusNode: _entry!.focusNode,
                controller: _entry!.controller,
                config: QuillEditorConfig(
                  placeholder: placeholder,
                  embedBuilders: const [PageBreakEmbedBuilder()],
                ),
              ),
            );
          },
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
