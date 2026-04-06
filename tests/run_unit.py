"""Run isolated unit tests for custom/pob-headless-runtime."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
REPO_ROOT = TEST_ROOT.parent.parent.parent
UNIT_DIR = TEST_ROOT / "unit"
RUNNER = TEST_ROOT / "helpers" / "unit_runner.lua"


@dataclass
class UnitResult:
    script: Path
    returncode: int
    stdout: str
    stderr: str


def _list_unit_scripts() -> list[Path]:
    return sorted(UNIT_DIR.glob("*_spec.lua"))


def _run_script(script_path: Path) -> UnitResult:
    command = [
        "luajit",
        str(RUNNER),
        str(script_path),
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
    )
    return UnitResult(
        script=script_path,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--script",
        action="append",
        type=Path,
        help="Run only the specified unit script(s). Can be passed multiple times.",
    )
    args = parser.parse_args()

    scripts = args.script if args.script else _list_unit_scripts()
    if not scripts:
        print(f"No unit scripts found in {UNIT_DIR}", file=sys.stderr)
        return 1

    results: list[UnitResult] = []
    for script in scripts:
        script_path = script.resolve()
        if not script_path.exists():
            print(f"Unit script not found: {script_path}", file=sys.stderr)
            return 1

        print(f"==> {script_path.name}")
        result = _run_script(script_path)
        results.append(result)

        if result.stdout:
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(result.stderr, end="" if result.stderr.endswith("\n") else "\n", file=sys.stderr)

        status = "PASS" if result.returncode == 0 else "FAIL"
        print(f"<== {script_path.name}: {status}\n")

    failures = [result for result in results if result.returncode != 0]
    print(f"Summary: {len(results) - len(failures)} passed, {len(failures)} failed")

    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
