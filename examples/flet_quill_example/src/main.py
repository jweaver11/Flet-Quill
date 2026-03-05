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
            height=150, width=300, alignment = ft.Alignment.CENTER, bgcolor=ft.Colors.PURPLE_200, 
            
            content=FletQuill(
                tooltip="My new FletQuill Control tooltip",
                #text_data=[{"insert": "Hello, world from text editor\n"}]
                
            ),
        ),

    )


ft.run(main)
