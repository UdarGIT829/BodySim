"""A "how the tracer works" reference for the authoring and review prompts.

Generated from the v2 muscle-action table and tracer constants, so it can't
drift from what the tracer actually does. It is deterministic (sorted, no
timestamps), which keeps it inside the cached prompt prefix: every authoring
or review request in a session reads it from cache.
"""

from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Tuple

from src.anatomy.muscle_actions_v2 import load_vocabulary, merged_table
from tools.exercises import kinematic_tracer as tracer


def _short(muscle_id: str) -> str:
    base = muscle_id.rsplit(".", 1)[0] if muscle_id.endswith((".left", ".right")) else muscle_id
    return base.replace("muscle.", "")


def tracer_reference() -> str:
    vocabulary = load_vocabulary()
    records, missing = merged_table()
    if missing:
        raise RuntimeError(f"muscle-action table incomplete: {', '.join(missing)}")

    # One row per muscle (left and right sides are identical).
    by_base: Dict[str, dict] = {}
    for r in records:
        if r["movement_muscle"]:
            by_base.setdefault(_short(r["muscle_id"]), r)

    actions: Dict[Tuple[str, str], List[Tuple[float, str]]] = defaultdict(list)
    demands: Dict[str, List[Tuple[float, str]]] = defaultdict(list)
    for name, r in sorted(by_base.items()):
        for a in r["actions"]:
            actions[(a["joint"], a["movement"])].append((a["weight"], name))
        for s in r["stabilizes"]:
            demands[s["demand"]].append((s["weight"], name))

    def listing(items: List[Tuple[float, str]]) -> str:
        return ", ".join(f"{n} {w:g}" for w, n in sorted(items, key=lambda x: (-x[0], x[1])))

    out = [
        "## How BodySim's tracer turns a definition into muscles",
        "",
        "The tracer is deterministic. It looks up every muscle in a curated, weighted muscle-action table:",
        f"- A muscle's action score is its highest table weight among the definition's `primary_joint_actions`. "
        f"Score >= {tracer.PRIMARY_THRESHOLD:g} makes it a primary mover; any lower positive score makes it a synergist. "
        "The coefficient is the score.",
        f"- A muscle with no action score becomes a stabilizer if it serves one of the definition's "
        f"`stabilization_demands`, with coefficient {tracer.STABILIZER_SCALE:g} x its demand weight.",
        "- Every other muscle is an explicit zero. Face, eye, jaw, tongue, palate, pharynx and larynx muscles are always zero.",
        f"- Each joint action has `emphasis` and `sides`. `emphasis: \"assist\"` counts the action at "
        f"{tracer.ASSIST_SCALE:g} x the table weight, so it can make a muscle a synergist but never primary. Use it for a "
        "joint that really moves but contributes little: the calves in a squat or a hang clean, the knee bend of a "
        "bicycle crunch. Use `primary` for the actions that move the load. Leaving a real action out entirely makes its "
        "muscles explicit zeros, which is just as wrong as making them primary.",
        "- Laterality: for `left`, `right` and `unilateral` (shown with the right side working), actions at limb joints "
        "count only on the working side, decided by joint (pectoralis major and latissimus follow the working arm), "
        "unless the action has `sides: \"both\"`. Use `both` when both limbs do that action although the load is "
        "one-sided, e.g. the two-legged hip hinge of a one-arm kettlebell windmill. Spinal actions always count on both sides.",
        "- Limb demands follow the working side for the limbs listed in `one_sided_limbs` (`arm`, `leg`); every other "
        "demand counts on both sides. Arm demands: " + ", ".join(f"`{d}`" for d, l in sorted(tracer.LIMB_OF_DEMAND.items()) if l == "arm")
        + ". Leg demands: " + ", ".join(f"`{d}`" for d, l in sorted(tracer.LIMB_OF_DEMAND.items()) if l == "leg")
        + ". For a one-arm push-up or a one-arm row, `one_sided_limbs` is [\"arm\"] so the free arm stays unloaded; "
        "for a pistol squat it is [\"leg\"]; for a bilateral exercise it is [].",
        "",
        "Consequences for authoring and review:",
        "- A muscle is only engaged if an action or demand in the definition reaches it. If a muscle should work, "
        "the definition must name the action or demand that the table assigns to it; see the lists below.",
        "- Put demands where the load is actually held. A barbell resting on the upper back needs scapular retraction "
        "for the shelf, not `grip` or `wrist_stability`; `grip` and `wrist_stability` are for loads held in the hands. "
        "`shoulder_position_hold` is for an upper arm held still against a load further down the limb (a curl, a rack "
        "position, an arm locked out overhead), `intra_abdominal_pressure` for heavy bracing, `postural_stabilization` "
        "for standing.",
        "- Every action and demand listed below exists. Never claim the vocabulary lacks something without checking "
        "these lists (e.g. forearm rotation is `radioulnar_joint/pronation` and `supination`).",
        "- A review should judge the definition's actions and demands against this table. A muscle missing from the "
        "output usually means a demand or action is missing from the definition.",
        "",
        "### Stabilization demands and the muscles that serve them (muscle weight)",
        "",
    ]
    for demand in sorted(vocabulary["stabilization_demands"]):
        served = demands.get(demand, [])
        out.append(f"- `{demand}`: {vocabulary['stabilization_demands'][demand]}")
        out.append(f"  Serves: {listing(served) if served else '(no muscles yet)'}")
    out += ["", "### Joint actions and the muscles that perform them (muscle weight)", ""]
    for joint in sorted(vocabulary["joints"]):
        for movement in vocabulary["joints"][joint]:
            performed = actions.get((joint, movement), [])
            if performed:
                out.append(f"- `{joint}/{movement}`: {listing(performed)}")
    return "\n".join(out) + "\n"
