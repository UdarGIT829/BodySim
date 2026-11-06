# BodySim

A full-body 3D map of the muscles each exercise works, built in Godot 4.

Pick an exercise and BodySim shows its muscle engagement across a 960-structure
musculoskeletal model (466 skeletal muscles), with each muscle's role
(primary, secondary or stabilizer), relative involvement and confidence.

- **Anatomy:** extracted from the open Z-Anatomy atlas through a Blender
  pipeline, cross-referenced to TA98 terminology. See `docs/`.
- **Exercises:** all 873 free-exercise-db exercises are searchable; 21 are
  fully visualizable. New definitions are drafted by an LLM, checked by
  deterministic validators, and accepted only by a review council.

## Running

Open the project in **Godot 4.7** and press Play (main scene:
`scenes/anatomy/whole_body_preview.tscn`). Right-click an exercise to see its
demonstration photos.

## Web build

1. Export the **Web** preset (writes `build/web/`). The authoring studio and
   review council are excluded from web builds.
2. Stage the photos next to it, since the web build fetches them on demand:
   `python3 tools/web/stage_web_photos.py build/web`

## Authoring tools (desktop only)

The Kinematic Definition Studio and Review Council call the OpenAI API. The key
is never stored in the project: set `OPENAI_API_KEY`, or put it in
`user://bodysim_authoring_settings.cfg` under `[openai] api_key="..."`.

## Credits

See [ATTRIBUTION.md](ATTRIBUTION.md) for the anatomy models (CC BY-SA) and
exercise data (Unlicense).
