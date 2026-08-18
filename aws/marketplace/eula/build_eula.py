#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pypdf==6.10.0",
#   "reportlab==4.4.9",
# ]
# ///
from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path

from template import DocumentBlock, DocumentMetadata, render_pdf


EULA_DIR = Path(__file__).resolve().parent
REPO_ROOT = EULA_DIR.parents[2]
DEFAULT_INPUT = (
    REPO_ROOT.parent / "corp-web-v2/src/content/legal/eula/en/index.md"
)
DEFAULT_CONFIG = EULA_DIR / "document.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build the QueryPie Marketplace EULA PDF from Markdown."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help="Markdown source path. Relative paths are resolved from the current directory.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG,
        help="Document metadata JSON path.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output PDF path. Defaults to output/pdf/eula-<last-updated>.pdf.",
    )
    return parser.parse_args()


def load_metadata(config_path: Path) -> DocumentMetadata:
    raw = json.loads(config_path.read_text(encoding="utf-8"))
    required = {
        "title",
        "subtitle",
        "last_updated",
        "licensor",
    }
    missing = required - raw.keys()
    if missing:
        raise ValueError(f"Missing document configuration keys: {sorted(missing)}")

    updated = date.fromisoformat(raw["last_updated"])
    return DocumentMetadata(
        title=raw["title"],
        subtitle=raw["subtitle"],
        last_updated=updated.isoformat(),
        last_updated_display=f"{updated.strftime('%B')} {updated.day}, {updated.year}",
        licensor=raw["licensor"],
    )


def parse_markdown(markdown: str) -> list[DocumentBlock]:
    blocks: list[DocumentBlock] = []
    paragraph: list[str] = []

    def flush_paragraph() -> None:
        if paragraph:
            blocks.append(DocumentBlock("paragraph", " ".join(paragraph)))
            paragraph.clear()

    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if not line or line == "<br />":
            flush_paragraph()
            continue

        heading = re.match(r"^(#{2,3})\s+(.+?)\s*$", line)
        if heading:
            flush_paragraph()
            blocks.append(
                DocumentBlock(
                    "heading", heading.group(2), level=len(heading.group(1))
                )
            )
            continue
        paragraph.append(line)

    flush_paragraph()
    if not blocks:
        raise ValueError("Markdown source did not contain any document blocks.")
    return blocks


def load_document(
    input_path: Path, config_path: Path
) -> tuple[list[DocumentBlock], DocumentMetadata]:
    input_path = input_path.expanduser().resolve()
    config_path = config_path.expanduser().resolve()
    if not input_path.is_file():
        raise FileNotFoundError(f"Markdown source not found: {input_path}")
    if not config_path.is_file():
        raise FileNotFoundError(f"Document configuration not found: {config_path}")

    metadata = load_metadata(config_path)
    markdown = input_path.read_text(encoding="utf-8")
    return parse_markdown(markdown), metadata


def default_output(metadata: DocumentMetadata) -> Path:
    return REPO_ROOT / "output/pdf" / f"eula-{metadata.last_updated}.pdf"


def main() -> None:
    args = parse_args()
    blocks, metadata = load_document(args.input, args.config)
    output = (args.output or default_output(metadata)).expanduser().resolve()
    render_pdf(blocks, metadata, output)
    print(output)


if __name__ == "__main__":
    main()
