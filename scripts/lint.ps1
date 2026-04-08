[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Luacheck = Join-Path $RepoRoot ".tools\luarocks\bin\luacheck.bat"

if (-not (Test-Path -LiteralPath $Luacheck)) {
    throw "Luacheck was not found. Run scripts/bootstrap.ps1 first."
}

$Targets = @(
    "headless_bridge.lua",
    "json_worker.lua",
    "src",
    "tests"
)

Push-Location $RepoRoot
try {
    & $Luacheck @Targets
}
finally {
    Pop-Location
}
