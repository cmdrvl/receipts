<#
.SYNOPSIS
  PowerShell port of run-receipt.sh — sealed CSV receipt, no bash needed.

.PARAMETER Old
  Path to the older CSV.

.PARAMETER New
  Path to the newer CSV.

.PARAMETER Key
  Column to align rows by. Recommended; without it, rows align by position.

.PARAMETER Out
  Output directory for the sealed pack. Must not exist or must be empty.

.PARAMETER Note
  Optional annotation written into the pack manifest.

.EXAMPLE
  .\run-receipt.ps1 nov.csv dec.csv -Key loan_id -Out C:\Temp\receipt -Note "Q4 reconciliation"

.NOTES
  Exit codes:
    0  pack created (NO_REAL_CHANGE or REAL_CHANGE; both are valid receipts)
    2  refusal — see structured envelope on stderr
#>

param(
    [string]$Old,
    [string]$New,
    [string]$Key,
    [string]$Out,
    [string]$Note
)

# Manual presence check — $Old and $New are required, but [CmdletBinding] +
# Mandatory caused parameter-binding-time failures on PowerShell 7.2 when
# invoked via `pwsh -File`. Plain check here is portable across pwsh 7.0+.
if (-not $Old -or -not $New) {
    [Console]::Error.WriteLine("usage: run-receipt.ps1 -Old <old.csv> -New <new.csv> [-Key <col>] [-Out <dir>] [-Note <text>]")
    exit 2
}

$ErrorActionPreference = "Stop"

# PowerShell 7.4+ introduced $PSNativeCommandUseErrorActionPreference which,
# under "Stop", turns any non-zero exit from a native command (shape, rvl,
# pack) into a terminating exception. We handle exit codes manually below
# via $LASTEXITCODE so we can map specific values to specific messages and
# our own exit code. Disable the native-command error escalation so our
# explicit checks actually run.
$PSNativeCommandUseErrorActionPreference = $false

# Print to stderr without throwing — Write-Error under "Stop" turns into a
# terminating exception, which leaves the wrapper exiting 1 (from the uncaught
# throw) instead of the intended exit code. Use this helper for all
# user-facing error messages that should be paired with an explicit exit.
function Write-Stderr { param([string]$Msg) [Console]::Error.WriteLine($Msg) }

if (-not (Test-Path $Old)) { Write-Stderr "not found: $Old"; exit 2 }
if (-not (Test-Path $New)) { Write-Stderr "not found: $New"; exit 2 }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("receipts-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    $shapeReport = Join-Path $work "shape.report.json"
    $rvlReport   = Join-Path $work "rvl.report.json"
    $packOut     = Join-Path $work "pack.out"

    # Build the spine flags arrays
    $keyArgs = @()
    if ($Key) { $keyArgs = @("--key", $Key) }

    # --- shape ---
    Write-Host "==> shape"
    $shapeArgs = @($Old, $New) + $keyArgs + @("--json", "--no-witness")
    & shape @shapeArgs > $shapeReport
    if ($LASTEXITCODE -ne 0) {
        Write-Stderr "shape REFUSAL — structural incompatibility:"
        Get-Content $shapeReport | ForEach-Object { Write-Stderr $_ }
        exit 2
    }
    $shape = Get-Content $shapeReport | ConvertFrom-Json
    Write-Host "  shape: $($shape.outcome)"

    # --- rvl ---
    Write-Host "==> rvl"
    $rvlArgs = @($Old, $New) + $keyArgs + @("--json", "--no-witness")
    & rvl @rvlArgs > $rvlReport
    $rvlExit = $LASTEXITCODE
    if ($rvlExit -eq 2) {
        Write-Stderr "rvl REFUSAL:"
        Get-Content $rvlReport | ForEach-Object { Write-Stderr $_ }
        exit 2
    }
    $rvl = Get-Content $rvlReport | ConvertFrom-Json
    Write-Host "  rvl:   $($rvl.outcome)"
    if ($rvl.outcome -eq "REAL_CHANGE") {
        $cells = $rvl.counts.numeric_cells_changed
        $rows  = $rvl.counts.rows_aligned
        $total = $rvl.metrics.total_change
        Write-Host "  rvl:   $cells cells changed across $rows aligned rows"
        Write-Host "  rvl:   total numeric movement: $total"
    }

    # --- pack seal ---
    Write-Host "==> pack seal"
    $packArgs = @("seal", $shapeReport, $rvlReport, "--no-witness")
    if ($Out)  {
        New-Item -ItemType Directory -Force -Path $Out | Out-Null
        $packArgs += @("--output", $Out)
    }
    if ($Note) { $packArgs += @("--note", $Note) }
    & pack @packArgs > $packOut 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Stderr "pack REFUSAL:"
        Get-Content $packOut | ForEach-Object { Write-Stderr $_ }
        exit 2
    }

    $createdLine = Get-Content $packOut | Where-Object { $_ -like "PACK_CREATED *" } | Select-Object -First 1
    $packId = ($createdLine -split " ")[1]
    $packDir = Get-Content $packOut | Select-Object -Skip 1 -First 1

    Write-Host ""
    Write-Host "  pack_id: $packId"
    Write-Host "  pack:    $packDir"
    Write-Host ""

    # --- pack verify ---
    Write-Host "==> pack verify"
    & pack verify $packDir --no-witness > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Stderr "verify FAILED"
        exit 1
    }
    Write-Host "  verify: OK"
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $work
}
