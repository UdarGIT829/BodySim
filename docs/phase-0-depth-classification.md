# Phase 0 Display-Depth Classification

BodySim's surface/deep controls are visualization aids for revealing overlapping
musculoskeletal geometry. They are not diagnostic, surgical, or universally agreed
anatomical planes.

The generated `data/anatomy/display_depth.json` classifies all 466 canonical skeletal
muscle structures:

- 160 superficial-display structures.
- 306 deep-display structures.
- 130 classifications explicitly supported by a Z-Anatomy name or collection.
- 68 classifications assigned by a curated surface-family rule.
- 268 conservative defaults retained in the deep layer.

Classification precedence is deterministic:

1. Source names or taxonomy containing `superficial` are superficial.
2. Source names or taxonomy containing `deep` are deep.
3. Curated, documented surface muscle families are superficial.
4. Uncertain muscles default to deep so hiding the surface never causes them to
   disappear from both useful views.

Non-muscle structures use `structural` depth and are controlled by their existing
bones, cartilage, teeth/features, or connective-tissue toggles. The surface and deep
buttons therefore filter muscles only and compose with every existing system,
selection, isolation, and hide state.

Regenerate the file with:

```bash
python3 tools/anatomy/generate_display_depth.py \
  --catalog data/anatomy/structures.json \
  --output data/anatomy/display_depth.json
```

The manifest generator requires complete depth coverage for every skeletal muscle
and fails if the classification file is stale or incomplete.
