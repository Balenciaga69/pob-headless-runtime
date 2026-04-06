# \"\"\"Run the custom PoB headless CLI bridge against a sample XML build.\"\"\"

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


TOOL_ROOT = Path(__file__).resolve().parent
REPO_ROOT = TOOL_ROOT.parent.parent
# Use an upstream test fixture because sample_build.xml is not stable enough for smoke runs.
XML_FILE = REPO_ROOT / "spec" / "TestBuilds" / "3.13" / "OccVortex.xml"
POB_LUA_PATH = TOOL_ROOT / "headless_bridge.lua"
HEADLESS_HELPER = TOOL_ROOT / "tests" / "helpers" / "headless_demo.lua"
RUNTIME_DIR = REPO_ROOT / "runtime"


def _prepare_environment() -> dict[str, str]:
    env = os.environ.copy()
    env["POB_HEADLESS_SCRIPT"] = str(HEADLESS_HELPER)
    env["PATH"] = str(RUNTIME_DIR) + os.pathsep + env.get("PATH", "")
    return env


def _ensure_sources() -> None:
    if not XML_FILE.exists():
        raise FileNotFoundError(
            "The smoke fixture XML is required before running this script."
        )


def main() -> int:
    try:
        _ensure_sources()
    except FileNotFoundError as err:
        print(err, file=sys.stderr)
        return 1

    env = _prepare_environment()

    command = [
        "luajit",
        str(POB_LUA_PATH),
        str(XML_FILE),
    ]

    print(f"Launching custom PoB headless bridge with {XML_FILE.name} …")
    print("Command:", " ".join(command))
    completed = subprocess.run(command, env=env, cwd=REPO_ROOT / "src")
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
