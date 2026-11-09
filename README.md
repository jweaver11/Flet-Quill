# flet-quill
FletQuill control for Flet

## Installation

Add dependency to `pyproject.toml` of your Flet app:

* **Git dependency**

Link to git repository:

```
dependencies = [
  "flet-quill @ git+https://github.com/MyGithubAccount/flet-quill",
  "flet>=0.81.0",
]

# If you get build errors, add these to pyproject.toml
[tool.flet.flutter.pubspec.dependency_overrides.flutter_colorpicker.git]
url = "https://github.com/flet-dev/flutter_colorpicker"
ref = "material-ui"
```


* **uv/pip dependency**  

If the package is published on pypi.org:

```
dependencies = [
  "flet-quill",
  "flet>=0.81.0",
]
```

Build your app:
```
flet build macos -v
```

## Documentation

[Link to documentation](https://MyGithubAccount.github.io/flet-quill/)

## Editor content

`FletQuill` and `FletQuillEditor` accept initial content through `text_data`
as a list of Quill Delta operations, for example:

```python
editor = FletQuillEditor(text_data=[{"insert": "Hello, world!\n"}])
delta_ops = await editor.save()
```

Omit `text_data` to start with an empty document. `save()` returns the current
Delta operations; it does not write a file. File paths, JSON strings, and
other document formats are not supported as editor input or output. Applications
that need file storage or format conversion must implement those separately.

## Toolbar buttons

`FletQuillToolbar` accepts a `toolbar_buttons` list of regular Flet controls.
Those controls are rendered after the built-in Quill formatting toolbar, which
lets you add app-specific actions such as save/export/page-break buttons.

Set `show_line_height_button=True` to add Flutter Quill's line-height dropdown
to either `FletQuill` or `FletQuillToolbar`.

Both toolbar variants include an **Insert page break** button. It inserts a
`page-break` block embed, rendered as a faded dashed divider that fills the
available editor width.

```python
toolbar = FletQuillToolbar(
  controller_id="page_1",
  show_line_height_button=True,
  toolbar_buttons=[
    ft.IconButton(icon=ft.Icons.SAVE, on_click=save_editor),
    ft.IconButton(icon=ft.Icons.INSERT_PAGE_BREAK, on_click=insert_page_break),
  ],
)
```
