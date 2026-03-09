import flet as ft
import json, os, sys
src_dir = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..", "src")
)
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)
from flet_quill import FletQuill


def main(page: ft.Page):
    page.vertical_alignment = ft.MainAxisAlignment.CENTER
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER

    page.add(

        ft.Container(
            alignment = ft.Alignment.CENTER,
            border=ft.Border.all(1, "blue"),
            expand=True, 
            content=FletQuill(
                tooltip="My new FletQuill Control tooltip",
                placeholder_text="Your placeholder text",
                file_path="My_file_path.txt",
                show_toolbar_divider=False,
                center_toolbar=True,
                text_data=[{"insert": "Hello, world from text editor\n"}],
                toolbar_buttons=[
                    ft.IconButton(ft.Icons.ADD),
                    ft.IconButton(ft.Icons.REMOVE),
                ]
                
            ),
        ),
        

    )
    page.add(ft.Container(border=ft.Border.all(1, "red"), expand=True))


ft.run(main)
