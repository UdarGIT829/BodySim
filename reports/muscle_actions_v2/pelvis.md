# Pelvis and pelvic floor

Drafted by claude-opus-5-5. Review each muscle; set `status` to `reviewed` in the JSON once it is right.

**Approved** (5 entries): accepted Claude (claude-opus-5-5) draft without line-by-line expert review, at the project owner's request; automated rule and whole-table sanity checks passed.

**Rule checks:** all passed

## Coccygeus muscle  `muscle.coccygeus`
*reviewed · confidence medium*

- stabilizes intra_abdominal_pressure: 0.20

> Forms the posterior pelvic diaphragm and gives a minor contribution to the pelvic floor's support during bracing. It flexes the coccyx and stabilises the sacrococcygeal joint, but the vocabulary has no joint for either action, so neither is listed.

## External anal sphincter  `muscle.external_anal_sphincter`
*reviewed · confidence medium* · **not a movement muscle**

- (no actions)

> A continence sphincter with no joint action and no meaningful role in trunk bracing, so it is treated as a non-movement muscle. Its reflex contraction during straining is not modelled.

## Iliococcygeus muscle  `muscle.iliococcygeus`
*reviewed · confidence medium*

- stabilizes intra_abdominal_pressure: 0.40

> As part of levator ani, it co-contracts with the diaphragm and transversus abdominis to form the floor of the pressurised abdominal canister during bracing, a clear assistant role. It has no vocabulary joint action; coccygeal flexion is omitted.

## Pubo-analis muscle  `muscle.pubo_analis`
*reviewed · confidence low*

- stabilizes intra_abdominal_pressure: 0.20

> These medial levator ani fibres act mainly on the anorectal junction for continence, giving only a minor share of pelvic floor support during bracing. It has no joint action in the vocabulary.

## Pubococcygeus muscle  `muscle.pubococcygeus`
*reviewed · confidence medium*

- stabilizes intra_abdominal_pressure: 0.40

> As the main levator ani component, it supports the pelvic viscera and co-contracts during trunk bracing to contain intra-abdominal pressure, a clear assistant role. It has no joint action in the vocabulary.
