[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ToolsRoot = Join-Path $RepoRoot ".tools"
$DownloadsRoot = Join-Path $ToolsRoot "downloads"
$SourcesRoot = Join-Path $ToolsRoot "src"
$LuaRocksRoot = Join-Path $ToolsRoot "luarocks"
$StyLuaRoot = Join-Path $ToolsRoot "stylua"
$LuaLsWingetId = "LuaLS.lua-language-server"
$StyLuaVersion = "2.4.1"
$StyLuaUrl = "https://github.com/JohnnyMorganz/StyLua/releases/download/v$StyLuaVersion/stylua-windows-x86_64.zip"
$ToolRepos = @(
    @{
        Name = "argparse"
        Url = "https://github.com/mpeterv/argparse.git"
        Rockspec = "argparse-scm-1.rockspec"
    },
    @{
        Name = "luafilesystem"
        Url = "https://github.com/lunarmodules/luafilesystem.git"
        Rockspec = "luafilesystem-scm-1.rockspec"
    },
    @{
        Name = "luacheck"
        Url = "https://github.com/lunarmodules/luacheck.git"
        Rockspec = "luacheck-dev-1.rockspec"
        ExtraArgs = @("--deps-mode=none")
    }
)

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found in PATH."
    }

    return $command.Source
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Ensure-PipPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package
    )

    $installed = & python -m pip show $Package 2>$null
    if (-not $installed) {
        & python -m pip install --user $Package
    }
}

function Ensure-GitClone {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        return
    }

    & git clone --depth 1 $Url $Path
}

function Ensure-StyLua {
    $styluaExe = Join-Path $StyLuaRoot "stylua.exe"
    if (Test-Path -LiteralPath $styluaExe) {
        return $styluaExe
    }

    Ensure-Directory -Path $DownloadsRoot
    $archivePath = Join-Path $DownloadsRoot "stylua-windows-x86_64.zip"
    Invoke-WebRequest -Uri $StyLuaUrl -OutFile $archivePath

    if (Test-Path -LiteralPath $StyLuaRoot) {
        Remove-Item -LiteralPath $StyLuaRoot -Recurse -Force
    }

    Expand-Archive -Path $archivePath -DestinationPath $StyLuaRoot
    return $styluaExe
}

function Ensure-LuaRocksEnvironment {
    $luacheckBat = Join-Path $LuaRocksRoot "bin\luacheck.bat"
    if (Test-Path -LiteralPath $luacheckBat) {
        return $luacheckBat
    }

    Ensure-PipPackage -Package "hererocks"

    if (-not (Test-Path -LiteralPath $LuaRocksRoot)) {
        & python -m hererocks $LuaRocksRoot -j 2.1.0-beta3 -r 3.8.0
    }

    Ensure-Directory -Path $SourcesRoot

    foreach ($tool in $ToolRepos) {
        $sourcePath = Join-Path $SourcesRoot $tool.Name
        Ensure-GitClone -Url $tool.Url -Path $sourcePath

        Push-Location $sourcePath
        try {
            $rockspecArgs = @("make", $tool.Rockspec)
            if ($tool.ContainsKey("ExtraArgs")) {
                $rockspecArgs += $tool.ExtraArgs
            }

            & (Join-Path $LuaRocksRoot "bin\luarocks.bat") @rockspecArgs

            if ($tool.Name -eq "luafilesystem") {
                & (Join-Path $LuaRocksRoot "bin\luarocks-admin.bat") make_manifest $LuaRocksRoot
            }
        }
        finally {
            Pop-Location
        }
    }

    return $luacheckBat
}

function Ensure-LuaLanguageServer {
    $existing = Get-Command "lua-language-server" -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing.Source
    }

    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Warning "winget is not available. Install Lua Language Server manually or through VS Code."
        return $null
    }

    & winget install --id $LuaLsWingetId --accept-source-agreements --accept-package-agreements --disable-interactivity

    $knownPaths = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\LuaLS.lua-language-server_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\lua-language-server.exe"),
        (Join-Path $env:USERPROFILE ".vscode\extensions\sumneko.lua-3.18.1-win32-x64\server\bin\lua-language-server.exe")
    )

    foreach ($path in $knownPaths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Ensure-VsCodeExtensions {
    $code = Get-Command "code" -ErrorAction SilentlyContinue
    if (-not $code) {
        Write-Warning "VS Code CLI was not found. Skipping extension install."
        return
    }

    & code --install-extension "sumneko.lua" --force
    & code --install-extension "johnnymorganz.stylua" --force
    & code --install-extension "EditorConfig.EditorConfig" --force
}

Write-Step "Checking required commands"
$null = Assert-Command -Name "git"
$null = Assert-Command -Name "python"
$null = Assert-Command -Name "luajit"

Write-Step "Installing repo-local LuaRocks environment and Luacheck"
$luacheck = Ensure-LuaRocksEnvironment

Write-Step "Installing repo-local StyLua"
$stylua = Ensure-StyLua

Write-Step "Installing Lua Language Server"
$luaLs = Ensure-LuaLanguageServer

Write-Step "Installing recommended VS Code extensions"
Ensure-VsCodeExtensions

Write-Step "Verifying installed tools"
& $stylua --version
& $luacheck --version

if ($luaLs) {
    & $luaLs --version
} else {
    Write-Warning "Lua Language Server was not verified automatically. Re-open your shell or install it manually."
}

Write-Host ""
Write-Host "Bootstrap completed." -ForegroundColor Green
