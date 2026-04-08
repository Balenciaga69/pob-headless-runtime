[CmdletBinding()]
param(
    [switch]$Experimental
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $RepoRoot
try {
    & python tests\run_unit.py
    & python tests\run_smoke.py --suite stable
    & python tests\run_transport_smoke.py

    if ($Experimental) {
        & python tests\run_smoke.py --suite experimental
    }
}
finally {
    Pop-Location
}
