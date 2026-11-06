"""Extract muscle terms redirected from TA98's muscle chapter."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from bs4 import BeautifulSoup


MUSCLE_RE = re.compile(r"(?:^|;\s*)\(?M{1,2}\.\s", re.IGNORECASE)
CODE_RE = re.compile(r"A\d{2}\.\d\.\d{2}\.\d{3}")
TARGETS = (
    ("tongue", "A05.1.04.1"),
    ("soft_palate", "A05.2.01.1"),
    ("pharynx", "A05.3.01.1"),
    ("larynx", "A06.2.08."),
    ("perineum", "A09.5."),
    ("perineum", "A09.4.02.016"),
    ("perineum", "A09.2.03.006"),
    ("extraocular", "A15.2.07."),
    ("auditory_ossicles", "A15.3.02."),
)
SOURCE_URLS = (
    "https://ifaa.unifr.ch/Public/EntryPage/TA98%20Tree/TA98%20EN/05%20TA98%20EN.htm",
    "https://ifaa.unifr.ch/Public/EntryPage/TA98%20Tree/TA98%20EN/06%20TA98%20EN.htm",
    "https://ifaa.unifr.ch/Public/EntryPage/TA98%20Tree/TA98%20EN/09%20TA98%20EN.htm",
    "https://ifaa.unifr.ch/Public/EntryPage/TA98%20Tree/TA98%20EN/15%20TA98%20EN.htm",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def decode(path: Path) -> str:
    raw = path.read_bytes()
    return raw.decode("utf-16") if b"\x00" in raw[:100] else raw.decode("utf-8")


def group_for(code: str) -> str | None:
    return next((group for group, prefix in TARGETS if code.startswith(prefix)), None)


def extract(paths: list[Path]) -> list[dict[str, object]]:
    by_code: dict[str, dict[str, object]] = {}
    for path in paths:
        soup = BeautifulSoup(decode(path), "html.parser")
        for row in soup.find_all("tr"):
            cells = [" ".join(cell.stripped_strings) for cell in row.find_all("td")]
            if len(cells) < 3:
                continue
            code_cell, latin, english = cells[:3]
            code_match = CODE_RE.search(code_cell)
            if not code_match:
                continue
            code = code_match.group(0)
            group = group_for(code)
            if not group or not MUSCLE_RE.search(latin):
                continue
            aliases = [item.strip(" ()") for item in english.split(";") if item.strip(" ()")]
            by_code[code] = {
                "code": code,
                "group": group,
                "latin": latin.strip("()"),
                "english": aliases[0],
                "english_aliases": aliases,
                "optional_or_variable": latin.startswith("("),
            }
    return [by_code[code] for code in sorted(by_code)]


def main() -> None:
    args = parse_args()
    terms = extract(args.input)
    document = {
        "schema_version": 1,
        "source": {
            "citation": "FIPAT/IFAA Terminologia Anatomica TA98 online partonomic chapters",
            "urls": SOURCE_URLS,
            "terms_license": "public_domain",
        },
        "selection": "Muscle terms in the seven sections redirected from TA98 Chapter 4",
        "terms": terms,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    counts = {group: sum(1 for term in terms if term["group"] == group) for group, _ in TARGETS}
    print(f"Extracted {len(terms)} cross-referenced terms: {counts}")


if __name__ == "__main__":
    main()
