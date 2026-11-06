# Phase 2A Completion: Complete Exercise Catalog and Media

## Result

Phase 2A is complete. BodySim now carries and exposes the complete audited
free-exercise-db snapshot while preserving a strict boundary between searchable source
records and reviewed biomechanical definitions.

## Catalog Inventory

| Inventory | Count |
|---|---:|
| Source records | 873 |
| Catalog-only records | 853 |
| Already promoted source records | 20 |
| Canonical visualizable variants | 21 |
| Rows represented in the merged selector | 874 |

The selector has one row for every unpromoted source record and one row for every
canonical visualizable variant. Barbell Squat is one promoted source record that maps
to both high-bar and low-bar canonical variants, producing the intentional one-row
difference between the 873-record source and 874-row merged view.

## Media Inventory

| Inventory | Count |
|---|---:|
| Local JPEG resources | 1,746 |
| Source records with two images | 873 |
| Media-manifest selector identities | 894 |
| Approximate source-image disk size | 102 MB |

The manifest includes every source identity plus the 21 canonical variant identities.
Each image record retains its source-relative path, local Godot resource path, SHA-256
checksum, and byte count. Images are local assets and require no runtime network call.

## Runtime Semantics

- Visualizable variants appear under a green **Visualizable** group.
- Unpromoted records appear under an amber **Catalog only** group.
- Catalog-only records are grouped by source exercise category.
- Search covers names, IDs, canonical aliases and movement families, source metadata,
  instructions, equipment, and quarantined broad muscle tags.
- Selecting a visualizable variant continues to render its reviewed profile.
- Selecting a catalog-only record disables any prior heatmap.
- The affected-structures panel explicitly reports that kinematic definition and
  review are required.
- Right-clicking either kind of exercise opens its two local source images.

Broad source muscle labels remain discovery metadata and are visibly identified as
not being evidence. No catalog-only record can emit the canonical `exercise_selected`
signal used to score a heatmap; it emits a separate `catalog_exercise_selected` signal.

## Generated and Maintained Files

- `data/exercises/catalog/candidates.json`
- `data/exercises/sources/free_exercise_db_media.json`
- `assets/exercises/free_exercise_db/`
- `tools/exercises/generate_candidate_catalog.py`
- `tools/exercises/import_free_exercise_db_media.py`

The generators are deterministic against the pinned local source snapshot. The media
importer is concurrent, resumable, validates JPEG signatures, and records checksums.

## Verification

- Candidate catalog represents all 873 unique source records exactly once.
- Status distribution is exactly 853 catalog-only and 20 promoted source records.
- Promoted records resolve to exactly 21 canonical variants.
- Media manifest contains 894 unique selector identities.
- All 1,746 unique resource paths exist locally.
- Selector verification covers merged counts, status grouping, canonical heatmaps,
  catalog-only heatmap suppression, affected muscles, and images for both states.

## Next Phase

Phase 2B builds the editor-authored Kinematic Definition Studio. It consumes a
catalog-only record and produces an editable, deterministically validated definition
candidate without modifying canonical exercise data.
