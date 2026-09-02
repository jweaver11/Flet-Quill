import flet as ft
import os, sys

src_dir = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..", "src")
)
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from flet_quill import FletQuill, FletQuillEditor, FletQuillToolbar

# IDs that connect toolbars to editors via the shared registry.
PAGE_1 = "page_1"
PAGE_2 = "page_2"


def main(page: ft.Page):
    page.title = "Flet-Quill Demo"
    page.vertical_alignment = ft.MainAxisAlignment.START
    page.horizontal_alignment = ft.CrossAxisAlignment.STRETCH

    async def save_editor(_):
        print(await editor.save())

    # ── Shared toolbar ─────────────────────────────────────────────────────
    toolbar = FletQuillToolbar(
        controller_id=PAGE_1,  # starts controlling page 1
        show_toolbar_divider=True,
        show_line_height_button=True,
        font_sizes=[16, 24, 20],
        toolbar_buttons=[
            ft.IconButton(
                icon=ft.Icons.SAVE,
                tooltip="Print Delta",
                on_click=save_editor,
            ),
            ft.IconButton(
                            icon=ft.Icons.SAVE,
                            tooltip="Print Delta",
                            on_click=save_editor,
                        ),
        ],
    )

    editor = FletQuillEditor(
        controller_id=PAGE_1,
        placeholder_text="Page 1 — click here to edit",
        text_data=[{"insert": "Page 1 content\n"}],
    )

    

    
    # Section 2: separate toolbar + multi-editor.
    page.add(
        
        toolbar,
        ft.Column([
            editor,
        ], scroll="auto"),
    )
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    


ft.run(main)
