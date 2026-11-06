import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class CoverageAuditTests(unittest.TestCase):
    def test_standard_adult_skeleton_has_no_coverage_failures(self):
        report = json.loads(
            (ROOT / "reports/phase0a_external_skeleton_coverage.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(report["requirements_audited"], 17)
        self.assertEqual(report["release_blocking_failures"], 0)

    def test_muscle_audit_has_no_unadjudicated_terms(self):
        report = json.loads(
            (ROOT / "reports/phase0a_external_muscle_coverage.json").read_text(
                encoding="utf-8"
            )
        )
        unresolved = [
            item for item in report["results"] if item["status"] == "unresolved"
        ]
        self.assertEqual(unresolved, [])
        self.assertEqual(report["release_blocking_gaps"], 0)

    def test_scope_exclusions_are_not_silently_treated_as_represented(self):
        report = json.loads(
            (ROOT / "reports/phase0a_external_muscle_coverage.json").read_text(
                encoding="utf-8"
            )
        )
        excluded = [
            item
            for item in report["results"]
            if item["status"] == "excluded_phase0_reference_only"
        ]
        self.assertEqual(len(excluded), 22)
        self.assertTrue(all(not item["evidence_ids"] for item in excluded))

    def test_cross_referenced_audit_has_no_unresolved_terms(self):
        report = json.loads(
            (ROOT / "reports/phase0a_cross_referenced_muscle_coverage.json").read_text(
                encoding="utf-8"
            )
        )
        unresolved = [item for item in report["results"] if item["status"] == "unresolved"]
        self.assertEqual(unresolved, [])
        self.assertEqual(report["release_blocking_gaps"], 0)

    def test_reference_only_exclusions_are_explicit_and_non_blocking(self):
        exclusions = json.loads(
            (ROOT / "data/anatomy/phase0_scope_exclusions.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(exclusions["status"], "approved_non_blocking_scope_exclusions")
        self.assertEqual(exclusions["excluded_term_count"], 42)
        self.assertEqual(len(exclusions["excluded_terms"]), 42)
        identities = {
            (item["reference_code"], item["name"])
            for item in exclusions["excluded_terms"]
        }
        self.assertEqual(len(identities), 42)

        for report_name, expected in [
            ("phase0a_external_muscle_coverage.json", 22),
            ("phase0a_cross_referenced_muscle_coverage.json", 20),
        ]:
            report = json.loads((ROOT / "reports" / report_name).read_text(encoding="utf-8"))
            excluded = [
                item
                for item in report["results"]
                if item["status"] == "excluded_phase0_reference_only"
            ]
            self.assertEqual(len(excluded), expected)
            self.assertEqual(report["release_blocking_gaps"], 0)

    def test_canonical_preview_has_complete_render_coverage(self):
        report = json.loads(
            (ROOT / "reports/phase0a_canonical_preview.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(report["catalog_structures"], 960)
        self.assertEqual(report["canonical_structure_nodes"], 960)
        self.assertEqual(report["canonical_mesh_nodes"], 960)
        self.assertEqual(report["asset_role"], "monolithic_catalog_extraction_check")
        self.assertEqual(report["scope_exclusions"], 42)
        self.assertEqual(report["catalog_system_counts"]["cartilage"], 31)
        self.assertEqual(report["catalog_system_counts"]["musculoskeletal_connective_tissue"], 217)
        self.assertEqual(report["catalog_system_counts"]["skeletal_feature"], 9)
        self.assertEqual(sum(report["catalog_system_counts"].values()), 960)

    def test_regional_export_partitions_every_canonical_identity_once(self):
        report = json.loads(
            (ROOT / "reports/phase0b_regional_export.json").read_text(encoding="utf-8")
        )
        self.assertEqual(report["assets_passed"], 7)
        self.assertEqual(report["structures_found"], 960)
        self.assertEqual(report["structures_expected"], 960)
        self.assertEqual(report["identity_failures"], 0)
        self.assertEqual(
            sum(item["structure_nodes"] for item in report["assets"].values()),
            960,
        )

    def test_mesh_manifest_resolves_every_canonical_structure(self):
        catalog = json.loads(
            (ROOT / "data/anatomy/structures.json").read_text(encoding="utf-8")
        )
        manifest = json.loads(
            (ROOT / "data/anatomy/mesh_manifest.json").read_text(encoding="utf-8")
        )
        records = manifest["structures"]
        self.assertEqual(manifest["catalog_sha256"], catalog["catalog_sha256"])
        self.assertEqual(manifest["structure_count"], 960)
        self.assertEqual(len(records), 960)
        self.assertEqual(
            {item["id"] for item in records},
            {item["id"] for item in catalog["structures"]},
        )
        self.assertTrue(all(item["mesh_assigned"] for item in records))
        self.assertTrue(all(item["visible"] for item in records))
        self.assertTrue(all(item["godot_node"] == item["id"] for item in records))
        muscle_depths = [
            item["display_depth"]
            for item in records
            if item["system"] == "skeletal_muscle"
        ]
        self.assertEqual(len(muscle_depths), 466)
        self.assertEqual(muscle_depths.count("superficial"), 160)
        self.assertEqual(muscle_depths.count("deep"), 306)

    def test_coverage_report_keeps_known_phase0_blockers_explicit(self):
        report = json.loads(
            (ROOT / "reports/anatomy_coverage.json").read_text(encoding="utf-8")
        )
        self.assertEqual(report["canonical_structures"], 960)
        self.assertEqual(report["mesh_assigned"], 960)
        self.assertEqual(report["renderable_mesh_nodes"], 960)
        self.assertEqual(report["missing_structures"], 0)
        self.assertEqual(report["import_failures"], 0)
        self.assertEqual(report["selectable"], 960)
        self.assertEqual(report["licensing_resolved"], 960)
        self.assertEqual(report["release_blocking_conditions"], [])
        self.assertEqual(report["phase0_status"], "complete")

    def test_source_license_has_distribution_evidence_and_obligations(self):
        source = json.loads(
            (ROOT / "data/anatomy/sources/z_anatomy.json").read_text(encoding="utf-8")
        )
        self.assertEqual(source["asset_license_status"], "verified_for_distribution")
        self.assertGreaterEqual(len(source["license_evidence"]), 3)
        self.assertGreaterEqual(len(source["distribution_obligations"]), 4)

    def test_whole_body_performance_meets_phase0_budgets(self):
        report = json.loads(
            (ROOT / "reports/phase0_performance.json").read_text(encoding="utf-8")
        )
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["measurements"]["canonical_meshes"], 960)
        self.assertTrue(all(report["checks"].values()))

if __name__ == "__main__":
    unittest.main()
