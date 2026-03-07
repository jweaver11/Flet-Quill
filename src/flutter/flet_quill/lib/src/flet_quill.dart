import 'package:flet/flet.dart';
import 'package:flutter/material.dart';

class FletQuillControl extends StatelessWidget {
  final Control control;

  const FletQuillControl({
    super.key,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    String placeholder_text = control.getString("placeholder_text", "")!;
    String file_path = control.getString("file_path", "")!;
    final show_toolbar_divider = control.getBool("show_toolbar_divider", true)!;
    String tooltip = control.getString("tooltip", "Could not read tooltip")!;
    final String center_toolbar = control.getBool("center_toolbar", false) == true ? "Yes" : "No";

    final text_data = control.getString(
      "text_data",
      [{"insert": "Hello, world!\\n"}].toString(),
    )!;

    final toolbarButtonControls = control.children("toolbar_buttons");

    final toolbarButtons = toolbarButtonControls
        .map((child) => ControlWidget(control: child))
        .toList();

    Widget myControl = Column(
      children: [
              Text(placeholder_text),
              Text("File path: $file_path"),
              Text("Show toolbar divider: $show_toolbar_divider"),
              Text("Tooltip: $tooltip"),
              Text("Center toolbar: $center_toolbar"),
              Text("Text data: $text_data"),
              Row(children: toolbarButtons)
            ]
        ,
    );

    return LayoutControl(control: control, child: myControl);
  }
}
