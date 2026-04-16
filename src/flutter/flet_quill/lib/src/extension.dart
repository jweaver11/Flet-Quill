import 'package:flet/flet.dart';
import 'package:flutter/widgets.dart';

import 'flet_quill.dart';

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "FletQuill":
        return FletQuillControl(control: control);
      case "FletQuillEditor":
        return FletQuillEditorControl(control: control);
      case "FletQuillToolbar":
        return FletQuillToolbarControl(control: control);
      default:
        return null;
    }
  }
}
