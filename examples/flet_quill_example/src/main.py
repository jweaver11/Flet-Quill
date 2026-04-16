import flet as ft
import json, os, sys

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

    # ── Shared toolbar ─────────────────────────────────────────────────────
    toolbar = FletQuillToolbar(
        controller_id=PAGE_1,  # starts controlling page 1
        show_toolbar_divider=True,
    )

    editor1 = FletQuillEditor(
        controller_id=PAGE_1,
        placeholder_text="Page 1 — click here to edit",
        text_data=[{"insert": "Page 1 content\n"}],
        expand=True,
    )

    editor2 = FletQuillEditor(
        controller_id=PAGE_2,
        placeholder_text="Page 2 — click here to edit",
        text_data=[{"insert": "Page 2 content\n"}],
        expand=True,
    )

    def focus_editor(editor_id: str):
        """Switch the toolbar to drive the focused editor."""
        toolbar.controller_id = editor_id
        #toolbar.update()
        page.update()

    # Wrap each editor in a GestureDetector-style Container so a tap sets focus.
    def make_page_card(editor: FletQuillEditor, editor_id: str, label: str):
        return ft.Container(
            border=ft.Border.all(1, ft.Colors.BLUE_200),
            border_radius=4,
            padding=4,
            expand=True,
            content=ft.Column(
                expand=True,
                spacing=0,
                controls=[
                    ft.Text(label, size=11, color=ft.Colors.BLUE_400),
                    editor,
                ],
            ),
            on_click=lambda _: focus_editor(editor_id),
        )
    
    quill = FletQuill(
                show_toolbar_divider=False,
                center_toolbar=False,
                text_data=[{"insert": "Hello from the combined control!\n"}],
                
            )
    
    async def _save_quill(e):
        data = await quill.save()
        print("Saved content:", data)

    # ── Layout ─────────────────────────────────────────────────────────────
    # Section 1: combined control (original API still works).
    page.add(
        ft.Text("Combined FletQuill (original API)", weight=ft.FontWeight.BOLD),
        ft.Container(
            border=ft.Border.all(1, ft.Colors.GREEN),
            expand=True,
            content=quill
        ),
        ft.Button("Save", on_click=_save_quill)
    )

    '''
    # Section 2: separate toolbar + multi-editor.
    page.add(
        ft.Text(
            "Separate Toolbar + Multi-Editor (click a page to focus)",
            weight=ft.FontWeight.BOLD,
        ),
        toolbar,
        ft.Row(
            expand=True,
            controls=[
                make_page_card(editor1, PAGE_1, "Page 1"),
                make_page_card(editor2, PAGE_2, "Page 2"),
            ],
        ),
    )
    '''


ft.run(main)
