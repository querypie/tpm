#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pypdf==6.10.0",
#   "reportlab==4.4.9",
# ]
# ///
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from build_eula import EULA_DIR, default_output, load_document
from template import render_pdf
from verify_eula import verify_pdf


class EulaPdfTest(unittest.TestCase):
    def test_builds_versionless_cover_without_mutating_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "eula.md"
            config = root / "document.json"
            output = root / "eula-2026-04-10.pdf"

            source.write_text(
                "## PART I: GENERAL TERMS\n\n"
                "### (1) TEST SECTION\n\n"
                "The source text must remain unchanged in the generated PDF.\n",
                encoding="utf-8",
            )
            config.write_text(
                json.dumps(
                    {
                        "title": "End User License Agreement",
                        "subtitle": "QueryPie Software Products",
                        "last_updated": "2026-04-10",
                        "licensor": "CHEQUER Global, Inc.",
                        "source_url": "https://www.querypie.com/eula",
                    }
                ),
                encoding="utf-8",
            )

            blocks, metadata = load_document(source, config)
            render_pdf(blocks, metadata, output)
            result = verify_pdf(output, source, config)

            self.assertEqual(result["expected_tokens"], result["actual_tokens"])
            self.assertGreaterEqual(result["pages"], 2)
            self.assertEqual(result["last_page"], result["pages"])
            self.assertEqual(
                default_output(metadata), EULA_DIR / "eula-2026-04-10.pdf"
            )


if __name__ == "__main__":
    unittest.main()
