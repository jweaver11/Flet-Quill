from dataclasses import field
import flet as ft
from typing import Optional, Callable, Any
import json
import os

from flet.controls.base_control import skip_field
from flet.controls.control_event import ControlEvent, ControlEventHandler
from .text_converter import load_file_to_delta_ops
import dataclasses

@ft.control("FletQuill")
class FletQuill(ft.LayoutControl):
    """
    FletQuill Control description.
    """

    file_path: Optional[str] = None
    show_toolbar_divider: bool = True
    center_toolbar: bool = False
    placeholder_text: Optional[str] = "Enter text here..."
    tooltip: Optional[str] = None

    # Non-standard data
    
    #save_method: Optional[Callable[[list], None]] = None #not needed?
    #font_sizes: list[int] = field(
        #default_factory=lambda: [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 32, 40, 48, 64]
    #)
    toolbar_buttons: list[ft.Control] = None
    _controller = None

    # public Python API
    text_data: list[dict[str, Any]] = None
    #print("Text data passed in: \n", text_data)


  