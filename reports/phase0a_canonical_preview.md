# Phase 0A Canonical Whole-Body Preview

- Canonical structures rendered: **960/960**
- GLB size: **30,410,776 bytes**
- GLB SHA-256: `2152726ab0365e792043b931c3b780bd628ff2f6d36aafcac1738c884b6a3498`
- Asset role: **monolithic_catalog_extraction_check**
- Explicit non-blocking terminology exclusions: **42**

Every structure in the approved baseline catalog has its own renderable Godot
mesh node. The whole-body preview exposes independent muscle, bone/feature,
cartilage, and connective-tissue layers.

The 42 external terminology terms recorded in
`data/anatomy/phase0_scope_exclusions.json` are outside the canonical product
scope. They are not counted as represented and no fallback geometry is shipped.
