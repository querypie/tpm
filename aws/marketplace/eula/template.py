from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape

from pypdf import PdfReader, PdfWriter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageTemplate,
    Paragraph,
    Spacer,
)


@dataclass(frozen=True)
class DocumentBlock:
    kind: str
    text: str
    level: int = 0


@dataclass(frozen=True)
class DocumentMetadata:
    title: str
    subtitle: str
    last_updated: str
    last_updated_display: str
    licensor: str
    source_url: str


class OutlineParagraph(Paragraph):
    def __init__(self, text: str, style: ParagraphStyle, level: int) -> None:
        super().__init__(escape(text), style)
        self.outline_level = level
        self.outline_text = text


class NumberedCanvas(canvas.Canvas):
    """Render body page numbers after the total PDF page count is known."""

    def __init__(self, *args: object, **kwargs: object) -> None:
        super().__init__(*args, **kwargs)
        self._saved_page_states: list[dict[str, object]] = []

    def showPage(self) -> None:
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self) -> None:
        body_page_count = len(self._saved_page_states)
        total_page_count = body_page_count + 1
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_page_number(total_page_count)
            super().showPage()
        super().save()

    def _draw_page_number(self, total_page_count: int) -> None:
        width, _ = A4
        pdf_page_number = self._pageNumber + 1
        self.saveState()
        self.setFillColor(colors.HexColor("#667085"))
        self.setFont("Helvetica", 7.5)
        self.drawRightString(
            width - 24 * mm,
            11 * mm,
            f"Page {pdf_page_number} of {total_page_count}",
        )
        self.restoreState()


class LegalDocumentTemplate(BaseDocTemplate):
    def __init__(self, target: BytesIO) -> None:
        super().__init__(
            target,
            pagesize=A4,
            leftMargin=24 * mm,
            rightMargin=24 * mm,
            topMargin=24 * mm,
            bottomMargin=22 * mm,
            title="QueryPie End User License Agreement",
            author="CHEQUER Global, Inc.",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="legal-body",
        )
        self.addPageTemplates(
            PageTemplate(id="legal", frames=[frame], onPage=self._draw_page_chrome)
        )
        self._outline_sequence = 0

    def _draw_page_chrome(self, pdf: canvas.Canvas, _doc: BaseDocTemplate) -> None:
        _, height = A4
        pdf.saveState()
        pdf.setFillColor(colors.HexColor("#667085"))
        pdf.setFont("Helvetica", 7.5)
        pdf.drawString(self.leftMargin, height - 13 * mm, "QUERYPIE EULA")
        pdf.restoreState()

    def afterFlowable(self, flowable: object) -> None:
        if not isinstance(flowable, OutlineParagraph):
            return
        self._outline_sequence += 1
        key = f"section-{self._outline_sequence}"
        self.canv.bookmarkPage(key)
        self.canv.addOutlineEntry(
            flowable.outline_text,
            key,
            level=flowable.outline_level,
            closed=False,
        )


def _styles() -> dict[str, ParagraphStyle]:
    return {
        "part": ParagraphStyle(
            "Part",
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=16,
            textColor=colors.HexColor("#162236"),
            spaceBefore=16,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "section": ParagraphStyle(
            "Section",
            fontName="Helvetica-Bold",
            fontSize=9.3,
            leading=12,
            textColor=colors.HexColor("#242A31"),
            spaceBefore=10,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            fontName="Helvetica",
            fontSize=8.15,
            leading=11.25,
            textColor=colors.HexColor("#242A31"),
            spaceAfter=6,
            allowWidows=0,
            allowOrphans=0,
        ),
    }


def _build_cover(metadata: DocumentMetadata) -> BytesIO:
    data = BytesIO()
    pdf = canvas.Canvas(data, pagesize=A4)
    width, _ = A4

    navy = colors.HexColor("#162236")
    blue = colors.HexColor("#1769E0")
    gray = colors.HexColor("#667085")
    body = colors.HexColor("#242A31")

    pdf.setTitle(metadata.title)
    pdf.setAuthor(metadata.licensor)
    pdf.setSubject(f"QueryPie EULA - Last updated {metadata.last_updated_display}")
    pdf.setCreator("QueryPie Marketplace EULA PDF generator")

    pdf.setFillColor(blue)
    pdf.setFont("Helvetica-Bold", 9)
    pdf.drawCentredString(width / 2, 688, "QUERYPIE LEGAL")

    pdf.setFillColor(navy)
    pdf.setFont("Helvetica-Bold", 28)
    pdf.drawCentredString(width / 2, 612, metadata.title)

    pdf.setFillColor(gray)
    pdf.setFont("Helvetica", 12)
    pdf.drawCentredString(width / 2, 572, metadata.subtitle)

    pdf.setFillColor(body)
    pdf.setFont("Helvetica", 9.5)
    pdf.drawString(56.7, 480, "Last updated")
    pdf.setFont("Helvetica", 10)
    pdf.drawString(56.7, 462, metadata.last_updated_display)

    pdf.setFont("Helvetica", 9.5)
    pdf.drawString(56.7, 418, "Licensor")
    pdf.setFont("Helvetica", 10)
    pdf.drawString(56.7, 400, metadata.licensor)

    pdf.setFillColor(body)
    pdf.setFont("Helvetica", 9.5)
    pdf.drawString(56.7, 356, "Source")
    pdf.setFillColor(blue)
    pdf.setFont("Helvetica", 10)
    pdf.drawString(56.7, 338, metadata.source_url)
    pdf.linkURL(
        metadata.source_url,
        (56.7, 335, 225, 350),
        relative=0,
        thickness=0,
    )

    pdf.showPage()
    pdf.save()
    data.seek(0)
    return data


def _build_body(blocks: list[DocumentBlock]) -> BytesIO:
    data = BytesIO()
    document = LegalDocumentTemplate(data)
    styles = _styles()
    story: list[object] = []

    for block in blocks:
        if block.kind == "heading":
            style_name = "part" if block.level == 2 else "section"
            outline_level = 0 if block.level == 2 else 1
            story.append(
                OutlineParagraph(block.text, styles[style_name], outline_level)
            )
        else:
            story.append(Paragraph(escape(block.text), styles["body"]))

    story.append(Spacer(1, 4 * mm))
    document.build(story, canvasmaker=NumberedCanvas)
    data.seek(0)
    return data


def _pdf_datetime(value: datetime) -> str:
    offset = value.strftime("%z")
    suffix = "Z" if not offset else f"{offset[:3]}'{offset[3:]}'"
    return f"D:{value.strftime('%Y%m%d%H%M%S')}{suffix}"


def render_pdf(
    blocks: list[DocumentBlock], metadata: DocumentMetadata, output: Path
) -> None:
    cover = PdfReader(_build_cover(metadata))
    body = PdfReader(_build_body(blocks))
    writer = PdfWriter()
    writer.append(cover, import_outline=False)
    writer.append(body, import_outline=True)

    generated_at = datetime.now().astimezone()
    generated_pdf_date = _pdf_datetime(generated_at)
    writer.add_metadata(
        {
            "/Title": metadata.title,
            "/Author": metadata.licensor,
            "/Subject": (
                f"QueryPie EULA - Last updated {metadata.last_updated_display}"
            ),
            "/Creator": "QueryPie Marketplace EULA PDF generator",
            "/CreationDate": generated_pdf_date,
            "/ModDate": generated_pdf_date,
        }
    )
    writer.page_mode = "/UseOutlines"

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as stream:
        writer.write(stream)
