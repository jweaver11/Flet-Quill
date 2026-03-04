from __future__ import annotations

from typing import Union
import json
import os
import re
from pathlib import Path
from bs4 import BeautifulSoup
from pypdf import PdfReader
import markdown
from docx import Document 

    

# Called to convert read and convert our file paths to delta ops (list)
def load_file_to_delta_ops(file_path: str) -> list:
    ''' Accepts our file path and calls the appropriate converter based on file type. '''

    # Set the file name from the path so we know what type it is
    file_name = os.path.basename(file_path)
    
    # If its json (delta ops), load and return that directly
    if file_name.lower().endswith(".json"):
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
        
    # If its .txt file, load and return delta ops from that
    elif file_name.lower().endswith(".txt"):
        return delta_from_txt(file_path)
    
    # If its .html file, load and return delta ops from that
    elif file_name.lower().endswith(".html") or file_name.lower().endswith(".htm"):
        return delta_from_html(file_path)
    
    # If its .pdf file, load and return delta ops from that
    elif file_name.lower().endswith(".pdf"):
        return delta_from_pdf(file_path)
    
    # If its .rtf file, load and return delta ops from that
    elif file_name.lower().endswith(".rtf"):
        return delta_from_rtf(file_path)
    
    # If its .md file, load and return delta ops from that
    elif file_name.lower().endswith(".md") or file_name.lower().endswith(".markdown"):
        return delta_from_md(file_path)

    # If its .docx file, load and return delta ops from that
    elif file_name.lower().endswith(".docx"):
        return delta_from_docx(file_path)

    # If not a supported file type, this error will fill the text editor
    else:
        return [{"insert": "Unsuppored file type\n"}]

# Called on .txt files to convert to delta ops
def delta_from_txt(file_path: str) -> list:
    """Convert a plain text file to Quill Delta ops list."""

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split on newlines, ensure each line ends with \n
    lines = content.splitlines(keepends=True)
    
    ops = [{"insert": line} for line in lines]
    return ops
    

# Called on .html files to convert to delta ops
def delta_from_html(file_path: str) -> list:
    """
    Load HTML from file_path and convert to Delta ops JSON list.
    Returns [{"insert": "text"}, {"insert": "\n"}, ...]
    """
    

    # Read HTML file safely
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        raise ValueError(f"HTML file not found: {file_path}")
    
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            html = f.read().strip()
    except Exception as e:
        raise RuntimeError(f"Failed to read HTML file {file_path}: {e}")

    if not html:
        return [{"insert": "\n"}]  # Empty document

    soup = BeautifulSoup(html, "html.parser")
    
    # Replace <br> with newlines
    for br in soup.find_all("br"):
        br.replace_with("\n")
    
    # Add newlines after block elements
    for tag_name in ("p", "div", "li", "h1", "h2", "h3", "h4", "h5", "h6", "tr"):
        for t in soup.find_all(tag_name):
            t.append("\n")
    
    # Extract and clean text
    text = soup.get_text()
    lines = [ln.rstrip() for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    
    # Collapse excessive blank lines (max 2)
    out_lines = []
    blank_run = 0
    for ln in lines:
        if ln.strip() == "":
            blank_run += 1
            if blank_run <= 2:
                out_lines.append("")
        else:
            blank_run = 0
            out_lines.append(ln)
    
    full_text = "\n".join(out_lines).strip()
    if not full_text.endswith("\n"):
        full_text += "\n"
    
    # Return proper Delta ops list
    return [{"insert": full_text}]


def delta_from_pdf(file_path: str) -> list:
    """Convert PDF file at file_path to Delta ops JSON list."""
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        raise ValueError(f"PDF file not found: {file_path}")
    
    
    # Read PDF from file path
    reader = PdfReader(file_path)
    
    pages_text = []
    for page in reader.pages:
        t = (page.extract_text() or "").replace("\r\n", "\n").replace("\r", "\n").strip()
        if t:
            # Normalize multiple spaces to single space, preserve newlines
            t = re.sub(r' +', ' ', t)
            pages_text.append(t)

    full_text = "\n\n".join(pages_text).strip()
    
    # FIX: Create Delta directly (match delta_from_html pattern)
    if not full_text.endswith("\n"):
        full_text += "\n"
    return [{"insert": full_text}]


def delta_from_rtf(file_path: str) -> list:
    """
    Load RTF from file_path and convert to Delta ops JSON list.
    """
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        raise ValueError(f"RTF file not found: {file_path}")
    
    try:
        from striprtf.striprtf import rtf_to_text  # type: ignore
    except ImportError as e:
        raise RuntimeError(
            "RTF conversion requires 'striprtf'. Install: pip install striprtf"
        ) from e

    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            rtf_content = f.read().strip()
    except Exception as e:
        raise RuntimeError(f"Failed to read RTF file {file_path}: {e}")

    if not rtf_content:
        return [{"insert": "\n"}]  # Empty document

    # Convert RTF to plain text (correct import usage)
    plain_text = rtf_to_text(rtf_content)
    
    # Clean up text (match your pattern)
    plain_text = plain_text.replace("\r\n", "\n").replace("\r", "\n").strip()
    plain_text = re.sub(r' +', ' ', plain_text)
    
    if not plain_text.endswith("\n"):
        plain_text += "\n"
    
    return [{"insert": plain_text}]


def delta_from_md(file_path: str) -> list:
    """
    Load Markdown from file_path and convert to Delta ops JSON list.
    Returns [{"insert": "text\n"}, ...]
    """

    # Read Markdown content
    with open(file_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    # Convert to HTML using the Python Markdown package
    # Use commonmark-like parsing with some basic extensions for better structure
    html = markdown.markdown(md_text, extensions=['extra', 'codehilite'])

    # Parse HTML to structured blocks
    soup = BeautifulSoup(html, 'html.parser')

    ops = []

    # Helper to append an insert operation with a trailing newline if needed
    def append_insert(text, with_nl=True):
        if not text:
            return
        insert_text = text if not with_nl else text + '\n'
        ops.append({"insert": insert_text})

    # Map HTML elements to Delta blocks
    for element in soup.body or soup:
        tag = element.name if element.name else None

        if tag in {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}:
            level = int(tag[1])
            header_text = element.get_text(" ", strip=True)
            # Use a bold/bold-ish style for headers and add a newline
            # Delta format: insert with attributes for header
            ops.append({"insert": header_text + "\n", "attributes": {"header": level}})
            continue

        if tag in {'p'}:
            text = element.get_text(" ", strip=True)
            if text:
                append_insert(text)
            continue

        if tag in {'li'}:
            # List item. Flatten with bullet and newline.
            text = element.get_text(" ", strip=True)
            if text:
                # Delta: use bullet list attribute
                ops.append({"insert": text + "\n", "attributes": {"list": "bullet"}})
            continue

        if tag in {'pre'}:
            code = element.get_text()
            if code:
                # Use code block with newline
                ops.append({"insert": code + "\n", "attributes": {"code-block": True}})
            continue

        if tag in {'code'}:
            code_text = element.get_text()
            if code_text:
                # Inline code combined in a paragraph; wrap in backticks appearance not stored,
                # but we can mark as code with inline style if desired.
                ops.append({"insert": code_text, "attributes": {"code": True}})
            continue

        if tag in {'strong', 'b'}:
            # Bold inside a paragraph or list item
            text = element.get_text(" ", strip=True)
            if text:
                ops.append({"insert": text, "attributes": {"bold": True}})
            continue

        if tag in {'em', 'i'}:
            text = element.get_text(" ", strip=True)
            if text:
                ops.append({"insert": text, "attributes": {"italic": True}})
            continue

        # Fallback: treat as a paragraph
        if element.string:
            append_insert(element.string.strip())

    # Normalize: merge adjacent plain inserts if needed (not strictly required for Delta)
    # Here we simply return the constructed list.
    return ops


def delta_from_docx(file_path: str) -> list:
    '''
    Load Docx to delta ops
    '''
    #from docx import Document

    document = Document(file_path)
    ops = []

    for para in document.paragraphs:
        # Determine paragraph-level attributes
        style_name = para.style.name.lower() if para.style else ""
        block_attr = {}

        # Map heading styles
        if "heading" in style_name:
            try:
                level = int(style_name.replace("heading", "").strip())
                block_attr["header"] = level
            except ValueError:
                block_attr["header"] = 1

        # Map list style
        elif any(x in style_name for x in ["list", "bullet"]):
            block_attr["list"] = "bullet"
        elif any(x in style_name for x in ["numbered", "ordered"]):
            block_attr["list"] = "ordered"
        elif "quote" in style_name:
            block_attr["blockquote"] = True

        # Handle text runs within paragraph
        for run in para.runs:
            text = run.text
            if not text:
                continue

            inline_attr = {}
            if run.bold:
                inline_attr["bold"] = True
            if run.italic:
                inline_attr["italic"] = True
            if run.underline:
                inline_attr["underline"] = True

            # Safely check run style for code
            if run.style and "code" in run.style.name.lower():
                inline_attr["code"] = True

            # Add run insert
            if inline_attr:
                ops.append({"insert": text, "attributes": inline_attr})
            else:
                ops.append({"insert": text})

        # Add newline to separate blocks with any paragraph-level attributes
        newline_op = {"insert": "\n"}
        if block_attr:
            newline_op["attributes"] = block_attr
        ops.append(newline_op)

    # Clean up empty ops and ensure final newline
    ops = [op for op in ops if op["insert"].strip()]  # Remove empty inserts
    if not ops or ops[-1].get("insert") != "\n":
        ops.append({"insert": "\n"})

    return ops