# Abdominal wall

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (6 entries): accepted Claude (claude-opus-5-5) draft without line-by-line expert review, at the project owner's request; automated rule and whole-table sanity checks passed.

**Rule checks:** all passed

## External abdominal oblique muscle  `muscle.external_abdominal_oblique`
*reviewed · confidence high*

- lumbar_spine / rotation: **0.90**
- lumbar_spine / lateral_flexion: **0.70**
- lumbar_spine / flexion: **0.60**
- stabilizes anti_rotation_torso: 1.00
- stabilizes anti_extension_spine: 0.80
- stabilizes intra_abdominal_pressure: 0.60
- stabilizes pelvic_alignment: 0.40

> Acting unilaterally it rotates the trunk to the opposite side together with the contralateral internal oblique, and it flexes the trunk to its own side. Acting bilaterally it assists rectus abdominis in trunk flexion. It is a key anti-rotation and anti-extension brace and contributes to posterior pelvic tilt.

## Internal abdominal oblique muscle  `muscle.internal_abdominal_oblique`
*reviewed · confidence high*

- lumbar_spine / rotation: **0.90**
- lumbar_spine / lateral_flexion: **0.70**
- lumbar_spine / flexion: **0.60**
- stabilizes anti_rotation_torso: 0.90
- stabilizes intra_abdominal_pressure: 0.80
- stabilizes anti_extension_spine: 0.70
- stabilizes lumbar_fascia_tension: 0.50
- stabilizes pelvic_alignment: 0.30

> Acting unilaterally it rotates the trunk to the same side, paired with the contralateral external oblique, and laterally flexes the trunk. Acting bilaterally it assists trunk flexion. Its deep transverse fibres and its attachment to the thoracolumbar fascia give it a larger bracing and fascia-tensioning role than the external oblique.

## Pyramidalis muscle  `muscle.pyramidalis`
*reviewed · confidence low*

- stabilizes intra_abdominal_pressure: 0.10

> This small, often absent muscle only tenses the linea alba and has no joint action. Its stabilizing contribution to abdominal wall bracing is at most minor.

## Quadratus lumborum muscle  `muscle.quadratus_lumborum`
*reviewed · confidence medium*

- lumbar_spine / lateral_flexion: **0.90**
- lumbar_spine / extension: **0.30**
- stabilizes pelvic_leveling_frontal: 0.60
- stabilizes postural_stabilization: 0.40
- stabilizes anti_flexion_spine: 0.30
- stabilizes lumbar_fascia_tension: 0.20

> Acting unilaterally it is a major lateral flexor of the lumbar spine and hikes the ipsilateral pelvis; pelvic elevation is not in the vocabulary and is covered by frontal pelvic leveling. Acting bilaterally it assists lumbar extension. It also fixes the 12th rib during inspiration, which is likewise not in the vocabulary.

## Rectus abdominis muscle  `muscle.rectus_abdominis`
*reviewed · confidence high*

- lumbar_spine / flexion: **1.00**
- lumbar_spine / lateral_flexion: **0.20**
- stabilizes anti_extension_spine: 1.00
- stabilizes pelvic_alignment: 0.60
- stabilizes intra_abdominal_pressure: 0.40

> It is the prime mover of trunk flexion and the main resister of lumbar extension, for example in planks. It tilts the pelvis posteriorly. Its unilateral lateral flexion is minor.

## Transversus abdominis muscle  `muscle.transversus_abdominis`
*reviewed · confidence high*

- stabilizes intra_abdominal_pressure: 1.00
- stabilizes lumbar_fascia_tension: 0.90
- stabilizes anti_rotation_torso: 0.30
- stabilizes anti_extension_spine: 0.30

> Its horizontal fibres compress the abdomen and tension the thoracolumbar fascia, making it the primary muscle for raising intra-abdominal pressure. Its direct spinal joint actions are negligible, so no joint actions are listed.
