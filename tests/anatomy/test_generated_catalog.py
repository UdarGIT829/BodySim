import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class GeneratedCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(
            (ROOT / "data/anatomy/structures.json").read_text(encoding="utf-8")
        )
        cls.inventory = json.loads(
            (ROOT / "data/anatomy/source/z_anatomy_inventory.json").read_text(
                encoding="utf-8"
            )
        )
        cls.object_index = json.loads(
            (ROOT / "data/anatomy/source/z_anatomy_object_index.json").read_text(
                encoding="utf-8"
            )
        )

    def test_pinned_source_was_extracted_completely(self):
        self.assertEqual(self.inventory["summary"]["objects"], 3817)
        self.assertEqual(self.inventory["missing_required_collections"], [])
        self.assertEqual(len(self.inventory["objects"]), 3817)
        self.assertEqual(self.object_index["object_count"], 7184)
        self.assertEqual(len(self.object_index["objects"]), 7184)

    def test_structure_ids_are_unique(self):
        identifiers = [item["id"] for item in self.catalog["structures"]]
        self.assertEqual(len(identifiers), len(set(identifiers)))

    def test_every_structure_has_source_geometry(self):
        inventory_names = {
            (item["collection"], item["source_name"])
            for item in self.inventory["objects"]
        }
        for structure in self.catalog["structures"]:
            self.assertTrue(structure["source_refs"])
            for source in structure["source_refs"]:
                self.assertIn(
                    (source["source_collection"], source["source_object"]),
                    inventory_names,
                )
                self.assertGreater(source["geometry"]["vertices"], 0)

    def test_whole_body_region_coverage_is_present(self):
        regions = {item["region"] for item in self.catalog["structures"]}
        self.assertTrue(
            {"head_neck", "torso", "pelvis", "upper_limb", "lower_limb"}.issubset(
                regions
            )
        )

    def test_no_unspecified_laterality_remains(self):
        unspecified = [
            item["id"]
            for item in self.catalog["structures"]
            if item["side"] == "unspecified"
        ]
        self.assertEqual(unspecified, [])

    def test_iliocostalis_colli_has_independent_source_objects(self):
        identifiers = {item["id"]: item for item in self.catalog["structures"]}
        self.assertEqual(
            identifiers["muscle.iliocostalis_colli.left"]["source_refs"][0][
                "source_object"
            ],
            "Iliocostalis colli muscle",
        )
        self.assertEqual(
            identifiers["muscle.iliocostalis_colli.right"]["source_refs"][0][
                "source_object"
            ],
            "Iliocostalis colli muscle.r",
        )

    def test_parent_references_exist_and_never_self_reference(self):
        identifiers = {item["id"] for item in self.catalog["structures"]}
        for item in self.catalog["structures"]:
            if item["parent_id"] is not None:
                self.assertIn(item["parent_id"], identifiers)
                self.assertNotEqual(item["parent_id"], item["id"])

    def test_iliotibial_tract_uses_curated_anatomical_parent(self):
        identifiers = {item["id"]: item for item in self.catalog["structures"]}
        item = identifiers["connective.iliotibial_tract.left"]
        self.assertEqual(item["parent_id"], "connective.fascia_lata.left")
        self.assertEqual(
            item["source_parent_candidate_id"], "muscle.tensor_fasciae_latae.left"
        )
        self.assertEqual(item["parent_relation"], "part_of")


if __name__ == "__main__":
    unittest.main()
