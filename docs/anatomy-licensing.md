# Phase 0 Anatomy Licensing

This record applies to BodySim's pinned 960-structure musculoskeletal extraction from
the Z-Anatomy `Startup.blend` archive. It is an engineering provenance decision, not
legal advice.

## Source evidence

The Z-Anatomy repository states that all code and content it shares is licensed under
Creative Commons Attribution-ShareAlike 4.0 International. Its model attribution
section requires credit to both:

- “Z-Anatomy - The libre 3D atlas of anatomy - CC-BY-SA 4.0”.
- “BodyParts3D - The Database Center for Life Science - CC-BY-SA 2.1 Japan”.

Primary evidence:

- [Z-Anatomy repository and licensing statement](https://github.com/Z-Anatomy/Models-of-human-anatomy)
- [Repository license text](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/License.txt)
- [Repository attribution section](https://github.com/Z-Anatomy/Models-of-human-anatomy/blob/master/Readme.md#attributions)

The same attribution section separately identifies incorporated inner-ear and kidney
assets under noncommercial licenses. BodySim's canonical extraction contains only
bones, skeletal muscles, cartilage, teeth, skeletal features, and musculoskeletal
connective tissue. It contains none of the named kidney, inner-ear, brain/white-matter,
or cranial-nerve third-party systems.

On that scoped evidence, the pinned Phase 0 musculoskeletal extraction is marked
`verified_for_distribution`. This conclusion must not be copied automatically to
future organs, nerves, textures, definitions, or other assets added from the mixed
archive.

## Distribution obligations

A BodySim distribution containing these meshes must:

1. Preserve the recorded Z-Anatomy and BodyParts3D attribution.
2. Include or link the applicable Creative Commons license notices.
3. identify BodySim's extraction, material replacement, metadata, and export changes.
4. Distribute adaptations under CC BY-SA 4.0-compatible share-alike terms.

The machine-readable source record is
`data/anatomy/sources/z_anatomy.json`. Every manifest structure references that source
record and carries its verified status and attribution.
