[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$StyLua = Join-Path $RepoRoot ".tools\stylua\stylua.exe"

if (-not (Test-Path -LiteralPath $StyLua)) {
    throw "StyLua was not found. Run scripts/bootstrap.ps1 first."
}

$Targets = @(
    "headless_bridge.lua",
    "json_worker.lua",
    "src",
    "tests",
    "scripts"
)

Push-Location $RepoRoot
try {
    $args = @()
    if ($Check) {
        $args += "--check"
    }
    $args += $Targets
    & $StyLua @args
}
finally {
    Pop-Location
}
