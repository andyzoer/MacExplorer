#!/usr/bin/env python3
"""Development only: pip install python-docx openpyxl python-pptx.
Regenerate the blank Office resources; no Python packages are required by Explorer.
"""
from pathlib import Path
from docx import Document
from openpyxl import Workbook
from pptx import Presentation

output = Path(__file__).resolve().parent.parent / "Sources/ExplorerCore/Resources/Templates"
output.mkdir(parents=True, exist_ok=True)
document = Document()
document.add_paragraph()
document.save(output / "Blank.docx")
Workbook().save(output / "Blank.xlsx")
presentation = Presentation()
presentation.slides.add_slide(presentation.slide_layouts[6])
presentation.save(output / "Blank.pptx")
