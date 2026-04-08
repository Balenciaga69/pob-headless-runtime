"""Run JSON stdin/stdout worker smoke tests for pob-headless-runtime."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
TOOL_ROOT = TEST_ROOT.parent
REPO_ROOT = TOOL_ROOT.parent
WORKER_PATH = TOOL_ROOT / "json_worker.lua"
DEFAULT_RUNTIME_DIR = REPO_ROOT / "runtime"
FIXTURE_XML = TEST_ROOT / "fixtures" / "mirage_example_xml.xml"
FIXTURE_CODE = TEST_ROOT / "fixtures" / "mirage_exmple_code.txt"


@dataclass
class SmokeCase:
    name: str
    request: dict


def _build_env() -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = str(DEFAULT_RUNTIME_DIR) + os.pathsep + env.get("PATH", "")
    return env


def _run_case(case: SmokeCase) -> tuple[int, dict]:
    completed = subprocess.run(
        ["luajit", str(WORKER_PATH)],
        cwd=REPO_ROOT / "src",
        env=_build_env(),
        input=json.dumps(case.request),
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.stderr:
        print(completed.stderr, end="" if completed.stderr.endswith("\n") else "\n", file=sys.stderr)
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as err:
        raise RuntimeError(f"{case.name}: invalid JSON response: {err}\nSTDOUT:\n{completed.stdout}") from err
    return completed.returncode, payload


def main() -> int:
    build_xml = FIXTURE_XML.read_text(encoding="utf-8")
    build_code = FIXTURE_CODE.read_text(encoding="utf-8").strip()
    expected_engine_version = "2.63.0"
    cases = [
        SmokeCase(
            name="health",
            request={"id": "health-1", "method": "health", "params": {}},
        ),
        SmokeCase(
            name="summary",
            request={
                "id": "summary-1",
                "method": "get_summary",
                "params": {
                    "build_xml": build_xml,
                },
            },
        ),
        SmokeCase(
            name="display-stats",
            request={
                "id": "display-stats-1",
                "method": "get_display_stats",
                "params": {
                    "build_xml": build_xml,
                },
            },
        ),
        SmokeCase(
            name="build-code",
            request={
                "id": "code-1",
                "method": "load_build_code",
                "params": {
                    "code": build_code,
                    "build_name": "Transport Build",
                },
            },
        ),
        SmokeCase(
            name="experimental-method",
            request={"id": "exp-1", "method": "compare_item_stats", "params": {}},
        ),
        SmokeCase(
            name="invalid-params",
            request={"id": "params-1", "method": "equip_item", "params": {}},
        ),
    ]

    failures = 0
    for case in cases:
        print(f"==> {case.name}")
        code, payload = _run_case(case)
        print(json.dumps(payload, ensure_ascii=False))

        if case.name == "health":
            meta = payload.get("meta") or {}
            ok = (
                code == 0
                and payload.get("ok") is True
                and payload.get("id") == "health-1"
                and isinstance(payload.get("result"), dict)
                and "mainReady" in payload["result"]
                and meta.get("request_id") == "health-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
                and isinstance(meta.get("duration_ms"), int)
            )
        elif case.name == "summary":
            result = payload.get("result") or {}
            summary = result.get("summary") or payload.get("result") or {}
            meta = payload.get("meta") or {}
            ok = (
                code == 0
                and payload.get("ok") is True
                and payload.get("id") == "summary-1"
                and isinstance(summary, dict)
                and summary.get("buildName") == "API Build"
                and summary.get("mainSkill") == "Kinetic Fusillade"
                and meta.get("request_id") == "summary-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
                and isinstance(meta.get("duration_ms"), int)
            )
        elif case.name == "build-code":
            result = payload.get("result") or {}
            summary = result.get("summary") or {}
            meta = payload.get("meta") or {}
            ok = (
                code == 0
                and payload.get("ok") is True
                and payload.get("id") == "code-1"
                and isinstance(summary, dict)
                and summary.get("buildName") == "Transport Build"
                and summary.get("className") == "Templar"
                and summary.get("ascendClassName") == "Hierophant"
                and summary.get("level") == 100
                and summary.get("mainSkill") == "Kinetic Fusillade"
                and meta.get("request_id") == "code-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
                and isinstance(meta.get("duration_ms"), int)
            )
        elif case.name == "display-stats":
            result = payload.get("result") or {}
            entries = result.get("entries") or []
            meta = payload.get("meta") or {}
            ok = (
                code == 0
                and payload.get("ok") is True
                and payload.get("id") == "display-stats-1"
                and isinstance(entries, list)
                and any(
                    entry.get("label") == "Average Damage"
                    for entry in entries
                    if isinstance(entry, dict)
                )
                and meta.get("request_id") == "display-stats-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
                and isinstance(meta.get("duration_ms"), int)
            )
        elif case.name == "experimental-method":
            error = payload.get("error") or {}
            meta = payload.get("meta") or {}
            ok = (
                code != 0
                and payload.get("ok") is False
                and payload.get("id") == "exp-1"
                and error.get("code") == "EXPERIMENTAL_API"
                and meta.get("request_id") == "exp-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
            )
        else:
            error = payload.get("error") or {}
            meta = payload.get("meta") or {}
            ok = (
                code != 0
                and payload.get("ok") is False
                and payload.get("id") == "params-1"
                and error.get("code") == "INVALID_PARAMS"
                and error.get("retryable") is False
                and meta.get("request_id") == "params-1"
                and meta.get("api_version") == "v1"
                and meta.get("engine_version") == expected_engine_version
            )

        print(f"<== {case.name}: {'PASS' if ok else 'FAIL'}\n")
        if not ok:
            failures += 1

    print(f"Summary: {len(cases) - failures} passed, {failures} failed")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
