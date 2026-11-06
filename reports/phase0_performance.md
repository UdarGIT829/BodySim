# Phase 0 Performance

Status: **PASSED**

Measured with Godot 4.7.1-stable (official) using `forward_plus` / `vulkan` at 64x64.

| Measurement | Result | Budget |
|---|---:|---:|
| Canonical meshes | 960 | 960 |
| Load to ready | 272.78 ms | ≤ 3000 ms |
| Incremental static memory | 126122479 bytes | ≤ 1073741824 bytes |
| Average frame rate | 144.94 FPS | ≥ 30 FPS |
| 95th-percentile frame | 6.917 ms | ≤ 33.34 ms |
| Draw calls | 0 | recorded |
| Rendered primitives | 0 | recorded |

The benchmark keeps all 960 canonical meshes loaded and visible. Budgets are the
Phase 0 reference-desktop contract; future optimizations may improve these values
but may not remove canonical anatomy.
