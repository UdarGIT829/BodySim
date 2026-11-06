"""
Generator for data/anatomy/muscle_actions.json mapping canonical muscle IDs to joint actions.
"""

import json
from pathlib import Path

ANATOMY_CATALOG = Path("data/anatomy/structures.json")
OUTPUT_PATH = Path("data/anatomy/muscle_actions.json")

# Rules mapping substring patterns in canonical muscle IDs to spanned joints, joint actions, and stabilization
ACTION_PATTERNS = [
    # Lower Body - Quadriceps
    {
        "pattern": "rectus_femoris",
        "spanned_joints": ["hip_joint", "knee_joint"],
        "actions": [
            {"joint": "knee_joint", "movement": "extension", "type": "primary"},
            {"joint": "hip_joint", "movement": "flexion", "type": "synergist"}
        ],
        "stabilization": ["anti_extension_hip"]
    },
    {
        "pattern": "vastus_",
        "spanned_joints": ["knee_joint"],
        "actions": [
            {"joint": "knee_joint", "movement": "extension", "type": "primary"}
        ],
        "stabilization": ["patellar_tracking"]
    },
    # Lower Body - Hamstrings
    {
        "pattern": "biceps_femoris",
        "spanned_joints": ["hip_joint", "knee_joint"],
        "actions": [
            {"joint": "knee_joint", "movement": "flexion", "type": "primary"},
            {"joint": "hip_joint", "movement": "extension", "type": "synergist"}
        ],
        "stabilization": ["knee_joint_stability"]
    },
    {
        "pattern": "semitendinosus",
        "spanned_joints": ["hip_joint", "knee_joint"],
        "actions": [
            {"joint": "knee_joint", "movement": "flexion", "type": "primary"},
            {"joint": "hip_joint", "movement": "extension", "type": "synergist"}
        ],
        "stabilization": ["knee_joint_stability"]
    },
    {
        "pattern": "semimembranosus",
        "spanned_joints": ["hip_joint", "knee_joint"],
        "actions": [
            {"joint": "knee_joint", "movement": "flexion", "type": "primary"},
            {"joint": "hip_joint", "movement": "extension", "type": "synergist"}
        ],
        "stabilization": ["knee_joint_stability"]
    },
    # Lower Body - Gluteals
    {
        "pattern": "gluteus_maximus",
        "spanned_joints": ["hip_joint"],
        "actions": [
            {"joint": "hip_joint", "movement": "extension", "type": "primary"},
            {"joint": "hip_joint", "movement": "external_rotation", "type": "synergist"}
        ],
        "stabilization": ["pelvic_alignment"]
    },
    {
        "pattern": "gluteus_medius",
        "spanned_joints": ["hip_joint"],
        "actions": [
            {"joint": "hip_joint", "movement": "abduction", "type": "primary"}
        ],
        "stabilization": ["pelvic_leveling_frontal"]
    },
    {
        "pattern": "gluteus_minimus",
        "spanned_joints": ["hip_joint"],
        "actions": [
            {"joint": "hip_joint", "movement": "abduction", "type": "primary"}
        ],
        "stabilization": ["femoral_head_stabilization"]
    },
    # Calves
    {
        "pattern": "gastrocnemius",
        "spanned_joints": ["knee_joint", "ankle_joint"],
        "actions": [
            {"joint": "ankle_joint", "movement": "plantarflexion", "type": "primary"},
            {"joint": "knee_joint", "movement": "flexion", "type": "synergist"}
        ],
        "stabilization": ["ankle_stability"]
    },
    {
        "pattern": "soleus",
        "spanned_joints": ["ankle_joint"],
        "actions": [
            {"joint": "ankle_joint", "movement": "plantarflexion", "type": "primary"}
        ],
        "stabilization": ["postural_sway_control"]
    },
    # Upper Body - Chest
    {
        "pattern": "pectoralis_major",
        "spanned_joints": ["glenohumeral_joint"],
        "actions": [
            {"joint": "glenohumeral_joint", "movement": "horizontal_adduction", "type": "primary"},
            {"joint": "glenohumeral_joint", "movement": "internal_rotation", "type": "synergist"}
        ],
        "stabilization": ["anterior_shoulder_stability"]
    },
    {
        "pattern": "pectoralis_minor",
        "spanned_joints": ["scapulothoracic_joint"],
        "actions": [
            {"joint": "scapulothoracic_joint", "movement": "depression", "type": "primary"}
        ],
        "stabilization": ["scapular_anchoring"]
    },
    # Upper Body - Back
    {
        "pattern": "latissimus_dorsi",
        "spanned_joints": ["glenohumeral_joint"],
        "actions": [
            {"joint": "glenohumeral_joint", "movement": "adduction", "type": "primary"},
            {"joint": "glenohumeral_joint", "movement": "extension", "type": "primary"}
        ],
        "stabilization": ["lumbar_fascia_tension"]
    },
    {
        "pattern": "trapezius",
        "spanned_joints": ["scapulothoracic_joint", "cervical_spine"],
        "actions": [
            {"joint": "scapulothoracic_joint", "movement": "elevation", "type": "primary"},
            {"joint": "scapulothoracic_joint", "movement": "retraction", "type": "primary"}
        ],
        "stabilization": ["scapular_stabilization"]
    },
    {
        "pattern": "rhomboid",
        "spanned_joints": ["scapulothoracic_joint"],
        "actions": [
            {"joint": "scapulothoracic_joint", "movement": "retraction", "type": "primary"}
        ],
        "stabilization": ["scapular_retraction_stability"]
    },
    # Upper Body - Shoulders (Deltoid)
    {
        "pattern": "deltoid",
        "spanned_joints": ["glenohumeral_joint"],
        "actions": [
            {"joint": "glenohumeral_joint", "movement": "abduction", "type": "primary"},
            {"joint": "glenohumeral_joint", "movement": "flexion", "type": "synergist"}
        ],
        "stabilization": ["humeral_head_stabilization"]
    },
    # Upper Body - Arms
    {
        "pattern": "biceps_brachii",
        "spanned_joints": ["glenohumeral_joint", "elbow_joint", "radioulnar_joint"],
        "actions": [
            {"joint": "elbow_joint", "movement": "flexion", "type": "primary"},
            {"joint": "radioulnar_joint", "movement": "supination", "type": "primary"}
        ],
        "stabilization": ["glenohumeral_stabilization"]
    },
    {
        "pattern": "triceps_brachii",
        "spanned_joints": ["glenohumeral_joint", "elbow_joint"],
        "actions": [
            {"joint": "elbow_joint", "movement": "extension", "type": "primary"}
        ],
        "stabilization": ["elbow_stability"]
    },
    {
        "pattern": "brachialis",
        "spanned_joints": ["elbow_joint"],
        "actions": [
            {"joint": "elbow_joint", "movement": "flexion", "type": "primary"}
        ],
        "stabilization": ["elbow_joint_integrity"]
    },
    # Core & Trunk
    {
        "pattern": "rectus_abdominis",
        "spanned_joints": ["lumbar_spine"],
        "actions": [
            {"joint": "lumbar_spine", "movement": "flexion", "type": "primary"}
        ],
        "stabilization": ["anti_extension_spine"]
    },
    {
        "pattern": "oblique",
        "spanned_joints": ["lumbar_spine"],
        "actions": [
            {"joint": "lumbar_spine", "movement": "rotation", "type": "primary"},
            {"joint": "lumbar_spine", "movement": "lateral_flexion", "type": "primary"}
        ],
        "stabilization": ["anti_rotation_torso"]
    },
    {
        "pattern": "transversus_abdominis",
        "spanned_joints": ["lumbar_spine"],
        "actions": [],
        "stabilization": ["intra_abdominal_pressure", "anti_flexion_spine", "anti_extension_spine"]
    },
    {
        "pattern": "erector_spinae",
        "spanned_joints": ["thoracic_spine", "lumbar_spine"],
        "actions": [
            {"joint": "lumbar_spine", "movement": "extension", "type": "primary"}
        ],
        "stabilization": ["anti_flexion_spine"]
    }
]


def generate_muscle_actions():
    with open(ANATOMY_CATALOG, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    muscles = [s for s in catalog["structures"] if s["id"].startswith("muscle.")]
    muscle_actions = []

    for m in muscles:
        m_id = m["id"]
        side = m.get("side", "median")
        
        # Match pattern
        matched_rule = None
        for rule in ACTION_PATTERNS:
            if rule["pattern"] in m_id:
                matched_rule = rule
                break

        if matched_rule:
            # Side-aware joint IDs
            joints = []
            for j in matched_rule["spanned_joints"]:
                if side in ("left", "right") and not j.endswith(f".{side}"):
                    joints.append(f"{j}.{side}")
                else:
                    joints.append(j)

            muscle_actions.append({
                "muscle_id": m_id,
                "spanned_joints": joints,
                "actions": matched_rule["actions"],
                "stabilization_capabilities": matched_rule["stabilization"]
            })
        else:
            # Fallback for deep/other muscles
            muscle_actions.append({
                "muscle_id": m_id,
                "spanned_joints": [f"local_joint.{side}" if side in ("left", "right") else "local_joint"],
                "actions": [],
                "stabilization_capabilities": ["postural_stabilization"]
            })

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(muscle_actions, f, indent=2)

    print(f"Generated {len(muscle_actions)} muscle action entries in {OUTPUT_PATH}")


if __name__ == "__main__":
    generate_muscle_actions()
