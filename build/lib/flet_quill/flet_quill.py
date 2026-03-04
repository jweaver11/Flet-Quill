from enum import Enum

import flet as ft
from typing import Any, Optional, Callable, Union

@ft.control("FletQuill")
class FletQuill(ft.LayoutControl):
    """
    FletQuill Control description.
    """

    value: str


    file_path: Optional[str] = None,    # str to file path to load and save to
    text_data: Optional[list] = None,
    save_method: Optional[Callable[[list], None]] = None,

    show_toolbar_divider: bool = True,
    center_toolbar: bool = False,
    font_sizes: list = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 32, 40, 48, 64],
    placeholder_text: str = "Enter text here...",

    #toolbar: 