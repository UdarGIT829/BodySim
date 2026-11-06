"""
Deterministic Workout Scorer Engine and OpenSim Calibrator for BodySim (Phase 1C).

Calculates per-set, per-exercise, and aggregate full-body exposure across all 466 canonical
skeletal muscles, with optional OpenSim primary-mover physics anchoring.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Set


def calculate_effort_factor(set_entry: Dict[str, Any]) -> float:
    """Calculates bounded effort factor for a performed set."""
    reps = set_entry.get("repetitions")
    duration = set_entry.get("duration_seconds")

    if reps is not None:
        rep_factor = float(reps)
    elif duration is not None:
        rep_factor = float(duration) / 5.0
    else:
        rep_factor = 1.0

    rpe = set_entry.get("rpe")
    if rpe is not None and isinstance(rpe, (int, float)):
        # Neutral baseline RPE 8.0 -> factor 1.0; RPE 10 -> 1.2; RPE 6 -> 0.8
        rpe_factor = 1.0 + (float(rpe) - 8.0) * 0.1
        rpe_factor = max(0.5, min(1.5, rpe_factor))
    else:
        rpe_factor = 1.0

    return max(0.1, rep_factor * rpe_factor)


class WorkoutScorer:
    def __init__(
        self,
        catalog_path: str | Path = "data/anatomy/structures.json",
        profiles_path: str | Path = "data/exercises/engagement_profiles.json",
        opensim_path: str | Path = "data/exercises/opensim_calibration.json"
    ):
        self.catalog_path = Path(catalog_path)
        self.profiles_path = Path(profiles_path)
        self.opensim_path = Path(opensim_path)

        with open(self.catalog_path, "r", encoding="utf-8") as f:
            catalog = json.load(f)

        self.canonical_muscle_ids = [
            s["id"] for s in catalog.get("structures", []) if s.get("id", "").startswith("muscle.")
        ]
        if len(self.canonical_muscle_ids) != 466:
            raise ValueError(f"Expected 466 canonical muscles, found {len(self.canonical_muscle_ids)}")

        with open(self.profiles_path, "r", encoding="utf-8") as f:
            profiles_data = json.load(f)
            self.profiles = profiles_data.get("profiles", {})

        self.opensim_anchors = {}
        if self.opensim_path.is_file():
            with open(self.opensim_path, "r", encoding="utf-8") as f:
                calib_list = json.load(f)
                for c in calib_list:
                    self.opensim_anchors[c["exercise_id"]] = c

    def score_workout(self, workout_data: Dict[str, Any]) -> Dict[str, Any]:
        """Calculates deterministic workout summary for all 466 muscles."""
        session_id = workout_data.get("session_id", "unknown_session")
        performed_exercises = workout_data.get("exercises", [])

        # Initialize exposure tracking for all 466 muscles
        muscle_summary = {
            m_id: {
                "muscle_id": m_id,
                "raw_exposure": 0.0,
                "opensim_estimated_force_n": 0.0,
                "contributions": []
            }
            for m_id in self.canonical_muscle_ids
        }

        exercise_summaries = []

        for ex_entry in performed_exercises:
            ex_id = ex_entry["exercise_id"]
            sets = ex_entry.get("sets", [])

            total_effort = sum(calculate_effort_factor(s) for s in sets)
            profile = self.profiles.get(ex_id, {}).get("muscles", [])
            profile_map = {m["muscle_id"]: m for m in profile}

            opensim_anchor = self.opensim_anchors.get(ex_id)
            primary_force_n = opensim_anchor.get("opensim_force_n", 0.0) if opensim_anchor else 0.0

            ex_mapped_muscles = 0

            for m_id in self.canonical_muscle_ids:
                m_info = profile_map.get(m_id, {"coefficient": 0.0, "role": "none"})
                coeff = float(m_info.get("coefficient", 0.0))
                role = m_info.get("role", "none")

                if coeff > 0:
                    ex_mapped_muscles += 1
                    raw_exp = coeff * total_effort
                    muscle_summary[m_id]["raw_exposure"] += raw_exp

                    est_force = coeff * primary_force_n
                    muscle_summary[m_id]["opensim_estimated_force_n"] += est_force

                    muscle_summary[m_id]["contributions"].append({
                        "exercise_id": ex_id,
                        "role": role,
                        "coefficient": coeff,
                        "raw_exposure": raw_exp,
                        "opensim_estimated_force_n": est_force
                    })

            exercise_summaries.append({
                "exercise_id": ex_id,
                "set_count": len(sets),
                "total_effort_factor": round(total_effort, 3),
                "mapped_muscles": ex_mapped_muscles,
                "opensim_calibrated": opensim_anchor is not None
            })

        # Calculate normalized emphasis (0-100)
        max_raw = max((m["raw_exposure"] for m in muscle_summary.values()), default=0.0)

        for m_id, m_data in muscle_summary.items():
            raw = m_data["raw_exposure"]
            m_data["raw_exposure"] = round(raw, 3)
            m_data["opensim_estimated_force_n"] = round(m_data["opensim_estimated_force_n"], 2)
            m_data["normalized_emphasis"] = round((raw / max_raw * 100.0), 1) if max_raw > 0 else 0.0

        mapped_count = sum(1 for m in muscle_summary.values() if m["raw_exposure"] > 0)
        zero_count = 466 - mapped_count

        return {
            "session_id": session_id,
            "total_canonical_muscles": 466,
            "active_muscles": mapped_count,
            "zero_exposure_muscles": zero_count,
            "max_raw_exposure": round(max_raw, 3),
            "exercises": exercise_summaries,
            "muscles": muscle_summary
        }
