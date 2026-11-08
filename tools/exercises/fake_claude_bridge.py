#!/usr/bin/env python3
"""Stands in for run_claude.py in the sandboxed auto-mode check
(tools/exercises/verify_auto_mode.sh). Nothing is sent to Anthropic.

Called like the real bridge: <this> <bridge path> --input IN --output OUT.
Environment:
  FAKE_CLAUDE_MODE           ok (default) | credits
  FAKE_AUTHORING_RESPONSE    JSON file returned for authoring requests
  FAKE_ACCEPT_SOURCE         reviews accept this source_id, reject the rest
  FAKE_EDIT_SOURCE           reviews of this source_id reject; while its kinetic
                             chain isn't closed_chain they propose the edit that sets it
"""

import json
import os
import re
import sys

USAGE = {"input_tokens": 1000, "output_tokens": 500, "cache_read_input_tokens": 15000,
         "cache_creation_input_tokens": 0}

args = sys.argv[1:]
request = json.load(open(args[args.index("--input") + 1]))
output = args[args.index("--output") + 1]
mode = os.environ.get("FAKE_CLAUDE_MODE", "ok")
metadata = {"provider": "fake", "model": request.get("model"), "usage": USAGE}

if mode == "credits":
    result = {"ok": False, "error_kind": "credits",
              "error": "Out of API credits: Your credit balance is too low to access the Anthropic API."}
elif request["task"] == "author":
    value = json.load(open(os.environ["FAKE_AUTHORING_RESPONSE"]))
    # A distinct exercise ID per source, so promoting one never collides with another.
    match = re.search(r'"source_id":\s*"([^"]+)"', request.get("context", ""))
    if match:
        slug = re.sub(r"[^a-z0-9]+", "_", match.group(1).lower()).strip("_")
        value["proposed_definition"]["id"] = f"exercise.fixture_{slug}.standard"
    result = {"ok": True, "value": value, "metadata": metadata}
else:
    revision = request["revision"]
    source_id = revision.get("source_id")
    chain = revision["authoring_response"]["proposed_definition"]["kinematic_profile"].get("kinetic_chain_type")
    accept = source_id == os.environ.get("FAKE_ACCEPT_SOURCE")
    edits = []
    if source_id == os.environ.get("FAKE_EDIT_SOURCE") and chain != "closed_chain":
        edits = [{"op": "set_kinetic_chain_type", "value": "closed_chain"}]
    finding = {"field_path": "kinematic_profile", "finding": "fake rejection", "suggested_correction": "none"}
    result = {"ok": True, "metadata": metadata, "value": {
        "decision": "accept" if accept else "reject",
        "summary": "fake review",
        "blocking_findings": [] if accept else [finding],
        "non_blocking_findings": [],
        "confidence": "high",
        "proposed_edits": edits,
        "edits_resolve_all_blocking_findings": bool(edits),
    }}

with open(output, "w") as handle:
    json.dump(result, handle)
