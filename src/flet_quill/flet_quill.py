from enum import Enum
from .text_converter import load_file_to_delta_ops
import flet as ft
from typing import Any, Optional, Callable, Union
import json, os

@ft.control("FletQuill")
class FletQuill(ft.LayoutControl):
    """
    FletQuill Control description.
    """

    file_path: Optional[str] = None,    # str to file path to load and save to
    text_data: Optional[list] = None,
    save_method: Optional[Callable[[list], None]] = None,

    show_toolbar_divider: bool = True,
    center_toolbar: bool = False,
    font_sizes: list = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 32, 40, 48, 64],
    placeholder_text: str = "Enter text here...",

    # A Flet Quill Toolbar control to be used with this editor. If none, a default toolbar will created for the quill
    toolbar: Optional[ft.Control] = None,  # If one is passed in, it won't be shown on screen, allowing multiple editors to share the same toolbar


    # If a filepath is passed in, we use that as our text editor to pass into the Quill
    if file_path is not None:

        text_data = load_file_to_delta_ops(file_path)   # Set text data from file here
        file_name = os.path.basename(file_path)     # Set file name to json so we can save to a different file than the one passed in

        # Json can read, so it needs no change
        if file_name.lower().endswith(".json"):
            file_path = file_path

        # Otherwise, make a new file name with the .json extension
        else:
            new_file_name = os.path.splitext(file_name)[0] + ".json"
            new_file_path = os.path.join(os.path.dirname(file_path), new_file_name)

            # New file path it will save to in deltaop json format
            file_path = new_file_path
            # TIP: This saves to a new/different file, so keep track of new path after conversions
            # or you'll be loading from an old file and saving to a new one
            

    @property
    def file_path(self):
        return self.__getattribute__("file_path")

    @file_path.setter
    def file_path(self, value):
        self.__setattr__("file_path", value)

    # text_data (JSON string attribute consumed by Flutter)
    @property
    def text_data(self) -> Optional[list]:
        v = self.__getattribute__("text_data")
        if not v:
            return None
        try:
            return json.loads(v)
        except Exception:
            return None

    @text_data.setter
    def text_data(self, value: Optional[list]):
        if value is None:
            self.__setattr__("text_data", None)
            return
        if not isinstance(value, list):
            raise TypeError("text_data must be a list of delta operations")
        self.__setattr__("text_data", json.dumps(value))

    # save_method (Python-side callback; Flutter triggers "save" event)
    @property
    def save_method(self) -> Optional[Callable[[list], None]]:
        return self._save_method

    @save_method.setter
    def save_method(self, cb: Optional[Callable[[list], None]]):
        self._save_method = cb

        # Let Flutter know whether it should write to file_path or emit an event.
        self.__setattr__("save_to_event", cb is not None)

        # Register/unregister handler.
        if cb is not None:
            self._trigger_event("save", self.__handle_save_event)
        else:
            self._trigger_event("save", None)

    def __handle_save_event(self, e: ft.Event):
        if self._save_method is None:
            return
        try:
            payload = json.loads(e.data) if e.data else []
        except Exception:
            payload = []
        self._save_method(payload)

    # border_visible
    @property
    def border_visible(self):
        return self.__getattribute__("border_visible", data_type=bool)

    @border_visible.setter
    def border_visible(self, value: bool):
        self.__setattr__("border_visible", value)

    # border_width
    @property
    def border_width(self):
        return self.__getattribute__("border_width", data_type=float)

    @border_width.setter
    def border_width(self, value: float):
        self.__setattr__("border_width", value)

    # padding_left
    @property
    def padding_left(self):
        return self.__getattribute__("padding_left", data_type=float)

    @padding_left.setter
    def padding_left(self, value: float):
        self.__setattr__("padding_left", value)

    # padding_top
    @property
    def padding_top(self):
        return self.__getattribute__("padding_top", data_type=float)

    @padding_top.setter
    def padding_top(self, value: float):
        self.__setattr__("padding_top", value)

    # padding_right
    @property
    def padding_right(self):
        return self.__getattribute__("padding_right", data_type=float)

    @padding_right.setter
    def padding_right(self, value: float):
        self.__setattr__("padding_right", value)

    # padding_bottom
    @property
    def padding_bottom(self):
        return self.__getattribute__("padding_bottom", data_type=float)

    @padding_bottom.setter
    def padding_bottom(self, value: float):
        self.__setattr__("padding_bottom", value)

    # aspect_ratio
    @property
    def aspect_ratio(self):
        return self.__getattribute__("aspect_ratio", data_type=float)

    @aspect_ratio.setter
    def aspect_ratio(self, value: float):
        self.__setattr__("aspect_ratio", value)

    # use_zoom_factor
    @property
    def use_zoom_factor(self):
        return self.__getattribute__("use_zoom_factor", data_type=bool)
    
    @use_zoom_factor.setter
    def use_zoom_factor(self, value: bool):
        self.__setattr__("use_zoom_factor", value)

    # show_toolbar_divider
    @property
    def show_toolbar_divider(self):
        return self.__getattribute__("show_toolbar_divider", data_type=bool)

    @show_toolbar_divider.setter
    def show_toolbar_divider(self, value: bool):
        self.__setattr__("show_toolbar_divider", value)

    # center_toolbar
    @property
    def center_toolbar(self):
        return self.__getattribute__("center_toolbar", data_type=bool)

    @center_toolbar.setter
    def center_toolbar(self, value: bool):
        self.__setattr__("center_toolbar", value)

    # font_sizes
    @property
    def font_sizes(self) -> list:
        v = self.__getattribute__("font_sizes")
        if not v:
            return []
        try:
            return json.loads(v)
        except Exception:
            return []
        
    @font_sizes.setter
    def font_sizes(self, value: list):
        if value is None:
            self.__setattr__("font_sizes", None)
            return
        self.__setattr__("font_sizes", json.dumps(value))


    # placeholder_text
    @property
    def placeholder_text(self) -> str:
        return self.__getattribute__("placeholder_text")
    
    @placeholder_text.setter
    def placeholder_text(self, value: str):
        self.__setattr__("placeholder_text", value)