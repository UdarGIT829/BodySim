"""Generate conservative superficial/deep display layers for skeletal muscles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


SURFACE_FAMILY_MARKERS = (
    "facial muscles",
    "epicranius",
    "platysma",
    "sternocleidomastoid",
    "trapezius",
    "latissimus dorsi",
    "pectoralis major",
    "deltoid",
    "serratus anterior",
    "rectus abdominis",
    "external oblique",
    "gluteus maximus",
    "gluteus medius",
    "tensor fasciae latae",
    "biceps brachii",
    "triceps brachii",
    "brachioradialis",
    "pronator teres",
    "flexor carpi radialis",
    "flexor carpi ulnaris",
    "palmaris longus",
    "extensor digitorum",
    "extensor carpi",
    "sartorius",
    "rectus femoris",
    "vastus lateralis",
    "vastus medialis",
    "adductor longus",
    "gracilis",
    "biceps femoris",
    "semitendinosus",
    "semimembranosus",
    "tibialis anterior",
    "fibularis longus",
    "fibularis brevis",
    "gastrocnemius",
    "soleus",
    "plantaris",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def classify(structure: dict[str, object]) -> dict[str, str]:
    text = " ".join(
        [str(structure["name"]), *map(str, structure.get("source_taxonomy", []))]
    ).lower()
    if "superficial" in text:
        return {
            "display_depth": "superficial",
            "confidence": "source_explicit",
            "basis": "Z-Anatomy name or collection explicitly identifies a superficial layer.",
        }
    if "deep" in text:
        return {
            "display_depth": "deep",
            "confidence": "source_explicit",
            "basis": "Z-Anatomy name or collection explicitly identifies a deep layer.",
        }
    marker = next((item for item in SURFACE_FAMILY_MARKERS if item in text), None)
    if marker:
        return {
            "display_depth": "superficial",
            "confidence": "curated_visualization_rule",
            "basis": f"Curated surface-family rule: {marker}.",
        }
    return {
        "display_depth": "deep",
        "confidence": "conservative_visualization_default",
        "basis": "Not explicitly identified as superficial; retained in the deep display layer so anatomy is never omitted.",
    }


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    structures = []
    for structure in catalog["structures"]:
        if structure["system"] != "skeletal_muscle":
            continue
        structures.append({"id": structure["id"], **classify(structure)})
    counts = Counter(item["display_depth"] for item in structures)
    confidence_counts = Counter(item["confidence"] for item in structures)
    report = {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "scope": "skeletal_muscle_visualization_only",
        "structure_count": len(structures),
        "depth_counts": dict(sorted(counts.items())),
        "confidence_counts": dict(sorted(confidence_counts.items())),
        "medical_use": False,
        "limitations": [
            "Display depth is a viewing aid, not a universal anatomical or surgical plane.",
            "Explicit Z-Anatomy depth labels take precedence over curated family rules.",
            "The conservative default assigns uncertain muscles to deep so they remain available when the superficial layer is hidden.",
        ],
        "structures": structures,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Display-depth classification generated: {counts['superficial']} superficial, "
        f"{counts['deep']} deep"
    )


if __name__ == "__main__":
    main()
