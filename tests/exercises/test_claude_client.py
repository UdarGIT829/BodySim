"""Claude client tests. A fake client stands in for the Anthropic SDK, so no
request is sent and nothing is billed."""

import base64
import json
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace

import pytest

from src.exercises.llm import claude_client as cc

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DRAFT = PROJECT_ROOT / "data/exercises/authoring/drafts/EZ-Bar_Curl.json"
PNG = "data:image/png;base64," + base64.b64encode(b"\x89PNG fake").decode()


class FakeClient:
    """Records the request and returns a canned final message."""

    def __init__(self, text='{"classification": "unsupported"}', stop_reason="end_turn", stop_details=None):
        self.params = None
        message = SimpleNamespace(
            id="msg_test", model="claude-opus-5-5", stop_reason=stop_reason, stop_details=stop_details,
            content=[SimpleNamespace(type="thinking", thinking=""), SimpleNamespace(type="text", text=text)],
            usage=SimpleNamespace(input_tokens=1200, output_tokens=300, cache_creation_input_tokens=0,
                                  cache_read_input_tokens=900, iterations=None),
            _request_id="req_test",
        )

        @contextmanager
        def stream(**params):
            self.params = params
            yield SimpleNamespace(get_final_message=lambda: message)

        self.beta = SimpleNamespace(messages=SimpleNamespace(stream=stream))


def _revision():
    draft = json.loads(DRAFT.read_text())
    return {
        "revision_sha256": "c" * 64, "revision_id": "EZ-Bar_Curl@cccccccccccc",
        "source": {"name": "EZ-Bar Curl"}, "additional_context": "",
        "authoring_response": draft["authoring_response"],
        "candidate_trace_report": draft["candidate_trace_report"],
    }


def test_authoring_request_shape_and_result():
    client = FakeClient()
    result = cc.run_task({"task": "author", "model": "claude-opus-5-5", "context": "SOURCE EXERCISE: x",
                          "image_data_url": PNG}, client=client)
    assert result["ok"], result
    assert result["value"] == {"classification": "unsupported"}
    p = client.params
    assert p["model"] == "claude-opus-5-5"
    assert p["thinking"] == {"type": "adaptive"}
    assert p["output_config"]["effort"] == "high"
    assert p["output_config"]["format"]["type"] == "json_schema"
    assert p["system"][0]["cache_control"] == {"type": "ephemeral", "ttl": "1h"}
    assert "Kinematic Author v2" in p["system"][0]["text"]
    content = p["messages"][0]["content"]
    assert [b["type"] for b in content] == ["image", "text"]          # varying content after the cached prefix
    assert content[0]["source"]["media_type"] == "image/png"
    assert p["fallbacks"] == "default" and p["betas"] == [cc.FALLBACK_BETA]
    assert result["metadata"]["usage"]["cache_read_input_tokens"] == 900
    assert result["metadata"]["provider"] == "anthropic"


def test_system_prompt_is_identical_across_exercises():
    a, b = FakeClient(), FakeClient()
    cc.run_task({"task": "author", "context": "exercise A"}, client=a)
    cc.run_task({"task": "author", "context": "exercise B"}, client=b)
    assert a.params["system"] == b.params["system"]                  # cacheable prefix
    assert a.params["messages"] != b.params["messages"]


@pytest.mark.parametrize("model,expect_fallback", [
    ("claude-opus-5-5", True), ("claude-sonnet-5-5", True), ("claude-fable-5-1", True), ("claude-haiku-5-5", False)])
def test_fallbacks_only_where_supported(model, expect_fallback):
    client = FakeClient()
    cc.run_task({"task": "author", "model": model, "context": "x"}, client=client)
    assert ("fallbacks" in client.params) == expect_fallback
    assert ("betas" in client.params) == expect_fallback


def test_review_payload_is_compact_and_lists_only_engaged_muscles():
    client = FakeClient(text='{"decision": "reject"}')
    revision = _revision()
    result = cc.run_task({"task": "review", "revision": revision, "review_context": "check the curl"}, client=client)
    assert result["ok"]
    text = client.params["messages"][0]["content"][-1]["text"]
    assert revision["revision_sha256"] in text
    assert "check the curl" in text
    payload = json.loads(text.split("no involvement):\n", 1)[1])
    listed = [m for group in payload["engaged_muscles_by_role"].values() for m in group]
    zero = payload["muscles_with_no_involvement"]
    assert len(listed) + zero == 466
    assert all(m["coefficient"] for m in listed)
    full = len(json.dumps(revision, indent=2))
    assert len(text) < full * 0.6                                     # far smaller than the full revision


def test_review_requires_a_frozen_revision():
    result = cc.run_task({"task": "review", "revision": {}}, client=FakeClient())
    assert not result["ok"] and "frozen revision" in result["error"]


def test_refusal_is_reported_not_parsed():
    details = SimpleNamespace(category="bio", explanation="declined")
    result = cc.run_task({"task": "author", "context": "x"},
                         client=FakeClient(text="", stop_reason="refusal", stop_details=details))
    assert not result["ok"] and "declined" in result["error"]


def test_truncated_output_is_reported():
    result = cc.run_task({"task": "author", "context": "x"}, client=FakeClient(stop_reason="max_tokens"))
    assert not result["ok"] and "output tokens" in result["error"]


def test_invalid_json_is_reported():
    result = cc.run_task({"task": "author", "context": "x"}, client=FakeClient(text="not json"))
    assert not result["ok"] and "not valid JSON" in result["error"]


def test_bad_image_and_unknown_task_and_effort():
    assert "data URL" in cc.run_task({"task": "author", "context": "x", "image_data_url": "http://x"}, client=FakeClient())["error"]
    assert "unknown task" in cc.run_task({"task": "draw"}, client=FakeClient())["error"]
    assert "effort" in cc.run_task({"task": "author", "context": "x", "effort": "huge"}, client=FakeClient())["error"]


def test_reads_key_from_godot_settings_file(tmp_path):
    cfg = tmp_path / "bodysim_authoring_settings.cfg"
    cfg.write_text('[openai]\n\napi_key="old"\n\n[anthropic]\n\napi_key="sk-ant-test"\nauthoring_model="claude-opus-5-5"\n')
    assert cc.read_settings_key(str(cfg)) == "sk-ant-test"
    assert cc.read_settings_key(str(tmp_path / "missing.cfg")) == ""


def test_schemas_use_only_supported_structured_output_keywords():
    unsupported = {"minimum", "maximum", "multipleOf", "minLength", "maxLength", "pattern"}
    for spec in cc.TASKS.values():
        text = spec["schema"].read_text()
        assert not any(f'"{k}"' in text for k in unsupported), spec["schema"].name


def test_system_prompt_includes_the_generated_tracer_reference():
    client = FakeClient()
    cc.run_task({"task": "review", "revision": _revision()}, client=client)
    system = client.params["system"][0]["text"]
    assert "How BodySim's tracer turns a definition into muscles" in system
    assert "`intra_abdominal_pressure`" in system and "Serves:" in system


def test_tracer_reference_is_deterministic():
    from src.exercises.llm.tracer_reference import tracer_reference
    assert tracer_reference() == tracer_reference()
