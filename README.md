# BodySim

A full-body 3D map of the muscles each exercise works, built in Godot 4.

Pick an exercise and BodySim shows its muscle engagement across a 960-structure
musculoskeletal model (466 skeletal muscles), with each muscle's role
(primary mover, synergist or stabilizer), relative involvement and confidence.

**Project page:** <https://udargit829.github.io/BodySim/> · **Live demo:**
<https://udargit829.github.io/BodySim/demo/>

- **Anatomy:** extracted from the open Z-Anatomy atlas through a Blender
  pipeline, cross-referenced to TA98 terminology. See `docs/`.
- **Exercises:** all 873 free-exercise-db exercises are searchable; 33 are
  fully visualizable. New definitions are drafted by Claude, traced into a
  466-muscle profile by a deterministic kinematic tracer, checked by
  validators, and accepted only by a review council.

## Running

Open the project in **Godot 4.7** and press Play (main scene:
`scenes/anatomy/whole_body_preview.tscn`). Right-click an exercise to see its
demonstration photos.

## Web build

Served from the `gh-pages` branch: the project page (`web/site/`) at the
root and the Godot web export under `demo/`. To publish the current `main`:

```bash
tools/web/deploy_pages.sh            # export, verify, publish
tools/web/deploy_pages.sh --no-push  # export and verify only
```

It requires a clean, pushed `main`, exports the **Web** preset into `demo/`
(the authoring studio and review council are excluded), stages the exercise
photos that the web build fetches on demand (`tools/web/stage_web_photos.py`),
adds the project page, checks the build for API keys and oversized files, and
replaces `gh-pages` with a single commit. Set `GODOT=/path/to/godot` if Godot
4.7 isn't at the default location.

The page's screenshots are generated, not hand-taken (needs a display):

```bash
godot --path . --resolution 1600x900 --script res://tools/web/take_screenshots.gd
```

## Authoring tools (desktop only)

The Kinematic Definition Studio and Review Council call Claude through the
Python bridge `tools/exercises/run_claude.py` (official `anthropic` SDK; install
with `python3 -m pip install --user -r requirements.txt`). Pick the model in
either tool; Claude Opus 5.5 is the default. The system prompt is cached (1-hour
TTL) and reviews send only the muscles the tracer engaged, to keep costs down.

The API key is never stored in the project: set `ANTHROPIC_API_KEY`, or put it
in `user://bodysim_authoring_settings.cfg` under `[anthropic] api_key="..."`.

## License

BodySim's code is released under the [MIT License](LICENSE). The anatomy
meshes in `build/anatomy/regions/` are not covered by it: they are adapted
from Z-Anatomy and BodyParts3D and remain under CC BY-SA 4.0. See
[ATTRIBUTION.md](ATTRIBUTION.md), which also credits the exercise data
(free-exercise-db, Unlicense).
