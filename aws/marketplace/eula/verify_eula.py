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
import re
import unicodedata
from pathlib import Path

from pypdf import PdfReader

from build_eula import DEFAULT_CONFIG, DEFAULT_INPUT, load_document


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify a generated QueryPie EULA PDF.")
    parser.add_argument("--pdf", type=Path, required=True)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    return parser.parse_args()


def tokens(value: str) -> list[str]:
    normalized = unicodedata.normalize("NFKC", value).replace("’", "'")
    return re.findall(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*", normalized.lower())


def verify_pdf(pdf_path: Path, input_path: Path, config_path: Path) -> dict[str, int]:
    blocks, metadata = load_document(input_path, config_path)
    reader = PdfReader(pdf_path.expanduser().resolve())
    if reader.is_encrypted:
        raise ValueError("Generated PDF must not be encrypted.")
    if len(reader.pages) < 2:
        raise ValueError("Generated PDF must contain a cover and body pages.")

    cover_text = reader.pages[0].extract_text() or ""
    required_cover = {
        metadata.title,
        metadata.subtitle,
        "Last updated",
        metadata.last_updated_display,
        metadata.licensor,
        "Source",
        metadata.source_url,
    }
    missing_cover = sorted(value for value in required_cover if value not in cover_text)
    if missing_cover:
        raise ValueError(f"Cover is missing required text: {missing_cover}")
    forbidden_cover = {"Document version", "Document date"}
    present_forbidden = sorted(value for value in forbidden_cover if value in cover_text)
    if present_forbidden:
        raise ValueError(f"Cover contains forbidden version fields: {present_forbidden}")

    source_links = {
        annotation.get_object().get("/A", {}).get("/URI")
        for annotation in reader.pages[0].get("/Annots", [])
    }
    if metadata.source_url not in source_links:
        raise ValueError("Cover source URL is not a clickable link.")

    body_lines: list[str] = []
    total_pages = len(reader.pages)
    for page_number, page in enumerate(reader.pages[1:], start=2):
        page_text = page.extract_text() or ""
        expected_footer = f"Page {page_number} of {total_pages}"
        if expected_footer not in page_text:
            raise ValueError(f"Page footer is missing: {expected_footer}")
        for line in (page.extract_text() or "").splitlines():
            stripped = line.strip()
            if stripped == "QUERYPIE EULA" or re.fullmatch(
                r"Page \d+ of \d+", stripped
            ):
                continue
            body_lines.append(line)

    expected_tokens = tokens("\n".join(block.text for block in blocks))
    actual_tokens = tokens("\n".join(body_lines))
    if expected_tokens != actual_tokens:
        mismatch = next(
            (
                index
                for index, (expected, actual) in enumerate(
                    zip(expected_tokens, actual_tokens, strict=False)
                )
                if expected != actual
            ),
            min(len(expected_tokens), len(actual_tokens)),
        )
        raise ValueError(
            "PDF body does not match the configured Markdown source at token "
            f"{mismatch}; expected={len(expected_tokens)}, actual={len(actual_tokens)}."
        )

    subject = (reader.metadata or {}).get("/Subject", "")
    expected_subject = f"QueryPie EULA - Last updated {metadata.last_updated_display}"
    if subject != expected_subject:
        raise ValueError(
            f"Unexpected PDF subject metadata: {subject!r}; expected {expected_subject!r}."
        )

    return {
        "pages": len(reader.pages),
        "expected_tokens": len(expected_tokens),
        "actual_tokens": len(actual_tokens),
        "last_page": len(reader.pages),
    }


def main() -> None:
    args = parse_args()
    result = verify_pdf(args.pdf, args.input, args.config)
    print(
        "verified "
        f"pages={result['pages']} body_tokens={result['actual_tokens']} "
        f"last_footer=Page_{result['last_page']}_of_{result['last_page']} "
        "encrypted=false version_field=false"
    )


if __name__ == "__main__":
    main()
