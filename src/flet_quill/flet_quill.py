import json
import flet as ft
from typing import Optional, Any

from .text_converter import load_file_to_delta_ops


@ft.control("FletQuill")
class FletQuill(ft.LayoutControl):
    """
    Combined Quill toolbar + editor in a single control.
    """

    file_path: Optional[str] = None
    show_toolbar_divider: bool = True
    center_toolbar: bool = False
    placeholder_text: Optional[str] = "Enter text here..."
    tooltip: Optional[str] = None
    toolbar_buttons: list[ft.Control] = None

    # Content passed as Delta ops list.
    text_data: list[dict[str, Any]] = None

    async def save(self) -> list[dict[str, Any]]:
        """
        Returns the current editor content as a Delta ops list.

        Example::

            data = await quill.save()
        """
        result = await self._invoke_method("get_delta")
        return json.loads(result)


@ft.control("FletQuillEditor")
class FletQuillEditor(ft.LayoutControl):
    """
    Standalone Quill editor.  Pair with FletQuillToolbar via a shared
    controller_id to support multiple editors driven by a single toolbar
    (e.g. simulating page breaks like Google Docs / Word).
    """

    controller_id: str = "default"
    placeholder_text: Optional[str] = "Enter text here..."
    # Initial content as Delta ops list.
    text_data: list[dict[str, Any]] = None

    async def save(self) -> list[dict[str, Any]]:
        """
        Returns the current editor content as a Delta ops list.

        Example::

            data = await editor.save()
        """
        result = await self._invoke_method("get_delta")
        return json.loads(result)


@ft.control("FletQuillToolbar")
class FletQuillToolbar(ft.Control):
    """
    Standalone Quill toolbar.  Set controller_id to match the active
    FletQuillEditor to control it.  Changing controller_id at runtime
    seamlessly transfers toolbar control to the new editor.
    """

    controller_id: str = "default"
    show_toolbar_divider: bool = True
    center_toolbar: bool = False
