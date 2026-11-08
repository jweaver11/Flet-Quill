# Introduction

FletQuill for Flet.

## Examples

```
import flet as ft

from flet_quill import FletQuill


def main(page: ft.Page):
    page.vertical_alignment = ft.MainAxisAlignment.CENTER
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER

    page.add(

                ft.Container(height=150, width=300, alignment = ft.Alignment.CENTER, bgcolor=ft.Colors.PURPLE_200, content=FletQuill(
                    tooltip="My new FletQuill Control tooltip",
                    text_data=[{"insert": "My new FletQuill Flet Control\n"}],
                ),),

    )


ft.run(main)
```

## Classes

[FletQuill](FletQuill.md)

