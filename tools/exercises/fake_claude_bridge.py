#!/usr/bin/env python3
"""Stands in for run_claude.py in the sandboxed auto-mode check
(tools/exercises/verify_auto_mode.sh). Nothing is sent to Anthropic.

Called like the real bridge: <this> <bridge path> --input IN --output OUT.
Environment:
  FAKE_CLAUDE_MODE           ok (default) | credits
  FAKE_AUTHORING_RESPONSE    JSON file returned for authoring requests
  FAKE_ACCEPT_SOURCE         reviews accept this source_id, reject the rest
"""

import json
import os
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
    result = {"ok": True, "value": json.load(open(os.environ["FAKE_AUTHORING_RESPONSE"])), "metadata": metadata}
else:
    accept = request["revision"].get("source_id") == os.environ.get("FAKE_ACCEPT_SOURCE")
    finding = {"field_path": "kinematic_profile", "finding": "fake rejection", "suggested_correction": "none"}
    result = {"ok": True, "metadata": metadata, "value": {
        "decision": "accept" if accept else "reject",
        "summary": "fake review",
        "blocking_findings": [] if accept else [finding],
        "non_blocking_findings": [],
        "confidence": "high",
    }}

with open(output, "w") as handle:
    json.dump(result, handle)
