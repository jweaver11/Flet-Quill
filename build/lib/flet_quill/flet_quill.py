import json
from dataclasses import field
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
    toolbar_buttons: list[ft.Control] = field(default_factory=list)
    font_sizes: Optional[list[int]] = None 
    page_width: Optional[float] = None
    page_height: Optional[float] = None
    page_spacing: Optional[float] = None
    page_color: Optional[str] = None
    padding: Optional[Any] = None
    border: Optional[Any] = None
    border_radius: Optional[Any] = None
    auto_page_breaks: bool = True

    # Content passed as Delta ops list.
    text_data: list[dict[str, Any]] = None

    # Target page height in logical pixels used by dynamic page breaks.
    page_break_height: Optional[float] = None
    # Extra vertical spacing inserted between pages.
    page_break_gap: Optional[float] = None

    async def save(self) -> list[dict[str, Any]]:
        """
        Returns the current editor content as a Delta ops list.

        Example::

            data = await quill.save()
        """
        result = await self._invoke_method("get_delta")
        return json.loads(result)

    async def page_break(self) -> None:
        """
        Inserts a page break at the current cursor position.
        The break dynamically fills the remaining space on the current page
        using ``page_break_height`` as the page height (defaults to 40 logical
        pixels when not set). ``page_break_gap`` adds extra spacing between
        pages (defaults to 0).

        Example::

            await quill.page_break()
        """
        await self._invoke_method("insert_page_break")


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
    page_width: Optional[float] = None
    page_height: Optional[float] = None
    page_spacing: Optional[float] = None
    page_color: Optional[str] = None
    padding: Optional[Any] = None
    border: Optional[Any] = None
    border_radius: Optional[Any] = None
    auto_page_breaks: bool = True

    # Target page height in logical pixels used by dynamic page breaks.
    page_break_height: Optional[float] = None
    # Extra vertical spacing inserted between pages.
    page_break_gap: Optional[float] = None

    async def save(self) -> list[dict[str, Any]]:
        """
        Returns the current editor content as a Delta ops list.

        Example::

            data = await editor.save()
        """
        result = await self._invoke_method("get_delta")
        return json.loads(result)

    async def page_break(self) -> None:
        """
        Inserts a page break at the current cursor position.
        The break dynamically fills the remaining space on the current page
        using ``page_break_height`` as the page height (defaults to 40 logical
        pixels when not set). ``page_break_gap`` adds extra spacing between
        pages (defaults to 0).

        Example::

            await editor.page_break()
        """
        await self._invoke_method("insert_page_break")


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
    font_sizes: Optional[list[int]] = None
    toolbar_buttons: list[ft.Control] = field(default_factory=list)
