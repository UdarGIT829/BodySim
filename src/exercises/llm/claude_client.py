"""Claude calls for the Kinematic Definition Studio and the Review Council.

Godot never talks to the API directly: it writes a request file and runs
``tools/exercises/run_claude.py``, which calls :func:`run_task`. Prompts and
schemas are chosen here, so they are versioned in one place.

Caching: the system prompt is the stable prefix (identical for every exercise)
and carries an explicit 1-hour cache breakpoint, because authoring sessions
are done by hand with gaps longer than five minutes. Everything that varies
(the exercise, its photos, the frozen revision) comes after it.
"""

from __future__ import annotations

import base64
import json
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

PROJECT_ROOT = Path(__file__).resolve().parents[3]
AUTHORING_DIR = PROJECT_ROOT / "data/exercises/authoring"

TASKS = {
    "author": {
        "prompt": AUTHORING_DIR / "prompts/authoring_v2.md",
        "schema": AUTHORING_DIR / "schemas/kinematic_authoring_response.schema.json",
        "max_tokens": 16000,
    },
    "review": {
        "prompt": AUTHORING_DIR / "prompts/review_v2.md",
        "schema": AUTHORING_DIR / "schemas/kinematic_review_response.schema.json",
        "max_tokens": 16000,
    },
}

# Models offered in the Studio and Council pickers (first = default).
MODELS: List[Dict[str, str]] = [
    {"id": "claude-opus-5-5", "label": "Claude Opus 5.5 · default"},
    {"id": "claude-sonnet-5-5", "label": "Claude Sonnet 5.5 · half the price"},
    {"id": "claude-haiku-5-5", "label": "Claude Haiku 5.5 · cheapest"},
    {"id": "claude-fable-5-1", "label": "Claude Fable 5.1 · most capable, priciest"},
]
DEFAULT_MODEL = MODELS[0]["id"]
EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")
DEFAULT_EFFORT = "high"

# Server-side refusal fallback ("default" routing) is available on these
# models; Claude Haiku 5.5 has no server-side fallback.
FALLBACK_MODELS = {"claude-opus-5-5", "claude-opus-5", "claude-fable-5-1", "claude-sonnet-5-5"}
FALLBACK_BETA = "server-side-fallback-2026-07-01"

DATA_URL = re.compile(r"^data:(image/(?:jpeg|png|gif|webp));base64,(.+)$", re.S)


class ClaudeTaskError(Exception):
    """A request that could not produce a usable structured response."""


# ── Public entry point ──────────────────────────────────────────────────────

def run_task(request: Dict[str, Any], client: Any = None) -> Dict[str, Any]:
    """Run one authoring or review request. Never raises: returns
    ``{"ok": True, "value": {...}, "metadata": {...}}`` or
    ``{"ok": False, "error": "..."}``."""
    try:
        return _run(request, client)
    except ClaudeTaskError as exc:
        return {"ok": False, "error": str(exc)}


def _run(request: Dict[str, Any], client: Any) -> Dict[str, Any]:
    task = request.get("task")
    if task not in TASKS:
        raise ClaudeTaskError(f"unknown task {task!r}; expected one of {sorted(TASKS)}")
    spec = TASKS[task]
    model = str(request.get("model") or DEFAULT_MODEL).strip()
    effort = str(request.get("effort") or DEFAULT_EFFORT).strip()
    if effort not in EFFORT_LEVELS:
        raise ClaudeTaskError(f"effort must be one of {', '.join(EFFORT_LEVELS)}")

    system_prompt = spec["prompt"].read_text(encoding="utf-8")
    schema = json.loads(spec["schema"].read_text(encoding="utf-8"))
    if task == "author":
        text = str(request.get("context", "")).strip()
        if not text:
            raise ClaudeTaskError("authoring request has no source context")
    else:
        revision = request.get("revision")
        if not isinstance(revision, dict) or not revision.get("revision_sha256"):
            raise ClaudeTaskError("review request has no frozen revision")
        text = build_review_context(revision, str(request.get("review_context", "")))

    content: List[Dict[str, Any]] = []
    image = request.get("image_data_url") or ""
    if image:
        content.append(_image_block(image))
    content.append({"type": "text", "text": text})

    params = build_params(model, effort, system_prompt, schema, content, spec["max_tokens"])
    if client is None:
        client = make_client(request.get("settings_path"))
    response = _call(client, params)
    return _parse(response, task, model, effort)


# ── Request building ────────────────────────────────────────────────────────

def build_params(model: str, effort: str, system_prompt: str, schema: Dict[str, Any],
                 content: List[Dict[str, Any]], max_tokens: int) -> Dict[str, Any]:
    params: Dict[str, Any] = {
        "model": model,
        "max_tokens": max_tokens,
        "thinking": {"type": "adaptive"},
        "output_config": {"effort": effort, "format": {"type": "json_schema", "schema": schema}},
        # Stable prefix: identical for every exercise, so it is read from cache.
        "system": [{"type": "text", "text": system_prompt,
                    "cache_control": {"type": "ephemeral", "ttl": "1h"}}],
        "messages": [{"role": "user", "content": content}],
    }
    if model in FALLBACK_MODELS:
        params["betas"] = [FALLBACK_BETA]
        params["fallbacks"] = "default"
    return params


def build_review_context(revision: Dict[str, Any], review_context: str) -> str:
    """A compact review payload: the definition, the source, the trace
    summary and only the muscles the tracer engaged (grouped by role).
    Sending all 466 entries cost ~47K tokens per review, mostly zeros."""
    trace = revision.get("candidate_trace_report", {})
    profile = trace.get("profile", {})
    engaged: Dict[str, List[Dict[str, Any]]] = {}
    zero = 0
    for entry in sorted(profile.get("muscles", []), key=lambda m: m.get("muscle_id", "")):
        role = entry.get("role", "none")
        if role == "none" or not entry.get("coefficient"):
            zero += 1
            continue
        engaged.setdefault(role, []).append({
            "muscle_id": entry.get("muscle_id"),
            "coefficient": entry.get("coefficient"),
            "confidence": entry.get("confidence"),
        })
    payload = {
        "revision_sha256": revision.get("revision_sha256"),
        "revision_id": revision.get("revision_id"),
        "source": revision.get("source", {}),
        "additional_context": revision.get("additional_context", ""),
        "authoring_response": revision.get("authoring_response", {}),
        "trace_summary": trace.get("summary", {}),
        "tracer": trace.get("provenance", {}).get("tracer", ""),
        "engaged_muscles_by_role": engaged,
        "muscles_with_no_involvement": zero,
    }
    return (
        f"FROZEN REVISION SHA-256: {revision.get('revision_sha256')}\n"
        f"CONTROLLED REVIEW CONTEXT (not authoring evidence):\n{review_context.strip() or '(none)'}\n\n"
        "FROZEN REVISION (muscles not listed under engaged_muscles_by_role have no involvement):\n"
        + json.dumps(payload, indent=1, sort_keys=True)
    )


def _image_block(data_url: str) -> Dict[str, Any]:
    match = DATA_URL.match(data_url.strip())
    if not match:
        raise ClaudeTaskError("the contact sheet must be a base64 data URL (jpeg, png, gif or webp)")
    media_type, data = match.groups()
    try:
        base64.b64decode(data, validate=True)
    except ValueError as exc:
        raise ClaudeTaskError("the contact sheet is not valid base64") from exc
    return {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data}}


# ── Client and API call ─────────────────────────────────────────────────────

def make_client(settings_path: Optional[str] = None) -> Any:
    """Anthropic client. Key order: ANTHROPIC_API_KEY, then [anthropic]
    api_key in the Godot user settings file, then the SDK's own resolution
    (e.g. an `ant auth login` profile)."""
    import anthropic  # noqa: PLC0415 - keeps tests importable without the SDK

    key = os.environ.get("ANTHROPIC_API_KEY", "").strip() or read_settings_key(settings_path)
    return anthropic.Anthropic(api_key=key) if key else anthropic.Anthropic()


def read_settings_key(settings_path: Optional[str]) -> str:
    """Read `api_key` from the [anthropic] section of a Godot ConfigFile."""
    if not settings_path or not Path(settings_path).is_file():
        return ""
    section = None
    for raw in Path(settings_path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
        elif section == "anthropic" and line.startswith("api_key"):
            _, _, value = line.partition("=")
            try:
                return str(json.loads(value.strip())).strip()
            except json.JSONDecodeError:
                return value.strip().strip('"').strip()
    return ""


def _call(client: Any, params: Dict[str, Any]) -> Any:
    import anthropic  # noqa: PLC0415

    try:
        with client.beta.messages.stream(**params) as stream:
            return stream.get_final_message()
    except anthropic.AuthenticationError as exc:
        raise ClaudeTaskError("Anthropic rejected the API key. Set ANTHROPIC_API_KEY or [anthropic] api_key in user settings.") from exc
    except anthropic.PermissionDeniedError as exc:
        raise ClaudeTaskError(f"This API key can't use {params['model']}: {exc.message}") from exc
    except anthropic.NotFoundError as exc:
        raise ClaudeTaskError(f"Unknown model {params['model']!r}: {exc.message}") from exc
    except anthropic.BadRequestError as exc:
        raise ClaudeTaskError(f"Request rejected: {exc.message}") from exc
    except anthropic.RateLimitError as exc:
        raise ClaudeTaskError("Rate limited by the Anthropic API; wait a minute and retry.") from exc
    except anthropic.APIStatusError as exc:
        raise ClaudeTaskError(f"Anthropic API error {exc.status_code}: {exc.message}") from exc
    except anthropic.APIConnectionError as exc:
        raise ClaudeTaskError("Could not reach the Anthropic API (network error).") from exc


def _parse(response: Any, task: str, model: str, effort: str) -> Dict[str, Any]:
    stop = getattr(response, "stop_reason", None)
    if stop == "refusal":
        details = getattr(response, "stop_details", None)
        why = getattr(details, "explanation", None) or getattr(details, "category", None) or "no details"
        raise ClaudeTaskError(f"Claude declined this {task} request ({why}).")
    if stop == "max_tokens":
        raise ClaudeTaskError("Claude ran out of output tokens before finishing; retry or lower the effort.")
    text = next((b.text for b in response.content if getattr(b, "type", "") == "text"), None)
    if text is None:
        raise ClaudeTaskError("Claude returned no structured output.")
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ClaudeTaskError("Claude's output was not valid JSON.") from exc
    if not isinstance(value, dict):
        raise ClaudeTaskError("Claude's output was not a JSON object.")

    usage = getattr(response, "usage", None)
    fallback_ran = any(getattr(it, "type", "") == "fallback_message"
                       for it in (getattr(usage, "iterations", None) or []))
    metadata = {
        "provider": "anthropic",
        "requested_model": model,
        "model": getattr(response, "model", model),
        "effort": effort,
        "response_id": getattr(response, "id", ""),
        "request_id": getattr(response, "_request_id", "") or "",
        "stop_reason": stop,
        "served_by_fallback": fallback_ran,
        "usage": {
            "input_tokens": getattr(usage, "input_tokens", 0),
            "output_tokens": getattr(usage, "output_tokens", 0),
            "cache_creation_input_tokens": getattr(usage, "cache_creation_input_tokens", 0) or 0,
            "cache_read_input_tokens": getattr(usage, "cache_read_input_tokens", 0) or 0,
        },
    }
    return {"ok": True, "value": value, "metadata": metadata}


def call_structured(system_text: str, schema: Dict[str, Any], content: List[Dict[str, Any]], *,
                    model: str = DEFAULT_MODEL, effort: str = DEFAULT_EFFORT, max_tokens: int = 64000,
                    client: Any = None, settings_path: Optional[str] = None, label: str = "request") -> Dict[str, Any]:
    """One structured-output call for offline tools (e.g. drafting the
    muscle-action table). Same caching, fallback and error handling as the
    studio tasks. Returns the run_task result shape."""
    try:
        if effort not in EFFORT_LEVELS:
            raise ClaudeTaskError(f"effort must be one of {', '.join(EFFORT_LEVELS)}")
        params = build_params(model, effort, system_text, schema, content, max_tokens)
        if client is None:
            client = make_client(settings_path)
        return _parse(_call(client, params), label, model, effort)
    except ClaudeTaskError as exc:
        return {"ok": False, "error": str(exc)}


def models_payload() -> Dict[str, Any]:
    return {"models": MODELS, "default_model": DEFAULT_MODEL,
            "efforts": list(EFFORT_LEVELS), "default_effort": DEFAULT_EFFORT}

