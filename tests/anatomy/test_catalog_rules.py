import sys
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[2] / "tools" / "anatomy"
sys.path.insert(0, str(TOOLS_DIR))

from catalog_rules import (  # noqa: E402
    canonical_id,
    classify_system,
    infer_region,
    parse_source_name,
    source_role,
)


class ParseSourceNameTests(unittest.TestCase):
    def test_bilateral_structure(self):
        parsed = parse_source_name("Latissimus dorsi muscle.r")
        self.assertEqual(parsed.base_name, "Latissimus dorsi muscle")
        self.assertEqual(parsed.side, "right")
        self.assertEqual(parsed.variant, "structure")

    def test_parenthesized_structure(self):
        parsed = parse_source_name("(Abdominal part of pectoralis major muscle).l")
        self.assertEqual(parsed.base_name, "Abdominal part of pectoralis major muscle")

    def test_indexed_attachment_overlay(self):
        parsed = parse_source_name("Diaphragm.o5r")
        self.assertEqual(parsed.base_name, "Diaphragm")
        self.assertEqual(parsed.side, "right")
        self.assertEqual(parsed.variant, "origin_overlay")
        self.assertEqual(parsed.attachment_index, 5)

    def test_aggregate_mesh(self):
        parsed = parse_source_name("Pelvic girdle.j")
        self.assertEqual(parsed.base_name, "Pelvic girdle")
        self.assertEqual(parsed.variant, "aggregate_mesh")


class ClassificationTests(unittest.TestCase):
    def test_muscle_id_removes_redundant_suffix(self):
        identifier = canonical_id(
            "Latissimus dorsi muscle", "skeletal_muscle", "left"
        )
        self.assertEqual(identifier, "muscle.latissimus_dorsi.left")

    def test_connective_tissue_in_muscular_collection(self):
        system = classify_system("4: Muscular system", "Common tendinous ring")
        self.assertEqual(system, "musculoskeletal_connective_tissue")

    def test_tensor_fasciae_latae_is_muscle_despite_name(self):
        system = classify_system("4: Muscular system", "Tensor fasciae latae")
        self.assertEqual(system, "skeletal_muscle")

    def test_tendinous_arch_is_connective_tissue(self):
        system = classify_system(
            "4: Muscular system", "Tendinous arch of levator ani"
        )
        self.assertEqual(system, "musculoskeletal_connective_tissue")

    def test_skeletal_feature_not_classified_as_whole_bone(self):
        system = classify_system("1: Skeletal system", "Sinus of frontal bone")
        self.assertEqual(system, "skeletal_feature")

    def test_ethmoidal_air_cells_are_features_not_bones(self):
        system = classify_system(
            "1: Skeletal system", "Anterior cells of ethmoid bone"
        )
        self.assertEqual(system, "skeletal_feature")

    def test_whole_bone_classification(self):
        system = classify_system("1: Skeletal system", "Humerus")
        self.assertEqual(system, "bone")

    def test_special_named_cervical_vertebra_is_bone(self):
        system = classify_system("1: Skeletal system", "Atlas (C1)")
        self.assertEqual(system, "bone")

    def test_phalanx_is_bone(self):
        system = classify_system("1: Skeletal system", "Proximal phalanx of thumb")
        self.assertEqual(system, "bone")

    def test_tooth_is_not_classified_as_bone(self):
        system = classify_system("1: Skeletal system", "Upper first molar tooth")
        self.assertEqual(system, "dental_structure")

    def test_region_uses_parent_hierarchy(self):
        region = infer_region(
            "Latissimus dorsi muscle",
            ["Hypaxial muscles of back.g", "Dorsal part of muscular system.g"],
        )
        self.assertEqual(region, "torso")

    def test_region_recognizes_auditory_ossicles(self):
        region = infer_region("Incus", ["Auditory ossicles.g", "Skeletal system.g"])
        self.assertEqual(region, "head_neck")

    def test_region_recognizes_lumbar_vertebrae(self):
        region = infer_region("Vertebra L1", ["Lumbar vertebrae.g", "Skeletal system.g"])
        self.assertEqual(region, "torso")

    def test_insertions_are_never_structure_candidates(self):
        parsed = parse_source_name("Rectus abdominis muscle.or")
        role = source_role("2: Muscular insertions", "MESH", parsed)
        self.assertEqual(role, "attachment_overlay")


if __name__ == "__main__":
    unittest.main()
