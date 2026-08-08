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

    page_width = 400
    page_height = 300
    page_spacing = 100

    async def save_editor(_):
        print(await editor.save())

    async def insert_page_break(_):
        await editor.page_break()

    # ── Shared toolbar ─────────────────────────────────────────────────────
    toolbar = FletQuillToolbar(
        controller_id=PAGE_1,  # starts controlling page 1
        show_toolbar_divider=True,
        font_sizes=[16, 24, 20],
        toolbar_buttons=[
            ft.IconButton(
                icon=ft.Icons.SAVE,
                tooltip="Print Delta",
                on_click=save_editor,
            ),
            ft.IconButton(
                icon=ft.Icons.INSERT_PAGE_BREAK,
                tooltip="Insert page break",
                on_click=insert_page_break,
            ),
        ],
    )

    editor = FletQuillEditor(
        controller_id=PAGE_1,
        placeholder_text="Page 1 — click here to edit",
        text_data=[{"insert": "Page 1 content\n"}],
        page_width=page_width,
        page_height=page_height,
        page_spacing=page_spacing,
        page_color=ft.Colors.SURFACE_CONTAINER_HIGHEST,
        border=ft.Border.all(1, ft.Colors.BLACK),
        border_radius=10,
        padding=12,
        auto_page_breaks=True,
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
