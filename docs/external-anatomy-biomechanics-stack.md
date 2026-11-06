# External Anatomy and Biomechanics Stack

## Purpose

This document records the external datasets, repositories, standards, and simulation projects evaluated for BodySim. It explains what each project contributes, what it does not provide, how BodySim expects to use it, and the licensing or technical risks that future development must preserve.

This is a research record and architecture guide, not legal or medical advice. Source availability and license terms must be verified again when assets are downloaded or redistributed.

See also [Phase 0: Full-Body Musculoskeletal Coverage](phase-0-full-body-coverage.md) for the asset-coverage implementation contract.

Last research review: **2026-08-10**

## Intended BodySim Stack

The projects below are not interchangeable. They occupy different layers:

```text
Anatomical geometry
  Z-Anatomy baseline
  Optional future Open3DModel upgrades
  BodyParts3D ontology research only
            ↓
Canonical BodySim structure catalog
  Stable IDs + TA2/FMA cross-references
            ↓
Exercise knowledge or biomechanical analysis
  Curated exercise mappings for the MVP
  OpenSim for mature regional analysis
  MuscleMimic for experimental unified full-body analysis
            ↓
Normalized BodySim muscle-result schema
  activation, force, length, strain-like metrics, and roles
            ↓
BodySim visualization and workout aggregation
```

OpenSim and MuscleMimic are alternative analysis backends. MuscleMimic is not intended to feed into OpenSim, or vice versa. Both should eventually produce the same BodySim result schema.

## Status Summary

| Project | Layer | BodySim status | Principal contribution | Principal limitation |
|---|---|---|---|---|
| Open3DModel | Anatomical geometry | Preferred geometry upgrade | Anatomist-reviewed and retopologized meshes in GLB, OBJ, and Blender formats | Coverage and downloadable packaging are still regional; static, canonical male anatomy |
| Z-Anatomy | Anatomical geometry | Phase 0 whole-body baseline | Broad, aligned, named whole-body anatomy in one Blender source | Static atlas with rougher geometry, thousands of helper objects, and mixed-license extras |
| BodyParts3D | Geometry and ontology | Research/reference only | Whole-body OBJ structures and FMA-linked hierarchy | Old, rough geometry is not part of the canonical BodySim asset |
| Open Anatomy Project | Regional clinical atlases | Supplemental/reference | MRI/CT-derived regional atlases with semantic and volumetric data | Not a complete whole-body musculoskeletal asset |
| Terminologia Anatomica 2 | Terminology | Canonical naming reference | Standard anatomical names and hierarchy | Terminology only; no geometry, exercise roles, or biomechanics |
| Foundational Model of Anatomy | Ontology | Cross-reference source | Stable anatomical concepts and part relationships | Ontology only; mappings still require curation |
| OpenSim | Biomechanical analysis | Preferred first simulation backend | Mature workflows and muscle force, fiber-length, activation, and tendon outputs | Model coverage is fragmented; muscle paths are not volumetric meshes |
| OpenSim Rajagopal model | Lower-body/full skeleton analysis | Candidate lower-body model | Validated gait-oriented lower-limb musculotendon model | Upper body is torque-actuated and unsuitable for detailed back/upper-body workouts |
| MoBL-ARMS | Upper-body analysis | Candidate upper-body model | Detailed shoulder, elbow, forearm, wrist, and selected hand musculature | Regional model; cannot independently capture whole-body stabilization |
| MuscleMimic | Full-body biomechanical analysis | Experimental post-MVP backend | Unified model with 416 Hill-type muscle actuators | Very new, computationally demanding, and not equivalent to measured human activation |
| MyoSuite | Model components and tasks | MuscleMimic dependency/reference | MuJoCo musculoskeletal models and task infrastructure | Primarily a research/control framework, not a finished anatomy product |
| MuJoCo | Physics and muscle-actuator runtime | Indirect dependency | Efficient contact dynamics and configurable muscle actuators | Generic muscle formulation and path geometry are not local 3D tissue simulation |
| MuSkeMo | Musculoskeletal authoring | Optional research tool | Builds and inspects musculoskeletal models and exports toward OpenSim | Authoring bridge, not a comprehensive validated human model |
| free-exercise-db | Exercise metadata | MVP seed/reference only | Public-domain exercise records with primary and secondary muscle groups | Broad fitness labels and unvalidated contribution magnitudes |
| wger | Exercise metadata/API | Optional reference | Large open fitness application and API | Exercise entries have individual licenses and broad muscle classifications |

## Anatomical Geometry Layer

### Open3DModel

Links:

- [Project overview](https://anatomytool.org/open3dmodel)
- [Source downloads](https://anatomytool.org/open3dmodel-create)
- [Technical and anatomical methodology](https://anatomytool.org/open3dmodel-about)

Maintained through AnatomyTOOL by anatomists associated with Leiden University Medical Center, University Medical Center Utrecht, Maastricht University Medical Center, KU Leuven, Amsterdam UMC, Radboud University Medical Center, University of Ghent, and collaborators.

#### Contribution to BodySim

- Preferred high-quality replacement geometry for structures in the Z-Anatomy baseline.
- Retopologized skeleton, muscles, tendons, joints, ligaments, cartilage, nerves, and vessels in published regions.
- Directly usable `.glb`, `.obj`, and `.blend` packages.
- Named and separately selectable structures suitable for an anatomical explorer.
- Anatomist review of structures against standard atlases, publications, and dissection material.
- Canonical Terminologia Anatomica-based naming.

The project reports that all structures were reviewed by one to three relevant anatomists and that an estimated 70% of inherited shapes were changed. Its work includes correcting muscle attachments, adding or adapting tendons and aponeuroses, improving bone features, and rebuilding many joints and connective structures.

#### Intended use

Open3DModel should replace baseline meshes only after each replacement is matched to a canonical BodySim structure ID and verified to align with adjacent structures. Its availability must not determine whether a structure exists in BodySim.

#### Limitations

- It is a work in progress, and downloadable source packaging is not yet uniform across every body region.
- Published materials emphasize a canonical adult male model.
- It represents canonical anatomy, not population variation or a patient-specific body.
- It is an educational atlas and does not guarantee clinical correctness.
- It is static geometry, not a biomechanically rigged or muscle-actuated character.
- Bilaterally identical structures may be supplied on only one side and mirrored by the project viewer. BodySim must reproduce and verify the missing side.
- A smoother, more detailed mesh may cost more memory and rendering time than the Z-Anatomy baseline.

#### Licensing

The project describes its model geometry as Creative Commons Attribution-ShareAlike. Confirm the exact license attached to each downloaded item.

Some downloadable muscle textures are separately identified as Creative Commons Attribution-NonCommercial-ShareAlike. BodySim should not assume that textures share the geometry license. Prefer original BodySim materials and retain per-asset provenance.

### Z-Anatomy

Links:

- [Human anatomy repository](https://github.com/Z-Anatomy/Models-of-human-anatomy)
- [Project site](https://www.z-anatomy.com/)

Z-Anatomy is a Blender-based open anatomy atlas derived substantially from BodyParts3D and augmented with additional structures, definitions, terminology, materials, curves, and interaction scripts.

#### Contribution to BodySim

- Phase 0 whole-body baseline because it supplies broad anatomy in one internally aligned source.
- Extensive object-level anatomical names.
- Complete spatial reference for combining head, neck, trunk, pelvis, and limbs.
- Muscular insertion overlays and a TA2 terminology table.
- The canonical visual representation used throughout Phase 0.

#### Audited source characteristics

The repository’s current `Z-Anatomy.zip` was downloaded and its `Startup.blend` was inspected headlessly during the 2026-08-09 research pass.

The file contained:

- 7,184 objects.
- 4,569 mesh objects.
- 951 curves.
- 1,660 text objects.
- 1,196,126 stored mesh vertices.
- 2,060,488 polygons.
- 1,944 collections.
- 894 objects in the muscular-system collection.
- 2,218 objects in the skeletal-system collection.
- 705 objects in the muscular-insertions collection.
- Zero armatures.
- Zero animation actions.

The compressed archive was approximately 83 MB, and the uncompressed Blender file was approximately 293 MB.

These are raw source counts. They include helpers, labels, overlays, mirrored objects, shared mesh data, and named subdivisions; they must not be treated as the canonical number of muscles or bones.

#### Intended use

- Extract only the anatomical structures needed for the BodySim musculoskeletal catalog.
- Remove text, lights, cameras, reference geometry, and Blender-only interaction helpers.
- Preserve named individual structures and laterality.
- Export deterministic regional GLBs that assemble into one complete body.
- Replace meshes with Open3DModel versions without changing canonical IDs.

#### Limitations

- It is a static atlas: there is no armature, animation, or simulation-ready rig.
- Its topology contains low-poly and hooked-surface artifacts that Open3DModel explicitly set out to correct.
- Thousands of objects and collections require preprocessing; direct import is not an acceptable production pipeline.
- Blender scripts and application-template behavior are not part of the desired BodySim runtime.
- The model is based on a canonical male foundation and does not cover population variation.
- Descriptions rely heavily on Wikipedia and automated translations, so they should not be treated as an authoritative medical knowledge base.

#### Licensing

The repository declares its shared code and content under CC BY-SA 4.0 and identifies its BodyParts3D ancestry. However, its attribution section also lists incorporated kidney and inner-ear assets under noncommercial licenses.

The repository is therefore a mixed-provenance bundle. BodySim must audit structures and textures at the asset level instead of treating the entire archive as commercially reusable. The musculoskeletal baseline should be isolated from unrelated mixed-license organs and media.

Phase 0 completed that scoped audit for the pinned 960-structure musculoskeletal
extraction. The canonical catalog contains none of the separately identified kidney,
inner-ear, brain/white-matter, or cranial-nerve systems; required Z-Anatomy and
BodyParts3D attribution and share-alike obligations are recorded in
[`anatomy-licensing.md`](anatomy-licensing.md). This conclusion does not extend to
future organs, nerves, textures, or definitions imported from the archive.

### BodyParts3D

Links:

- [Database description](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/desc.html)
- [Downloads](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html)
- [Current license](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html)
- [Original publication](https://pubmed.ncbi.nlm.nih.gov/18835852/)

BodyParts3D is a dictionary-style anatomical database in which concepts are represented by segments of a whole-body adult male model. It is the principal geometry ancestor of Z-Anatomy and therefore also of Open3DModel.

#### Contribution to BodySim

- Historical geometry reference; its meshes are not part of the canonical BodySim asset.
- OBJ geometry with stable database part IDs.
- IS-A and PART-OF hierarchy tables.
- Compound-organ definitions.
- FMA-linked concepts useful when constructing the canonical structure catalog.
- A reference source for anatomical identifiers and hierarchy research.

The current archive offers reduced polygon OBJ packages organized through IS-A and PART-OF trees, plus tables connecting names, IDs, inclusion relationships, and compound structures.

#### Limitations

- The underlying anatomical data and geometry are old; the database reports its last model update as 2013.
- Geometry is rougher and less organically retopologized than Open3DModel.
- It is derived from a single young adult male foundation and cannot represent normal human variation.
- OBJ does not preserve rich hierarchy, rigging, animation, or modern material metadata.
- It contains anatomy, not muscle activation, strain, force, exercise roles, or joint control.
- FMA mappings may not align one-to-one with the granularity used by TA2, Z-Anatomy, OpenSim, or MuscleMimic.

#### Licensing

The current database license page states CC BY 4.0 and gives the required attribution text. Older derivatives and documentation may cite older CC BY-SA terms. Record the license attached to the exact downloaded version and do not assume that a derivative inherited the archive’s later relicensing.

### Open Anatomy Project

Links:

- [Project site](https://www.openanatomy.org/)
- [Atlas catalog](https://www.openanatomy.org/atlas-pages/)
- [Open Anatomy Browser repository](https://github.com/mhalle/oabrowser)
- [Surgical Planning Laboratory datasets](https://spl.harvard.edu/software-and-data-sets)

The Open Anatomy Project at Brigham and Women’s Hospital distributes open, imaging-derived regional anatomy atlases and supporting visualization software.

#### Contribution to BodySim

- Supplemental reference for checking difficult regional anatomy.
- MRI/CT-derived knee, head and neck, abdomen, thorax, brain, liver, and inner-ear atlases.
- Volumetric labels, surface models, semantic annotations, and source imaging in some packages.
- A possible future source for organs, cross-sectional anatomy, and region-specific validation.

#### Limitations

- It is a collection of regional atlases rather than one complete aligned full-body musculoskeletal model.
- Atlas subjects, coordinate systems, segmentation resolutions, and structure granularity differ.
- Clinical scan segmentation is not automatically a clean real-time rendering mesh.
- It does not supply a unified exercise or musculoskeletal simulation model.
- It cannot be merged into the Z-Anatomy baseline without registration, normalization, and anatomical review.

#### Licensing

The project describes its browser and SPL atlases under the liberal 3D Slicer license, permitting broad use including commercialization. Verify the license and attribution accompanying each particular atlas package.

## Terminology and Identity Layer

### Terminologia Anatomica 2

Links:

- [TA2 Viewer](https://ta2viewer.openanatomy.org/)
- Z-Anatomy’s repository includes a `TA2.csv` working table.

#### Contribution to BodySim

- Preferred reference for canonical anatomical names.
- Latin and English terminology.
- Named parts and subdivisions used to construct stable BodySim IDs.
- A shared vocabulary for search, display, and cross-source aliases.

#### Limitations

- TA2 is terminology, not a directly usable whole-body mesh database.
- It does not define exercise involvement, biomechanical parameters, or simulator actuator names.
- Source models may organize anatomy at different levels of granularity.
- BodySim must maintain its own stable IDs and explicit mappings rather than making display names into primary keys.

### Foundational Model of Anatomy

BodyParts3D uses the Foundational Model of Anatomy as a major conceptual reference.

#### Contribution to BodySim

- Cross-source anatomical concept identifiers.
- PART-OF and IS-A relationships.
- A useful ontology for connecting source meshes and inherited BodyParts3D metadata.

#### Limitations

- It does not solve geometric, simulator-name, laterality, or exercise-data mappings automatically.
- FMA and TA2 may differ in organization and granularity.
- A BodySim curator must still resolve aliases, subdivisions, and many-to-many mappings.

### BodySim canonical IDs

Neither TA2 nor FMA should be used directly as the application’s only primary key. BodySim needs a stable internal namespace that can survive source replacement:

```text
muscle.biceps_brachii.right
muscle.biceps_brachii.right.long_head
bone.humerus.left
```

Each record can reference TA2, FMA, source object names, visual nodes, OpenSim muscles, and MuscleMimic actuators. The canonical catalog is the central translation layer, not a copy of any one external ontology.

## Biomechanical Analysis Layer

### OpenSim

Links:

- [OpenSim core repository](https://github.com/opensim-org/opensim-core)
- [OpenSim model repository](https://github.com/opensim-org/opensim-models)
- [Musculoskeletal model catalog](https://opensimconfluence.atlassian.net/wiki/spaces/OpenSim/pages/53090607/Musculoskeletal%2BModels)
- [Muscle output API](https://opensim-org.github.io/opensim-moco-site/docs/1.1.0/html_user/classOpenSim_1_1Muscle.html)
- [Analysis overview](https://opensimconfluence.atlassian.net/wiki/spaces/OpenSim/pages/53089585/Getting%20Started%20with%20Analyses)

OpenSim is the mature open-source platform selected for BodySim’s first biomechanical analysis experiments.

#### Contribution to BodySim

- Inverse kinematics and inverse dynamics workflows.
- Static optimization and muscle-control workflows.
- Muscle and joint analysis from prescribed motion and external loads.
- Per-muscle outputs including:
  - Activation.
  - Fiber length and normalized fiber length.
  - Fiber velocity.
  - Tendon length and tendon strain.
  - Active and passive fiber force.
  - Total musculotendon force.
  - Pennation angle.
  - Muscle power and stiffness.
  - Joint moment and induced-acceleration contributions where supported by the analysis.
- Python, Java, MATLAB, C++, and command-line integration options.

#### Intended use

OpenSim should initially run outside the visualization process as an offline analysis step or local sidecar. An adapter will translate model-specific muscle names into canonical BodySim IDs and emit normalized result files.

```text
motion + loads + OpenSim model
              ↓
        OpenSim analysis
              ↓
BodySim canonical muscle-result file
```

#### Limitations

- OpenSim software being open source does not mean every contributed model shares its license. Each model must be audited separately.
- The model ecosystem is fragmented by body region, research question, subject assumptions, and validation target.
- A model valid for gait is not automatically valid for a barbell row or shoulder exercise.
- Muscle geometry is typically a one-dimensional path with wrapping surfaces, not a volumetric muscle belly.
- Muscle recruitment is underdetermined; optimization assumptions or measured EMG influence estimated activation.
- Model outputs are estimates for the model and inputs, not direct measurements of the user.
- Tendon strain and normalized fiber length are not the same as local three-dimensional tissue strain.
- Regional model results must not be naively summed for compound movements because forces are coupled through the torso and contacts.
- Directly embedding the full OpenSim runtime into the visualization application is unnecessary for the MVP and would add deployment complexity.

#### Licensing

OpenSim core and API are Apache 2.0. Contributed models, examples, and plugins retain their own licenses. Record model-specific terms and citations with every analysis profile.

### Rajagopal full-body gait model

Links:

- [Model paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC5507211/)
- Available through the OpenSim model ecosystem.

#### Contribution to BodySim

- A full-body skeletal representation with 37 degrees of freedom.
- 80 Hill-type lower-limb musculotendon units.
- Anatomical parameters derived from cadaver studies and MRI data.
- Validation oriented toward healthy walking and running.
- A credible starting point for lower-body and gait-like analysis.

#### Limitations

- Its detailed muscle actuation is concentrated in the lower limbs.
- The upper body uses ideal torque actuators rather than detailed upper-body musculature.
- Several small lower-limb muscles were omitted where source architecture data was unavailable.
- It was designed and validated for gait, not arbitrary resistance-training exercises.
- It is not sufficient by itself for detailed rows, pull-ups, presses, or whole-body back analysis.

### MoBL-ARMS and related upper-extremity models

Links:

- [Upper-extremity model documentation](https://opensimconfluence.atlassian.net/wiki/spaces/OpenSim24/pages/54002482)
- [MoBL resources](https://mobl.wordpress.ncsu.edu/resources/)

#### Contribution to BodySim

- Detailed shoulder, elbow, forearm, wrist, thumb, and selected finger mechanics.
- Approximately 50 muscle compartments in the documented upper-extremity model.
- Muscle-tendon lengths, moment arms, forces, and joint moments over upper-limb postures.
- A candidate for curls, extensions, supported rows, and controlled upper-body exercises.

#### Limitations

- It is a regional model and does not capture lower-body or full torso stabilization.
- Scapular and thoracic behavior varies between model versions and related research models.
- It cannot make a bent-over barbell row a whole-body analysis by itself.
- Input motion, scaling, model version, and model-specific license still require careful selection.

### MuscleMimic

Links:

- [MuscleMimic framework repository](https://github.com/amathislab/musclemimic)
- [Standalone model repository](https://github.com/amathislab/musclemimic_models)
- [2026 paper](https://arxiv.org/abs/2603.25544)

MuscleMimic is a new open research framework for muscle-actuated motion imitation using MuJoCo-based musculoskeletal bodies.

#### Contribution to BodySim

- A unified MyoFullBody model with:
  - 123 joints.
  - 72 controllable degrees of freedom.
  - 416 Hill-type muscle actuators.
  - A chain spanning toes to fingertips.
  - Whole-body environmental contact and self-collision support.
- A fixed-root MyoBimanualArm model with 126 muscle actuators.
- Motion-retargeting pipelines for SMPL/AMASS-style motion.
- Learned muscle-control policies and GPU-parallel training infrastructure.
- A candidate for compound exercises that couple hands, torso, hips, legs, and ground contact.
- Standalone model assets under an Apache-2.0 repository.

The standalone model repository contains modular MJCF XML and approximately 70 STL skeletal meshes. The muscle representation is actuator and tendon-path based rather than a collection of volumetric muscle meshes.

#### Intended use

MuscleMimic should remain an experimental post-MVP analysis backend until exercise-specific feasibility, validation, compute cost, and output interpretation are understood. It should emit the same canonical BodySim result schema as OpenSim.

#### Limitations

- The paper and model release are new as of 2026 and have a much shorter validation and adoption history than OpenSim.
- Reported kinematic agreement does not mean every muscle activation is physiologically correct.
- Reproducing a movement requires a suitable controller, trajectory optimization, retargeting, or policy; the model does not automatically know how to perform an arbitrary gym exercise.
- Training policies can require substantial GPU computation and research engineering.
- The 416 actuators do not correspond one-to-one with all visually distinct anatomical muscle meshes.
- STL bone meshes and path actuators do not replace the Open3DModel/Z-Anatomy visual layer.
- Results reflect model architecture, controller objectives, and training data.
- It does not provide local volumetric tissue strain.

#### Licensing

The standalone `musclemimic_models` repository declares Apache 2.0 and includes LICENSE and NOTICE files. Audit the main framework, checkpoints, retargeted datasets, motion datasets, and transitive model assets separately; their terms need not all match the standalone model package.

### MyoSuite

Links:

- [MyoSuite repository](https://github.com/MyoHub/myosuite)
- [Documentation](https://myosuite.readthedocs.io/en/stable/)

MyoSuite supplies MuJoCo musculoskeletal models and reinforcement-learning tasks. MuscleMimic builds its bodies from MyoSuite components such as MyoArm, MyoLegs, and MyoTorso.

#### Contribution to BodySim

- Underlying musculoskeletal model components used by MuscleMimic.
- Reference environments for muscle-actuated control.
- Tooling for inspecting simulations and training controllers.
- A library of smaller models useful for isolated experiments.

#### Limitations

- It is designed for research environments and motor-control tasks, not for serving a polished anatomical atlas.
- Individual environments have different anatomical coverage and simplifications.
- Some optional models or assets may be fetched separately and require their own provenance checks.
- Its visual geometry is not a substitute for BodySim’s full-coverage anatomical source.
- Its action spaces and task assumptions may not correspond to resistance-training technique.

#### Licensing

The repository declares Apache 2.0. Separately downloaded models, submodules, datasets, and dependencies still require review.

### MuJoCo

Links:

- [MuJoCo repository](https://github.com/google-deepmind/mujoco)
- [Muscle-actuator documentation](https://mujoco.readthedocs.io/en/stable/modeling.html#muscle-actuators)
- [MJCF XML reference](https://mujoco.readthedocs.io/en/stable/XMLreference.html)

MuJoCo is the physics runtime underlying MyoSuite and MuscleMimic.

#### Contribution to BodySim

- Fast articulated rigid-body and contact simulation.
- Tendon and muscle actuator paths.
- Muscle activation dynamics.
- Force-length-velocity muscle behavior.
- Actuator length, velocity, activation, and force state that can be adapted into BodySim metrics.
- CPU simulation and accelerated research variants used by the MuscleMimic ecosystem.

#### Limitations

- Its built-in muscle formulation is a generic scalable model, not a guarantee of subject-specific physiology.
- Valid results depend on correct paths, moment arms, force parameters, joint constraints, contacts, and control inputs.
- A muscle actuator is not a volumetric finite-element muscle.
- MuJoCo by itself does not supply a canonical human body, exercise catalog, anatomical mesh atlas, or trained workout controller.
- Direct runtime integration is unnecessary for the MVP; a separate analysis process is simpler and safer.

#### Licensing

MuJoCo is distributed under Apache 2.0. Models, policies, meshes, and datasets loaded into it retain separate licenses.

### MuSkeMo

Links:

- [MuSkeMo repository](https://github.com/PashavanBijlert/MuSkeMo)
- [Project paper](https://www.biorxiv.org/content/10.1101/2024.12.10.627828v1)

MuSkeMo is an open tool for constructing, inspecting, and analyzing musculoskeletal models with interfaces for rigid bodies, joints, landmarks, muscle paths, and reference frames.

#### Potential contribution to BodySim

- Authoring and inspecting custom musculoskeletal geometry.
- Visual comparison between anatomical meshes and muscle paths.
- Defining joints, landmarks, and attachment points.
- Converting authored models toward OpenSim.
- A possible bridge when BodySim needs to create or repair an analysis model.

#### Limitations

- It is a model-authoring tool, not a complete validated human musculoskeletal dataset.
- Using it does not automatically make a model anatomically or biomechanically valid.
- It is not required for the MVP or Phase 0 asset pipeline.
- It adds value only when custom simulation-model construction becomes necessary.

## Exercise Knowledge Layer

The MVP will need exercise-to-muscle mappings before OpenSim or MuscleMimic supports every logged exercise. These mappings must be treated as curated product data rather than inferred directly from the visual anatomy.

### free-exercise-db

Link:

- [Repository](https://github.com/yuhonas/free-exercise-db)

#### Contribution to BodySim

- 873 exercise records in the snapshot audited on 2026-08-10, with unique source IDs
  and case-insensitive names.
- Exercise names, instructions, equipment, force/mechanic categories, primary muscles, and secondary muscles.
- A useful seed for aliases, exercise search, filters, and the Phase 1 review queue.

#### Limitations

- Its schema permits only 17 broad fitness-region labels such as `biceps`, `forearms`,
  or `quadriceps`, and every audited record has exactly one primary label.
- It does not map exercises to the detailed canonical anatomy required by BodySim.
- Primary and secondary labels are not quantitative activation or force measurements.
- It does not reliably represent stabilizers, contraction type, technique variations, or whole-body force transmission.
- The repository declares the dataset public domain through the Unlicense, but reviewed
  pages do not document per-item provenance for inherited photographs or instructions.

#### Intended use

Use a pinned snapshot as a discovery, alias, and metadata seed behind an explicit
review crosswalk. Do not import its muscle labels as biomechanical truth, infer zero
from omission, or redistribute its images before an asset provenance audit. BodySim
maintains independently reviewed exercise mappings with explicit confidence and
provenance. See the detailed
[`free-exercise-db` assessment](free-exercise-db-assessment.md).

### wger

Links:

- [Repository](https://github.com/wger-project/wger)
- [Documentation](https://wger.readthedocs.io/en/stable/)

#### Contribution to BodySim

- A large open-source workout, exercise, nutrition, and tracking application.
- A REST API and community-maintained exercise catalog.
- Primary and secondary muscle fields.
- Useful reference for exercise aliases, equipment, translations, and workout data modeling.

#### Limitations

- Application code is AGPL, which is not automatically appropriate to embed in BodySim.
- Exercise and ingredient records use Creative Commons licenses on an individual-entry basis.
- Muscle classifications remain too broad for BodySim’s detailed anatomical catalog.
- Community data quality and completeness vary.
- Depending on the public API would introduce network and service availability concerns.

#### Intended use

Treat wger as a reference or optional import source, not a default runtime dependency. If records are incorporated, store the license and attribution of each entry.

## Normalized Analysis Contract

All analysis sources must be translated into a simulator-independent BodySim schema. The visualization and workout-summary layers must not depend on an OpenSim or MuscleMimic name.

Example:

```json
{
  "schema_version": 1,
  "analysis_backend": "opensim",
  "analysis_profile": "mobl_arms_version_x",
  "exercise_id": "dumbbell_curl",
  "samples": [
    {
      "phase": 0.5,
      "muscles": {
        "muscle.biceps_brachii.right.long_head": {
          "activation": 0.72,
          "normalized_fiber_length": 0.91,
          "force_newtons": 384.5,
          "tendon_strain": 0.021,
          "joint_moment_nm": 18.4,
          "confidence": "model_estimate"
        }
      }
    }
  ]
}
```

Adapters are responsible for:

- Mapping simulator names to canonical IDs.
- Declaring the model version and license.
- Recording motion, load, and scaling assumptions.
- Converting units.
- Distinguishing unavailable outputs from numeric zero.
- Identifying whether a value is measured, prescribed, optimized, simulated, or curated.
- Preventing unsupported precision from appearing in the interface.

## Interpretation Rules

Future development must preserve the following distinctions:

1. **A visible muscle mesh is not a biomechanical muscle model.** The visual mesh displays results produced elsewhere.
2. **Curated engagement is not simulated activation.** MVP scores must be labeled as modeled workout exposure.
3. **Simulated activation is not measured activation.** Optimization and controller assumptions matter.
4. **Normalized fiber length is not local tissue strain.** Full local strain requires volumetric finite-element geometry and material models.
5. **A zero is not missing data.** Unmapped, unsupported, failed, and genuinely negligible values require different states.
6. **Regional simulations cannot simply be added.** Whole-body compound movements exchange forces through the torso and contacts.
7. **Canonical anatomy is not universal anatomy.** The initial sources primarily represent a canonical young adult male foundation.
8. **Open source does not imply one uniform license.** Code, models, textures, datasets, policies, and individual records may differ.

## Source Selection Rules

When choosing a source for new work:

### Visual geometry

1. Prefer a verified Open3DModel mesh.
2. Fall back to the aligned Z-Anatomy baseline.
3. Fall back to BodyParts3D.
4. Record unresolved gaps as blockers; never silently omit them.

### Biomechanical analysis

1. Prefer a model validated for the movement and body region in question.
2. Use OpenSim first for mature regional analysis.
3. Use a unified full-body model for exercises that couple upper body, torso, lower body, and ground contact.
4. Treat MuscleMimic as experimental until an exercise-specific validation workflow exists.
5. Use curated MVP mappings when no defensible simulation profile is available, and label them accordingly.

### Exercise metadata

1. Use external exercise datasets for discovery and aliases.
2. Store BodySim’s detailed muscle mappings independently.
3. Record mapping evidence, contributor, review state, and confidence.
4. Do not translate a broad label such as `back` or `biceps` into detailed anatomy without explicit curation.

## Current Architectural Decisions

- Z-Anatomy is the full-coverage Phase 0 baseline, not the final quality ceiling.
- Open3DModel is the preferred regional geometry upgrade.
- BodyParts3D is retained only as an ontology and historical geometry reference.
- Open Anatomy Project is supplemental, not part of the aligned whole-body baseline.
- BodySim owns its canonical IDs and cross-reference table.
- Curated exercise mappings power the MVP.
- OpenSim is the preferred first simulation integration.
- MuscleMimic is the candidate full-body research backend.
- MyoSuite and MuJoCo are underlying simulation dependencies, not visual anatomy sources.
- Analysis runs outside the visualization runtime initially.
- Animation and muscle deformation are presentation phases and do not block static analysis or heatmaps.
- Asset, model, data, and texture licenses are tracked independently.

## Open Questions

- What exact canonical muscle and bone count will result from the Phase 0 catalog audit?
- Does the latest Open3DModel release provide every trunk structure needed for direct replacement, or only regional submodels?
- Which Z-Anatomy musculoskeletal objects are true structures versus insertion overlays, helpers, or duplicates?
- Which OpenSim model versions and licenses best cover the initial exercise catalog?
- What full-body model best handles loaded hip hinges, rows, squats, and presses without unsupported assumptions?
- Can MuscleMimic reproduce specific resistance-training movements without extensive new policy training?
- What external-load representation will be used for barbells, dumbbells, cables, machines, and body weight?
- How should canonical muscle groups inherit or divide scores when evidence exists only at group level?
- What clinical or anatomical review process is feasible for the exercise-to-muscle mappings?

These questions should produce explicit decisions and records rather than implicit assumptions in code.
