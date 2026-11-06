"""Extract individual muscle terms from the official TA98 chapter HTML.

The terminology's individual terms are public domain. The surrounding source
publication remains attributed and is not copied into this repository.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from bs4 import BeautifulSoup


SOURCE_URL = (
    "https://ifaa.unifr.ch/Public/EntryPage/TA98%20Tree/"
    "TA98%20EN/04%20TA98%20EN.htm"
)
CODE_RE = re.compile(r"A04\.[1-7]\.\d{2}\.\d{3}")
MUSCLE_RE = re.compile(r"^\(?M{1,2}\.\s", re.IGNORECASE)
SPECIAL_TERMS = {"Diaphragma", "Platysma"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def read_html(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in raw[:100]:
        return raw.decode("utf-16")
    return raw.decode("utf-8")


def extract_terms(html: str) -> list[dict[str, object]]:
    soup = BeautifulSoup(html, "html.parser")
    terms = []
    for row in soup.find_all("tr"):
        cells = [" ".join(cell.stripped_strings) for cell in row.find_all("td")]
        if len(cells) < 3:
            continue
        code_cell, latin, english = cells[:3]
        code_match = CODE_RE.search(code_cell)
        if not code_match:
            continue
        code = code_match.group(0)
        if not (MUSCLE_RE.match(latin) or latin in SPECIAL_TERMS):
            continue
        aliases = [item.strip(" ()") for item in english.split(";") if item.strip(" ()")]
        terms.append(
            {
                "code": code,
                "latin": latin.strip("()"),
                "english": aliases[0],
                "english_aliases": aliases,
                "optional_or_variable": latin.startswith("("),
            }
        )
    return sorted(terms, key=lambda item: item["code"])


def main() -> None:
    args = parse_args()
    terms = extract_terms(read_html(args.input))
    document = {
        "schema_version": 1,
        "source": {
            "citation": "FIPAT. Terminologia Anatomica. 2nd ed. FIPAT, 2019.",
            "reference_edition": "TA98 online partonomic chapter",
            "url": SOURCE_URL,
            "terms_license": "public_domain",
        },
        "selection": "A04.1-A04.7 rows whose Latin term denotes an individual muscle",
        "terms": terms,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Extracted {len(terms)} individual muscle terms")


if __name__ == "__main__":
    main()
