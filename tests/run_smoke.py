"""Run headless smoke tests in pob-headless-runtime/tests/smoke."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
TOOL_ROOT = TEST_ROOT.parent
REPO_ROOT = TOOL_ROOT.parent
POB_LUA_PATH = TOOL_ROOT / "headless_bridge.lua"
DEFAULT_FIXTURE = TEST_ROOT / "fixtures" / "mirage_example_xml.xml"
DEFAULT_RUNTIME_DIR = REPO_ROOT / "runtime"
SMOKE_DIR = TEST_ROOT / "smoke"

SUITES: dict[str, tuple[str, ...]] = {
    "stable": (
        "smoke_build_code.lua",
        "smoke_contract_regression.lua",
        "smoke_item_compare.lua",
        "smoke_min_api.lua",
        "smoke_stats_compare.lua",
        "smoke_tree_simulation.lua",
    ),
    "experimental": (
        "smoke_config_compare_stats.lua",
        "smoke_importer_update.lua",
        "smoke_item_slot_rules.lua",
        "smoke_item_tooltip.lua",
        "smoke_simulate_mod.lua",
        "smoke_skills_config.lua",
    ),
}


@dataclass
class SmokeResult:
    script: Path
    returncode: int
    stdout: str
    stderr: str


def _build_env(script_path: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["POB_HEADLESS_TEST_SCRIPT"] = str(script_path)
    env["PATH"] = str(DEFAULT_RUNTIME_DIR) + os.pathsep + env.get("PATH", "")
    return env


def _list_smoke_scripts() -> list[Path]:
    return sorted(SMOKE_DIR.glob("*.lua"))


def _list_suite_scripts(suite: str) -> list[Path]:
    if suite == "all":
        return _list_smoke_scripts()
    names = SUITES[suite]
    return [SMOKE_DIR / name for name in names]


def _run_script(script_path: Path, fixture: Path) -> SmokeResult:
    command = [
        "luajit",
        str(POB_LUA_PATH),
        str(fixture),
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT / "src",
        env=_build_env(script_path),
        text=True,
        capture_output=True,
        check=False,
    )
    return SmokeResult(
        script=script_path,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--fixture",
        type=Path,
        default=DEFAULT_FIXTURE,
        help="XML build fixture to pass to every smoke test.",
    )
    parser.add_argument(
        "--script",
        action="append",
        type=Path,
        help="Run only the specified smoke script(s). Can be passed multiple times.",
    )
    parser.add_argument(
        "--suite",
        choices=("stable", "experimental", "all"),
        default="stable",
        help="Run a named smoke suite.",
    )
    args = parser.parse_args()

    fixture = args.fixture.resolve()
    if not fixture.exists():
        print(f"Fixture not found: {fixture}", file=sys.stderr)
        return 1

    scripts = args.script if args.script else _list_suite_scripts(args.suite)
    if not scripts:
        print(f"No smoke scripts found in {SMOKE_DIR}", file=sys.stderr)
        return 1

    results: list[SmokeResult] = []
    for script in scripts:
        script_path = script.resolve()
        if not script_path.exists():
            print(f"Smoke script not found: {script_path}", file=sys.stderr)
            return 1

        print(f"==> {script_path.name}")
        result = _run_script(script_path, fixture)
        results.append(result)

        if result.stdout:
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(
                result.stderr,
                end="" if result.stderr.endswith("\n") else "\n",
                file=sys.stderr,
            )

        status = "PASS" if result.returncode == 0 else "FAIL"
        print(f"<== {script_path.name}: {status}\n")

    failures = [result for result in results if result.returncode != 0]
    print(f"Summary: {len(results) - len(failures)} passed, {len(failures)} failed")

    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
