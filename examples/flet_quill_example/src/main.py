import flet as ft
from flet_quill import FletQuill, FletQuillEditor, FletQuillToolbar


def main(page: ft.Page):

    async def get_word_count():
        wc = 0
        doc_data = await quill_editor.save()    # Returns our delta json data (Quill Delta format)
        for block in doc_data:
            if "insert" in block:
                if isinstance(block["insert"], str):    # Protect against page breaks
                    wc += len(block["insert"].split())
        word_count.value = f"Word Count: {wc}"

    # Nice little formatted word count button
    word_count_button = ft.IconButton(
        icon=ft.CupertinoIcons.TEXTFORMAT_SIZE,
        tooltip="Word Count", 
        on_click=get_word_count,
        bgcolor=ft.Colors.TRANSPARENT,
        highlight_color=ft.Colors.TRANSPARENT,
        hover_color=ft.Colors.TRANSPARENT,
        padding=ft.Padding.all(0),
        size_constraints=ft.BoxConstraints(min_width=0, min_height=0),
    )

    quill_toolbar = FletQuillToolbar(
        controller_id="default",
        toolbar_buttons=[word_count_button]
    )

    
    quill_editor = FletQuillEditor(
        controller_id="default",
        text_data=[{"insert": "This is my Quill Data!\n"}],        # Pass in data
        placeholder_text="Start typing here...",
    )

    word_count = ft.Text("Word Count: 5")   # Word count text
    
    page.add(
        ft.SafeArea(
            expand=True,
            content=ft.Column([
                quill_toolbar,
                ft.Container(
                    quill_editor, 
                    border=ft.Border.all(2, ft.Colors.OUTLINE_VARIANT), 
                    expand=True,
                    padding=72
                ),
                word_count
            ])
        )
    )

    # Combined - accepts all arguments for both split elements above
    quill = FletQuill()


if __name__ == "__main__":
    ft.run(main)
