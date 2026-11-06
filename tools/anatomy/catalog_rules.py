"""Pure classification rules for the Phase 0A anatomy catalog.

This module deliberately has no Blender dependency so its naming and
classification behavior can be covered by ordinary unit tests.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass


_ATTACHMENT_SUFFIX_RE = re.compile(
    r"\.(?P<attachment>[oe])(?P<index>\d*)(?P<side>[lr])$",
    re.IGNORECASE,
)
_SIMPLE_SUFFIX_RE = re.compile(r"\.(?P<variant>[l r j i g s])$".replace(" ", ""), re.IGNORECASE)
_DUPLICATE_SUFFIX_RE = re.compile(r"\.\d{3}$")
_NON_ALNUM_RE = re.compile(r"[^a-z0-9]+")
_SPACE_RE = re.compile(r"\s+")
_TERMINAL_MUSCLE_RE = re.compile(r"\s+muscles?$", re.IGNORECASE)


CONNECTIVE_TERMS = (
    "aponeuros",
    "bursa",
    "fascia",
    "fibrous sheath",
    "ligament",
    "linea alba",
    "membrane",
    "raphe",
    "retinaculum",
    "septum",
    "sheath",
    "tarsus",
    "tendinous ring",
    "tendinous arch",
    "tendon",
    "tract",
)

CARTILAGE_TERMS = ("cartilage", "chondral")

SKELETAL_FEATURE_TERMS = (
    " angle of ",
    " apex of ",
    " border of ",
    " canal",
    " condyle",
    " crest",
    " epicondyle",
    " facet",
    " foramen",
    " fossa",
    " groove",
    " head of ",
    " line of ",
    " malleolus",
    " margin",
    " neck of ",
    " notch",
    " process",
    " ramus",
    " spine of ",
    " sulcus",
    " surface",
    " trochanter",
    " tubercle",
    " tuberosity",
    " wing of ",
)

BONE_TERMS = (
    "atlas",
    "axis",
    "bone",
    "calcaneus",
    "capitate",
    "clavicle",
    "coccyx",
    "cuboid",
    "cuneiform",
    "ethmoid",
    "femur",
    "fibula",
    "hamate",
    "humerus",
    "incus",
    "lunate",
    "malleus",
    "mandible",
    "maxilla",
    "navicular",
    "patella",
    "phalanx",
    "pisiform",
    "radius",
    "rib",
    "sacrum",
    "scaphoid",
    "sesamoid",
    "scapula",
    "sphenoid",
    "stapes",
    "sternum",
    "talus",
    "tibia",
    "trapezium",
    "trapezoid",
    "triquetrum",
    "ulna",
    "vertebra",
    "vomer",
)


@dataclass(frozen=True)
class ParsedName:
    source_name: str
    base_name: str
    side: str
    variant: str
    attachment_index: int | None = None


def clean_display_name(value: str) -> str:
    """Remove source-only punctuation without rewriting anatomical wording."""

    cleaned = _SPACE_RE.sub(" ", value.strip())
    if cleaned.startswith("(") and cleaned.endswith(")"):
        cleaned = cleaned[1:-1].strip()
    return cleaned


def parse_source_name(source_name: str) -> ParsedName:
    """Parse Z-Anatomy's side and generated-object suffix conventions."""

    attachment_match = _ATTACHMENT_SUFFIX_RE.search(source_name)
    if attachment_match:
        attachment = attachment_match.group("attachment").lower()
        index_text = attachment_match.group("index")
        variant = "origin_overlay" if attachment == "o" else "ending_overlay"
        return ParsedName(
            source_name=source_name,
            base_name=clean_display_name(source_name[: attachment_match.start()]),
            side="left" if attachment_match.group("side").lower() == "l" else "right",
            variant=variant,
            attachment_index=int(index_text) if index_text else None,
        )

    simple_match = _SIMPLE_SUFFIX_RE.search(source_name)
    if simple_match:
        suffix = simple_match.group("variant").lower()
        variants = {
            "l": ("left", "structure"),
            "r": ("right", "structure"),
            "j": ("unspecified", "aggregate_mesh"),
            "i": ("unspecified", "feature_overlay"),
            "g": ("unspecified", "group_mesh"),
            "s": ("unspecified", "selection_helper"),
        }
        side, variant = variants[suffix]
        return ParsedName(
            source_name=source_name,
            base_name=clean_display_name(source_name[: simple_match.start()]),
            side=side,
            variant=variant,
        )

    return ParsedName(
        source_name=source_name,
        base_name=clean_display_name(source_name),
        side="unspecified",
        variant="structure",
    )


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii").lower()
    return _NON_ALNUM_RE.sub("_", ascii_value).strip("_")


def canonical_stem(display_name: str, system: str) -> str:
    value = clean_display_name(display_name)
    if system == "skeletal_muscle":
        value = _TERMINAL_MUSCLE_RE.sub("", value)
    return slugify(value)


def canonical_id(display_name: str, system: str, side: str) -> str:
    prefixes = {
        "bone": "bone",
        "cartilage": "cartilage",
        "dental_structure": "tooth",
        "skeletal_feature": "skeletal_feature",
        "skeletal_structure": "skeletal_structure",
        "skeletal_muscle": "muscle",
        "musculoskeletal_connective_tissue": "connective",
    }
    prefix = prefixes[system]
    identifier = f"{prefix}.{canonical_stem(display_name, system)}"
    if side in {"left", "right"}:
        identifier += f".{side}"
    return identifier


def source_role(collection_name: str, object_type: str, parsed: ParsedName) -> str:
    if object_type == "FONT":
        return "label"
    if collection_name == "2: Muscular insertions":
        return "attachment_overlay"
    if parsed.variant in {
        "aggregate_mesh",
        "feature_overlay",
        "group_mesh",
        "selection_helper",
    }:
        return parsed.variant
    if object_type not in {"MESH", "CURVE"}:
        return "helper"
    return "structure_candidate"


def classify_system(collection_name: str, display_name: str) -> str:
    lowered = f" {display_name.lower()} "
    if collection_name == "4: Muscular system":
        if display_name.lower() == "tensor fasciae latae":
            return "skeletal_muscle"
        if any(term in lowered for term in CONNECTIVE_TERMS):
            return "musculoskeletal_connective_tissue"
        return "skeletal_muscle"

    if any(term in lowered for term in (" tooth", " teeth", "incisor", "canine", "premolar")):
        return "dental_structure"
    if "cells of ethmoid bone" in lowered:
        return "skeletal_feature"
    if any(term in lowered for term in CARTILAGE_TERMS):
        return "cartilage"
    if any(term in lowered for term in SKELETAL_FEATURE_TERMS):
        return "skeletal_feature"
    if "sinus" in lowered or "cavity" in lowered:
        return "skeletal_feature"
    if any(re.search(rf"\b{re.escape(term)}\b", lowered) for term in BONE_TERMS):
        return "bone"
    return "skeletal_structure"


def infer_region(display_name: str, parent_chain: list[str]) -> str:
    text = " ".join([display_name, *parent_chain]).lower()

    if any(term in text for term in ("pelvi", "perine", "pelvic diaphragm", "sacrum", "coccyx")):
        return "pelvis"
    if any(
        term in text
        for term in (
            "head",
            "cran",
            "facial",
            "ocular",
            "eye",
            "mandible",
            "maxilla",
            "hyoid",
            "laryn",
            "pharyn",
            "tongue",
            "neck",
            "cervical",
            "auditory ossicle",
            "teeth",
            "tooth",
            "incisor",
            "canine",
            "premolar",
            "nasal cartilage",
        )
    ):
        return "head_neck"
    if any(
        term in text
        for term in (
            "upper limb",
            "pectoral girdle",
            "shoulder",
            "arm",
            "forearm",
            "hand",
            "carpal",
        )
    ):
        return "upper_limb"
    if any(
        term in text
        for term in (
            "lower limb",
            "gluteal",
            "hip",
            "thigh",
            " leg",
            "foot",
            "tarsal",
        )
    ):
        return "lower_limb"
    if any(
        term in text
        for term in (
            "back",
            "dorsal",
            "thorac",
            "abdomen",
            "abdominal",
            "trunk",
            "rib",
            "sternum",
            "lumbar",
            "fasciae of thorax",
            "pectoral fascia",
        )
    ):
        return "torso"
    return "unknown"


def review_flags(
    source_name: str,
    parsed: ParsedName,
    system: str,
    region: str,
    source_object_count: int,
) -> list[str]:
    flags: list[str] = []
    if parsed.side == "unspecified":
        flags.append("laterality_unverified")
    if region == "unknown":
        flags.append("region_unresolved")
    if system in {"skeletal_structure", "skeletal_feature"}:
        flags.append("system_classification_review")
    if source_object_count > 1:
        flags.append("canonical_id_collision")
    if _DUPLICATE_SUFFIX_RE.search(source_name):
        flags.append("blender_duplicate_name")
    return sorted(set(flags))
