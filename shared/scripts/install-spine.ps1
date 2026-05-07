<#
.SYNOPSIS
  Install cmdrvl spine binaries on Windows. PowerShell-native, no Homebrew.

.DESCRIPTION
  Downloads pinned versions of the spine binaries (shape, rvl, pack) from
  each tool's GitHub releases, extracts the .exe to %USERPROFILE%\.cmdrvl\bin,
  and adds that directory to the user PATH if not already present.

  Idempotent — re-running with the same versions is a no-op once binaries
  exist on PATH.

.NOTES
  Architecture: x86_64 only. ARM64 Windows runs the x86_64 .exe via
  emulation. Versions are pinned in $Versions; bump as needed.
#>

[CmdletBinding()]
param(
    [string]$BinDir = (Join-Path $env:USERPROFILE ".cmdrvl\bin")
)

$ErrorActionPreference = "Stop"

# Pinned tool versions. Keep in sync with shared/scripts/install-spine.sh
# REQUIRED set. The release-asset name is "<tool>-<version>-x86_64-pc-windows-msvc.zip".
$Versions = @{
    "shape" = "0.5.0"
    "rvl"   = "0.5.1"
    "pack"  = "0.3.0"
}

function Say  { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Ok   { param($Msg) Write-Host "  $([char]0x2713) $Msg" -ForegroundColor Green }
function Warn { param($Msg) Write-Host "  ! $Msg" -ForegroundColor Yellow }

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

function Install-SpineBinary {
    param($Tool, $Version)

    $exePath = Join-Path $BinDir "$Tool.exe"
    if (Test-Path $exePath) {
        # Already installed — confirm the version matches
        try {
            $installed = & $exePath --version 2>$null | Select-Object -First 1
            if ($installed -match [regex]::Escape($Version)) {
                Ok "$Tool $Version already installed"
                return
            }
            Warn "$Tool installed at $installed; replacing with v$Version"
        } catch {
            Warn "$Tool exists but unreadable; replacing"
        }
    }

    $assetName = "$Tool-v$Version-x86_64-pc-windows-msvc.zip"
    # pack uses a different naming convention (no v-prefix on version in asset)
    if ($Tool -eq "pack") {
        $assetName = "pack-$Version-x86_64-pc-windows-msvc.zip"
    }
    $url = "https://github.com/cmdrvl/$Tool/releases/download/v$Version/$assetName"

    $tmpZip = Join-Path $env:TEMP "$Tool-$Version-receipts.zip"
    $tmpDir = Join-Path $env:TEMP "$Tool-$Version-receipts-extract"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmpZip, $tmpDir

    Say "downloading $Tool v$Version"
    Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing

    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

    # Find the .exe inside the extracted dir
    $found = Get-ChildItem -Path $tmpDir -Filter "$Tool.exe" -Recurse | Select-Object -First 1
    if (-not $found) {
        throw "Could not find $Tool.exe in extracted archive at $tmpDir"
    }

    Move-Item -Force $found.FullName $exePath
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmpZip, $tmpDir

    $verCheck = & $exePath --version 2>$null | Select-Object -First 1
    Ok "installed $Tool ($verCheck)"
}

foreach ($tool in $Versions.Keys) {
    Install-SpineBinary -Tool $tool -Version $Versions[$tool]
}

# --- Add BinDir to user PATH if missing ---
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    Say "adding $BinDir to user PATH"
    $newPath = if ([string]::IsNullOrEmpty($userPath)) { $BinDir } else { "$userPath;$BinDir" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    # Also surface in current session
    $env:Path = "$env:Path;$BinDir"
    Ok "added — open a new terminal for the change to take effect everywhere"
} else {
    Ok "$BinDir already on user PATH"
}

Write-Host ""
Write-Host "ok — spine ready." -ForegroundColor Green
Write-Host ""
Write-Host "Verify:"
Write-Host "  shape --version"
Write-Host "  rvl   --version"
Write-Host "  pack  --version"
