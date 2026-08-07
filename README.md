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

## Toolbar buttons

`FletQuillToolbar` accepts a `toolbar_buttons` list of regular Flet controls.
Those controls are rendered after the built-in Quill formatting toolbar, which
lets you add app-specific actions such as save/export/page-break buttons.

```python
toolbar = FletQuillToolbar(
  controller_id="page_1",
  toolbar_buttons=[
    ft.IconButton(icon=ft.Icons.SAVE, on_click=save_editor),
    ft.IconButton(icon=ft.Icons.INSERT_PAGE_BREAK, on_click=insert_page_break),
  ],
)
```
