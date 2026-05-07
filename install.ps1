<#
.SYNOPSIS
  Install cmdrvl/receipts skills on Windows. No bash required.

.DESCRIPTION
  Native Windows installer for receipts-csv. Downloads the cmdrvl spine
  binaries directly from GitHub releases (no Homebrew needed), clones
  the receipts repo, and registers the skills with each detected AI
  coding agent (Claude Code, Codex, Gemini, Cursor).

  PowerShell-only — does NOT require Git Bash, WSL2, or Cygwin to install.
  (The bash run-receipt.sh wrapper still wants a Unix shell to *run*; use
  run-receipt.ps1 instead — see README.)

.EXAMPLE
  iwr -useb https://raw.githubusercontent.com/cmdrvl/receipts/main/install.ps1 | iex

.NOTES
  Coverage: Windows x86_64. ARM64 Windows binaries are not currently
  shipped in spine releases — open an issue at
  https://github.com/cmdrvl/receipts if you need them.
#>

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/cmdrvl/receipts.git",
    [string]$Ref = "main",
    [switch]$SkipSpineInstall
)

$ErrorActionPreference = "Stop"

function Say  { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Ok   { param($Msg) Write-Host "  $([char]0x2713) $Msg" -ForegroundColor Green }
function Warn { param($Msg) Write-Host "  ! $Msg" -ForegroundColor Yellow }
function Die  { param($Msg) Write-Host "error: $Msg" -ForegroundColor Red; exit 1 }

# --- Pre-flight ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "git not found. Install Git for Windows first: https://git-scm.com/download/win"
}

$Arch = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
if ($Arch -notmatch "64") {
    Die "32-bit Windows is not supported. Receipts ships x86_64 binaries only."
}
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    Warn "ARM64 Windows detected. Spine binaries are x86_64 only; they will run via emulation."
}

# --- Detect AI coding agent skill dirs ---
Say "detecting AI coding agent skill dirs"
$Harnesses = @("claude", "codex", "gemini", "cursor", "agents")
$Detected = @()
foreach ($h in $Harnesses) {
    $dir = Join-Path $env:USERPROFILE ".$h"
    if (Test-Path $dir) {
        $Detected += $h
        Ok "found $dir"
    }
}

if ($Detected.Count -eq 0) {
    Warn "no AI coding agent dirs found; creating ~/.claude/skills as the default home"
    New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE ".claude\skills") | Out-Null
    $Detected = @("claude")
}

# --- Bundle location ---
$BundleHarness = $Detected[0]
$BundleDir = Join-Path $env:USERPROFILE ".$BundleHarness\skills\receipts-bundle"

# Back-compat: existing claude bundle
$ClaudeBundle = Join-Path $env:USERPROFILE ".claude\skills\receipts-bundle"
if (Test-Path (Join-Path $ClaudeBundle ".git")) {
    $BundleDir = $ClaudeBundle
}

New-Item -ItemType Directory -Force -Path (Split-Path $BundleDir) | Out-Null

# --- Clone or update ---
if (Test-Path (Join-Path $BundleDir ".git")) {
    Say "updating $BundleDir"
    git -C $BundleDir fetch --quiet origin $Ref
    git -C $BundleDir checkout --quiet $Ref
    git -C $BundleDir pull --quiet --ff-only origin $Ref
    Ok "repo at $(git -C $BundleDir rev-parse --short HEAD)"
} elseif (Test-Path $BundleDir) {
    Die "$BundleDir exists but is not a git repo. Move or remove it, then re-run."
} else {
    Say "cloning $RepoUrl -> $BundleDir"
    git clone --quiet --branch $Ref $RepoUrl $BundleDir
    Ok "cloned at $(git -C $BundleDir rev-parse --short HEAD)"
}

# --- Register skills with each detected harness ---
# Windows symlinks need admin or developer mode; use directory junctions
# (which don't) for the skill links.
function Link-Skill {
    param($Name, $Harness)
    $Target = Join-Path $BundleDir "skills\$Name"
    $LinkDir = Join-Path $env:USERPROFILE ".$Harness\skills"
    $Link = Join-Path $LinkDir $Name

    if (-not (Test-Path $Target)) {
        Warn "skill $Name not found at $Target -- skipping"
        return
    }
    New-Item -ItemType Directory -Force -Path $LinkDir | Out-Null

    if (Test-Path $Link) {
        $existing = Get-Item $Link -Force
        if ($existing.LinkType -in @("Junction","SymbolicLink")) {
            $current = $existing.Target | Select-Object -First 1
            if ($current -eq $Target) {
                Ok "[$Harness] $Name already linked"
                return
            }
            Warn "[$Harness] $Link points to $current -- replacing"
            Remove-Item $Link -Force -Recurse
        } else {
            Warn "[$Harness] $Link exists and is not a junction; leaving in place"
            return
        }
    }
    # Junction works without admin and without developer mode
    cmd /c mklink /J "$Link" "$Target" | Out-Null
    Ok "[$Harness] linked $Name"
}

# Clean up junctions/symlinks left over from prior install names (renames).
function Cleanup-OrphanSkill {
    param($Old, $Harness)
    $Link = Join-Path $env:USERPROFILE ".$Harness\skills\$Old"
    if (-not (Test-Path $Link)) { return }
    $existing = Get-Item $Link -Force
    if ($existing.LinkType -notin @("Junction","SymbolicLink")) { return }
    $current = $existing.Target | Select-Object -First 1
    $expected = Join-Path $BundleDir "skills\$Old"
    if ($current -eq $expected) {
        Remove-Item $Link -Force -Recurse
        Ok "[$Harness] removed orphan link: $Old (renamed)"
    }
}

Say "linking skills into $($Detected.Count) detected harness(es)"
foreach ($h in $Detected) {
    Cleanup-OrphanSkill -Old "receipts-flywheel" -Harness $h
    Link-Skill -Name "receipts-csv"     -Harness $h
    Link-Skill -Name "all-the-receipts" -Harness $h
}

# --- Spine tools (optional) ---
if ($SkipSpineInstall) {
    Say "skipping spine install (-SkipSpineInstall)"
} else {
    Say "installing cmdrvl spine tools (shape, rvl, pack) for Windows"
    & (Join-Path $BundleDir "skills\receipts-csv\scripts\install-spine.ps1")
}

# --- Next steps ---
Write-Host ""
Write-Host "ok — receipts installed." -ForegroundColor Green
Write-Host ""
Write-Host "Bundle: $BundleDir"
Write-Host "Linked into: $($Detected -join ', ')"
Write-Host ""
Write-Host "Try the bundled demo (PowerShell-native, no bash needed):"
Write-Host ""
$DemoCmd = "& '$BundleDir\skills\receipts-csv\scripts\run-receipt.ps1' " +
           "'$BundleDir\skills\receipts-csv\assets\channel-spend\agency-report.csv' " +
           "'$BundleDir\skills\receipts-csv\assets\channel-spend\bank-statement.csv' " +
           "-Key channel -Out (Join-Path $env:TEMP 'my-first-receipt')"
Write-Host "  $DemoCmd"
Write-Host ""
Write-Host "Or, in any compatible session: /receipts-csv"
Write-Host ""
Write-Host "Repo: https://github.com/cmdrvl/receipts"
