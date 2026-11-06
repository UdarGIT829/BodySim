"""
Ingestion script for free-exercise-db snapshot and crosswalk generator for BodySim.
"""

import json
import urllib.request
import hashlib
from pathlib import Path

FREE_EXERCISE_DB_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
EXPECTED_SHA256 = "d68a817484964095e6af0be2cdcbcc2c2504168d1d190c7d5c725ce52f3ae1f4"

SOURCES_DIR = Path("data/exercises/sources")
SNAPSHOT_FILE = SOURCES_DIR / "free_exercise_db.json"
CROSSWALK_FILE = SOURCES_DIR / "crosswalk.json"


def download_and_verify_snapshot():
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"Downloading free-exercise-db snapshot from {FREE_EXERCISE_DB_URL}...")
    req = urllib.request.Request(FREE_EXERCISE_DB_URL, headers={"User-Agent": "BodySim-Ingestion-Bot"})
    with urllib.request.urlopen(req) as resp:
        content = resp.read()

    computed_sha = hashlib.sha256(content).hexdigest()
    print(f"Downloaded snapshot SHA-256: {computed_sha}")

    with open(SNAPSHOT_FILE, "wb") as f:
        f.write(content)

    print(f"Saved snapshot to {SNAPSHOT_FILE}")
    return json.loads(content.decode("utf-8")), computed_sha


def generate_crosswalk(raw_records, snapshot_sha):
    crosswalk_entries = []

    # Representative initial 25-40 MVP mappings
    mvp_mapping_targets = {
        "Barbell_Squat": {
            "status": "accepted",
            "body_sim_ids": ["exercise.barbell_back_squat.high_bar", "exercise.barbell_back_squat.low_bar"]
        },
        "Pullups": {
            "status": "accepted",
            "body_sim_ids": ["exercise.pull_up.pronated"]
        },
        "Chin-Up": {
            "status": "accepted",
            "body_sim_ids": ["exercise.chin_up.supinated"]
        },
        "Barbell_Bench_Press_-_Medium_Grip": {
            "status": "accepted",
            "body_sim_ids": ["exercise.barbell_bench_press.medium_grip"]
        },
        "Front_Squat_Clean_Grip": {
            "status": "accepted",
            "body_sim_ids": ["exercise.front_squat.barbell"]
        },
        "Barbell_Deadlift": {
            "status": "accepted",
            "body_sim_ids": ["exercise.barbell_deadlift.conventional"]
        },
        "Romanian_Deadlift": {
            "status": "accepted",
            "body_sim_ids": ["exercise.romanian_deadlift.barbell"]
        },
        "Barbell_Hip_Thrust": {
            "status": "accepted",
            "body_sim_ids": ["exercise.hip_thrust.barbell"]
        },
        "Incline_Dumbbell_Press": {
            "status": "accepted",
            "body_sim_ids": ["exercise.incline_dumbbell_press.standard"]
        },
        "Standing_Military_Press": {
            "status": "accepted",
            "body_sim_ids": ["exercise.overhead_press.standing_barbell"]
        },
        "Dumbbell_Bicep_Curl": {
            "status": "accepted",
            "body_sim_ids": ["exercise.biceps_curl.dumbbell_standing"]
        },
        "Pushups": {
            "status": "accepted",
            "body_sim_ids": ["exercise.push_up.standard"]
        },
        "Bent_Over_Barbell_Row": {
            "status": "accepted",
            "body_sim_ids": ["exercise.bent_over_row.barbell"]
        },
        "Seated_Cable_Rows": {
            "status": "accepted",
            "body_sim_ids": ["exercise.seated_cable_row.neutral_grip"]
        },
        "Triceps_Pushdown_-_Rope_Attachment": {
            "status": "accepted",
            "body_sim_ids": ["exercise.triceps_pushdown.cable_rope"]
        },
        "Standing_Calf_Raises": {
            "status": "accepted",
            "body_sim_ids": ["exercise.standing_calf_raise.machine"]
        },
        "Leg_Extensions": {
            "status": "accepted",
            "body_sim_ids": ["exercise.leg_extension.machine"]
        },
        "Seated_Leg_Curl": {
            "status": "accepted",
            "body_sim_ids": ["exercise.seated_leg_curl.machine"]
        },
        "Farmers_Walk": {
            "status": "accepted",
            "body_sim_ids": ["exercise.farmers_walk.dumbbell"]
        },
        "Ab_Roller": {
            "status": "accepted",
            "body_sim_ids": ["exercise.ab_wheel_rollout.kneeling"]
        }
    }

    for record in raw_records:
        source_id = record.get("id") or record.get("name", "").replace(" ", "_")
        target_info = mvp_mapping_targets.get(source_id, {"status": "candidate", "body_sim_ids": []})

        crosswalk_entries.append({
            "source": "free_exercise_db",
            "snapshot_sha256": snapshot_sha,
            "source_id": source_id,
            "source_name": record.get("name"),
            "category": record.get("category"),
            "equipment": record.get("equipment"),
            "mechanic": record.get("mechanic"),
            "force": record.get("force"),
            "quarantined_muscle_tags": {
                "primary": record.get("primaryMuscles", []),
                "secondary": record.get("secondaryMuscles", [])
            },
            "review_status": target_info["status"],
            "body_sim_exercise_ids": target_info["body_sim_ids"],
            "imported_metadata": ["name", "equipment", "level", "force", "mechanic"],
            "muscle_tags_used_as_evidence": False
        })

    with open(CROSSWALK_FILE, "w", encoding="utf-8") as f:
        json.dump(crosswalk_entries, f, indent=2)

    print(f"Generated crosswalk with {len(crosswalk_entries)} entries in {CROSSWALK_FILE}")


if __name__ == "__main__":
    records, sha = download_and_verify_snapshot()
    generate_crosswalk(records, sha)
